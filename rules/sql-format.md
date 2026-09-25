# SQL Format

**Single responsibility:** Formatting and layout conventions for raw SQL
(SELECT/INSERT/MERGE, views, CTEs) — independent of PL/SQL block structure
(`plsql-standards.md`) and DDL object conventions (`ddl-conventions.md`).

> Consolidated from `oracle-apex_standards.mdc` §1 (general formatting) and
> §4 (query standards), `docs/coding-standards/plsql/{general,queries}.md`,
> and `.cursor/rules/{sql-formatting,sql-joins-selects}.mdc`. Originals
> archived under `_archive/coding-standards-legacy/`.

## 1. General Formatting

- **Indentation**: 2 spaces. Never tabs.
- **Case**: SQL/PLSQL keywords and identifiers are lowercase (`select`, `from`, `where`).
- **Leading commas**: place commas at the start of the line for column/parameter lists.
- **Vertical alignment**: align identifiers, types, column names, and assignments.
- **Operators**: place `and` / `or` at the start of the continuation line.
- **Blocks**: indent the content of `IF`, `LOOP`, `CASE`, and `BEGIN...END` blocks.
- **IF/THEN**: keep `if` condition and `then` on the same line — never put `then` on its own line.

**GOOD**:
```sql
begin
  if l_count > 0 then
    process_data();
  end if;
end;
```

**BAD**:
```sql
BEGIN
    if l_count > 0
    then
        process_data();
    end if;
END;
```

## 2. Code Sectioning

Standardized header blocks improve scannability in long files. Standard width is **80 characters**.

- **Level 1** (high importance / complex blocks) — use `=`:
```sql
-- =============================================================================
-- IMPORTANT UPDATE FOR SEARCH RESULTS
-- =============================================================================
```

- **Level 2** (minor blocks / logic separation) — use `-`:
```sql
-- -----------------------------------------------------------------------------
-- Refresh cache
-- -----------------------------------------------------------------------------
```

- **In-line comments**: single space after `--`.

## 3. Technical Debt & TODOs

Mandatory format: `-- TODO_[Initials]_<MONTH-DD-YYYY> [Description]`

**GOOD**: `-- TODO_AFLORES_MARCH-09-2026 Pending validation with the business`
**BAD**: `-- TODO: fix this later`

## 4. SELECT Patterns

- First column on the same line as `select` (2 spaces out); align subsequent columns with leading commas.
- **Always alias every column** (`as my_col`) — self-documenting, avoids ambiguity in joins.
- **Always use table aliases** in joins.

**GOOD**:
```sql
select c.customer_id        as customer_id
     , c.customer_name      as customer_name
     , o.order_date         as last_order_date
     , o.total_amount       as order_total
  from prefix_customers          c
  join prefix_orders             o on o.customer_id = c.customer_id
 where c.active_yn = 'Y';
```

**BAD**:
```sql
SELECT ID, PARENT_ID, NOMBRE, DESCRIPTION
FROM DEMO_HIERARCHICAL_DATA
WHERE ACTIVE_YN='Y'
ORDER BY ORDEN;
```

## 5. JOIN Alignment (`from`, `join`, `left join`)

- Use **one consistent indent** for the whole join block. With a comma-first `select` list (comma at five spaces), `from`/`join` are typically indented **four** spaces; `left join` uses **three** leading spaces so the relation name starts in the same screen column as plain `join` rows.
- **Relation → alias**: pad spaces so all aliases begin in one vertical column.
- **`on` with alias**: `on` and the first join predicate stay on the same line as the alias (`… alias on predicate`) — never leave `on` alone on the next line.
- **Anchor column**: on continuation `select` lines, ` as ` sits at a stable column; widen padding so the `o` of ` on ` aligns with the `a` of ` as `. Extra `and` predicates go on the next line, indented to align with that same anchor column.
- **`where`**: continuation `and` lines align under the `where` predicate.

**GOOD**:
```sql
     , sch.project_id                                           as project_id
     , pub.email                                                as published_by_email
    from cwms_project_milestones                         pm
    join cwms_project_milestone_schedule                sch on sch.milestone_schedule_id = pm.milestone_schedule_id
   left join cwms_milestone_catalog                      mc on mc.milestone_catalog_id = pm.milestone_catalog_id
                                                           and mc.active_yn = 'Y'
   left join cw_auth_user_vw                            pub on pub.auth_user_id = sch.published_by_user_id
   where pm.active_yn = 'Y'
     and sch.active_yn = 'Y';
```

