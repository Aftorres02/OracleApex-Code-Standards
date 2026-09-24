---
name: oracle-performance-investigation
description: Diagnose and fix a slow Oracle refresh/query using real execution evidence (V$SQL_MONITOR + DBMS_XPLAN.DISPLAY_CURSOR, not EXPLAIN PLAN FOR) and a mechanism-by-mechanism testing discipline. Load when a materialized view refresh, report query, or batch job is slow/timing out and the cause isn't obvious from reading the DDL.
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

## 1. Get the REAL execution plan, not a hypothetical one

`EXPLAIN PLAN FOR <query>` shows the plan Oracle *would* choose for that
literal text parsed fresh — it is not guaranteed to match what a stored
view/MV actually executes, because query rewrite can rename subqueries and
columns (`from$_subquery$_NNN`, `COL_N`) and can restructure the query
entirely (see §2). Always get the plan of the statement that *actually ran*:

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
   (see §4) that never appears in the DDL you're reading.

See [`find_real_plan.sql`](find_real_plan.sql) for a ready-to-run version
of steps 2-3, parameterized by a target-object-name substring.

---

## 2. UNPIVOT silently multiplies everything upstream of it

The optimizer rewrites `UNPIVOT` into one `UNION ALL` branch **per
unpivoted column**. Any join, subquery, or remote database-link access
that sits in the source feeding the `UNPIVOT` gets re-executed once per
branch — a 37-column unpivot means a 37x (really 38x, counting the
original) repeat of everything upstream, including an expensive remote
call, and this is completely invisible from reading the view's DDL. It
only shows up by counting `REMOTE` / join operations in the *real* plan
from §1.

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

## 3. Measure the real operation, not a proxy for it

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
  easily produce a false improvement otherwise.

---

## 4. Comparing NVARCHAR2 against VARCHAR2 breaks things quietly

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
  predicate from §1. Before creating an index to speed up a join, check
  the real predicate first — it may not be the raw column you expect, and
  the index may need a matching function-based definition (or the
  upstream expression needs an explicit `cast(... as varchar2(...))`) to
  actually be usable.

---

## 5. Mechanism-by-mechanism testing discipline

When there are multiple candidate fixes, **never apply more than one at a
time, and never touch the live object until a candidate is chosen**:

1. Number each candidate mechanism as you identify it.
2. Test it in isolation against a separate test object (suffix the
   compiled object name `_M<N>`, e.g. `create materialized view
   my_mv_m3 (...) build deferred as select ...`) — never rename the
   underlying *file*, so `git diff` keeps showing the real history of what
   changed between rounds even as the compiled object name inside changes
   per round.
3. For each mechanism, in order: (a) measure with the real operation
   (§3), (b) verify **exact** data equivalence against the live object —
   same row count, `MINUS` in **both** directions (`candidate minus live`
   and `live minus candidate`, both must be 0 rows), plus a column-by-column
   spot check keyed on a natural key, (c) only then move to the next
   mechanism or combine it with an already-proven one.
4. Keep a timing log — one row per environment/mechanism/run, never
   overwritten, so the full iteration history stays visible (which
   candidate was tried when, on what data volume, with what result).
   Compare same-environment-to-itself only; different environments can
   have wildly different data volumes and are not directly comparable.
5. Once a mechanism is chosen: apply it to the real tracked file/object,
   validate the same way (snapshot the live object's data before
   replacing it, recreate, `MINUS` the new object against the snapshot in
   both directions), **then** drop every `_M<N>` test artifact — test
   MVs/views, packages, types — in every environment they were created,
   keeping only what's actually adopted (the final object, and any index
   that measurably helps or is provably harmless).
6. If you don't have write access to every environment (e.g. only a DEV
   connection is available), don't skip STG/PROD cleanup — prepare a
   self-contained, idempotent script (guard every `drop` against
   "object doesn't exist" so it's safe to run without knowing exactly
   what's there) and hand it to whoever has access, rather than guessing.
7. Organize scripts and results **one folder per mechanism** as you go
   (script + result file(s) together) — this is what makes an
   investigation like this auditable after the fact instead of a pile of
   loose files with numbers in their names.

---

## 6. Miscellaneous gotchas (if re-implementing SQL logic in PL/SQL)

Only relevant if a candidate involves hand-porting a SQL expression into
PL/SQL (e.g. inside a pipelined function) instead of keeping it as SQL:

- `TO_CHAR(number_var, '000')` in PL/SQL does **not** apply the same
  implicit formatting SQL does for a positive number (SQL reserves a
  leading sign-space even for positives; a PL/SQL `varchar2` holding a
  numeric-looking value passed through `TO_CHAR` skips this). Force
  `TO_NUMBER()` first if you need to match SQL's exact output —confirm
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
`DBMS_XPLAN.DISPLAY_CURSOR`. Run the real operation first (§1), then this
script, passing a substring of the target object's name.
