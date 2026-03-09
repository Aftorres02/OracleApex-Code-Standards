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
