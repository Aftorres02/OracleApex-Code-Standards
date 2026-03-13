# APEX Specific Standards

## 1. APEX Error Handling

Never use raw internal PL/SQL exceptions to show messages to APEX users. Use the `apex_error` API.

### Examples

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

## 2. AJAX Procedures

Procedures intended for APEX AJAX callbacks (e.g., On-Demand Processes) should:

1. Read inputs from `apex_application.g_x01`, `g_x02`, etc.
2. Return JSON using `apex_json` package.
3. Handle exceptions explicitly by returning a JSON object with `success: false`.

### Examples

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

## 3. Process Conditions

All APEX processes in the **Processing** section **must** have a condition. Typically this is a Server-side Condition tied to a button or a `REQUEST IN ()` expression. This prevents processes from running on unintended page submissions.

When possible, use **Expression** type conditions (e.g., `Type = Expression`, `Expression 1 = :REQUEST`, `Expression 2 = 'CREATE'`). Expressions are easier to identify in the APEX Builder tree and make reviewing differences across environments simpler.

### Examples

**GOOD**:

| Attribute | Value |
|---|---|
| **Server-side Condition Type** | Expression |
| **Expression 1** | `:REQUEST` |
| **Expression 2** | `'CREATE'` |

Or equivalently:

| Attribute | Value |
|---|---|
| **Server-side Condition Type** | Request is contained in Value |
| **Value** | `CREATE,SAVE` |

**BAD**:

| Attribute | Value |
|---|---|
| **Server-side Condition Type** | *- No Condition -* |

> ⚠️ A process without a condition will execute on **every** page submit, including navigation and other buttons.

## 4. Never Put HTML Inside SQL Queries

Do not embed HTML markup inside `select` statements used in APEX reports. Instead, use **APEX Template Directives** (`#COLUMN_NAME#`, Template Components, or HTML Expression attributes in the column definition) to control the rendering in the report.

### Examples

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

## 5. Popup LOV — Display Null Value

When a Popup LOV item has **Display Null Value** enabled, always use the application-level substitution string `&SELECT_LABEL.` for the null display text. The value of this substitution must be set to `- Select -` (or the agreed-upon label) at the application level.

### Example

| Attribute | Value |
|---|---|
| **Display Null Value** | Yes |
| **Null Display Value** | `&SELECT_LABEL.` |

This ensures every LOV in the application shows a consistent prompt and the label can be changed globally from a single place.

## 6. DML Form — Convert to SQL

When using the APEX **Automatic DML** (Form Region), do **not** leave the default "Table" mode. Instead:

1. Assign the target table.
2. Convert the DML process to **PL/SQL Code** or **SQL** mode.
3. Only keep the columns that are **actually needed** by the form.
4. Comment out or remove any columns that generate unnecessary APEX items.

This prevents APEX from creating hidden page items for every column in the table, which adds unnecessary overhead and potential security exposure.

### Example

```sql
-- After converting to SQL, only include the columns you need:
insert
  into tf_tickets (
       description
     , priority
     , assigned_to
     -- , internal_notes  -- not needed on this form
     -- , legacy_code     -- not needed on this form
)
values (
       :P10_DESCRIPTION
     , :P10_PRIORITY
     , :P10_ASSIGNED_TO
);
```
