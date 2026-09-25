---
name: oracle-performance-investigation
description: Diagnose and fix a slow Oracle refresh/query using real execution evidence (V$SQL_MONITOR + DBMS_XPLAN.DISPLAY_CURSOR, not EXPLAIN PLAN FOR), a hypothesis-driven diagnostic phase, and a mechanism-by-mechanism testing/documentation discipline. Load when a materialized view refresh, report query, or batch job is slow/timing out and the cause isn't obvious from reading the DDL.
---

# Oracle Performance Investigation

A repeatable methodology for tracking down *why* a real Oracle operation
(most often `dbms_mview.refresh`, but the same approach applies to any slow
query or PL/SQL batch job) is slow, proposing candidate fixes, and proving
each one is both faster and data-safe before it touches a real object.
Distilled from a real investigation (Issue 440: a materialized view refresh
that took 23+ minutes in PROD, brought down to under 20 seconds).

> This is a methodology, not a checklist to rush through. The core
> discipline is: **never trust a hypothetical plan or an assumption about
> where the time goes — always get real evidence, and always prove
> equivalence before adopting a candidate.**

> For a quick, read-only, no-database-connection check of a single SQL
> file (formatting compliance, obvious smells like a missing index visible
> in the same file), use the `sql-perf-reviewer` agent instead — this skill
> is for when that isn't enough and the slowness needs to be reproduced and
> measured against a real environment.

---

## 1. Start from a hypothesis, proven by a read-only diagnostic

Before writing a single candidate fix, spend a round on **read-only**
diagnostics that test one hypothesis at a time about where the time or the
row-count actually inflates — don't assume it from reading the DDL.

- Isolate one join/predicate at a time. A common pattern: start from the
  base query and add each join back one at a time, watching the row count
  after each addition — this pinpoints exactly which join causes a fan-out,
  and by how much, instead of guessing from the view's structure.
- Time a suspect subquery/expression **standalone** to sanity-check it, but
  don't let a fast standalone number rule it out completely — the same
  expression can become the dominant cost once it's re-evaluated per row in
  a different context (e.g. after an `UNPIVOT`, see §3). A hypothesis is
  only rejected once it's tested *in the actual shape it runs in*, not in
  isolation.
- State each hypothesis explicitly and record whether the diagnostic
  confirmed or rejected it, before moving to the next one. This read-only
  phase is what produces the initial list of candidate mechanisms for the
  options document (§6) — every mechanism should trace back to a confirmed
  hypothesis, not a guess.

---

## 2. Get the REAL execution plan, not a hypothetical one

`EXPLAIN PLAN FOR <query>` shows the plan Oracle *would* choose for that
literal text parsed fresh — it is not guaranteed to match what a stored
view/MV actually executes, because query rewrite can rename subqueries and
columns (`from$_subquery$_NNN`, `COL_N`) and can restructure the query
entirely (see §3). Always get the plan of the statement that *actually ran*:

1. Trigger the real operation (e.g. `dbms_mview.refresh(...)`).
2. Find its `SQL_ID` and `CHILD_NUMBER` via `V$SQL_MONITOR` — Oracle
   auto-tracks any statement running longer than ~5 seconds, which a slow
   refresh always will be. This also sidesteps two dead ends:
   - `V$SQL.SQL_TEXT` truncates at 1000 characters, so searching by a
     literal string that appears later in a long generated query silently
     fails — search by the **target object name** instead
     (`upper(sql_text) like '%MY_TARGET_OBJECT%'`).
   - `V$SQL_FULLTEXT` does not exist in every schema (`ORA-00942`); don't
     rely on it being there. `V$SQL.LAST_ACTIVE_TIME` can also come back
     blank/unreliable — use `V$SQL_MONITOR.SQL_EXEC_START` /
     `ELAPSED_TIME` to find and rank the right execution instead.
