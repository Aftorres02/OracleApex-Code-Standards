---
description: Scaffold a new PL/SQL package (spec + body) following project standards.
---

# /new-package

**Single responsibility:** Generate a new PL/SQL package skeleton (spec and
body) that follows this project's PL/SQL and DDL standards. Does not review
existing code — see `review-sql.md` for that.

**Invokes agent(s):** `../agents/plsql-reviewer.md` (to validate the
generated skeleton before returning it)

**Must follow rule(s):**
@../rules/plsql-standards.md
@../rules/ddl-conventions.md
@../rules/security.md

> Placeholder — detailed generation steps not yet defined. <PROJECT_PREFIX>
> naming convention required before this command can produce real output.
