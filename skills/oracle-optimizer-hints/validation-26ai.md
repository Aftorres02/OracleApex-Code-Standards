# Validation on Oracle AI Database 26ai

The facts in this skill that could be tested were executed against a real
database while it was written. This file records what was run and what
happened, so the claims in the other files can be traced — and re-checked
on another version. Part of the [`oracle-optimizer-hints`](SKILL.md) skill.

---

## Environment

| Item | Value |
|---|---|
| Database | Oracle AI Database 26ai Free Release **23.26.1.0.0** (`compatible = 23.6.0`, `optimizer_features_enable = 23.1.0`) |
| Container / schema | `FREEPDB1`, an ordinary developer schema with `DB_DEVELOPER_ROLE` + `SELECT_CATALOG_ROLE`. SQL Patch and SPM steps ran as `SYS`, on the local instance only. |
| Tablespace | ASSM (`segment space management auto`) |
| APEX | 26.1.0, via `APEX_EXEC` in a temporary `apex_session` |
| Date | September 25, 2026 |

> **Note:** Oracle Free has `parallel_max_servers = 1`, so no statement
> can run in parallel there. `parallel(n)` shows as `U` for that reason —
> not because the hint is wrong.

---

## Re-run it yourself

[`validate_hints.sql`](validate_hints.sql) repeats every check below that
doesn't need special privileges. It creates `zz_hint_*` objects, prints
each plan and hint report next to the expected result, and drops
everything at the end. Run it in a **dev** schema:

```text
sql -nolog
SQL> connect -name "<dev connection>"
SQL> @skills/oracle-optimizer-hints/validate_hints.sql
```

On 19c, expect two differences: a schema-qualified hint may produce no
report line at all, and check 4b raises `ORA-12838`.

---

## Results

### V$SQL_HINT

| Check | Result |
|---|---|
| Rows in `V$SQL_HINT` | **425**, against 406 in 23.1 (Neil Chandler's listing) and 388 in 21.3 (Jonathan Lewis's) |
| Documented hints missing from `V$SQL_HINT` | `PARALLEL` (listed as `SHARED`), `USE_BAND` / `NO_USE_BAND`, `GROUPING`, and the deprecated spellings `NOPARALLEL_INDEX` / `NOREWRITE` |
| `CELL_FLASH_CACHE` | **Absent** — it is a storage clause, not a hint |
| `VECTOR_INDEX_SCAN` / `VECTOR_INDEX_TRANSFORM` (+ `NO_`), `IVF_ITERATION` / `NO_IVF_ITERATION`, `COMPRESS_IMMEDIATE` / `NO_COMPRESS_IMMEDIATE` | Present, all since 23.1 |
| CBO class (`PROPERTY` bit 16) | `APPEND`, `RESULT_CACHE`, `DRIVING_SITE`, `MONITOR`, `QB_NAME`, `WITH_PLSQL`, `GATHER_PLAN_STATISTICS`, `NO_PARALLEL` → **not** CBO. `INDEX`, `FULL`, `LEADING`, `USE_NL`, `FIRST_ROWS`, `MATERIALIZE`, vector hints → CBO. |

### Hint report

| # | Hint | Marker observed |
|---|---|---|
| 1a | `index(zz_hint_child …)` — table name, but the table has an alias | `N` |
| 1b | `full(dev_1.zz_hint_child)` — schema-qualified | `N`. On 19c, Connor McDonald observed no report line at all. |
| 1c | `leading(p) use_hash(c)` on a `between` join | `use_hash(c)` → `U`. It fell back to nested loops. |
| 1d | `index(c …) merg(v) full(p)` | `E merg`. `full(p)` is **not listed** at all. |
| 1e | `use_nl(p c)` with no `leading` | The same text is `U` on `P` and used on `C` |
| 1f | `leading(p c) use_nl(c) index(c (parent_id))` | All 3 used |
| 1g | `ordered(p c)` / bare `dynamic_sampling` | `E` / `E` |
| 1h | Two hint comments on one block | Only the first counts. The second is just a comment. |
| 1i | `/* + full(c) */` — space between `*` and `+` | No hint report. It's a plain comment. |
| 1j | `bogus full(c)` — a bare unknown word | `E bogus`, and `full(c)` **is still used** |
| 1k | `this is a comment full(c)` — prose | `E this`, and `full(c)` is **not applied** |
| — | `qb_name(a) APEX$USE_ROWNUM_PAGINATION full(c)` | `E APEX$USE_ROWNUM_PAGINATION`, and `full(c)` is used |

