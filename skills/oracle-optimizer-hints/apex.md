# Hints in Oracle APEX

What APEX adds on top of the general rules. Read
[`sql-and-plsql.md`](sql-and-plsql.md) first: everything there applies
unchanged to SQL inside APEX processes, packages called from APEX,
automations and so on. This file covers only what is **specific to APEX**
— the Optimizer Hint attribute, the SQL wrapper APEX generates, pseudo
hints, and `APEX_EXEC`. Part of the [`oracle-optimizer-hints`](SKILL.md)
skill.

> **Note:** the facts here come from the **APEX 26.1** install source (the
> Property Editor metadata, the `APEX_EXEC` spec and the dictionary views),
> and were **verified** by running `APEX_EXEC` on APEX 26.1 / Oracle AI
> Database 26ai Free (see [`validation-26ai.md`](validation-26ai.md)).
> Older APEX releases may lack some attributes or pseudo hints.

---

## The Optimizer Hint attribute

### Which components have it

A plain-text attribute, up to **255** characters, on every component whose
data source is **Local Database, REST Enabled SQL, REST Data Source,
Duality View or JSON Collection**:

| Component | Builder location | Dictionary view (`OPTIMIZER_HINT` column) |
|---|---|---|
| Region — Interactive Report, Interactive Grid, Classic Report, Cards, Form, Chart, Map, Calendar, template components…, plus the region filtered by Faceted Search / Smart Filters | Region → Source | `apex_application_page_regions` |
| Chart series | Series → Source | `apex_application_page_chart_s` |
| Map layer | Layer → Source | `apex_appl_page_map_layers` |
| Shared List of Values | Shared Components → LOV → Source | `apex_application_lovs` |
| Automation | Automation → Source | `apex_appl_automations` |
| Report Query statement | Shared Components → Report Queries | `apex_appl_rpt_qry_sources` |
| Search Configuration | Shared Components → Search Configurations | `apex_appl_search_configs` |

How to fill it in:

- Enter the hint text only, **without** `/*+ */`.

- **No substitutions.** `&P1_X.` stays literal.

- Inline LOVs on page items, and SQL in processes or dynamic actions, have
  no such attribute. Put the hint in the SQL text itself.

### Where APEX puts it — verified

APEX wraps your query in its own layers (pagination, filters, sorting,
aggregation, facet counts…) and writes the attribute into a `--+` hint
comment on the **outermost** `select`. It adds two `qb_name` hints of its
own. This is the actual 26.1 SQL from `apex_exec.open_query_context` with
`p_optimizer_hint => 'first_rows(25)'` (whitespace added):

```sql
select --+qb_name(apex$143_1) first_rows(25)
       * from (select * from (select * from (
         select a.*, row_number() over (order by null) apx$rownum
           from (select * from (select /*+ qb_name(apex$inner) */ * from (
                   select c.id, c.status, c.created_on          -- your region query
                     from zz_hint_child c
                    where c.parent_id = 5
                 ) d ) i ) a
       ) where apx$rownum <= :p$_max_rows ) where apx$rownum > :p$_first_row )
```

`apex$143_1` is `apex$<app_id>_<page_id>`. That's a handy way to find a
page's cursors: `v$sql where sql_text like '%qb_name(apex$143_1)%'`.

### What that means for your hint

**Verified:**

| In the attribute | Hint report | Result |
|---|---|---|
| `first_rows(25)` | used, at `STATEMENT` level | Works: statement-level hints apply from anywhere |
| `full(c)` | `N — unresolved` | Does nothing: `c` lives in your block, not APEX's outer block |
| `full(@src c)`, with `/*+ qb_name(src) */` in the region query | used | Works |
| *(none)*, with a region source starting `with function …` | — | `ORA-32034: unsupported use of WITH clause` |
| `WITH_PLSQL`, with the same region source | — | Works |

So there are two ways to hint a region:

1. Put table-level hints **inside the region SQL**, in the query block
   where the table appears.
2. Put them in the attribute with `qb_name` / `@qb`.

Use the attribute as is only for statement-level hints (`first_rows(n)`,
`opt_param`, `with_plsql`) and for pseudo hints.

```sql
-- Region source (Interactive Report)
select /*+ qb_name(src) */
       o.order_id                                as order_id
     , o.order_date                              as order_date
     , c.customer_name                           as customer_name
  from prefix_orders                  o
  join prefix_customers               c on c.customer_id = o.customer_id
 where o.status = :P10_STATUS
```

```text
Optimizer Hint attribute:  first_rows(25) leading(@src o c) use_nl(@src c)
```

---

## APEX pseudo hints

APEX reads these words from the attribute and changes the SQL it
generates. **They are still sent to the database** inside the `--+`
comment, where the hint report lists them as `E — Syntax error`. That is
expected and harmless — don't "fix" it.

A bare unknown word doesn't stop Oracle parsing the hints that follow it.
That was verified with `APEX$USE_ROWNUM_PAGINATION first_rows(25)`, where
`first_rows(25)` was still used. Never add parentheses to a pseudo hint:
an unknown word *with* parentheses makes Oracle drop every hint after it.
Writing a pseudo hint inside the SQL text itself does nothing.