**BAD**:
```sql
select pm.project_milestone_id, sch.project_id
  from cwms_project_milestones pm
 left join cwms_project_milestone_schedule sch on sch.milestone_schedule_id = pm.milestone_schedule_id
 left join cwms_milestone_catalog mc on mc.milestone_catalog_id = pm.milestone_catalog_id and mc.active_yn = 'Y';
```

## 6. Function Calls in SELECT

Break multi-parameter functions across lines: opening `(` stays on the function-name line, each parameter on its own line (2-space indent), `=>` vertically aligned, closing `)` on its own line aligned with the function start.

**GOOD**:
```sql
select apex_item.checkbox2(
           p_idx   => 1
         , p_value => s.segment_num
       ) as copy_segment
     , s.segment_label
  from prefix_segments s
```

## 7. Avoid Explicit Cursors — Use FOR Loop Queries

Do not declare explicit cursors (`open`/`fetch`/`close`). Use implicit cursor `for` loops — cleaner, less error-prone, automatic cleanup.

**GOOD**:
```plsql
for l_rec in (
  select ticket_id
       , description
    from prefix_tickets
   where active_yn = 'Y'
)
loop
  process_ticket(
      p_ticket_id   => l_rec.ticket_id
    , p_description => l_rec.description
  );
end loop;
```

## 8. INSERT Patterns

Always use the explicit column list and leading commas.

**GOOD**:
```sql
insert
  into employees (
       employee_id
     , first_name
     , last_name
)
values (
       p_employee_id
     , p_first_name
     , p_last_name
);
```

**BAD**: `insert into employees values (p_employee_id, p_first_name, p_last_name);`

## 9. MERGE Patterns

Use `merge` for sync/upsert operations instead of a select-then-branch (race-condition prone).

**GOOD**:
```sql
merge into prefix_task_list t
using (select p_task_id as task_id
         from dual
) s
   on (t.task_id = s.task_id)
 when matched then
  update
      set t.task_name = p_task_name
 when not matched then
  insert (
         task_name
       , active_yn
  )
  values (
         p_task_name
       , 'Y'
  );
```

**Seed/data scripts**: when writing `merge` statements for LOV/lookup seed data (see `ddl-conventions.md` for the full runnable pattern), keep the `insert` column list and `values` list closely aligned:

```sql
 when not matched then
  insert (
         receiver_name
       , bank_name
       , routing_number
  )
  values (
         s.receiver_name
       , s.bank_name
       , s.routing_number
  );
```

## 10. Views and WITH Clause

- Use a **WITH** clause (CTEs) for view bodies instead of a flat `select`.
- **CTE naming**: CTEs must start with **`w_`** (e.g. `w_base`, `w_inv`).
- **`as` alignment**: pad expressions so the `as` keyword starts in the same character column across every `select` list in the view (each CTE and the outer `select`). Widen the target column for the whole view if one expression needs more room.
- **Indent**: first column of a CTE uses `  select ` (two spaces); subsequent columns use `     , ` (five spaces, comma, space) — same continuation indent as the outer `select` list.

**GOOD**:
```sql
create or replace view prefix_list_vw
as
with w_base as (
  select t.id                                              as widget_id
     , t.name                                              as widget_name
    from my_table t
   where t.active_yn = 'Y'
)
select w.widget_id                                         as widget_id
     , w.widget_name                                       as widget_name
  from w_base w;
```

See [`view_template.sql`](../templates/view_template.sql) for a ready-to-copy skeleton.

## 11. No Inline Subselects in JOINs

Never place a subselect (derived table) directly inside a `join`/`left join`. Extract it into a CTE first, then reference the CTE by name.

**GOOD**:
```sql
with w_totals as (
  select ofp.order_form_id                                         as order_form_id
       , count(1)                                                  as products_total
    from roi_po_order_form_products ofp
   group by ofp.order_form_id
)
select odf.id                                                      as id
     , nvl(t.products_total, 0)                                    as products_total
  from roi_order_forms                odf
  left join w_totals                    t on t.order_form_id = odf.id
 where odf.active_yn = 'Y';
```

## 12. Filter-First CTE Pattern

When a query filters a driving table (e.g. by a bind variable) and aggregates data from child tables, create a base CTE (`w_base`) that filters the driving table first, then `join` that base CTE into each child aggregation CTE. This keeps the execution plan narrow instead of full-scanning child tables before filtering.