The parsing rule that follows from these results:

- A **bare** unknown word is reported and skipped, and the hints after it
  still apply.

- An unknown word **followed by `(…)`**, or free text, makes Oracle drop
  everything after it — silently, with no report line.

### Query blocks, views and CTEs

| # | Case | Result |
|---|---|---|
| 2a | `full(c)` on the outer query of a pagination wrapper, where `c` lives in an inline view | `N` |
| 2b | `qb_name(src)` inside + `full(@src c)` outside | Used |
| 2c | `first_rows(25)` on the outer query | Used, at `STATEMENT` level. The plan switched to `INDEX RANGE SCAN DESCENDING` + `WINDOW NOSORT STOPKEY`. |
| 2d | A CTE referenced twice, no hint | `TEMP TABLE TRANSFORMATION` — materialized automatically |
| — | A CTE referenced once | Merged inline |
| — | `full(v.c)` dot-notation into a simple inline view or stored view | Used |
| 6d | `full(c)` inside a stored view, view queried alone | Used |
| 6e | The same view joined to another table | `U — hint is discarded during view merging` |
| — | `full(v)` on a single-table view | Used — applied to the table inside |

### PL/SQL

| # | Case | Result |
|---|---|---|
| 3a | `select /*+ full(c) */ … into` in a package | `v$sql`: `SELECT /*+ full(c) */ COUNT(*) FROM ZZ_HINT_CHILD C WHERE C.PARENT_ID = :B1`. Normalized, but the hint text is kept verbatim. Used. |
| 3b | Cursor `for` loop with `index(c (status created_on))` | Kept and used |
| 3c | `execute immediate` with a hint | Text kept verbatim. Used. |
| — | `alter session set optimizer_mode = first_rows_10`, then static SQL from a package | `v$sql.optimizer_mode = FIRST_ROWS`. The session setting **does** reach PL/SQL, so the old 11gR2 note is obsolete. |
| 6a | `with function` in a subquery, the function actually used, no hint — through SQLcl, `execute immediate`, `dbms_sql` and `open … for` | `ORA-32034` on every path |
| 6b | The same with `/*+ with_plsql */` | Works on every path |
| 6c | The same with no hint, when the outer query doesn't use the function column (`count(*)`) | **No error.** The column is pruned — a test with `count(*)` can pass while the real query fails. |

### Direct path

| # | Statement | Plan / *Note* |
|---|---|---|
| 4a | `insert /*+ append */ … select` into a plain table | `LOAD AS SELECT` |
| 4b | A `select` and a conventional `insert` on that table **before** `commit` | Both worked. 23ai/26ai lift the touch-once rule for ASSM heap tables; 19c raises `ORA-12838`. |
| 4c | The same into a table with a trigger | `LOAD TABLE CONVENTIONAL` — *Direct Load disabled because triggers are defined* |
| 4d | The same into a table with an FK | `LOAD TABLE CONVENTIONAL` — *Direct Load disabled because parent referential constraints are present* |
| 4e | `insert /*+ append */ … values` | `LOAD TABLE CONVENTIONAL` — *Direct Load disabled because insert values with no append values hint used* |
| 4f | `forall … insert /*+ append_values */ … values` | `LOAD AS SELECT` (`BULK BINDS GET`) |

### Switching hints off

