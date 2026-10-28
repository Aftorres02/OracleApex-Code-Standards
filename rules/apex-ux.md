# APEX UX

**Single responsibility:** UX/UI and application-layer conventions for
Oracle APEX (error handling, AJAX, process conditions, page/region/button
naming, CSS/theming) — independent of the underlying SQL/PL/SQL.

> Consolidated from `oracle-apex_standards.mdc` §6 (APEX application layer),
> §7 (APEX page UX), §9 (CSS & styling), `docs/coding-standards/apex/apex.md`,
> `docs/coding-standards/apex/page-standards.md`, `docs/coding-standards/ui-ux/css.md`,
> and `.cursor/rules/apex-backend.mdc`. Originals archived under
> `_archive/coding-standards-legacy/`.

## 1. APEX Error Handling

Use the `apex_error` API instead of raw PL/SQL exceptions to show messages to APEX users.

> Some exceptions cannot be handled directly by APEX — in those cases `raise_application_error` is appropriate. See also `security.md` for guidance on not leaking raw exception text to end users, and `error-handling.md` for the full layer-separation rule (business packages never call `apex_error.add_error` directly).

**GOOD**:
```plsql
apex_error.add_error(
    p_message          => 'Invalid ticket status.'
  , p_display_location => apex_error.c_inline_with_field_and_notif
  , p_page_item_name   => 'P1_STATUS'
);
```

**BAD**: `raise_application_error(-20001, 'Invalid ticket status.');`

