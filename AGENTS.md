# Oracle APEX Coding Standards

This document is the **single source of truth** for all coding standards and best practices in this project. It is fully self-contained and can be exported independently.

---

## Table of Contents

1. [General Principles](#1-general-principles)
2. [Naming Conventions](#2-naming-conventions)
3. [Database — Tables & DDL](#3-database--tables--ddl)
4. [Query Standards — SELECT, INSERT, MERGE](#4-query-standards--select-insert-merge)
5. [PL/SQL Package Standards](#5-plsql-package-standards)
6. [APEX Application Layer](#6-apex-application-layer)
7. [APEX Page UX](#7-apex-page-ux)
8. [JavaScript Standards](#8-javascript-standards)
9. [CSS & Styling](#9-css--styling)
10. [Templates](#10-templates)

---

## 1. General Principles

- **Consistency**: Adhere strictly to the patterns defined in this document.
- **Case Sensitivity**:
  - **SQL/PLSQL**: Lowercase for keywords and identifiers.
  - **JavaScript**: camelCase for variables/functions, UPPERCASE for constants.
- **Indentation**: Use **2 spaces** for indentation. DO NOT use tabs.
- **Formatting**:
  - **Leading Commas**: Place commas at the beginning of the line for lists (columns, parameters).
  - **Vertical Alignment**: Align identifiers, types, column names, and assignments vertically for readability.
  - **Operators**: Place SQL operators (`and`, `or`) at the beginning of the line.
  - **Blocks**: Indent the content of `IF`, `LOOP`, `CASE`, and `BEGIN...END` blocks.
- **IF/THEN Formatting**: Keep `if` condition and `then` on the **same line**. Do not put `then` on a separate line.

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
    if l_count > 0 then
        process_data();
    end if;
END;
```

### 1.1. Code Sectioning

To improve scannability in long files, use standardized header blocks. The standard width is **80 characters**.

- **Level 1: High Importance / Complex Blocks** (Use `=`):
```sql
-- =============================================================================
-- IMPORTANT UPDATE FOR SEARCH RESULTS
-- =============================================================================
```

- **Level 2: Minor Blocks / Logic Separation** (Use `-`):
```sql
-- -----------------------------------------------------------------------------
-- Refresh cache
-- -----------------------------------------------------------------------------
```

- **In-line Comments**: Use a single space after `--`.

**GOOD**:
```sql
-- =============================================================================
-- IMPORTANT UPDATE FOR SEARCH RESULTS
-- =============================================================================
update search_index
   set active_yn = 'N';

-- -----------------------------------------------------------------------------
-- Refresh cache
-- -----------------------------------------------------------------------------
refresh_cache();
```

**BAD**:
```sql
--========================================
--IMPORTANT UPDATE
--========================================

--refresh cache
refresh_cache();
```

### 1.2. Technical Debt & TODOs

When code requires future action, follow this mandatory format:
`-- TODO_[Initials]_<MONTH-DD-YYYY> [Description]`

**GOOD**:
```sql
-- TODO_AFLORES_MARCH-09-2026 Pending validation with the business
```

**BAD**:
```sql
-- TODO: fix this later
```

### 1.3. Security & SQL Injection Prevention

- Never concatenate user input into dynamic SQL.
- Use `execute immediate ... using ...` for dynamic statements.
- Use `dbms_assert` when passing object names dynamically.

**GOOD**:
```sql
execute immediate 'select count(*) from ' || dbms_assert.enquote_name(p_table) || ' where id = :1' using p_id;
```

**BAD**:
```sql
execute immediate 'select count(*) from ' || p_table || ' where id = ' || p_id;
```

---

## 2. Naming Conventions

- **Keywords**: ALL SQL keywords in lowercase (`create`, `table`, `select`, `from`, `where`).
- **Objects**: ALL object names in `snake_case`.
- **Project Prefix**: All core architectural objects (Tables, Views, Packages) MUST begin with the approved project prefix (e.g., `tf_`).
  - **Tables**: Plural (e.g., `tf_tickets`)
  - **Views**: Plural names with suffix `_vw` (e.g., `tf_tickets_vw`)
  - **Packages**: `{module_name}_pkg` or `{module}_api`/`{module}_utils` (e.g., `tf_tickets_api`)
- **Validations**: Use `_yn` suffix for boolean flags (`active_yn`).

### 2.1. Variables & Parameters

Use standard prefixes to distinguish variable scope and type:

| Prefix | Scope/Type | Example |
|---|---|---|
| `l_` | Local Variables | `l_count` |
| `lc_` | Local Constants | `lc_max_size` |
| `p_` | IN Parameters | `p_ticket_id` |
| `o_` | OUT Parameters | `o_error_msg` |
| `io_` | IN OUT Parameters | `io_error_msg` |
| `g_` | Global Variables | `g_user` |
| `gc_` | Global Constants | `gc_scope_prefix` |
| `l_cursor` | Cursors | `l_cursor` |
| `l_{context}_rec` | Records | `l_ticket_rec` |

**GOOD**:
```plsql
procedure get_ticket_info(
    p_ticket_id                        in number
  , o_status                           out varchar2
  , io_error                           in out varchar2
) is
  l_count number;
begin
  -- ... logic here
  null;
end;
```

**BAD**:
```plsql
procedure get_ticket_info(
    ticket_id in number
  , status   out varchar2
) is
  count_val number;
begin
  -- ... logic here
  null;
end;
```

### 2.2. Constraints

Always use prefixes for constraints:

| Prefix | Type | Pattern |
|---|---|---|
| `fk_` | Foreign Key | `fk_<table>_<ref_table>` |
| `uk_` | Unique | `uk_<table>_<column>` |
| `ck_` | Check | `ck_<table>_<description>` |

**GOOD**:
```sql
alter table tf_tickets add constraint fk_tickets_users foreign key (user_id) references users (user_id);
```

**BAD**:
```sql
alter table tf_tickets add constraint tickets_users_fk foreign key (user_id) references users (user_id);
```

---

## 3. Database — Tables & DDL

### 3.1. Primary Key

The primary key column must follow the pattern `<entity_name>_id` — using the **entity name without the module prefix**. The module prefix belongs on the **table name** for schema-level uniqueness, but columns use only the entity name for readability.

**GOOD**:
```sql
create table tf_tickets (
    ticket_id number generated by default on null as identity (start with 1) primary key not null
);

create table cwco_change_orders (
    change_order_id number generated by default on null as identity (start with 1) primary key not null
);
```

**BAD**:
```sql
-- Generic "id" column — impossible to distinguish in joins
create table tf_tickets (
    id number generated by default on null as identity (start with 1) primary key not null
);

-- Prefix repeated in PK column — redundant
create table cwco_change_orders (
    cwco_change_order_id number generated by default on null as identity (start with 1) primary key not null
);
```

### 3.2. Data Types & Char Semantics

- **Strings**: MUST always use `char` byte semantics (e.g., `varchar2(100 char)`), never `byte` or implicit size.
- **Numbers**: Use `number` for IDs, or `number(p,s)` for decimals.
- **Dates**: Use `date` for dates without time specificity needs.
- **Timestamps**: Use `timestamp with local time zone` for audit events.
- **CLOB**: Use for large text fields (descriptions, notes).

**GOOD**:
```sql
create table tf_clients (
    client_id    number generated by default on null as identity (start with 1) primary key not null
  , client_name  varchar2(100 char)
  , email        varchar2(255 char)
);

alter table tf_clients add segment_4 varchar2(100 char);
```

**BAD**:
```sql
-- byte semantics — will silently truncate multi-byte characters
create table tf_clients (
    client_id    number generated by default on null as identity (start with 1) primary key not null
  , client_name  varchar2(100)
  , email        varchar2(255 byte)
);

alter table tf_clients add segment_4 varchar2(100 byte);
```

### 3.3. Standard Audit Columns & Active Flag

Every table must include the standard active flag and audit columns coalescing `sys_context`:

```sql
  , active_yn                    varchar2(1 char) default 'Y' not null
  , created_by                   varchar2(60 char) default
                                  coalesce(
                                    sys_context('APEX$SESSION','app_user')
                                  , regexp_substr(sys_context('userenv','client_identifier'),'^[^:]*')
                                  , sys_context('userenv','session_user')
                                  )
                                  not null
  , created_on                   timestamp with local time zone default localtimestamp not null
  , last_updated_by              varchar2(60 char)
  , last_updated_on              timestamp with local time zone
  , constraint ck_tf_tickets_active_yn check (active_yn in ('Y', 'N'))
```

### 3.4. Trigger Patterns (Audit Automation)

Maintain audit columns automatically using a **Compound Trigger**.

```sql
create or replace trigger tf_tickets_compound_trg
for insert or update on tf_tickets
compound trigger

  before each row is
  begin
    if updating then
      :new.last_updated_on := localtimestamp;
      :new.last_updated_by := coalesce(
                                sys_context('APEX$SESSION','app_user')
                              , regexp_substr(sys_context('userenv','client_identifier'),'^[^:]*')
                              , sys_context('userenv','session_user')
                              );
    end if;
  end before each row;

end tf_tickets_compound_trg;
/
```

> **Note on Soft-Deletes**: When performing a soft-delete (e.g., `update ... set active_yn = 'N'`), do **not** set `last_updated_by` or `last_updated_on` in your application code. The compound trigger handles it automatically.

### 3.5. Table Comments & DDL Structure

Comments are mandatory via `execute immediate`. This ensures scripts are re-runnable.

```sql
begin
  execute immediate 'comment on table tf_tickets is ''Tracks all support tickets in the system.''';
  execute immediate 'comment on column tf_tickets.ticket_id is ''Unique identifier for the ticket.''';
  execute immediate 'comment on column tf_tickets.description is ''User-provided description of the issue.''';
  execute immediate 'comment on column tf_tickets.active_yn is ''Soft-delete flag: Y = active, N = inactive.''';
end;
/
```

### 3.6. DDL File Structure

When writing the SQL file for a table, follow this order:

1. **Table Creation Statement** (with inline constraints).
2. **Performance Indexes**.
3. **Triggers** (compound trigger for audit).
4. **Comments** (grouped in a `begin...end;` block).

```sql
-- =============================================================================
-- 1. TABLE
-- =============================================================================
create table tf_tickets (
    ticket_id   number generated by default on null as identity (start with 1) primary key not null
  , description varchar2(200 char)
  , active_yn   varchar2(1 char) default 'Y' not null
  , created_by  varchar2(60 char) default
                coalesce(
                  sys_context('APEX$SESSION','app_user')
                , regexp_substr(sys_context('userenv','client_identifier'),'^[^:]*')
                , sys_context('userenv','session_user')
                )
                not null
  , created_on      timestamp with local time zone default localtimestamp not null
  , last_updated_by varchar2(60 char)
  , last_updated_on timestamp with local time zone
  , constraint ck_tf_tickets_active_yn check (active_yn in ('Y', 'N'))
);

-- =============================================================================
-- 2. INDEXES
-- =============================================================================
create index idx_tf_tickets_active on tf_tickets (active_yn);

-- =============================================================================
-- 3. TRIGGERS
-- =============================================================================
create or replace trigger tf_tickets_compound_trg
for insert or update on tf_tickets
compound trigger

  before each row is
  begin
    if updating then
      :new.last_updated_on := localtimestamp;
      :new.last_updated_by := coalesce(
                                sys_context('APEX$SESSION','app_user')
                              , regexp_substr(sys_context('userenv','client_identifier'),'^[^:]*')
                              , sys_context('userenv','session_user')
                              );
    end if;
  end before each row;

end tf_tickets_compound_trg;
/

-- =============================================================================
-- 4. COMMENTS
-- =============================================================================
begin
  execute immediate 'comment on table tf_tickets is ''Tracks all support tickets.''';
  execute immediate 'comment on column tf_tickets.ticket_id is ''Unique ticket identifier.''';
  execute immediate 'comment on column tf_tickets.description is ''Issue description.''';
end;
/
```

---

## 4. Query Standards — SELECT, INSERT, MERGE

### 4.1. SELECT Patterns

- **Alignment**: Place first column on same line as `select` (2 spaces out). Align subsequent columns vertically with leading commas.
- **Aliases**: Name the alias for every column (`as my_col`).
- **Table Aliases**: Always use table aliases in joins.

**GOOD**:
```sql
select id
     , parent_id
     , nombre
     , description
  from demo_hierarchical_data
 where active_yn = 'Y'
 order by orden;
```

**BAD**:
```sql
SELECT ID, PARENT_ID, NOMBRE, DESCRIPTION
FROM DEMO_HIERARCHICAL_DATA
WHERE ACTIVE_YN='Y'
ORDER BY ORDEN;
```

### 4.2. Always Alias Columns

Name the alias for every column. This makes the query self-documenting, prevents ambiguity in joins, and makes it easier to identify columns in reports.

**GOOD**:
```sql
select c.customer_id        as customer_id
     , c.customer_name      as customer_name
     , o.order_date         as last_order_date
     , o.total_amount       as order_total
  from tf_customers          c
  join tf_orders             o on o.customer_id = c.customer_id
 where c.active_yn = 'Y';
```

**BAD**:
```sql
-- No aliases, ambiguous column references
select customer_id
     , customer_name
     , order_date
     , total_amount
  from tf_customers
  join tf_orders on tf_orders.customer_id = tf_customers.customer_id
 where active_yn = 'Y';
```

### 4.3. LEFT JOIN Alignment

`on` stays on the same line as the joined table and alias. `and` stays on the next line aligned with expressions after `on`.

**GOOD**:
```sql
select i.invoice_id             as invoice_id
     , c.client_name            as client_name
     , bus.business_name        as business_name
     , ba.bank_address          as bank_address
  from tf_invoices i
  left join tf_clients        c on c.client_id = i.client_id
                               and c.active_yn = 'Y'
  left join tf_businesses   bus on bus.business_id = i.business_id
                               and bus.active_yn = 'Y'
  left join tf_bank_info     ba on ba.bank_id = i.bank_id
 where i.active_yn = 'Y';
```

**BAD**:
```sql
-- Misaligned joins, no aliases, conditions scattered
select i.invoice_id, client_name, business_name
  from tf_invoices i
LEFT JOIN tf_clients ON tf_clients.client_id = i.client_id AND tf_clients.active_yn = 'Y'
LEFT JOIN tf_businesses ON tf_businesses.business_id = i.business_id;
```

### 4.4. Function Calls in SELECT

Break multi-parameter functions across lines, vertically aligned `=>`.

- Opening parenthesis stays on the same line as the function name.
- Each parameter on its own line, indented 2 spaces inside the parentheses.
- Named parameter arrows (`=>`) vertically aligned.
- Closing parenthesis on its own line, aligned with the function start.

**GOOD**:
```sql
select apex_item.checkbox2(
           p_idx   => 1
         , p_value => s.segment_num
       ) as copy_segment
     , s.segment_label
     , apex_item.checkbox2(
           p_idx   => 2
         , p_value => s.segment_num
       ) as copy_options
  from tf_segments s
```

**BAD**:
```sql
-- Parameters on one line breaks readability and column alignment
select apex_item.checkbox2(p_idx => 1, p_value => s.segment_num) as copy_segment
     , s.segment_label
```

### 4.5. Avoid Cursors — Use FOR Loop Queries

Do not declare explicit cursors (`open`, `fetch`, `close`). Use implicit cursor `for` loops. They are cleaner, less error-prone, and automatically handle resource cleanup.

**GOOD**:
```plsql
for l_rec in (
  select ticket_id
       , description
    from tf_tickets
   where active_yn = 'Y'
)
loop
  process_ticket(
      p_ticket_id   => l_rec.ticket_id
    , p_description => l_rec.description
  );
end loop;
```

**BAD**:
```plsql
-- Explicit cursor: verbose, error-prone, and requires manual close
declare
  cursor c_tickets is
    select ticket_id
         , description
      from tf_tickets
     where active_yn = 'Y';
  l_rec c_tickets%rowtype;
begin
  open c_tickets;
  loop
    fetch c_tickets into l_rec;
    exit when c_tickets%notfound;
    process_ticket(
        p_ticket_id   => l_rec.ticket_id
      , p_description => l_rec.description
    );
  end loop;
  close c_tickets;
end;
```

### 4.6. INSERT Patterns

Always use the column list and leading commas.

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

**BAD**:
```sql
insert into employees values (p_employee_id, p_first_name, p_last_name);
```

### 4.7. MERGE Patterns

Use `merge` for sync/upsert operations.

**GOOD**:
```sql
merge into tf_task_list t
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

**BAD**:
```sql
-- Separate select + conditional insert/update — race condition prone
begin
  select count(*)
    into l_count
    from tf_task_list
   where task_id = p_task_id;

  if l_count > 0 then
    update tf_task_list set task_name = p_task_name where task_id = p_task_id;
  else
    insert into tf_task_list (task_name, active_yn) values (p_task_name, 'Y');
  end if;
end;
```

### 4.8. Views and WITH Clause

- **Views**: Use a **WITH** clause (common table expressions) for view bodies.
- **CTE naming**: CTEs must start with **`w_`** (e.g. `w_base`, `w_inv`).

**GOOD**:
```sql
create or replace view tf_list_vw
as
with w_base as (
  select id
       , name
    from my_table
   where active_yn = 'Y'
)
select id
     , name
  from w_base;
```

**BAD**:
```sql
create or replace view tf_list_vw
as
  select id
       , name
    from my_table
   where active_yn = 'Y';
```

---

## 5. PL/SQL Package Standards

### 5.1. Always Use Packages

Never build standalone functions/procedures. All logic must be in packages. This provides namespace isolation, supports overloading, and keeps the schema organized.

**GOOD**:
```sql
create or replace package body tf_tickets_api
as

  procedure create_ticket(
      p_description in varchar2
  )
  is
  begin
    -- logic here
    null;
  end create_ticket;

end tf_tickets_api;
/
```

**BAD**:
```sql
-- Standalone procedure polluting the schema
create or replace procedure create_ticket(
    p_description in varchar2
)
is
begin
  -- logic here
  null;
end create_ticket;
/
```

### 5.2. Package Structure

- **Naming**:
  - Business Logic: `*_api` (e.g., `tf_tickets_api`)
  - Utilities: `*_utils` (e.g., `tf_tickets_utils`)
- **Scope Constant**: Define a scope prefix at the top of the body for logging context.

```plsql
gc_scope_prefix constant varchar2(31) := lower($$plsql_unit) || '.';
```

### 5.3. Use `%type` References

Prefer anchored declarations (`table.column%type`) over hardcoded datatypes. This ensures code automatically adapts when column definitions change.

**GOOD**:
```plsql
procedure update_ticket(
    p_ticket_id   in tf_tickets.ticket_id%type
  , p_description in tf_tickets.description%type
)
is
  l_status tf_tickets.status%type;
begin
  select status
    into l_status
    from tf_tickets
   where ticket_id = p_ticket_id;
end update_ticket;
```

**BAD**:
```plsql
-- Hardcoded types that will silently break if the column definition changes
procedure update_ticket(
    p_ticket_id   in number
  , p_description in varchar2
)
is
  l_status varchar2(30);
begin
  select status
    into l_status
    from tf_tickets
   where ticket_id = p_ticket_id;
end update_ticket;
```

### 5.4. Procedure / Function Call Formatting

For multi-line calls: `(` on same line. Parameters next line (2 spaces in). Vertically align `=>`. `);` aligned left with parameters.

**GOOD**:
```plsql
procedure_name(
    p_param_one   => 'Value'
  , p_param_two   => 'Value Two'
  , p_param_three => 'Value Three'
  , p_param_four  => 'Value Four'
);
```

**BAD**:
```plsql
procedure_name(p_param_one => 'Value',
               p_param_two => 2);
```

### 5.5. Instrumentation (Logging)

- Logging scope: `gc_scope_prefix constant varchar2(31) := lower($$plsql_unit) || '.';`
- Always log START, END, input params, and OTHERS exceptions via `logger`.
- **Conditional Compilation** can be used (`$if $$verbose_output $then`) for expensive debug logs.

```plsql
procedure calculate_totals(
    p_invoice_id in tf_invoices.invoice_id%type
)
is
  l_scope  logger_logs.scope%type := gc_scope_prefix || 'calculate_totals';
  l_params logger.tab_param;
  l_total  number;
begin
  logger.append_param(l_params, 'p_invoice_id', p_invoice_id);
  logger.log('START', l_scope, null, l_params);

  select sum(amount)
    into l_total
    from tf_invoice_lines
   where invoice_id = p_invoice_id;

  $if $$verbose_output $then
    logger.log('l_total calculated: ' || l_total, l_scope);
  $end

  logger.log('END', l_scope, null, l_params);
exception
  when others then
    logger.log_error('Unhandled Exception', l_scope, null, l_params);
    raise;
end calculate_totals;
```

**Conditional compilation setup**:
```sql
-- Default: verbose logging disabled
alter session set plsql_ccflags = 'VERBOSE_OUTPUT:FALSE';

-- To enable for a debugging session, then recompile the target package:
alter session set plsql_ccflags = 'VERBOSE_OUTPUT:TRUE';
alter package tf_tickets_api compile body;
```

### 5.6. Documentation Tags

Every procedure and function must include a JavaDoc-style comment block:

| Tag | Required | Description |
|---|---|---|
| `@example` | Yes | A runnable call example so the developer validates the code at least once |
| `@issue` | Yes | The ticket/issue number. Add a new `@issue` line for each subsequent ticket |
| `@author` | Yes | Developer name and role |
| `@created` | Yes | Creation date |
| `@param` | Yes | One per parameter, with a short description |
| `@return` | Functions only | Return type and description |
| `@input` | AJAX only | APEX global variables read by the procedure (`g_x01`, `g_x02`, etc.) |

> When a procedure is modified under a new ticket, append a new `@issue` line rather than replacing the original. This preserves the full change history directly in the source code.

### 5.7. Procedure Template

```plsql
/**
 * Short description of procedure.
 *
 * @example
 * procedure_name(
 *     p_value => 'Value'
 *   , o_error_message => null
 * );
 *
 * @issue   TF-101
 * @issue   TF-118 Added validation for duplicate names
 *
 * @author  Angel Flores (Consultant)
 * @created March 09, 2026
 *
 * @param p_value Description
 * @param o_error_message Output error
 * @param io_error In/Out error state
 */
procedure procedure_name(
    p_value                                   in varchar2
  , o_error_message                           out varchar2
  , io_error                                  in out varchar2
)
is
  l_scope  logger_logs.scope%type := gc_scope_prefix || 'procedure_name';
  l_params logger.tab_param;
begin
  logger.append_param(l_params, 'p_value: ', p_value);
  logger.log('START', l_scope, null, l_params);

  -- Business Logic Here

  logger.log('END', l_scope, null, l_params);
exception
  when OTHERS then
    logger.log_error('Unhandled Exception', l_scope, null, l_params);
    raise;
end procedure_name;
```

### 5.8. Function Template

```plsql
/**
 * Short description of function.
 *
 * @example
 * l_result := function_name(
 *     p_value => 'Value'
 * );
 *
 * @issue   TF-95
 *
 * @author  Angel Flores (Consultant)
 * @created March 09, 2026
 *
 * @param  p_value  Description of input
 * @return varchar2 Description of return value
 */
function function_name(
    p_value                                   in varchar2
)
return varchar2
is
  l_scope  logger_logs.scope%type := gc_scope_prefix || 'function_name';
  l_params logger.tab_param;
  l_return_value                              varchar2(100 char);
begin
  logger.append_param(l_params, 'p_value: ', p_value);
  logger.log('START', l_scope, null, l_params);

  l_return_value := 'value';

  logger.append_param(l_params, 'l_return_value: ', l_return_value);
  logger.log('END', l_scope, null, l_params);

  return l_return_value;
exception
  when OTHERS then
    logger.log_error('Unhandled Exception', l_scope, null, l_params);
    raise;
end function_name;
```

---

## 6. APEX Application Layer

### 6.1. APEX Error Handling

Use the `apex_error` API instead of raw internal PL/SQL exceptions to show messages to APEX users.

> **Note:** Some exceptions cannot be handled directly by APEX. In those cases, using `raise_application_error` is appropriate.

**GOOD**:
```plsql
apex_error.add_error(
    p_message          => 'Invalid ticket status.'
  , p_display_location => apex_error.c_inline_with_field_and_notif
  , p_page_item_name   => 'P1_STATUS'
);
```

**BAD**:
```plsql
raise_application_error(-20001, 'Invalid ticket status.');
```

### 6.2. AJAX Procedures

Procedures intended for APEX AJAX callbacks (e.g., On-Demand Processes) should:

1. Read inputs from `apex_application.g_x01`, `g_x02`, etc.
2. Return JSON using `apex_json` package.
3. Handle exceptions explicitly by returning a JSON object with `success: false`.

**GOOD**:
```plsql
procedure move_ticket_ajax
is
  l_ticket_id tf_tickets.ticket_id%type := apex_application.g_x01;
begin
  -- Business logic

  apex_json.open_object;
  apex_json.write('success', true);
  apex_json.close_object;

exception
  when OTHERS then
    apex_json.open_object;
    apex_json.write('success', false);
    apex_json.write('message', sqlerrm);
    apex_json.close_object;
end move_ticket_ajax;
```

**BAD**:
```plsql
-- Relying on htp.p casually and raising unhandled exceptions in AJAX
procedure move_ticket_ajax
is
begin
  htp.p('Success');
end;
```

### 6.3. Process Conditions

All APEX processes in the **Processing** section **must** have a condition. When possible, use **Expression** type conditions.

**GOOD** — Single request using Expression type:

| Attribute | Value |
|---|---|
| **Server-side Condition Type** | Expression |
| **Expression 1** | `:REQUEST in (CREATE,SAVE)` |

**GOOD** — Condition based on a page item:

| Attribute | Value |
|---|---|
| **Server-side Condition Type** | Expression |
| **Expression 1** | `:P1_OPERATION = 'DELETE'` |

**BAD** — No condition at all:

| Attribute | Value |
|---|---|
| **Server-side Condition Type** | *- No Condition -* |

> ⚠️ A process without a condition will execute on **every** page submit, including navigation and other buttons.

### 6.4. Never Put HTML In SQL

Avoid embedding HTML markup inside `select` statements used in APEX reports. Use **APEX Template Directives** instead.

**GOOD** — Use Template Directives in the column's HTML Expression attribute:
```html
<!-- Column HTML Expression in APEX Builder -->
<span class="u-color-success">#STATUS#</span>
```

```sql
-- The query stays clean, returning only data
select ticket_id
     , status
     , description
  from tf_tickets
 where active_yn = 'Y';
```

**BAD**:
```sql
-- HTML embedded in SQL — unmaintainable and violates separation of concerns
select ticket_id
     , '<span class="u-color-success">' || status || '</span>' as status
     , description
  from tf_tickets
 where active_yn = 'Y';
```

### 6.5. Select Lists (LOV)

When a Popup LOV item has **Display Null Value** enabled, always use the application-level substitution string `&SELECT_LABEL.` for the null display text.

| Attribute | Value |
|---|---|
| **Display Null Value** | Yes |
| **Null Display Value** | `&SELECT_LABEL.` |

This ensures every LOV in the application shows a consistent prompt and the label can be changed globally from a single place.

### 6.6. DML Forms

Convert Automatic DML forms to SQL or PL/SQL mode:

1. Assign the target table.
2. Convert the DML process to **PL/SQL Code** or **SQL** mode.
3. Only keep the columns that are **actually needed** by the form.
4. Comment out or remove any columns that generate unnecessary APEX items.

```sql
-- After converting to SQL, only include the columns you need:
select ticket_id
     , description
     , priority
     , assigned_to
     , active_yn
    -- , created_on
    -- , created_by
    -- , last_updated_on
    -- , last_updated_by
  from tf_tickets;
```

---

## 7. APEX Page UX

### 7.1. Page Numbering Convention

Organize APEX pages using a structured numbering scheme so that pages are logically grouped by module.

| Scope | Increment | Example |
|---|---|---|
| **Module** (top-level sections) | `100` | Clients = 100, Invoices = 200, Reports = 300 |
| **Detail / Modal pages** (within a module) | `10` | Client List = 100, Client Edit = 110, Client Dashboard = 120 |

**Example**:

| Page # | Name | Type |
|---|---|---|
| 100 | Clients | Interactive Report |
| 110 | Edit Client | Modal Dialog |
| 120 | Client Dashboard | Normal |
| 200 | Invoices | Interactive Report |
| 210 | Edit Invoice | Modal Dialog |
| 300 | Roles | Interactive Report |

### 7.2. Region Naming & IDs

**Hidden Regions**: Regions not displayed to the user must be named with curly braces as visual markers.

**GOOD**:

| Region Name | Purpose |
|---|---|
| `Tickets` | Visible report region |
| `{params}` | Hidden region holding `P10_TICKET_ID`, `P10_USER_ID`, etc. |
| `{ticket details}` | Hidden region, not rendered |

**BAD**:

| Region Name | Problem |
|---|---|
| `Hidden Region` | No convention, hard to scan |
| `params` | Missing curly braces, not clear it's hidden |

**Region Static IDs**: Assign meaningful static IDs using a suffix that denotes the region type.

| Suffix | Region Type |
|---|---|
| `IR` | Interactive Report |
| `CR` | Classic Report |
| `SR` | Static Content Region |

**GOOD**:

| Region Name | Static ID |
|---|---|
| Tickets | `ticketsIR` |
| Client List | `clientsCR` |
| {params} | `paramsSR` |

**BAD**:

| Region Name | Static ID |
|---|---|
| Tickets | `region1` |
| Client List | `R1234567` |

### 7.3. Button Standards

Button static IDs must be **the same as the button name** and in **UPPERCASE**.

**GOOD**:

| Button Name | Static ID |
|---|---|
| `CREATE` | `CREATE` |
| `SAVE` | `SAVE` |
| `DELETE` | `DELETE` |

**BAD**:

| Button Name | Static ID |
|---|---|
| `CREATE` | `btn_create` |
| `SAVE` | `B1234567` |

**Standard Button Icons**: Use application-level substitution strings for standard action button icons.

| Action | Substitution String |
|---|---|
| Create | `&CREATE_ICON.` |
| Delete | `&DELETE_ICON.` |
| Edit | `&EDIT_ICON.` |
| Save | `&SAVE_ICON.` |

| Attribute | Value |
|---|---|
| **Button Name** | `CREATE` |
| **Static ID** | `CREATE` |
| **Icon CSS Classes** | `&CREATE_ICON.` |

---

## 8. JavaScript Standards

### 8.1. Naming Conventions

- **Variables & Functions**: Use `camelCase`.
- **Constants**: Use `UPPER_CASE` with underscores.
- **Private Members**: Prefix with `_` (underscore) to signal they are internal.

**GOOD**:
```javascript
var ticketId = 123;
var isInitialized = false;
var MODULE_NAME = 'KanbanServices';
var MAX_RETRY_COUNT = 3;
var _currentDragTicket = null;

var fetchTicketDetails = function(ticketId) {
  // logic
};
```

**BAD**:
```javascript
var TicketId = 123;
var is_initialized = false;
var moduleName = 'KanbanServices';
var currentDragTicketPrivate = null;
```

### 8.2. Formatting

- **Indentation**: Use **2 spaces**. Avoid tabs.
- **Leading Commas**: Use leading commas for multi-line object literals, arrays, and parameter lists.
- **Strict Mode**: Always include `'use strict';` as the first statement inside the module IIFE.

**GOOD**:
```javascript
var CONFIG = {
    COLUMN_CLASS: '.column-5a'
  , CONTAINER_CLASS: '.tickets-container-5a'
  , TICKET_CLASS: '.ticket-card'
};
```

**BAD**:
```javascript
var CONFIG = {
  COLUMN_CLASS: '.column-5a',
  CONTAINER_CLASS: '.tickets-container-5a',
  TICKET_CLASS: '.ticket-card'
};
```

### 8.3. Code Sectioning

Use standardized section headers to group related functions within a module. Standard width is **64 characters** using `=`.

```javascript
/* ================================================================ */
/* SECTION NAME                                                      */
/* ================================================================ */
```

### 8.4. Revealing Module Pattern (IIFE)

All JavaScript must be organized using the **Revealing Module Pattern** wrapped in an IIFE. This avoids polluting the global scope.

```javascript
var namespace = namespace || {};

namespace.moduleName = (function(namespace, $, undefined) {
  'use strict';

  var MODULE_NAME = 'ModuleName';

  // CONFIG, logger, private variables...

  // Private functions...

  // Public API
  return {
      publicMethod: publicMethod
    , anotherMethod: anotherMethod
  };

})(namespace, apex.jQuery);
```

**Key rules**:
- The global `namespace` variable is initialized once per page. Each file must include the guard `var namespace = namespace || {};`.
- Pass `namespace` and `apex.jQuery` (aliased as `$`) as IIFE arguments.
- The third `undefined` parameter protects against accidental reassignment.
- Always include `'use strict';` as the first statement inside the IIFE.

### 8.5. CONFIG Object

Centralize all magic strings (AJAX process names, CSS selectors, threshold values) into a `CONFIG` object declared immediately after `MODULE_NAME`.

**GOOD**:
```javascript
var CONFIG = {
    COLUMN_CLASS: '.column-5a'
  , CONTAINER_CLASS: '.tickets-container-5a'
  , TICKET_CLASS: '.ticket-card'
  , DRAG_OVER_CLASS: 'drag-over'
  , AJAX_GET_TICKETS: 'get_tickets_for_column_ajax'
  , AJAX_MOVE_TICKET: 'move_ticket_ajax'
};
```

**BAD**:
```javascript
// Selectors and process names sprinkled across the file
var column = document.querySelector('.column-5a');
apex.server.process('get_url_ajax', ...);
```

### 8.6. Logger

Each module must include a self-contained logger that prefixes every message with the module name.

```javascript
var _PREFIX = '[' + MODULE_NAME + ']';
var logger = {
    log:     function(msg, data) { console.log(_PREFIX, msg, data || ''); }
  , warning: function(msg, data) { console.warn(_PREFIX, msg, data || ''); }
  , error:   function(msg, data) { console.error(_PREFIX, msg, data || ''); }
};
```

Usage:
```javascript
logger.log('Initializing kanban board...');
logger.log('Ticket moved successfully', {ticketId: ticketId, columnId: columnId});
logger.warning('No columns found during initialization');
logger.error('AJAX error updating ticket status', {status: textStatus, error: errorThrown});
```

### 8.7. Private vs Public Members

- **Private** functions and variables are declared with `var` inside the IIFE and prefixed with `_`.
- **Public** members are exposed via the `return` object at the bottom of the module.

| Scope | Prefix | Example |
|---|---|---|
| Private variable | `_` | `_currentDragTicket`, `_isModalOpening` |
| Private function | `_` | `_handleTicketClick`, `_loadColumnData` |
| Public variable | none | `isInitialized` |
| Public function | none | `initialize`, `refresh` |

```javascript
// Private — only accessible inside the module
var _currentDragTicket = null;

var _handleTicketClick = function(event) {
  // internal logic
};

// Public — returned at the end
var initialize = function() {
  // setup logic
};

return {
    initialize: initialize
  , refresh: refresh
};
```

### 8.8. Public API (Return Object)

Group the return entries by purpose and use leading commas.

```javascript
/* ================================================================ */
/* Return public API                                                 */
/* ================================================================ */
return {
    // Lifecycle
    initialize: initialize
  , refresh: refresh
  , refreshAfterRegionUpdate: refreshAfterRegionUpdate

    // Rendering
  , renderTicketsForColumn: renderTicketsForColumn

    // Actions
  , showTicketDetails: showTicketDetails
  , addTicket: addTicket
  , openTicketDetails: openTicketDetails
};
```

### 8.9. Module Separation (Services vs View)

When a feature grows beyond a single file, split it into two modules:

| Module | Suffix | Responsibility | Example |
|---|---|---|---|
| **Services** | `Services` | AJAX calls, data transformation, business logic | `namespace.kanbanServices` |
| **View** | `View` | DOM manipulation, event listeners, rendering | `namespace.kanbanView` |

The **View** module calls **Services** for data. Services should have no direct DOM dependencies.

```javascript
// View calls Services for data
namespace.kanbanServices.getTicketsForColumn(columnId, filters, function(tickets) {
  renderTicketsForColumn(columnId, tickets, true);
});
```

### 8.10. AJAX — Use `apex.server.process`

All AJAX calls to the backend must use `apex.server.process`.

```javascript
apex.server.process(
  CONFIG.AJAX_PROCESS_NAME,
  {
      x01: value1
    , x02: value2
  },
  {
    success: function(pData) {
      if (pData.success) {
        // Handle success
      } else {
        logger.error('Server returned error', {error: pData.message});
      }
    },
    error: function(jqXHR, textStatus, errorThrown) {
      logger.error('AJAX request failed', {status: textStatus, error: errorThrown});
    }
  }
);
```

**Key rules**:
- Reference AJAX process names from the `CONFIG` object, never hardcoded.
- Map `x01`, `x02`, etc. to match the PL/SQL backend reading from `apex_application.g_x01`, `g_x02`.
- Always handle **both** `success` and `error` callbacks.
- Inside `success`, always check `pData.success` — the HTTP request can succeed while server-side logic fails.

**GOOD**:
```javascript
success: function(pData) {
  logger.log('Response received', {success: pData.success});

  if (pData.success) {
    callback(pData.tickets || []);
  } else {
    logger.error('Server error', {error: pData.message});
    callback([]);
  }
}
```

**BAD**:
```javascript
success: function(pData) {
  // Assumes success without checking — server errors silently ignored
  callback(pData.tickets);
}
```

### 8.11. User Feedback (AJAX)

Use APEX built-in APIs for user-facing messages after AJAX operations:

| Outcome | API |
|---|---|
| Success | `apex.message.showPageSuccess('Ticket moved successfully');` |
| Error | `apex.message.showErrors('Failed to move ticket.');` |

Avoid using `alert()` or custom DOM-injected messages.

### 8.12. DOM & Event Handling

**Event Delegation**: Use event delegation on a stable parent element (typically `document`) rather than binding events directly to dynamic elements. APEX pages frequently re-render regions, so directly-bound handlers on dynamic elements will break after a refresh.

**GOOD**:
```javascript
var _setupEventListeners = function() {
  document.addEventListener('click', function(event) {
    if (event.target.classList.contains('ticket-number') ||
        event.target.closest('.ticket-number')) {
      event.preventDefault();
      _handleTicketNumberClick(event);
    }
  });
};
```

**BAD**:
```javascript
// Binds directly to elements that may not exist yet or will be replaced on refresh
$('.ticket-number').on('click', function() {
  // this handler is lost after region refresh
});
```

**DOM Queries**: Use `CONFIG` constants for CSS selectors. Prefer `document.querySelector` / `querySelectorAll`.

**GOOD**:
```javascript
var columnElement = document.querySelector('[data-column-id="' + columnId + '"]');
var ticketsContainer = columnElement.querySelector(CONFIG.CONTAINER_CLASS);
```

**BAD**:
```javascript
// Hardcoded selector — not refactoring-safe
var ticketsContainer = columnElement.querySelector('.tickets-container-5a');
```

**Data Attributes**: Use `data-*` attributes to store entity identifiers on DOM elements.

```javascript
ticketElement.setAttribute('data-ticket-id', ticket.TICKET_ID);
var ticketId = ticketElement.getAttribute('data-ticket-id');
```

**APEX Page Item Interaction**: Use `apex.item()` to read and write APEX page items.

**GOOD**:
```javascript
var userIds = apex.item('P10_ASSIGNED_TO_ID').getValue();
apex.item('P10_STATUS').setValue('CLOSED');
```

**BAD**:
```javascript
// Bypasses APEX session state and cascading LOVs
var userIds = $('#P10_ASSIGNED_TO_ID').val();
$('#P10_STATUS').val('CLOSED');
```

**Dynamic Item Names**: Build item names using `apex.env.APP_PAGE_ID` when page items follow a predictable pattern.

```javascript
var apexPageID = apex.env.APP_PAGE_ID;

var _filterConfig = {
    userFilterItem: 'P' + apexPageID + '_ASSIGNED_TO_ID'
  , searchFilterItem: 'P' + apexPageID + '_SEARCH'
  , priorityFilterItem: 'P' + apexPageID + '_PRIORITY'
};
```

**APEX Navigation & Dialogs**: Use `apex.navigation.dialog` to open modal dialogs.

```javascript
apex.navigation.dialog(
  pData.url,
  {
      title: 'Edit Ticket: ' + ticketNumber
    , modal: true
    , resizable: true
  },
  '',
  $(triggeringElement)
);
```

**Preventing Duplicate Actions**: Use a flag variable to prevent duplicate modal openings or AJAX calls on double-click.

```javascript
var _isModalOpening = false;

var _openTicketDialog = function(columnId, ticketId, triggeringElement) {
  if (_isModalOpening) {
    logger.warning('Modal already opening, ignoring duplicate request');
    return;
  }

  _isModalOpening = true;

  apex.server.process(CONFIG.AJAX_GET_URL, { x01: columnId }, {
    success: function(pData) {
      if (pData.success) {
        apex.navigation.dialog(pData.url, { modal: true }, '', $(triggeringElement));
      }
      // Reset flag in dialog close handler, not here
    },
    error: function() {
      _isModalOpening = false;
    }
  });
};
```

### 8.13. JSDoc Documentation

Every function (public and private) must include a JSDoc comment block.

| Tag | Required | Description |
|---|---|---|
| Description | Yes | First line, plain text description of the function |
| `@param` | Yes | One per parameter: `{type} name - Description` |
| `@returns` | When applicable | `{type} - Description` of the return value |

**GOOD**:
```javascript
/**
 * Get tickets for a specific column via AJAX
 * @param {string} columnId - The column ID
 * @param {Object} filters - Filter criteria object
 * @param {Function} callback - Callback function to handle tickets data
 */
var getTicketsForColumn = function(columnId, filters, callback) {
  // logic
};
```

### 8.14. File Header

Every JavaScript file must start with a header block.

```javascript
/*
 * ==========================================================================
 * FILE NAME
 * ==========================================================================
 *
 * @description Short description of the file purpose
 * @author      Author Name
 * @created     Month YYYY
 * @issue       TF-101
 * @version     1.0
 */
```

---

## 9. CSS & Styling

### 9.1. Custom Class Naming

Ensure all custom CSS classes are safely prefixed to avoid clashing with the APEX Universal Theme classes.

**GOOD**:
```css
.app-custom-card {
  padding: 1rem;
  background-color: var(--ut-body-bg);
}
```

**BAD**:
```css
/* This conflicts with native Oracle APEX Universal Theme styling */
.t-Card {
  background-color: red !important;
}
```

### 9.2. Universal Theme Best Practices

- Always attempt to use built-in declarative options within the APEX Builder (e.g., Template Options, Theme Roller) before resorting to writing custom CSS.
- When injecting custom properties, utilize Oracle's exposed CSS custom variables (`var(--ut-...)`) to maintain theme compatibility across updates.

---

## 10. Templates

### 10.1. Table Template

```sql
-- =============================================================================
-- Table:   <prefix>_<entity_name_plural>
-- Purpose: <Short description of the table.>
--
-- @author  <Author Name> (<Role>)
-- @created <Month DD, YYYY>
-- @ticket  <TICKET-NUMBER>
-- =============================================================================


-- =============================================================================
-- 1. TABLE
-- =============================================================================
create table <prefix>_<entity_name_plural> (
    <entity_name>_id             number generated by default on null as identity (start with 1) primary key not null
  , <column_1>                   varchar2(100 char)
  , <column_2>                   number
  , <fk_entity>_id               number
  , active_yn                    varchar2(1 char) default 'Y' not null
  , created_by                   varchar2(60 char) default
                                  coalesce(
                                    sys_context('APEX$SESSION','app_user')
                                  , regexp_substr(sys_context('userenv','client_identifier'),'^[^:]*')
                                  , sys_context('userenv','session_user')
                                  )
                                  not null
  , created_on                   timestamp with local time zone default localtimestamp not null
  , last_updated_by              varchar2(60 char)
  , last_updated_on              timestamp with local time zone
  , constraint ck_<prefix>_<entity_name_plural>_active_yn check (active_yn in ('Y', 'N'))
  , constraint fk_<entity_name_plural>_<ref_entity_plural> foreign key (<fk_entity>_id) references <prefix>_<ref_entity_plural> (<fk_entity>_id)
);


-- =============================================================================
-- 2. INDEXES
-- =============================================================================
create index idx_<prefix>_<entity_name_plural>_active on <prefix>_<entity_name_plural> (active_yn);
create index idx_<prefix>_<entity_name_plural>_<fk_entity> on <prefix>_<entity_name_plural> (<fk_entity>_id);


-- =============================================================================
-- 3. TRIGGERS
-- =============================================================================
create or replace trigger <prefix>_<entity_name_plural>_compound_trg
for insert or update on <prefix>_<entity_name_plural>
compound trigger

  before each row is
  begin
    if updating then
      :new.last_updated_on := localtimestamp;
      :new.last_updated_by := coalesce(
                                sys_context('APEX$SESSION','app_user')
                              , regexp_substr(sys_context('userenv','client_identifier'),'^[^:]*')
                              , sys_context('userenv','session_user')
                              );
    end if;
  end before each row;

end <prefix>_<entity_name_plural>_compound_trg;
/


-- =============================================================================
-- 4. COMMENTS
-- =============================================================================
begin
  execute immediate 'comment on table <prefix>_<entity_name_plural> is ''<Short description of the table.>''';
  execute immediate 'comment on column <prefix>_<entity_name_plural>.<entity_name>_id is ''Unique identifier.''';
  execute immediate 'comment on column <prefix>_<entity_name_plural>.<column_1> is ''<Description.>''';
  execute immediate 'comment on column <prefix>_<entity_name_plural>.<column_2> is ''<Description.>''';
  execute immediate 'comment on column <prefix>_<entity_name_plural>.active_yn is ''Soft-delete flag: Y = active, N = inactive.''';
end;
/
```

### 10.2. View Template

```sql
-- =============================================================================
-- View:    tf_<view_name>_vw
-- Purpose: <Short description of the view.>
--
-- @author  <Author Name> (<Role>)
-- @created <Month DD, YYYY>
-- @ticket  <TICKET-NUMBER>
-- =============================================================================
create or replace view tf_<view_name>_vw
as
with w_base as (
  select t.<table_name>_id          as <table_name>_id
       , t.<column_1>               as <column_1>
       , t.<column_2>               as <column_2>
       , r.<ref_column>             as <ref_column>
    from tf_<table_name>             t
    left join tf_<ref_table>         r on r.<ref_table>_id = t.<ref_table>_id
                                      and r.active_yn = 'Y'
   where t.active_yn = 'Y'
)
select <table_name>_id
     , <column_1>
     , <column_2>
     , <ref_column>
  from w_base;
```

### 10.3. Compound Trigger Template

```sql
-- =============================================================================
-- Trigger: tf_<table_name>_compound_trg
-- Purpose: Automatically maintains audit columns (last_updated_by,
--          last_updated_on) on every update to tf_<table_name>.
--
-- @author  <Author Name> (<Role>)
-- @created <Month DD, YYYY>
-- @ticket  <TICKET-NUMBER>
-- =============================================================================
create or replace trigger tf_<table_name>_compound_trg
for insert or update on tf_<table_name>
compound trigger

  before each row is
  begin
    if updating then
      :new.last_updated_on := localtimestamp;
      :new.last_updated_by := coalesce(
                                sys_context('APEX$SESSION','app_user')
                              , regexp_substr(sys_context('userenv','client_identifier'),'^[^:]*')
                              , sys_context('userenv','session_user')
                              );
    end if;
  end before each row;

end tf_<table_name>_compound_trg;
/
```

### 10.4. Package Spec Template

```plsql
create or replace package tf_<module>_api
as

  /**
   * Short description of procedure.
   *
   * @param p_value Description
   * @param o_error_message Output error
   */
  procedure procedure_name(
      p_value                                   in varchar2
    , o_error_message                           out varchar2
  );

end tf_<module>_api;
/
```

### 10.5. Package Body Template

```plsql
create or replace package body tf_<module>_api
as

  gc_scope_prefix constant varchar2(31) := lower($$plsql_unit) || '.';

  -- =============================================================================
  -- PROCEDURE: procedure_name
  -- =============================================================================
  /**
   * Short description of procedure.
   *
   * @example
   * procedure_name(
   *     p_value => 'Value'
   *   , o_error_message => null
   * );
   *
   * @issue   TF-101
   *
   * @author  <Author Name> (<Role>)
   * @created <Month DD, YYYY>
   *
   * @param p_value Description
   * @param o_error_message Output error
   */
  procedure procedure_name(
      p_value                                   in varchar2
    , o_error_message                           out varchar2
  )
  is
    l_scope  logger_logs.scope%type := gc_scope_prefix || 'procedure_name';
    l_params logger.tab_param;
  begin
    logger.append_param(l_params, 'p_value: ', p_value);
    logger.log('START', l_scope, null, l_params);

    -- Business Logic Here

    logger.log('END', l_scope, null, l_params);
  exception
    when OTHERS then
      logger.log_error('Unhandled Exception', l_scope, null, l_params);
      raise;
  end procedure_name;

end tf_<module>_api;
/
```

### 10.6. JavaScript Module Template

```javascript
/*
 * ==========================================================================
 * MODULE FILE NAME
 * ==========================================================================
 *
 * @description Short description of the module purpose
 * @author      Author Name
 * @created     Month YYYY
 * @issue       TF-101
 * @version     1.0
 */

var namespace = namespace || {};

namespace.moduleName = (function(namespace, $, undefined) {
  'use strict';

  /* ================================================================ */
  /* CONSTANTS & CONFIG                                                */
  /* ================================================================ */
  var MODULE_NAME = 'ModuleName';

  var CONFIG = {
      COLUMN_CLASS:    '.column-selector'
    , AJAX_PROCESS:    'ajax_process_name'
  };

  /* ================================================================ */
  /* LOGGER                                                            */
  /* ================================================================ */
  var _PREFIX = '[' + MODULE_NAME + ']';
  var logger = {
      log:     function(msg, data) { console.log(_PREFIX, msg, data || ''); }
    , warning: function(msg, data) { console.warn(_PREFIX, msg, data || ''); }
    , error:   function(msg, data) { console.error(_PREFIX, msg, data || ''); }
  };

  /* ================================================================ */
  /* PRIVATE VARIABLES                                                 */
  /* ================================================================ */
  var _isInitialized = false;

  /* ================================================================ */
  /* PRIVATE FUNCTIONS                                                 */
  /* ================================================================ */

  /**
   * Setup all event listeners for the module
   */
  var _setupEventListeners = function() {
    document.addEventListener('click', function(event) {
      if (event.target.closest(CONFIG.COLUMN_CLASS)) {
        event.preventDefault();
        // handle click
      }
    });
  };

  /* ================================================================ */
  /* PUBLIC FUNCTIONS                                                  */
  /* ================================================================ */

  /**
   * Initialize the module
   */
  var initialize = function() {
    if (_isInitialized) {
      logger.warning('Already initialized, skipping');
      return;
    }

    logger.log('Initializing...');
    _setupEventListeners();
    _isInitialized = true;
    logger.log('Initialized successfully');
  };

  /* ================================================================ */
  /* Return public API                                                 */
  /* ================================================================ */
  return {
      initialize: initialize
  };

})(namespace, apex.jQuery);
```