3. Pull the real plan with real predicates and real row counts:
   ```sql
   select *
     from table(
       dbms_xplan.display_cursor(
           sql_id        => '<sql_id>'
         , cursor_child_no => <child_number>
         , format        => 'ALLSTATS LAST +COST +PREDICATE'
       )
     );
   ```
   The `Predicate Information` section at the bottom is what actually ran
   — this is where you'll find things like an unexpected `SYS_OP_C2C()`
   (see §5) that never appears in the DDL you're reading.

See [`find_real_plan.sql`](find_real_plan.sql) for a ready-to-run version
of steps 2-3, parameterized by a target-object-name substring.

---

## 3. UNPIVOT silently multiplies everything upstream of it

The optimizer rewrites `UNPIVOT` into one `UNION ALL` branch **per
unpivoted column**. Any join, subquery, or remote database-link access
that sits in the source feeding the `UNPIVOT` gets re-executed once per
branch — a 37-column unpivot means a 37x (really 38x, counting the
original) repeat of everything upstream, including an expensive remote
call, and this is completely invisible from reading the view's DDL. It
only shows up by counting `REMOTE` / join operations in the *real* plan
from §2.

**Fix pattern:** add `/*+ materialize */` to the `WITH`-clause CTE that
wraps the pre-`UNPIVOT` source:

```sql
with w_base as (
  select /*+ materialize */
         d.*
    from expensive_remote_or_joined_source d
)
select ...
  from (select * from w_base)
  unpivot (...) s
```

This forces Oracle to resolve the CTE **once**, into a temporary segment,
before the `UNPIVOT` expands it — confirm it worked by checking the real
plan again for a `TEMP TABLE TRANSFORMATION` step and a drop in remote/join
access count. This is pure SQL — no PL/SQL required — and was the smallest
possible fix once the root cause was understood (a PL/SQL pipelined
function wrapping the exact same query "accidentally" fixed the same
problem, because the optimizer treats a pipelined function as an opaque
black box and can't unpivot-duplicate what's inside it — but that carries
a much bigger surface area to maintain than one hint. **Look for the SQL-only
fix before committing to a PL/SQL rewrite that happens to dodge the issue.**)

---

## 4. Measure the real operation, not a proxy for it

- `dbms_mview.refresh(...)` with the default `atomic_refresh => true` does
  a transactional **DELETE + INSERT**, not a truncate. Timing a
  `CREATE MATERIALIZED VIEW ... BUILD IMMEDIATE` instead (a direct-path
  insert) exercises a different code path and can differ from the real
  refresh by roughly 5-20% at small-to-medium row counts. It's an
  acceptable quick proxy for an early read, but always confirm the real
  number with an actual `dbms_mview.refresh()` call before calling any
  result final — note the gap explicitly if you report the proxy number
  first.
- If a candidate needs `BUILD IMMEDIATE` and its query touches a table
  over a database link from inside a PL/SQL pipelined function, expect
  `ORA-12840` (remote access isn't allowed inside a direct-path insert's
  transaction). Use `BUILD DEFERRED` followed by a separate
  `dbms_mview.refresh()` call instead — this sidesteps the error **and**
  is the more correct comparable measurement anyway, per the point above.
- Re-run a known "control" measurement immediately before/after the
  candidate under test, **in the same session**, before trusting a timing
  difference — buffer-cache warmth from a prior run of the same query can
  easily produce a false improvement otherwise. This same warm-cache
  discipline applies again in §9 when isolating whether an index actually
  helped.

---

## 5. Comparing NVARCHAR2 against VARCHAR2 breaks things quietly

Tables sourced from a remote/legacy system are often `NVARCHAR2`; local
tables and PL/SQL types are usually `VARCHAR2`. Two consequences:

- **`MINUS`/set comparisons** between the two throw
  `ORA-12704: character set mismatch`. Wrap every text column on both
  sides in an explicit `cast(col as varchar2(N char))` before comparing.
