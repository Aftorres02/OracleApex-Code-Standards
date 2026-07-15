# Error Handling

**Single responsibility:** Which layer is allowed to raise which kind of
error — business packages vs. the APEX layer. Complements `security.md`
(don't leak raw errors to end users) and `apex-ux.md` (the `apex_error`
API pattern itself and the AJAX `{success, message}` convention).

> New file — authored directly (not consolidated from a prior source).

> **Summary:** `apex_error.add_error` only lives in the APEX layer (the
> global Error Handling Function or targeted Validations). Business
> packages always use `raise_application_error` or a custom exception —
> they never know APEX exists.

This is a hard rule, not a suggestion — the goal is zero mixing of
`apex_error.add_error` and `raise_application_error` across layers.

---

## 1. Separate by Layer, Not by Preference

| Layer | Uses | Never uses |
|---|---|---|
| Business packages (`_api`/`_utils`, no APEX awareness) | `raise_application_error(-20xxx, ...)` or a custom exception + `raise` | `apex_error.add_error` |
| APEX layer (Page Processes, Validations, the app-level Error Handling Function) | `apex_error.add_error` | `raise_application_error` directly surfaced to the end user |

---

## 2. Why the Split Exists

Business packages must be runnable outside an APEX context — scheduled
jobs, other applications, unit tests, SQL*Plus.

Calling `apex_error.add_error` inside a business package couples it to an
APEX session that may not exist. Error presentation is a UI concern — it
belongs to the APEX layer, not the package layer.

---

## 3. How the Layers Connect

Do not call `apex_error.add_error` manually at every process/package call
site.

Configure one application-level Error Handling Function (Shared Components
→ Error Handling) that intercepts any unhandled exception and translates it
via `apex_error.add_error` automatically.

Business packages only ever do `raise_application_error(-20001, 'Client not
found');` or raise a custom exception — nothing APEX-aware.

Calling `apex_error.add_error` by hand is only appropriate in two places:

### Inside the global Error Handling Function

This is the one place `apex_error.add_error` is expected to run
unconditionally, translating whatever exception reaches it.

### Inside a Validation needing custom association

Use it here only when you need to customize the message, severity, or
association (page item vs. page level) beyond what the global handler
resolves by default.

---

## 4. AJAX Callbacks

For AJAX processes returning JSON (the `{success, message}` pattern per
this project's convention — see `apex-ux.md` §2), catch the business
package's exception in an `exception when others` block inside the
callback and build the JSON response there.

Do not call `apex_error.add_error` in this path either — you're not
rendering a page, you're returning JSON.

---

## 5. Error Code Ranges

> **Open decision:** this project has not yet defined a `-20xxx` error
> code range convention. Ask before assigning custom exception codes so
> they land in a consistent, non-colliding range — don't invent one.

---

## 6. Example

**BAD** — business package calling `apex_error.add_error` directly:

```plsql
procedure get_client(
    p_client_id in prefix_clients.client_id%type
)
is
begin
  ...
exception
  when no_data_found then
    apex_error.add_error(
        p_message          => 'Client not found.'
      , p_display_location => apex_error.c_inline_with_field_and_notif
    );
end get_client;
```

**GOOD** — same procedure stays APEX-unaware; the app-level Error Handling
Function does the translation instead:

```plsql
procedure get_client(
    p_client_id in prefix_clients.client_id%type
)
is
begin
  ...
exception
  when no_data_found then
    raise_application_error(-20001, 'Client not found.');
end get_client;
```

The app's global Error Handling Function then receives `ORA-20001: Client
not found.` and calls `apex_error.add_error` on its behalf — see
`apex-ux.md` §1 for the `apex_error` pattern itself.
