---
name: oracle-optimizer-hints
description: Decide whether an Oracle optimizer hint is justified, pick the right one, write it so it is actually applied, prove it with the 19c+ Hint Usage Report, and choose how to deliver it (in code, SQL Patch, or SQL Plan Baseline). Applies to ANY Oracle SQL — PL/SQL packages, static/dynamic SQL, views, CTEs, batch/ETL loads (APPEND, FORALL + APPEND_VALUES), scripts — with an extra section for Oracle APEX (the Optimizer Hint attribute, APEX$ pseudo hints, APEX_EXEC p_optimizer_hint). Covers every documented hint 19c–26ai, undocumented hints found in outlines, and Autonomous Database defaults; behaviour verified on 26ai. Load before writing, reviewing or removing any /*+ … */ or --+ hint, before filling an APEX Optimizer Hint attribute, and whenever someone asks to "add a hint" to fix a slow query, package, report, APEX region, or bulk load.
---

# Oracle Optimizer Hints

The team guide to optimizer hints: **when** one is legitimate, **which**
one, **how** to write it so it applies, and **how to prove it**.

It is **database-first**. Everything except [`apex.md`](apex.md) applies to
any Oracle code — package bodies, standalone scripts, views, scheduler
jobs, reports, and SQL from any client. APEX is one more layer on top:
it wraps your query in its own SQL, so it adds a few rules, but it never
changes the database rules. The behaviour described here was
[verified on 26ai](validation-26ai.md), and
[`validate_hints.sql`](validate_hints.sql) re-checks it on your version.