- **Joins and predicates**: concatenating an `NVARCHAR2` column with
  `VARCHAR2` literals (`nvarchar_col || ' - ' || other_col`) promotes the
  whole expression to `NVARCHAR2`. If that gets compared/joined against a
  genuinely `VARCHAR2` column elsewhere, Oracle silently wraps one side in
  `SYS_OP_C2C()` to reconcile the character sets — and a plain B-tree
  index on the `VARCHAR2` side then **cannot** be used cleanly for that
  predicate. This never appears in the DDL; it only shows up in the real
  predicate from §2. Before creating an index to speed up a join, check
  the real predicate first (§9) — it may not be the raw column you expect,
  and the index may need a matching function-based definition (or the
  upstream expression needs an explicit `cast(... as varchar2(...))`) to
  actually be usable.

---

## 6. Documentation workflow: two living documents

Keep two separate documents for the whole investigation, both updated as
you go — not written up after the fact:

**An options/mechanisms document** — the single source of truth for the
analysis. A numbered table, one row per candidate mechanism, with columns
for what it attacks, its cost/risk, whether it's been tested, and the
result. Add a row the moment a mechanism is identified (from §1's
diagnostics), even before it's tested — the point is an honest record of
everything *considered*, not just what worked. Update it after every
finding: a confirmed hypothesis, a rejected candidate, a root-cause
discovery, an index experiment, the final decision and why it beat the
alternatives.

**A timing log** — a separate, append-only, flat table: one row per
environment/mechanism/run, with date, environment, exactly what was
measured, duration, row count, result file, and notes. **Never overwrite a
row**, even one that turned out to be superseded or wrong — the value is a
complete chronological record of how the number moved and what was tried
when, not a clean final table. Compare same-environment-to-itself only —
different environments can have wildly different data volumes and are not
directly comparable to each other.

Keeping these separate matters: the options document is prose-and-table
*analysis* (why), the timing log is a flat factual *record* (what
happened, when) — mixing narrative into the timing log or raw numbers into
the options document makes both harder to scan later.

---

## 7. Mechanism-by-mechanism testing discipline

When there are multiple candidate fixes, **never apply more than one at a
time, and never touch the live object until a candidate is chosen**:

1. Test each mechanism in isolation against a separate test object (suffix
   the compiled object name `_M<N>`, e.g. `create materialized view
   my_mv_m3 (...) build deferred as select ...`) — never rename the
   underlying *file*, so `git diff` keeps showing the real history of what
   changed between rounds even as the compiled object name inside changes
   per round.
2. For each mechanism, in order: (a) measure with the real operation
   (§4), logging it in the timing log (§6); (b) verify **exact** data
   equivalence against the live object — same row count, `MINUS` in
   **both** directions (`candidate minus live` and `live minus candidate`,
   both must be 0 rows), plus a column-by-column spot check keyed on a
   natural key; (c) only then move to the next mechanism or combine it
   with an already-proven one, updating the options document either way.
3. Generate the test/measurement script itself so it's reusable
   across mechanisms and environments (see §8) rather than one-off and
   hand-edited per run — the equivalence check in particular (with its
   `cast(... as varchar2(...))` handling from §5) is worth writing once and
   reusing for every mechanism.

---

## 8. Environment-adaptive test scripts