**GOOD**:
```sql
with w_base as (
  select odf.id                                                    as id
       , odf.name                                                  as name
    from roi_order_forms odf
   where odf.purchase_order_id = :P2_ID
), w_products as (
  select ofp.order_form_id                                         as order_form_id
       , count(1)                                                  as products_total
    from roi_po_order_form_products ofp
    join w_base                       b on b.id = ofp.order_form_id
   group by ofp.order_form_id
)
select odf.id                                                      as id
     , nvl(p.products_total, 0)                                    as products_total
  from w_base                        odf
  left join w_products                 p on p.order_form_id = odf.id;
```

## 13. Optimizer Hints

A hint is a **directive** the optimizer obeys whenever it is valid — and a
last resort, not a formatting habit. Whether a hint is justified at all,
which one to use, and how to prove it works is covered by the
[`oracle-optimizer-hints`](../skills/oracle-optimizer-hints/SKILL.md) skill.
This section only defines how a hint that *does* get committed must look.

- **Placement**: immediately after the `select`/`insert`/`update`/`delete`/`merge` keyword of the query block it targets, on the same line. When a `select` carries a hint, the first column moves to the next line, indented 7 spaces so it lines up with the leading-comma rows below it.
- **Lowercase**, like every other keyword. Hints are case-insensitive.
- **Aliases only**: reference the table alias exactly as written in that query block — never the table name when it has an alias, never `schema.table`. A wrong reference is silently ignored.
- **One alias per join/access hint**: `use_nl(c) use_nl(ol)`, not the compound `use_nl(c ol)`. Join-method hints (`use_nl`/`use_hash`/`use_merge`) always come with a `leading(...)` that lists every table of the join.
- **Index hints by column list when possible**: `index(o (customer_id order_date))` survives index renames; an index name that doesn't exist is silently ignored.
- **Cross-block hints use `qb_name`**: name the inner block with `qb_name(x)` and target it with `@x` — never dot-notation `view.alias`.
- **No prose inside the hint comment** — free text (or an unknown word with parentheses) silently disables every hint after it. Explanations go in the justification comment.
- **Justification comment is mandatory** directly above the statement, following the TODO format in §3: `-- HINT_[Initials]_<MONTH-DD-YYYY> <why> | evidence: <what proved it> | <ticket>`.
- **Never commit diagnostic hints** (`gather_plan_statistics`, `monitor`, `no_query_transformation`), undocumented estimate hints (`cardinality`, `opt_estimate`, ...), or deprecated ones (`rule`, `ordered`, `noparallel`). The only undocumented hint allowed is `materialize`, and only with `STARTS` evidence in its justification comment. See the skill's `hint-catalog.md` for the full verdict list.
- **Never build hint text from user input** in dynamic SQL — see `security.md` §1.
- **Every committed hint must show as used** (no `E`/`N`/`U` marker) in the 19c+ hint report: `dbms_xplan.display_cursor(format => 'typical +hint_report')`. An unused hint is dead code — remove it. Two exceptions: `append`/`append_values` never appear in the report (prove them with `LOAD AS SELECT` in the plan), and APEX `APEX$...` pseudo hints always show as `E` by design.

**GOOD**:
```sql
-- HINT_AFLORES_SEPTEMBER-25-2026 first_rows(25) + nested loops: the IR shows 25 of
-- ~2M rows; all_rows plan hash-joins everything first (12s -> 0.2s) | evidence:
-- hint report 4/4 used, A-Rows plan attached to ticket | CWMS-412
select /*+ first_rows(25) leading(o c) use_nl(c) index(o (status order_date)) */
       o.order_id                                          as order_id
     , o.order_date                                        as order_date
     , c.customer_name                                     as customer_name
  from prefix_orders                  o
  join prefix_customers               c on c.customer_id = o.customer_id
 where o.status = :P10_STATUS
 order by o.order_date desc;
```

**BAD**:
```sql
select /*+ INDEX(prefix_orders PREFIX_ORDERS_IX9) use_nl(o c) gather_plan_statistics */ o.order_id
     , c.customer_name
  from prefix_orders o
  join prefix_customers c on c.customer_id = o.customer_id
 where o.status = :P10_STATUS;
```
Table name instead of alias (unresolved), a hard-coded index name, a compound join hint with no `leading`, a diagnostic hint left in, uppercase, and no justification comment.
