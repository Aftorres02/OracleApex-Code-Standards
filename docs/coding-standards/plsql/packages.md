# Package Standards

## 1. Always Use Packages

All PL/SQL logic should be encapsulated within a package rather than standalone functions or procedures. This provides namespace isolation, supports overloading, and keeps the schema organized.

### Examples

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

## 2. Package Structure

- **Naming**:
  - Business Logic: `*_api` (e.g., `tf_tickets_api`)
  - Utilities: `*_utils` (e.g., `tf_tickets_utils`)
- **Scope Constant**: Define a scope prefix at the top of the body for logging context.

```plsql
gc_scope_prefix constant varchar2(31) := lower($$plsql_unit) || '.';
```

## 3. Use `%type` References

Prefer anchored declarations (`table.column%type`) over hardcoded data types like `varchar2` or `number`. This ensures that your code automatically adapts when column definitions change and prevents type mismatches.

### Examples

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

## 4. Procedure / Function Calls

- **Multi-line calls:** Opening `(` on same line as call; parameters on next line(s) with 2-space indent; leading commas; closing `);` at same indent as parameters. Avoid deeply indenting parameters to align under the call name.

**GOOD**:

```plsql
procedure_name(
    p_param_one   => 'Value'
  , p_param_two   => 'Value Two'
  , p_param_three => 'Value Three'
  , p_param_four  => 'Value Four'
  , p_param_five  => 'Value Five'
  , p_param_six   => 'Value Six'
);
```

**BAD**:

```plsql
procedure_name(p_param_one => 'Value',
               p_param_two => 2);
```

## 5. Instrumentation (Logging)

- Use the `logger` package for all instrumentation.
- **Start/End**: Log start and end of all procedures/functions.
- **Parameters**: Log main input parameters using `logger.append_param`.
- **Exceptions**: Always catch and log using `logger.log_error`.

## 6. Documentation Tags

Every procedure and function in the package body should include a JavaDoc-style comment block with the following tags:

| Tag | Required | Description |
|---|---|---|
| `@example` | Yes | A runnable call example so the developer validates the code at least once |
| `@issue` | Yes | The ticket or issue number from the project tracker (Jira, GitHub Issues, Azure DevOps, etc.). Add a new `@issue` line for each subsequent ticket that modifies the procedure |
| `@author` | Yes | Developer name and role |
| `@created` | Yes | Creation date |
| `@param` | Yes | One per parameter, with a short description |
| `@return` | Functions only | Return type and description |
| `@input` | AJAX only | APEX global variables read by the procedure (`g_x01`, `g_x02`, etc.) |

> When a procedure is modified under a new ticket, append a new `@issue` line rather than replacing the original. This preserves the full change history directly in the source code.

## 7. Procedure Template

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

## 8. Function Template

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

## 9. Conditional Compilation for Verbose Logging

Use conditional compilation flags to enable verbose debug logging without incurring a runtime cost in production. Default is **off**. See [Jorge Rimblas](https://rimblas.com/blog/2020/05/debugging-logger-conditional-compilation/) for background.

### Setup

```sql
-- Default: verbose logging disabled
alter session set plsql_ccflags = 'VERBOSE_OUTPUT:FALSE';

-- To enable for a debugging session, then recompile the target package:
alter session set plsql_ccflags = 'VERBOSE_OUTPUT:TRUE';
alter package tf_tickets_api compile body;
```

### Usage Example

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

  -- Continue with business logic...

  logger.log('END', l_scope, null, l_params);
exception
  when others then
    logger.log_error('Unhandled Exception', l_scope, null, l_params);
    raise;
end calculate_totals;
```
