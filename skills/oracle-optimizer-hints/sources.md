# Sources and Further Study

Everything the [`oracle-optimizer-hints`](SKILL.md) skill is based on,
grouped by authority. Every URL below was fetched when the skill was
written (September 2026).

---

## Oracle documentation

These are authoritative for syntax and behaviour.

| Document | Why read it |
|---|---|
| [SQL Language Reference 19c — Comments → Hints](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Comments.html) | The rules (placement, aliases, query blocks, global hints) and the alphabetical syntax of all 101 documented 19c hints |
| [SQL Language Reference 21c](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/Comments.html) / [23ai](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/Comments.html) / [26ai](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqlrf/Comments.html) | The same chapter in later releases. 26ai adds `COMPRESS_IMMEDIATE` and `IVF_ITERATION`, and updates `RESULT_CACHE` and `IGNORE_ROW_ON_DUPKEY_INDEX`. |
| [SQL Tuning Guide 19c — Influencing the Optimizer](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/influencing-the-optimizer.html) ([26ai](https://docs.oracle.com/en/database/oracle/oracle-database/26/tgsql/influencing-the-optimizer.html)) | Hint types and scope, join-order guidelines, and the full **Hint Usage Report** chapter with worked examples |
| [Performance Tuning Guide 11gR2 — Using Optimizer Hints](https://docs.oracle.com/cd/E15586_01/server.1111/e16638/hintsref.htm) | Still the clearest explanation of full hint sets, complex index hints, and hints with mergeable vs non-mergeable views |
| [DBMS_XPLAN (19c)](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_XPLAN.html) | Format keywords (`ALLSTATS`, `+ALIAS`, `+OUTLINE`, `+HINT_REPORT`), `COMPARE_PLANS` |
| [DBMS_SQLDIAG (19c)](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_SQLDIAG.html) · [DBA_SQL_PATCHES](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/DBA_SQL_PATCHES.html) | `CREATE_SQL_PATCH` (`sql_text` / `sql_id` overloads), `DROP_SQL_PATCH`, the staging-table procedures |
| [DBMS_SPM (19c)](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_SPM.html) | `LOAD_PLANS_FROM_CURSOR_CACHE` overloads (`sql_text` / `sql_handle`) |
| [OPTIMIZER_IGNORE_HINTS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/OPTIMIZER_IGNORE_HINTS.html) · [OPTIMIZER_IGNORE_PARALLEL_HINTS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/OPTIMIZER_IGNORE_PARALLEL_HINTS.html) | Parameter reference |
| [INSERT (19c)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/INSERT.html) · [INSERT (26ai)](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqlrf/INSERT.html) | Direct-path restrictions (triggers, FKs, `ORA-12838` — the paragraph was dropped in 26ai) |
| [SELECT (19c) — plsql_declarations](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html) | `WITH_PLSQL`: *"It is not an optimizer hint."* |
| [AI Vector Search 26ai — Vector Index Hints](https://docs.oracle.com/en/database/oracle/oracle-database/26/vecse/vector-index-hints.html) | `VECTOR_INDEX_SCAN`, `VECTOR_INDEX_TRANSFORM` and their filter types |
| [ADB — Manage Optimizer Statistics (and hints)](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/manage-optimizer-stats.html) | Lakehouse ignores hints by default; Transaction Processing / JSON honour them |
| [ADB — Database Service Names](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/predefined-database-services-names.html) · [ADB — Initialization Parameters](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/autonomous-initialization-parameters.html) | LOW/MEDIUM/HIGH parallelism. `PARALLEL` hints are honoured on TP/JSON/APEX Service. 26ai lifts the parallel-DML touch-once restriction. |

---

## Oracle Optimizer team (blogs.oracle.com/optimizer)

- [What is Hint Usage Reporting?](https://blogs.oracle.com/optimizer/what-is-hint-usage-reporting)
  — Nigel Bayliss. `TYPICAL` shows unused hints, `+HINT_REPORT`,
  `+HINT_REPORT_USED` / `_UNUSED`.

- [Using SQL Patch to add hints to a packaged application](https://blogs.oracle.com/optimizer/using-sql-patch-to-add-hints-to-a-packaged-application)
  — Maria Colgan.

- [Adding and Disabling Hints Using SQL Patch](https://blogs.oracle.com/optimizer/adding-and-disabling-hints-using-sql-patch)
  — Nigel Bayliss. Query-block-qualified hints, and the
  `IGNORE_OPTIM_EMBEDDED_HINTS` trick.

- [Additional Information on SQL Patches](https://blogs.oracle.com/optimizer/additional-information-on-sql-patches)
  — no extra licence; normalized-text matching.

- [What should I do with old hints in my workload?](https://blogs.oracle.com/optimizer/what-should-i-do-with-old-hints-in-my-workload)
  — re-test hints after upgrades, and map a hinted plan to the unhinted SQL
  with SPM.

- [Copy an Execution Plan From One SQL Statement to Another using SQL Plan Baselines](https://blogs.oracle.com/optimizer/using-sql-plan-management-to-control-sql-execution-plans)

- [How to Generate a Useful SQL Execution Plan](https://blogs.oracle.com/optimizer/how-to-generate-a-useful-sql-execution-plan)

- [New SQL Analysis Report in Oracle Database 23c Free](https://blogs.oracle.com/optimizer/sql-analysis-report-in-23c-free)

- [What is the difference between SQL Profiles and SQL Plan Baselines?](https://blogs.oracle.com/optimizer/what-is-the-difference-between-sql-profiles-and-sql-plan-baselines)
  · [What is Real-time SQL Plan Management?](https://blogs.oracle.com/optimizer/what-is-realtime-spm)

- Runnable examples by Nigel Bayliss:
  [oracle-samples/oracle-db-examples → optimizer](https://github.com/oracle-samples/oracle-db-examples/tree/main/optimizer).
  See `creative_w_plan/patch` (SQL Patch, and copying an outline from one
  SQL to another), `creative_w_plan/spm_plan`, `sql_analysis_report`,
  `first_rows` and `direct_path`.

---

## Oracle APEX

- **APEX 26.1 install source.** The Property Editor help for *Optimizer
  Hint* (property 975) lists the pseudo hints, the 255-character limit, "no
  substitutions" and "added to the top-level statement". The `APEX_EXEC`
  spec documents `p_optimizer_hint`. The dictionary views show the
  `OPTIMIZER_HINT` column.

- [Application Express 18 and Report Pagination](https://blogs.oracle.com/apex/application-express-18-and-report-pagination)
  — Carsten Czarski. `row_number()` pagination,
  `APEX$USE_ROWNUM_PAGINATION` / `APEX$USE_NO_PAGINATION`, and debug
  LEVEL9 showing the SQL and plan.

- [The secret APEX performance hack](https://connor-mcdonald.com/2026/05/08/6991/)
  — Connor McDonald. `apex-adb-high` / `apex-adb-medium` in the Optimizer
  Hint attribute on Autonomous.

- [Digging deeper into SQL under APEX](https://connor-mcdonald.com/2022/07/12/digging-deeper-into-sql-under-apex/)
  — Connor McDonald, with the
  [`apex_plan`](https://github.com/connormcd/misc-scripts/blob/master/apex_plan.sql)
  helper.

---

## Community experts

- [v$sql_hint](https://jonathanlewis.wordpress.com/2022/03/07/vsql_hint/)
  — Jonathan Lewis. A script and full listing of all hints with `VERSION`,
  `VERSION_OUTLINE`, `INVERSE` and `TARGET_LEVEL`: 388 hints in 21.3, about
  120 of them documented.

- [Hint Classifications](https://chandlerdba.com/2024/07/28/hint-classifications/)
  — Neil Chandler. `PROPERTY` bit 16 marks the CBO hints that
  `IGNORE_OPTIM_EMBEDDED_HINTS` disables (406 hints in 23.1).

- [Avoid compound hints for better Hint Reporting in 19c](https://medium.com/@FranckPachot/avoid-compound-hints-for-better-hint-reporting-in-19c-79702f06c735)
  — Franck Pachot. `use_hash(a b)` is two hints, and the report can't tell
  which half failed.

- [19c: scalable Top-N queries without further hints](https://www.dbi-services.com/blog/19c-scalable-top-n-queries/)
  — Franck Pachot. Fix control `22174392` lets `fetch first n rows` use an
  index without hints.

- [Kris Kringle the Database — Get the HINT](https://connor-mcdonald.com/2024/12/16/kris-kringle-the-database-get-the-hint/)
  — Connor McDonald. Eight plausible-looking hints that are all invalid,
  each with its hint-report marker and the reason.

- [Removal of Touch-Once Restriction after Parallel DML (23ai/26ai)](https://oracle-base.com/articles/23/removal-of-touch-once-restriction-after-parallel-dml-23)
  — Tim Hall. See also
  [Randolf Geist on unrestricted direct loads' glitches](https://oracle-randolf.blogspot.com/2023/08/oracle-23c-free-unrestricted-direct.html).

- [How to Create an Execution Plan](https://blogs.oracle.com/sql/how-to-create-an-execution-plan)
  — Chris Saxon.

- [Databases for Developers: Performance](https://devgym.oracle.com/pls/apex/dg/class/databases-for-developers-performance.html)
  — Chris Saxon's free Dev Gym class, the recommended starting point for
  developers.

---

## Videos

| Video | Speaker / channel | Key takeaways |
|---|---|---|
| [Harnessing the power of Oracle Database optimizer hints (CloudWorld 2022)](https://www.youtube.com/watch?v=fVdFT8y-IX4) | Maria Colgan / Oracle | Hints were built as a *testing* tool. A hint is a directive, followed whenever applicable. `USE_NL` names the inner table, so pair it with `LEADING`. The only guarantee is the full outline, so use SPM. Use `+ALIAS` and `QB_NAME` for query blocks. `FIRST_ROWS(n)` for dashboards. `OPT_PARAM` and `OPTIMIZER_FEATURES_ENABLE` fix problems at statement scope. Re-test hints after every upgrade. |
| [Hints, Histograms and Hocus Pocus](https://www.youtube.com/watch?v=dt6_Gt17BtA) | Connor McDonald & Maria Colgan | The ideal number of hints is zero. Hints are triage, so move the fix into an SPM baseline on the unhinted SQL. If you use `LEADING`, give the *whole* story. Hints that go in never come out. |
| [Why did the optimizer ignore my hints?](https://www.youtube.com/watch?v=z6uliHqoh04) | Connor McDonald | "Ignored" really means *invalid*. `USE_HASH` into the wrong side, `ORDERED` lost to view merging (`NO_MERGE` preserves it), `QB_NAME` renamed after transformation, `FULL` on an IOT. |
| [Understanding optimizer hints in 19c](https://www.youtube.com/watch?v=mjzWiWhuZgU) | Connor McDonald | A hint report walk-through: E, N, U, and outer-block hints overriding inner ones. A schema-qualified hint gives no report line at all. On 26ai it is reported as `N` instead. |
| [How do I tune a SQL statement when the Optimizer picks the wrong index?](https://www.youtube.com/watch?v=1Al5LOYwigs) | Maria Colgan (SQLMaria) | Diagnose the estimate first (E-Rows vs A-Rows), then fix statistics before hinting. |
| [How do I tune a SQL statement that uses a Nested Loops join instead of a Hash Join?](https://www.youtube.com/watch?v=akk2t7G8f4g) | Maria Colgan (SQLMaria) | A wrong join method is usually a cardinality misestimate. Fix the estimate. |
| [My THREE rules for SQL tuning](https://www.youtube.com/watch?v=3FGrsmouRG4) | Connor McDonald | Understand the requirement and the data before touching the SQL — "lipstick on a pig". |
| [How to use Hints for the Oracle Optimizer](https://www.youtube.com/watch?v=np-cgLbKGQU) | SkillBuilders | The DBA vs developer view of hints in application code. |
| [SQL Patch](https://www.youtube.com/watch?v=Uo2ksdtGKWU) | Oracle AI Database: Upgrade / Migration / Patching | Add a hint without changing the app. Works in SE2 too. `DBMS_SQLDIAG_INTERNAL` (11.2/12.1) vs `DBMS_SQLDIAG` (12.2+). |
| [Quickly fix bad statements with SQL Patch](https://www.youtube.com/watch?v=xRhGBbu3VgQ) | Oracle AI Database: Upgrade / Migration / Patching | A patch with `IGNORE_OPTIM_EMBEDDED_HINTS` neutralises a bad hard-coded hint. It's persistent and transportable. |
| [APPEND Hint, Redo and NOLOGGING](https://www.youtube.com/watch?v=xI92xIsaojw) | Tim Hall / ORACLE-BASE | In `ARCHIVELOG` mode, `APPEND` alone doesn't reduce redo; only `APPEND` + `NOLOGGING` does, at the cost of recoverability. |
| [10 Oracle optimizer tips (OOW13) — playlist](https://www.youtube.com/playlist?list=PLR0UXVQ7j2yxiYban5wzrLMCgU3_aJFtx) | Jonathan Lewis & Maria Colgan | Classic short tips, several of them about hints and statistics |

---

## Books

- *Troubleshooting Oracle Performance* (2nd ed.) — Christian Antognini.
  The chapters on hints, SQL profiles, SQL plan baselines and SQL patches.

- *Cost-Based Oracle Fundamentals* — Jonathan Lewis. Why the optimizer
  does what it does, so you hint less.

---

## Review notes on the packaged Oracle skill (github.com/oracle/skills)

The `db:db` plugin (`db/sql-dev/sql-tuning.md`,
`db/performance/explain-plan.md`) agrees with this skill on the principle —
statistics, indexes and SPM before hints; `GATHER_PLAN_STATISTICS` +
`ALLSTATS LAST` to diagnose. It covers only about 20 hints and has these
inaccuracies:

- `db/architecture/exadata-features.md` lists `/*+ CELL_FLASH_CACHE(KEEP) */`
  as a hint. It isn't one: it's a `STORAGE` clause attribute, and it is
  absent from `V$SQL_HINT` (verified on 26ai). Worse, `/*+ cell_flash_cache(keep) */`
  is a syntax error that discards every hint written after it.

- It presents `CARDINALITY` and `MATERIALIZE` alongside documented hints
  without flagging them as undocumented.

- Its examples use the legacy object-level `PARALLEL(t, 8)` form. Since
  11gR2 the statement-level `PARALLEL(8)` is the documented primary form.

- It has no coverage of the Hint Usage Report codes, query block naming,
  SQL Patch, the ADB defaults, or the APEX Optimizer Hint attribute and
  pseudo hints.
