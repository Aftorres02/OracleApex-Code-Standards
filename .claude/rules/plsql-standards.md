# PL/SQL Standards

**Single responsibility:** Coding standards for PL/SQL packages, procedures,
functions — naming, structure, documentation, logging. Query/SQL formatting
lives in `sql-format.md`; table/DDL conventions live in `ddl-conventions.md`.

> Consolidated from `oracle-apex_standards.mdc` §2.1 (variable naming) and §5
> (PL/SQL package standards), `docs/coding-standards/plsql/{naming,packages}.md`,
> and `.cursor/rules/plsql-packages.mdc`. Originals archived under
> `_archive/coding-standards-legacy/`.

## 1. Variable & Parameter Prefixes

| Prefix | Scope/Type | Example |
|---|---|---|
| `l_` | Local Variables | `l_count` |
| `lc_` | Local Constants | `lc_max_size` |
| `p_` | IN Parameters | `p_ticket_id` |
| `o_` | OUT Parameters | `o_error_msg` |
| `io_` | IN OUT Parameters | `io_error_msg` |
| `g_` | Global Variables | `g_user` |
| `gc_` | Global Constants | `gc_scope_prefix` |
| `l_cursor` | Cursors (avoid explicit cursors — see `sql-format.md` §7) | `l_cursor` |
| `l_{context}_rec` | Records | `l_ticket_rec` |

## 2. Always Use Packages

Never build standalone functions/procedures. All logic lives in a package — namespace isolation, overloading support, organized schema.

**GOOD**:
```sql
create or replace package body prefix_tickets_api
as
  procedure create_ticket(
      p_description in varchar2
  )
  is
  begin
    null;
  end create_ticket;
end prefix_tickets_api;
/
```

**BAD**: a standalone `create or replace procedure create_ticket(...)` polluting the schema.

## 3. Package Structure & Naming

- Business logic packages: `*_api` (e.g. `prefix_tickets_api`)
- Utility packages: `*_utils` (e.g. `prefix_tickets_utils`)
- Every package body defines a scope constant for logging context:
```plsql
gc_scope_prefix constant varchar2(31) := lower($$plsql_unit) || '.';
```

## 4. Package Body Vertical Spacing

- **Between procedures and functions**: after `gc_scope_prefix` and after each `end <unit>;`, insert **exactly 8 blank lines** before the next unit's JavaDoc or declaration. This is the single authoritative number — do not use 6 or 1 (see [`package_body_template.sql`](../../docs/coding-standards/templates/package_body_template.sql), which has been corrected to match).
- **Delegated calls inside another unit**: wrap each delegated call in paired Level 1 banners (`-- ===...===`) — an opening block (banner + short title comment) immediately before the call, and a closing banner line immediately after the closing `);`.
- **Spacing around nested calls**: 2 blank lines between preceding logic and the opening banner; 1 blank line between the opening banner's closing `===` line and the call; 1 blank line after the closing banner before the next block.

**GOOD** (nested paired banners):
```plsql
    end;


    -- =========================================================================
    -- Ensure related header exists before detail rows.
    -- =========================================================================

    ensure_related_header(
        p_parent_id                     => p_parent_id
      , o_header_id                     => l_header_id
    );
    -- =========================================================================
```

## 5. Use `%type` References

Prefer anchored declarations (`table.column%type`) over hardcoded datatypes so code adapts automatically when column definitions change.

**GOOD**:
```plsql
procedure update_ticket(
      p_ticket_id                             in prefix_tickets.ticket_id%type
    , p_description                           in prefix_tickets.description%type
)
is
  l_status prefix_tickets.status%type;
begin
  select status
    into l_status
    from prefix_tickets
   where ticket_id = p_ticket_id;
end update_ticket;
```

## 6. Parameter Lists: Align Names and the `in` Keyword

When a signature spans multiple lines with leading commas:

1. **Parameter name column**: pad the first parameter line so every identifier starts in the same column as continuation lines (as if the first line also had `, ` before the name). With a 4-space base indent, continuation lines look like `    , p_foo`; the first line uses 6 spaces before `p_foo`.
2. **IN column**: pad so `in`/`out`/`in out` starts in the same vertical column on every line. **Project default: the `i` of `in` begins at column 49** (1-based). Widen the column for the entire signature if a name would cross it.
3. **Calls too**: the same leading-comma simulation applies to multi-line procedure/function calls — pad the first actual parameter, keep `=>` in one column.

