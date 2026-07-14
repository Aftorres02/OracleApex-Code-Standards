---
description: Generate a CRUD APEX page (region + items + processes) following project standards.
---

# /gen-crud-page

**Single responsibility:** Generate a CRUD-style Oracle APEX page (form/report
region, items, processes) for a given table, following this project's APEX UX
and security standards. Does not generate the underlying table/PL/SQL — pair
with `new-package.md` for that.

**Invokes agent(s):** `../agents/apex-page-reviewer.md` (to validate the
generated page before returning it)

**Must follow rule(s):**
@../rules/apex-ux.md
@../rules/ddl-conventions.md
@../rules/security.md

> Placeholder — detailed generation steps not yet defined. <PROJECT_PREFIX>
> naming convention required before this command can produce real output.
