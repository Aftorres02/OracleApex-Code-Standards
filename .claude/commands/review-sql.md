---
description: Review SQL/PL/SQL files against project standards.
---

# /review-sql

**Single responsibility:** Run a standards review over one or more
SQL/PL/SQL files and report findings. Does not modify files or generate new
code — see `new-package.md` / `gen-crud-page.md` for generation.

**Invokes agent(s):**
- `../agents/sql-perf-reviewer.md`
- `../agents/plsql-reviewer.md`

**Must follow rule(s):**
@../rules/sql-format.md
@../rules/plsql-standards.md
@../rules/security.md

> Placeholder — detailed review workflow not yet defined.