**GOOD**:
```plsql
procedure validate_draft_milestone(
      p_project_milestone_id                    in cwms_project_milestones.project_milestone_id%type
    , p_baseline_type_rc_id                     in cwms_project_milestones.draft_baseline_type_rc_id%type
    , p_baseline_year                           in cwms_project_milestones.draft_baseline_year%type
)
```

## 7. Procedure / Function Call Formatting

- Opening `(` stays on the same line as the procedure/function name.
- Each parameter on its own line, leading commas.
- Vertically align `=>` (pad shorter parameter names).
- Close with `);` on its own line, aligned with the start of the name.
- When the call is a distinct delegation step inside another procedure, combine with the paired Level 1 banners from §4.

**GOOD**:
```plsql
procedure_name(
      p_param_one                     => 'Value'
    , p_param_two                     => 'Value Two'
    , p_param_three                   => 'Value Three'
);
```

## 8. Instrumentation (Logging)

- Every unit logs START, END, input params, and OTHERS exceptions via `logger`.
- Use `gc_scope_prefix || '<unit_name>'` as the scope.
- Conditional compilation (`$if $$verbose_output $then`) may be used for expensive debug-only logs (default `VERBOSE_OUTPUT:FALSE`).

```plsql
procedure calculate_totals(
    p_invoice_id in prefix_invoices.invoice_id%type
)
is
  l_scope  logger_logs.scope%type := gc_scope_prefix || 'calculate_totals';
  l_params logger.tab_param;
begin
  logger.append_param(l_params, 'p_invoice_id', p_invoice_id);
  logger.log('START', l_scope, null, l_params);
  -- business logic
  logger.log('END', l_scope, null, l_params);
exception
  when others then
    logger.log_error('Unhandled Exception', l_scope, null, l_params);
    raise;
end calculate_totals;
```

## 9. Documentation Tags

Every procedure/function needs a JavaDoc-style comment block:

| Tag | Required | Description |
|---|---|---|
| `@example` | Yes | Runnable script; use declaration alignment (§10); use an anonymous block with `dbms_output` when results aren't otherwise visible (§11) |
| `@issue` | Yes | Ticket/issue number — append a new `@issue` line per subsequent ticket rather than replacing the original |
| `@author` | Yes | Developer name and role |
| `@created` | Yes | Creation date |
| `@param` | Yes | One per parameter |
| `@return` | Functions only | Return type and description |
| `@input` | AJAX only | APEX globals read (`g_x01`, `g_x02`, etc.) |

## 10. `@example` Blocks: Match Declaration/Call Alignment

Multi-line `@example` calls must mirror the parameter layout of the declaration directly below (§6/§7):

- First actual: pad after ` * ` so the name starts in the same column as continuations.
- Continuations: leading `, ` on each subsequent line.
- Mode column: align every `=>` on the same column as `in`/`out`/`in out` on the declaration.
- Comment offset: use 2 fewer leading spaces inside `* ` comments than on the declaration line.

## 11. Runnable `@example`: When to Use Anonymous Blocks + `dbms_output`

An `@example` must be pasteable into SQL Developer/SQL*Plus and runnable once to validate the unit.

Use a **complete script** (`set serveroutput on`, `declare` section if needed, `begin...end;`, `dbms_output.put_line` for every result, trailing `/`) when:

| Situation | Why assignment-only isn't enough |
|---|---|
| Function returns `boolean` | Nothing appears in the worksheet output panel |
| `out`/`in out` parameters | Outputs only exist after the call — must be printed |
| Procedures (no return value) | No expression to assign |
| Return type otherwise not visible (`%rowtype`, object, nested table) | Nothing to inspect without printing attributes |

Assignment-only is acceptable for functions returning a single scalar with only `in` parameters, when the example only illustrates call syntax — but prefer wrapping in a block with `dbms_output.put_line(l_result)` anyway.

## 12. Procedure / Function Templates

Use the ready-to-copy skeletons in [`package_spec_template.sql`](../../docs/coding-standards/templates/package_spec_template.sql) and [`package_body_template.sql`](../../docs/coding-standards/templates/package_body_template.sql). They already encode §4 (8-blank-line spacing), §6 (parameter alignment), §9–11 (documentation tags) and §8 (logging).

## 13. Conditional Compilation for Verbose Logging

```sql
-- Default: verbose logging disabled
alter session set plsql_ccflags = 'VERBOSE_OUTPUT:FALSE';

-- To enable for a debugging session, then recompile the target package:
alter session set plsql_ccflags = 'VERBOSE_OUTPUT:TRUE';
alter package prefix_tickets_api compile body;
```

Background: [Jorge Rimblas — debugging logger conditional compilation](https://rimblas.com/blog/2020/05/debugging-logger-conditional-compilation/).