| # | Setting | Result |
|---|---|---|
| 5a | `optimizer_ignore_hints = true`, then `index(c …)` | `U — rejected by IGNORE_OPTIM_EMBEDDED_HINTS` |
| 5b | `optimizer_ignore_hints = true`, then `append` | Still `LOAD AS SELECT` |
| 5c | `optimizer_ignore_hints = true`, then `result_cache` | Still a `RESULT CACHE` line — hint used |
| — | Inline `/*+ ignore_optim_embedded_hints index(c …) result_cache */` | `index` rejected, `result_cache` used |
| — | `optimizer_ignore_parallel_hints = true`, then `parallel(2)` | `U — because of _optimizer_ignore_parallel_hints` |

### SQL Patch and SQL Plan Management

These ran as `SYS`, and every patch and baseline was dropped afterwards.

| Case | Result |
|---|---|
| `dbms_sqldiag.create_sql_patch(sql_id => …, hint_text => 'FULL(@"SEL$1" "C"@"SEL$1")')` on an unhinted statement | The plan switched to `TABLE ACCESS FULL`. The hint report lists the patch hint. *Note: SQL patch "…" used for this statement.* |
| The same statement with different whitespace and case (`select   COUNT(*) …`) | The patch **still applied** — matching is on normalized text |
| Patch `'IGNORE_OPTIM_EMBEDDED_HINTS FULL(@"SEL$1" "C"@"SEL$1")'` on a statement hinted `index(c …)` | `index` → `U — rejected by IGNORE_OPTIM_EMBEDDED_HINTS`. `FULL` from the patch was used. |
| `dbms_spm.load_plans_from_cursor_cache(sql_id => <hinted>, plan_hash_value => …, sql_text => <unhinted text>)` | 1 plan loaded. The unhinted statement then ran the hinted plan. The hint report showed the stored outline (`IGNORE_OPTIM_EMBEDDED_HINTS`, `OPTIMIZER_FEATURES_ENABLE`, `FULL(@"SEL$1" "C"@"SEL$1")`). *Note: SQL plan baseline … used.* |

### APEX 26.1 (APEX_EXEC)

| Case | Result |
|---|---|
| `p_optimizer_hint => 'first_rows(25)'` | Generated SQL: `select --+qb_name(apex$143_1) first_rows(25) * from (… row_number() over (order by null) apx$rownum … /*+ qb_name(apex$inner) */ … <your query> …)`. `first_rows(25)` was used. |
| `'full(c)'` | `N` — the alias isn't visible from APEX's outer block |
| `'full(@src c)'` + `/*+ qb_name(src) */` in the query | Used |
| `'APEX$USE_ROWNUM_PAGINATION first_rows(25)'` | Pagination switched to `rownum`. The pseudo hint shows as `E`, and `first_rows(25)` was still used. |
| `'APEX$USE_OFFSET_PAGINATION'` | Pagination: `offset :p$_first_row rows fetch next :p$_max_rows rows only` |
| `'APEX$USE_NO_PAGINATION'` | No pagination wrapper, and APEX's `qb_name(apex$…)` tag was dropped |
| Source starting `with function …`, no hint / `'WITH_PLSQL'` | `ORA-32034` / works |
| The hint-audit query over the 7 dictionary views | Runs without error |

---

## Not verified here

| Topic | Why not |
|---|---|
| `apex-adb-high` / `apex-adb-medium` | Needs Autonomous Database |
| ADB workload-type defaults | Taken from Oracle's ADB documentation |
| Actual parallel execution | Oracle Free runs no parallel query |
| `APEX$USE_NO_BULK_FETCH`, `APEX$USE_NO_GROUPING_SETS` | Taken from the APEX 26.1 Builder help text, not executed |
| `driving_site` | Needs a database link |
| 19c-specific behaviour | Taken from Oracle's docs, blogs and videos. Run `validate_hints.sql` on a 19c database to confirm. |
