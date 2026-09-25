# Hints in SQL and PL/SQL

How hints behave in **any** Oracle code — package bodies, standalone
scripts, views, scheduler/batch jobs, reports, or SQL sent from any client.
Nothing here depends on APEX. APEX adds one extra layer on top, described
separately in [`apex.md`](apex.md). Part of the
[`oracle-optimizer-hints`](SKILL.md) skill.

> **Note:** statements marked **Verified on 26ai** were executed on Oracle
> AI Database 26ai Free 23.26.1 while this skill was written. The full log
> is in [`validation-26ai.md`](validation-26ai.md).

---

## Where a hint can live

Every *statement block* can carry one hint comment, right after its first
keyword:

| Construct | Hint placement |
|---|---|
| Query | `select /*+ … */ …` — and again inside each subquery, inline view, CTE block and `union` branch, since each is its own block |
| DML | `insert /*+ … */ into …`, `update /*+ … */ t set …`, `delete /*+ … */ from …`, `merge /*+ … */ into …` |
| `insert … select` / CTAS | Two blocks. `insert /*+ append */ into t select /*+ full(s) */ … from s`. Load hints go on `insert`; query hints go on the `select`. |
| PL/SQL static SQL | `select … into`, cursor `for` loops, explicit cursors, `bulk collect`, `forall` — all written exactly as in plain SQL |
| Dynamic SQL | Inside the string passed to `execute immediate`, `open … for`, or `dbms_sql.parse` |
| Views | Inside the view's `select`. Oracle discourages this — see [Hints in views and CTEs](#hints-in-views-and-ctes). |
| Code you must not edit | Nowhere in the code: use a **SQL Patch** or **SQL Plan Baseline** ([`diagnostics.md`](diagnostics.md#deliver-a-hint-without-touching-the-code)) |

---

## PL/SQL keeps your hints

**Verified on 26ai.** Static SQL in a package is normalized by the PL/SQL
compiler — keywords uppercased, PL/SQL variables turned into `:B1`,
`:B2` … — but the hint comment is preserved **verbatim** and applied. The
cursor in `v$sql` looks like this:

```text
SELECT /*+ full(c) */ COUNT(*) FROM ZZ_HINT_CHILD C WHERE C.PARENT_ID = :B1
SELECT /*+ index(c (status created_on)) */ C.ID FROM ZZ_HINT_CHILD C WHERE C.STATUS = 'OPEN' AND ROWNUM <= 5
select /*+ full(c) zzdyn */ count(*) from zz_hint_child c where c.parent_id = :b1   -- execute immediate: kept exactly
```

The hint report showed each hint **used**, for the `select … into`, the
cursor `for` loop, and the `execute immediate` alike.

Hints work the same way inside a package procedure — with the
justification comment `sql-format.md` §13 requires:

```plsql
  procedure load_daily_orders(
      p_load_date                               in date
  )
  is
    l_scope  logger_logs.scope%type := gc_scope_prefix || 'load_daily_orders';
    l_params logger.tab_param;
  begin
    logger.append_param(l_params, 'p_load_date', p_load_date);
    logger.log('START', l_scope, null, l_params);

    -- HINT_AFLORES_SEPTEMBER-25-2026 append: nightly bulk load into a trigger-less,
    -- FK-less staging table | evidence: plan shows LOAD AS SELECT | CWMS-418
    insert /*+ append */
      into prefix_stage_orders (
           order_id
         , customer_id
         , order_date
    )
    select o.order_id                                  as order_id
         , o.customer_id                               as customer_id
         , o.order_date                                as order_date
      from prefix_orders o
     where o.order_date >= p_load_date
       and o.order_date <  p_load_date + 1;

    commit;
    logger.log('END', l_scope, null, l_params);
  exception
    when others then
      logger.log_error('Unhandled Exception', l_scope, null, l_params);
      raise;
  end load_daily_orders;
```

### Session optimizer_mode does reach PL/SQL

**Verified on 26ai.** After `alter session set optimizer_mode =
first_rows_10`, a static SQL statement hard-parsed from inside a package
got `v$sql.optimizer_mode = FIRST_ROWS`. The 11gR2 Performance Tuning
Guide's note that *"ALTER SESSION … SET OPTIMIZER_MODE does not affect SQL
run within PL/SQL"* is **obsolete** — don't rely on it. If one statement
needs a different goal, give that statement a `first_rows(n)` hint instead
of changing the session.

### Never build hint text from input

In dynamic SQL, a hint is part of the SQL text. Concatenating anything
user-controlled into it is SQL injection (`security.md` §1). If the hint
must vary, pick between fixed literal statements in code.

---

## Direct-path loads: APPEND and APPEND_VALUES

`APPEND` goes with `insert … select`. `APPEND_VALUES` goes with
`forall … insert … values`. Break a restriction and Oracle silently runs a
conventional insert.

`APPEND` is not in the Hint Report's scope, so check the **plan**
(`dbms_xplan.display_cursor(format => 'BASIC +NOTE')`):
`LOAD AS SELECT` means direct path, `LOAD TABLE CONVENTIONAL` means it
wasn't. On 26ai the *Note* section also says why.

**Verified on 26ai:**

| Statement | Plan | 26ai *Note* |
|---|---|---|
| `insert /*+ append */ into plain_table select …` | `LOAD AS SELECT` | — |
| The same into a table **with a trigger** | `LOAD TABLE CONVENTIONAL` | *Direct Load disabled because triggers are defined* |
| The same into a table **with an FK** | `LOAD TABLE CONVENTIONAL` | *Direct Load disabled because parent referential constraints are present* |
| `insert /*+ append */ into t values (…)` | `LOAD TABLE CONVENTIONAL` | *Direct Load disabled because insert values with no append values hint used* |
| `forall … insert /*+ append_values */ into t values (…)` | `LOAD AS SELECT` (`BULK BINDS GET`) | — |

```plsql
forall i in 1 .. l_rows.count
  insert /*+ append_values */
    into prefix_stage_orders (
         order_id
       , customer_id
  )
  values (
         l_rows(i).order_id
       , l_rows(i).customer_id
  );
commit;
```

- **Our standard tables can't be direct-path loaded.**
  [`table_template.sql`](../../templates/table_template.sql) gives every
  table a compound audit trigger and usually FKs. Direct path only works on
  staging or ETL tables built without them.

- **Same-transaction access.** On 19c, after a direct-path insert the same
  transaction can't read or modify the table until `commit`
  (`ORA-12838`). **Verified on 26ai:** a `select` and a conventional
  `insert` on the table right after `insert /*+ append */` both succeeded
  without a commit — the 23ai "Unrestricted Direct Loads" feature for heap
  tables in ASSM tablespaces. Code that must also run on 19c still needs
  the commit.

- Direct path locks the segment, writes above the high-water mark and
  doesn't reuse free space. It's for batch loads, never for single-row
  inserts from an online transaction.

- In an `ARCHIVELOG` database, `APPEND` alone doesn't cut redo. Only
  `APPEND` on a `NOLOGGING` table does, and that costs recoverability.

---

## Upserts and duplicates

We use `merge` for upserts (`sql-format.md` §9).
`ignore_row_on_dupkey_index(t, t_uk)` is a *semantic* hint: it silently
skips rows of a single-table `insert` that would violate that unique index.
It is fine for idempotent seed or batch inserts where skipping is the
intended behaviour. But it does a row-level rollback per duplicate,
disables direct path and parallel DML, and raises `ORA-38912`/`38913`/`38915`
when misused.

---

## RESULT_CACHE: the hint vs the function clause

| | SQL hint `/*+ result_cache */` | PL/SQL `function … result_cache` |
|---|---|---|
| Caches | The result of a query, `with` block or inline view | The return value per argument set |
| Invalidation | Any committed DML on a dependency (plus `shelflife=n` seconds) | The same |
| Good for | Small, read-mostly lookups hit constantly — config tables, code lists | Deterministic lookups called from many places |
| Bad for | Per-user, volatile or large results. Heavy churn causes result-cache latch contention. | The same |

The plan shows a `RESULT CACHE` line when the hint applies — **verified on
26ai**. `result_cache_integrity` (26ai, default `TRUSTED` on the Free
image) set to `ENFORCED` refuses to cache queries that call PL/SQL
functions not declared `deterministic`.

---

## Database links

`driving_site(alias)` executes a distributed query at the site of the
named table. Use it when the remote side is big and the local filter is
selective — rows then travel the other way. It doesn't apply to DML, which
always runs at the target table's site.

---

## Hints in views and CTEs

Our standards favour views built on `w_` CTEs (`sql-format.md` §10-12).
Oracle discourages hints inside or on views, because a view is written in
one context and queried in another.

**Verified on 26ai:**

| Case | Result |
|---|---|
| `full(c)` inside a stored view; query selects only the view | Used |
| The same view **joined to another table** | `U — hint is discarded during view merging` |
| `full(v)` **on** a single-table view from outside | Used — applied to the table inside |
| `full(v.c)` dot-notation into the view | Used (single block, no ANSI join) |
| Outer-query hint on an inline-view alias, `full(c)` from outside | `N` — unresolved |
| `qb_name(src)` inside + `full(@src c)` outside | Used |
| A CTE referenced **twice**, no hint | `TEMP TABLE TRANSFORMATION` — materialized automatically |
| A CTE referenced **once**, no hint | Merged inline |

Rules that follow from these results:

- To hint a table inside a view, CTE or subquery from outside, use
  `qb_name` + `@queryblock`. Dot notation works for simple cases, but the
  docs say it fails across multiple query blocks and with ANSI joins.

- Don't put access or join hints in a **stored** view that others join
  to — they are thrown away as soon as the view merges.

- Don't add `materialize` just in case. It's undocumented, and the
  optimizer already materializes a CTE referenced more than once by name.
  It *is* justified when a transformation duplicates a single reference —
  `UNPIVOT` becomes one `UNION ALL` branch per column — and
  `V$SQL_PLAN_MONITOR.STARTS` proves the CTE runs repeatedly. See
  [`oracle-performance-investigation`](../oracle-performance-investigation/SKILL.md)
  §3 and §12 for the real case: the biggest win where `STARTS` was high,
  noise where it was 1.

---

## WITH_PLSQL

A `with function …` declaration is allowed only in the **top-level**
`select`. If the query containing it becomes a subquery — wrapped by a
reporting tool, a view, or an `insert … select` — the top-level statement
needs `/*+ with_plsql */`. This is not an optimizer hint.

**Verified on 26ai:**

```sql
select * from (
  with function zz_dbl(p in number) return number is begin return p * 2; end;
  select zz_dbl(p.id) as d from zz_hint_parent p where p.id <= 2
);                                              -- ORA-32034: unsupported use of WITH clause

select /*+ with_plsql */ * from (
  with function zz_dbl(p in number) return number is begin return p * 2; end;
  select zz_dbl(p.id) as d from zz_hint_parent p where p.id <= 2
);                                              -- works
```

The rule is the same through plain SQL, `execute immediate`, `dbms_sql`
and `open … for` — all four raised `ORA-32034` without the hint and
worked with it.

> **Note:** there's a trap when testing. If the outer query doesn't need
> the function's column — `select count(*) from (…)` — the optimizer
> prunes it and **no error is raised**. A quick `count(*)` test can pass
> while the real query fails, so test with the real select list.

---

## Compiler directives are not hints

`NOCOPY`, `PRAGMA UDF`, `PRAGMA INLINE` and `DETERMINISTIC` guide the
**PL/SQL compiler**, not the optimizer. They never appear in a hint report.

To cut the cost of PL/SQL functions called from SQL, use `PRAGMA UDF` or a
`with function` declaration. A scalar subquery
(`select (select f(x) from dual) …`) caches results without any hint.

---

## Autonomous Database

This applies to every client — SQL Developer, a batch job, ORDS or APEX:

| Workload type | Optimizer hints | `PARALLEL` hints |
|---|---|---|
| Lakehouse (formerly Data Warehouse) | **Ignored by default** (`optimizer_ignore_hints = true`) | **Ignored by default** |
| Transaction Processing, JSON, APEX Service | Honoured | Honoured. Parallelism depends on the service you connect to: LOW has none, MEDIUM and HIGH do. |

**Verified on 26ai:** with `optimizer_ignore_hints = true`, plan-shaping
hints are reported as `U — rejected by IGNORE_OPTIM_EMBEDDED_HINTS`, while
`append` (still `LOAD AS SELECT`) and `result_cache` (still a `RESULT
CACHE` line) keep working. With `optimizer_ignore_parallel_hints = true`,
`parallel(n)` is reported as `U — because of _optimizer_ignore_parallel_hints`.

A job or package on Lakehouse that relies on hints must run
`alter session set optimizer_ignore_hints = false` — for example in a logon
trigger, or at the start of the job.
