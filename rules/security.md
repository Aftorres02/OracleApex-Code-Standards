# Security

**Single responsibility:** Cross-cutting security requirements applied across
SQL, PL/SQL, and APEX layers — the rule every reviewer checks in addition to
its own layer-specific rule.

> Consolidated from `oracle-apex_standards.mdc` §1.3 (SQL injection) and §6.1
> (error-handling exposure), `docs/coding-standards/plsql/general.md` §4, and
> the security-review item from `docs/workflows/code-review.md`. Originals
> archived under `_archive/coding-standards-legacy/`.

## 1. SQL Injection Prevention

- Never concatenate user input into dynamic SQL.
- Use `execute immediate ... using ...` for dynamic statements (bind variables).
- Use `dbms_assert` when passing object names (tables, columns) dynamically.

**GOOD**:
```sql
execute immediate 'select count(*) from ' || dbms_assert.enquote_name(p_table) || ' where id = :1' using p_id;
```

**BAD**:
```sql
execute immediate 'select count(*) from ' || p_table || ' where id = ' || p_id;
```

## 2. Don't Leak Internal Errors to End Users

Do not expose raw exception text, stack traces, or `sqlerrm` details directly to APEX end users. Use the `apex_error` API / sanitized JSON error responses instead — see `apex-ux.md` §1–2 for the exact pattern (`apex_error.add_error`, AJAX `{"success": false, "message": ...}` responses). See `error-handling.md` for which layer is allowed to call `apex_error.add_error` in the first place.

## 3. Whitelist Client-Supplied Identifiers

When the client says *which* column, attribute or action to touch (e.g. an AJAX callback receiving `g_x02 = 'job'`), map it through a `case` statement with one branch per allowed value and **no `else`**. Any other value raises the predefined `CASE_NOT_FOUND`, so the whitelist needs neither dynamic SQL nor a custom `-20xxx` code (see `error-handling.md` §5).

**GOOD**:
```plsql
case lower(apex_application.g_x02)
  when 'ename'  then l_attr_number := 1;
  when 'job'    then l_attr_number := 2;
end case;  -- anything else raises CASE_NOT_FOUND
```

**BAD**: `execute immediate 'update prefix_emp set ' || apex_application.g_x02 || ' = :1 ...'` — the client picks the column.

## 4. Review Checklist Pointer

Code review must verify `dbms_assert` is used for dynamic objects and that bind variables are used throughout (not string concatenation) — see `git-workflow.md` for the full review checklist and how it maps to each rule file.
