---
name: plsql-reviewer
description: Reviews PL/SQL code (packages, procedures, functions, triggers) for standards compliance.
---

# PL/SQL Reviewer

**Single responsibility:** Review PL/SQL code for compliance with this
project's PL/SQL, DDL, and security standards. Does not review raw SQL
formatting or APEX page UX — see the other reviewer agents for those.

**Validates against:**
@../rules/plsql-standards.md
@../rules/ddl-conventions.md
@../rules/security.md

**Depends on / referenced by:**
- Invoked by `../commands/new-package.md`
- Invoked by `../commands/review-sql.md`

> Placeholder — review checklist and detailed logic not yet defined.