Reference: [Traust Toolkit APEX error handler](https://github.com/traustconsulting/Traust_OracleAPEX_Toolkit/tree/main/01_Core_Services/Traust_Error_Handler).

## 2. AJAX Procedures

Procedures for APEX AJAX callbacks (On-Demand Processes) must:

1. Read inputs from `apex_application.g_x01`, `g_x02`, etc.
2. Return JSON via `apex_json`.
3. Handle exceptions explicitly, returning `{"success": false}`.

**GOOD**:
```plsql
procedure move_ticket_ajax
is
  l_ticket_id prefix_tickets.ticket_id%type := apex_application.g_x01;
begin
  -- business logic
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

**BAD**: relying on `htp.p` casually and raising unhandled exceptions in AJAX.

## 3. Process Conditions

All APEX processes in the **Processing** section **must** have a condition. Prefer **Expression** type conditions — they're easier to identify in APEX export files.

**GOOD**: `Server-side Condition Type = Expression`, `Expression 1 = :REQUEST in (CREATE,SAVE)`
**BAD**: `Server-side Condition Type = - No Condition -`

> A process without a condition executes on **every** page submit, including navigation and other buttons.

## 4. Never Put HTML in SQL

Avoid embedding HTML markup inside `select` statements used in APEX reports. Use **APEX Template Directives** in the column's HTML Expression attribute instead.

**GOOD**:
```html
<!-- Column HTML Expression in APEX Builder -->
<span class="u-color-success">#STATUS#</span>
```
```sql
select ticket_id
     , status
     , description
  from prefix_tickets
 where active_yn = 'Y';
```

**BAD**: `'<span class="u-color-success">' || status || '</span>' as status` embedded in the query.

> **Note:** Template Directive syntax (`{if}`/`{endif}`, `{case}`/`{when}`/`{otherwise}`/`{endcase}`) is
> evaluated at runtime, not by any compiler or linter — a broken directive doesn't error, it silently
> falls back to the raw unstyled value. Verify the exact syntax against the official Oracle docs
> (`docs.oracle.com/en/database/oracle/apex/26.1/htmdb/using-template-directives.html`) or the
> `apexlang-lessons` skill's "Runtime-evaluated content" section before writing one, and confirm it
> actually renders before calling the work done — never trust a planning doc's literal HTML snippet.

## 5. Select Lists (Popup LOV)

When a Popup LOV item has **Display Null Value** enabled, always use the application-level substitution string `&SELECT_LABEL.` for the null display text (value: `- Select -` or the agreed label). This keeps every LOV's null prompt consistent and changeable from one place.

## 6. DML Forms

Convert Automatic DML forms away from default "Table" mode:

1. Assign the target table.
2. Convert the DML process to **PL/SQL Code** or **SQL** mode.
3. Only keep columns actually needed by the form; comment out the rest.

This avoids APEX creating hidden page items for every table column — unnecessary overhead and potential security exposure.

## 7. Page Numbering Convention

Organize APEX pages using a structured numbering scheme so pages are logically grouped by module. **This is the single authoritative scheme** — do not use any other numbering (a stale scratch-note version once existed and has been discarded).

| Scope | Increment | Example |
|---|---|---|
| **Module** (top-level sections) | `100` | Clients = 100, Invoices = 200, Roles = 300 |
| **Detail / Modal pages** (within a module) | `10` | List = x00, Edit = x10 (Modal), Dashboard = x20 |

| Page # | Name | Type |
|---|---|---|
| 100 | Clients | Interactive Report |
| 110 | Edit Client | Modal Dialog |
| 120 | Client Dashboard | Normal |
| 200 | Invoices | Interactive Report |
| 210 | Edit Invoice | Modal Dialog |
| 300 | Roles | Interactive Report |

## 8. Region Naming & IDs

**Hidden regions** (not displayed to the user) are named with curly braces: `{params}` for the standard hidden-items region, `{ticket details}` for other hidden regions.

**Region static IDs** use a suffix denoting the region type:

| Suffix | Region Type |
|---|---|
| `IR` | Interactive Report |
| `CR` | Classic Report |
| `SR` | Static Content Region |

**GOOD**: `Tickets → ticketsIR`, `Client List → clientsCR`, `{params} → paramsSR`
**BAD**: `Tickets → region1`, `Client List → R1234567`

## 9. Button Standards

Button static IDs must be **the same as the button name**, in **UPPERCASE**.

**GOOD**: `CREATE → CREATE`, `SAVE → SAVE`, `DELETE → DELETE`
**BAD**: `CREATE → btn_create`, `SAVE → B1234567`

Standard action button icons use application-level substitution strings: `&CREATE_ICON.`, `&DELETE_ICON.`, `&EDIT_ICON.`, `&SAVE_ICON.`

## 10. CSS & Styling

- **Custom class naming**: always prefix custom CSS classes to avoid clashing with APEX Universal Theme classes.

**GOOD**:
```css
.app-custom-card {
  padding: 1rem;
  background-color: var(--ut-body-bg);
}
```

**BAD**: overriding a Universal Theme class directly (e.g. `.t-Card { background-color: red !important; }`).

- **Universal Theme first**: prefer built-in declarative options (Template Options, Theme Roller) before writing custom CSS.
- When custom properties are unavoidable, use Oracle's exposed CSS variables (`var(--ut-...)`) to keep theme compatibility across updates.
- **Native utility classes before custom CSS**: the Universal Theme ships layout and component classes that cover most needs, including markup inside Template Components and region HTML. Classes verified on APEX 26.1:

| Need | Native classes |
|---|---|
| Flex layout | `u-flex`, `u-flex-direction-column`, `u-align-items-center`, `u-justify-content-*`, `u-gap-0` … `u-gap-10` |
| Grow / equal columns | `u-flex-grow-1`, `u-flex-basis-0`, `u-flex-shrink-0` |
| Spacing | `u-padding-*`, `u-margin-*` |
| Hide | `u-hidden` (removed from layout), `u-invisible` (keeps its space), `u-vh` (visually hidden, still read by screen readers) |
| Form fields outside an APEX item | `apex-item-text`, `apex-item-select`; full width with `stretch` |
| Invalid field | `apex-page-item-error` (theme's danger border) |
| Icon-only buttons | `t-Button t-Button--noLabel t-Button--icon`; add `t-Button--noUI` for no background |
| Labels | `t-Form-label` |

- **Equal-width columns**: put `u-flex-grow-1 u-flex-basis-0` on a wrapper `div` and `stretch` on the field inside it. Flex cannot shrink an item below its own padding, so with the classes on the fields themselves a select (wider padding for its arrow) ends up wider than the text inputs and headers no longer line up.

**GOOD**:
```html
<div class="u-flex u-align-items-center u-gap-2">
  <div class="u-flex-grow-1 u-flex-basis-0"><input type="text" class="apex-item-text stretch"></div>
  <div class="u-flex-grow-1 u-flex-basis-0"><select class="apex-item-select stretch"></select></div>
</div>
```

**BAD**: `<input class="apex-item-text u-flex-grow-1 u-flex-basis-0">` next to `<select class="apex-item-select u-flex-grow-1 u-flex-basis-0">` — the columns come out different widths.

- **Verify a class against the instance's theme CSS** before relying on it — class names change between versions. Download the CSS the page actually loads (`/i/<version>/app_ui/css/Core.min.css`, `/i/<version>/themes/theme_42/<version>/css/Core.min.css`) and search it; don't rely on memory.
- **Custom CSS only for what has no native equivalent** (e.g. a `:last-child` rule), and say in a comment why no utility class covers it.