| Pseudo hint | Since | Effect (verified on 26.1 unless noted) |
|---|---|---|
| `APEX$USE_ROWNUM_PAGINATION` | 18.2 | Pagination uses `rownum` instead of the default `row_number() over (order by null)`. The plan changed from `WINDOW NOSORT STOPKEY` to `COUNT STOPKEY`. Use it when complex views get a bad plan from the `row_number()` wrapper. |
| `APEX$USE_OFFSET_PAGINATION` | in 26.1 help (release unverified) | Pagination uses `offset :p$_first_row rows fetch next :p$_max_rows rows only` |
| `APEX$USE_NO_PAGINATION` | 18.2 | No pagination SQL at all: fetch from row 1 and skip client-side. APEX also drops its `qb_name(apex$<app>_<page>)` tag here. |
| `APEX$USE_NO_BULK_FETCH` | in 26.1 help (release unverified) | Don't bulk-fetch this query. Not verified. |
| `APEX$USE_NO_GROUPING_SETS` | in 26.1 help (release unverified) | Faceted Search / Smart Filters compute each facet's counts in its own query, combined with `union all`, instead of one `grouping sets` query. Try it when facet counts are slow. Not verified. |
| `apex-adb-high` / `apex-adb-medium` | undocumented. Connor McDonald (Oracle), May 2026. | **On Autonomous Database only**: run this region's query on the HIGH / MEDIUM consumer group, which has parallelism, then switch back to LOW. Not in the Builder help, so it may change without notice. Not verified — needs ADB. |

---

## APEX_EXEC

`p_optimizer_hint` has the same semantics as the attribute, including the
pseudo hints. The query calls apply it to the outermost generated SQL
(**verified**):

| Call | Where the hint goes |
|---|---|
| `apex_exec.open_query_context` (location overload) | The outermost query APEX generates |
| `apex_exec.describe_query` (location overload) | The same, for describing |
| `apex_exec.open_local_dml_context` | *"added to the DML clause"* |
| `apex_exec.open_remote_dml_context` | The same, over REST Enabled SQL |

```plsql
l_context := apex_exec.open_query_context(
                 p_location       => apex_exec.c_location_local_db
               , p_sql_query      => 'select /*+ qb_name(src) */ o.order_id, o.status from prefix_orders o'
               , p_optimizer_hint => 'first_rows(50) APEX$USE_ROWNUM_PAGINATION'
               , p_first_row      => 1
               , p_max_rows       => 50
             );
```

---

## See the SQL APEX actually ran

### Run the page with debug LEVEL9

The debug log shows the generated SQL — and, since 18.1, the execution
plan APEX fetched right after running it.

### Find the cursor

Search `v$sql` for `qb_name(apex$<app_id>_<page_id>)`, or filter by the
module APEX sets.

### Reproduce it with actual row counts

Use `gather_plan_statistics` + `dbms_xplan.display_cursor(format =>
'ALLSTATS LAST +HINT_REPORT')` ([`diagnostics.md`](diagnostics.md)). Connor
McDonald's
[`apex_plan`](https://github.com/connormcd/misc-scripts/blob/master/apex_plan.sql)
does this from SQL Workshop, binds included. It needs `select` on
`v_$session`, `v_$sql_plan` and `v_$sql_plan_statistics_all`.

### Audit every attribute hint in an application

This was verified on APEX 26.1.

```sql
select 'REGION'                                  as component_type
     , r.page_id                                 as page_id
     , r.region_name                             as component_name
     , r.optimizer_hint                          as optimizer_hint
  from apex_application_page_regions r
 where r.application_id = :app_id
   and r.optimizer_hint is not null
union all
select 'CHART SERIES'                            as component_type
     , s.page_id                                 as page_id
     , s.region_name || ' / ' || s.series_name   as component_name
     , s.optimizer_hint                          as optimizer_hint
  from apex_application_page_chart_s s
 where s.application_id = :app_id
   and s.optimizer_hint is not null
union all
select 'MAP LAYER'                               as component_type
     , m.page_id                                 as page_id
     , m.region_name || ' / ' || m.name          as component_name
     , m.optimizer_hint                          as optimizer_hint
  from apex_appl_page_map_layers m
 where m.application_id = :app_id
   and m.optimizer_hint is not null
union all
select 'LOV'                                     as component_type
     , null                                      as page_id
     , l.list_of_values_name                     as component_name
     , l.optimizer_hint                          as optimizer_hint
  from apex_application_lovs l
 where l.application_id = :app_id
   and l.optimizer_hint is not null
union all
select 'AUTOMATION'                              as component_type
     , null                                      as page_id
     , a.name                                    as component_name
     , a.optimizer_hint                          as optimizer_hint
  from apex_appl_automations a
 where a.application_id = :app_id
   and a.optimizer_hint is not null
union all
select 'REPORT QUERY'                            as component_type
     , null                                      as page_id
     , q.report_query_name                       as component_name
     , q.optimizer_hint                          as optimizer_hint
  from apex_appl_rpt_qry_sources q
 where q.application_id = :app_id
   and q.optimizer_hint is not null
union all
select 'SEARCH CONFIG'                           as component_type
     , null                                      as page_id
     , sc.label                                  as component_name
     , sc.optimizer_hint                         as optimizer_hint
  from apex_appl_search_configs sc
 where sc.application_id = :app_id
   and sc.optimizer_hint is not null
 order by 1, 2, 3;
```

Hints written *inside* region SQL, LOV SQL or packages don't show up here.
Grep the application export and the PL/SQL sources for `/*+` and `--+` as
well.

---

## APEX on Autonomous Database

The workload-type defaults are in
[`sql-and-plsql.md`](sql-and-plsql.md#autonomous-database). Two points are
APEX-specific:

- APEX sessions run on the **LOW** service, which has no parallelism, so
  a `parallel` hint in region SQL won't parallelize. `apex-adb-high` /
  `apex-adb-medium` in the attribute is the (undocumented) way around that.

- On a **Lakehouse** instance, an app that relies on hints needs this in
  *Shared Components → Security Attributes → Database Session →
  Initialization PL/SQL Code*:

  ```plsql
  execute immediate 'alter session set optimizer_ignore_hints = false';
  ```