The same test/measurement script needs to run safely and unambiguously
across DEV/STG/PROD — different data volumes, and sometimes a database
that reports a different name for what the team colloquially calls an
environment (confirm this once, don't assume the database's own label
matches the team's name for it).

- Detect the environment programmatically at the top of the script (a
  project's own environment-lookup function, or `sys_context('userenv',
  ...)` if there isn't one) rather than hardcoding an environment name in
  the script. A hardcoded label is exactly the kind of thing that silently
  mislabels a result the first time the same script gets reused somewhere
  else.
- Use the detected environment to name the result/spool file
  unambiguously, so a result can never be mistaken for a different
  environment's run later.
- Keep the script otherwise identical across environments — the whole
  point of environment-detection is that one script is trustworthy
  everywhere, instead of a hand-modified copy per environment that can
  drift out of sync with the others.

---

## 9. Indices: a mini-investigation of their own

Don't add an index speculatively — treat each candidate index as its own
small hypothesis to prove, the same discipline as §1:

1. Confirm the column truly has no covering index already
   (`user_indexes`/`user_ind_columns`), and confirm which side of the join
   is even indexable — a view over a remote table/db link is not.
2. Create the index in isolation, then re-measure the same candidate
   mechanism with a cache-warmed control run immediately before/after
   (§4).
3. Check the REAL plan again (§2) to confirm the index is actually used
   **for that predicate**, and that it's used the way you'd expect — a
   full index scan replacing a full table scan is not the same as a
   selective range/unique scan, and may not translate into a real time
   improvement even though "the index is used."
4. Don't assume a measured improvement came from the index just added — a
   before/after real-plan comparison is the only way to attribute it
   correctly; cache warmth or an unrelated plan change can produce a
   misleading number.
5. An index with no measurable benefit but no real downside (doesn't
   meaningfully slow writes, isn't a near-duplicate of an existing index)
   can still be kept if it plausibly helps other consumers of the same
   table — but say so explicitly in the options document rather than
   implying it's part of the confirmed fix.

---

## 10. Adopt the winner, then clean up

1. Apply the chosen mechanism to the real tracked file/object. Validate
   the same way as every other mechanism: snapshot the live object's data
   before replacing it, recreate, `MINUS` the new object against the
   snapshot in both directions (§7).
2. Drop every `_M<N>` test artifact — test MVs/views, packages, types — in
   **every** environment they were created, keeping only what's actually
   adopted (the final object, and any index that measurably helps or is
   provably harmless per §9).
3. If you don't have write access to every environment (e.g. only a DEV
   connection is available), don't skip STG/PROD cleanup — prepare a
   self-contained, idempotent script (guard every `drop` against
   "object doesn't exist" so it's safe to run without knowing exactly
   what's there) and hand it to whoever has access, rather than guessing.
4. Organize scripts and results **one folder per mechanism** as you go
   (script + result file(s) together) — this is what makes an
   investigation like this auditable after the fact instead of a pile of
   loose files with numbers in their names.

---

## 11. Miscellaneous gotchas (if re-implementing SQL logic in PL/SQL)

Only relevant if a candidate involves hand-porting a SQL expression into
PL/SQL (e.g. inside a pipelined function) instead of keeping it as SQL:

- `TO_CHAR(number_var, '000')` in PL/SQL does **not** apply the same
  implicit formatting SQL does for a positive number (SQL reserves a
  leading sign-space even for positives; a PL/SQL `varchar2` holding a
  numeric-looking value passed through `TO_CHAR` skips this). Force
  `TO_NUMBER()` first if you need to match SQL's exact output — confirm
  byte-for-byte with `DUMP()` if the mismatch is subtle.
- `col1 || literal || col2` in SQL never returns pure `NULL` unless
  **every** operand is `NULL` (`NULL` is treated as an empty string
  otherwise) — a `LEFT JOIN`'s "no match" row still produces the literal
  glue text. A PL/SQL re-implementation must replicate this
  unconditionally (always concatenate), not gate the concatenation on
  "was there a match".
- `PIPE ROW` may only appear directly in a pipelined function's own
  executable section — never inside a subprogram it calls. Split
  dedup/helper logic into a boolean-returning helper function instead, and
  keep the actual `pipe row(...)` call inline in the pipelined function.

---

## Reference

[`find_real_plan.sql`](find_real_plan.sql) — finds the `SQL_ID` of the
most recent long-running statement matching a target object name via
`V$SQL_MONITOR`, then displays its real execution plan with predicates via
`DBMS_XPLAN.DISPLAY_CURSOR`. Run the real operation first (§2), then this
script, passing a substring of the target object's name.