This skill
does not replace the packaged Oracle skill (`db:db` → `sql-dev/sql-tuning.md`,
`performance/explain-plan.md`) — that one covers general tuning. This one
goes deep on hints, and corrects a few things the packaged skill gets wrong
(see [`sources.md`](sources.md#review-notes-on-the-packaged-oracle-skill-githubcomoracleskills)).

| File | Use it for |
|---|---|
| [`hint-catalog.md`](hint-catalog.md) | Every documented hint by category — syntax, inverse, version, and our verdict. Also undocumented and deprecated hints. |
| [`diagnostics.md`](diagnostics.md) | Getting a real plan, reading the Hint Report, query block names, Outline Data, SQL Patch, SPM, `OPTIMIZER_IGNORE_HINTS` |
| [`sql-and-plsql.md`](sql-and-plsql.md) | **Any Oracle code, no APEX needed**: where hints can live, PL/SQL static and dynamic SQL, direct path (`APPEND` / `FORALL` + `APPEND_VALUES`), upserts, `RESULT_CACHE`, db links, views and CTEs, `WITH_PLSQL`, Autonomous Database |
| [`apex.md`](apex.md) | **APEX only**: the Optimizer Hint attribute and the SQL wrapper APEX generates, `APEX$` pseudo hints, `APEX_EXEC`, finding and auditing APEX SQL, APEX on ADB |
| [`validation-26ai.md`](validation-26ai.md) · [`validate_hints.sql`](validate_hints.sql) | What was executed on Oracle AI Database 26ai + APEX 26.1 and what happened, plus a re-runnable script for your own database |
| [`sources.md`](sources.md) | Official docs, Optimizer blog, experts, videos — and review notes on the packaged skill |

The formatting rules for a hint that *does* get committed live in
[`sql-format.md`](../../rules/sql-format.md) §13.

---

## What a hint really is

A hint is a **directive, not a suggestion**. Whenever it is valid and
applicable, the optimizer obeys it. When a hint "is ignored", it is
almost always one of these:

- **Invalid**: misspelled, wrong alias, a schema-qualified name, or a
  missing argument.

- **Not applicable**: `use_hash` on a non-equality join, `use_nl(x)` when
  `x` ended up as the outer table, `full` on an IOT.

- **In the wrong query block**, or **lost to a query transformation**.

- **In conflict** with another hint, in which case both are dropped.

- **Incomplete**: it pinned one decision and left the optimizer free to
  choose the rest.

Oracle introduced hints as a *testing* tool for the cost-based optimizer.
Its official position, stated in the SQL Language Reference, is to use
them sparingly — after gathering statistics and evaluating the unhinted
plan — and to prefer SQL Plan Management, SQL Tuning Advisor and SQL
Performance Analyzer, because *"any short-term benefit … may not continue …
over the long term."*

> **Note:** not every hint is a plan-shaping optimizer hint. `APPEND`,
> `DRIVING_SITE`, `RESULT_CACHE`, `FIRST_ROWS(n)`, `QB_NAME`, the parallel
> family and the semantic `IGNORE_ROW_ON_DUPKEY_INDEX` change *how* a
> statement executes or state an intent the optimizer can't know. Those are
> normal tools, and the "last resort" rule applies to plan-shaping hints.
> The catalog's **Team use** column tells you which is which.

---

## The workflow

Follow these steps in order. Most tuning ends at Step 3 without any hint.

### Step 1 — Reproduce and measure

Get the *actual* plan with actual row counts from the cursor cache — not
from `explain plan`:

```sql
select /*+ gather_plan_statistics */ …;          -- the slow statement, real binds

select *
  from table(dbms_xplan.display_cursor(
           format => 'ALLSTATS LAST +PEEKED_BINDS +ALIAS +HINT_REPORT'
       ));
```

For a full investigation of a slow operation against a live database —
`V$SQL_MONITOR`, `find_real_plan.sql`, `STARTS`, and proving equivalence
of candidate fixes — follow the
[`oracle-performance-investigation`](../oracle-performance-investigation/SKILL.md)
skill, and come back here at Step 4 when a hint is on the table.

In a package, find the cursor in `v$sql` — PL/SQL uppercases static SQL
and turns variables into `:B1` ([`sql-and-plsql.md`](sql-and-plsql.md)).
For an APEX region, capture the SQL APEX really runs, because APEX wraps
your query ([`apex.md`](apex.md#see-the-sql-apex-actually-ran)).

### Step 2 — Find where the estimate breaks

Walk the plan and find the **first** line where `E-Rows` and `A-Rows`
differ by an order of magnitude or more. A cardinality misestimate is the
leading cause of bad join orders, wrong join methods, and wrong index vs
full-scan choices. Hinting the symptom downstream of it treats the wrong
thing.

### Step 3 — Fix the root cause first

| Symptom at the diverging line | Fix, before any hint |
|---|---|
| Stale or missing statistics, a table loaded after the stats job | `dbms_stats.gather_table_stats` — and schedule it after bulk loads |
| Skewed column in the predicate | A histogram (`method_opt … size auto`) |
| Correlated columns (`country = 'PE' and city = 'LIMA'`) | Extended statistics (a column group) |
| Function on the column (`upper(email) = …`), implicit conversion (`varchar2_col = 123`) | A function-based index or virtual column, or matching data types (the Predicate section shows `TO_NUMBER(…)`) |
| No index supports the selective predicate or join | An index — see `ddl-conventions.md` for naming |
| Row-by-row PL/SQL, `select` in a loop | Set-based SQL, `bulk collect` / `forall` |
| The query shape forces bad work (`union` vs `union all`, a filter applied late) | Rewrite it — the filter-first CTE, `sql-format.md` §12 |
| A plan regression after an upgrade or a stats change | A SQL Plan Baseline for the old good plan, then investigate |

### Step 4 — Decide whether a hint is legitimate

Look the hint up in [`hint-catalog.md`](hint-catalog.md) and apply its
**Team use** verdict:

| Verdict | Examples | Rule |
|---|---|---|
| **Allowed** | `first_rows(n)`, `append`/`append_values` in batch loads, `driving_site`, `result_cache` on small lookups, `qb_name`, `parallel` in batch jobs, `no_gather_optimizer_statistics` | Commit it with the justification comment (`sql-format.md` §13) |
| **Last resort** | `leading`, `use_nl`/`use_hash`, `index`/`full`, `no_merge`, `unnest`, `opt_param`, `optimizer_features_enable` | Only when Step 3 can't fix it, with the plan evidence in the comment, and as a **complete** set (Step 5). Prefer delivering it through Step 7's patch or baseline. |
| **Diagnostic** | `gather_plan_statistics`, `monitor`, `no_query_transformation` | Use during investigation. Never commit it. |
| **Niche** | Star/In-Memory/XML/vector/multitenant hints | Only where that feature is really in use |
| **Avoid** | `rule`, `ordered`, `index_desc`, undocumented estimate hints (`cardinality`, `opt_estimate`), `inline` | Don't commit them. Find the documented equivalent or fix the root cause. The one undocumented exception is `materialize` as a *Last resort*, backed by `STARTS` evidence — see the catalog. |

A hint is **also** the right tool when:

- you know something the optimizer can't: "only the first 25 rows are ever
  shown", "the remote table is the big one";

- you are *testing* whether a different plan is better;

- or you are applying triage to stop an incident right now — then move the
  fix to a SQL Plan Baseline (Step 7) and remove the hint.

### Step 5 — Write it so it applies

- **Placement**: immediately after the `select` / `insert` / `update` /
  `delete` / `merge` keyword that opens the query block it targets. There
  is only one hint comment per block, and a second one is just a comment.
  Write `/*+` with no space between `*` and `+`.

- **Name tables by alias**, exactly as in the `from` clause. Never use the
  table name when there's an alias, and never `schema.table`. Both come
  back as `N — unresolved` on 26ai, and on 19c a schema-qualified hint
  doesn't even appear in the report.

- **Hint in the block where the table lives**, or target it from outside
  with `qb_name(x)` in the inner block and `@x` in the hint. Get
  system-generated names from `+ALIAS`. Don't rely on dot-notation
  `view.alias`: it fails across multiple query blocks and with ANSI joins.

- **Join methods need an order.** `use_nl(t)`, `use_hash(t)` and
  `use_merge(t)` mean "when joining *into* `t` (as the inner table), use
  this method". Pair them with `leading(…)`, and write one alias per hint:
  `use_nl(c) use_nl(ol)`, not `use_nl(c ol)`.

- **Hint completely.** For a multi-table join: the join order (`leading`
  with *every* table), the join method into each non-leading table, and the
  access path where it matters. A partial set works today and drifts
  tomorrow. The only complete set is the Outline Data (`+OUTLINE`), and at
  that point you want SPM, not code.

- **Index hints by column list** when you can:
  `index(o (customer_id order_date))` survives index renames and
  environment differences. A hinted index name that doesn't exist is
  silently unresolved.

- **Know the transformations.** View merging and subquery unnesting reshape
  the query before join order is decided, which can invalidate
  `leading`/`ordered`. Add `no_merge` / `no_unnest` deliberately, or hint
  the final query block from `+ALIAS`.

- **No prose inside the hint comment.** Verified on 26ai: free text, or
  an unknown word with parentheses, makes Oracle silently drop every hint
  written after it. Put the explanation in the justification comment
  above the statement.

### Step 6 — Prove it with the Hint Report

Re-run the statement and display it with `+HINT_REPORT` (19c+). Every
committed hint must appear **without** a marker:

| Marker | Meaning | Action |
|---|---|---|
| `E` | Syntax error. If it has `(…)` or is free text, the hints after it are dropped too. APEX `APEX$…` pseudo hints show `E` by design. | Fix the spelling or arguments |
| `N` | Unresolved — the alias, index or query block doesn't exist there | Fix the alias, use `@qb`, check the index name |
| `U` | Unused — valid but not applicable in the final plan | Add the missing `leading`, check the join type, check for a transformation or a conflict |
| No line at all | A hint after a syntax error, a second hint comment, `/* +` with a space, a hint not right after the keyword, a schema-qualified name on 19c — or `append` / `append_values`, which the report doesn't cover | Fix the syntax. For direct path, check the plan: `LOAD AS SELECT` vs `LOAD TABLE CONVENTIONAL`. |

Then confirm the **benefit**: compare `A-Time` and `Buffers` with and
without the hint, using the same binds. A used hint that doesn't make the
statement faster is still dead weight.

### Step 7 — Choose the delivery vehicle

| Situation | Deliver it as |
|---|---|
| A behavioural or intent hint that belongs with the code (`append`, `first_rows(n)`, `driving_site`, `result_cache`) | An in-code hint |
| You need a plan-shaping fix for SQL you shouldn't edit — APEX-generated SQL, a vendor package, an emergency — or you need to **disable** bad embedded hints | A **SQL Patch** (`dbms_sqldiag.create_sql_patch`, with `@qb`-qualified hints or `ignore_optim_embedded_hints`) |
| You want plan stability for a critical statement, or you found the good plan *with* hints | A **SQL Plan Baseline** of the hinted plan, loaded onto the **unhinted** statement (`dbms_spm.load_plans_from_cursor_cache` with `sql_handle`). Then remove the hints. |
| SQL Tuning Advisor found estimate corrections | Accept the **SQL Profile** (Tuning Pack) |

The recipes are in [`diagnostics.md`](diagnostics.md#deliver-a-hint-without-touching-the-code).

### Step 8 — Document it, and re-validate on every upgrade

- Write the justification comment required by `sql-format.md` §13: why,
  evidence, date, author, ticket. Hints that go in without a reason never
  come out.

- After every database upgrade, re-run the hinted statements with
  `alter session set optimizer_ignore_hints = true;` and compare. Old hints
  block new optimizer features such as adaptive cursor sharing, new
  transformations and batched rowid access. Remove the ones that no longer
  win.

---

## Environment gotchas

### Any Oracle code

- **Autonomous Database — Lakehouse** (formerly ADW) ignores optimizer and
  `PARALLEL` hints by default. Transaction Processing, JSON and APEX
  Service honour them.

- **`APPEND` on our standard tables does nothing.** Our tables all have a
  compound audit trigger and usually FKs, so direct path silently falls
  back to a conventional insert. On 26ai the plan's *Note* says so. Load
  through a trigger-less, FK-less staging table.

- **`OPTIMIZER_IGNORE_HINTS = TRUE`** and the `IGNORE_OPTIM_EMBEDDED_HINTS`
  hint in a SQL Patch switch off only the CBO-class hints. Verified on
  26ai: `index`, `full`, `leading` and the like are rejected, while
  `append` and `result_cache` keep working. `PARALLEL` hints have their
  own parameter, `OPTIMIZER_IGNORE_PARALLEL_HINTS`.

- **`with function` in a subquery needs `/*+ with_plsql */`** on the
  top-level statement, through every API (verified on 26ai). A `count(*)`
  test can hide the error.

- **Hints never raise errors.** The three semantic hints
  (`ignore_row_on_dupkey_index`, `change_dupkey_error_index`,
  `retry_on_row_change`) are the only exception, and they raise
  `ORA-389xx` on misuse. Only the Hint Report or the plan tells you what
  happened to any other hint.

### APEX only

- **The Optimizer Hint attribute lands on APEX's outer wrapper query**
  (`select --+qb_name(apex$<app>_<page>) <your hint> * from (…)`), not on
  your `from` clause. Table-level hints in it need `qb_name` / `@qb`, while
  statement-level ones like `first_rows(n)` work as is (verified).

- **`APEX$…` pseudo hints reach the database** and show as `E` in the hint
  report. That's harmless — never write them with parentheses.

- **APEX sessions on ADB run on the LOW service**, which has no
  parallelism, unless you use the `apex-adb-high` / `apex-adb-medium`
  pseudo hint.
