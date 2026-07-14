---
name: sql-perf-reviewer
description: Reviews SQL statements for formatting compliance and performance issues.
---

# SQL Performance Reviewer

**Single responsibility:** Review raw SQL statements (queries/DML) for
compliance with SQL formatting standards and for common performance
pitfalls (missing bind variables, unindexed predicates, implicit
conversions). Does not review PL/SQL control structures — see
`plsql-reviewer.md` for that.

**Validates against:**
@../rules/sql-format.md
@../rules/security.md

**Depends on / referenced by:**
- Invoked by `../commands/review-sql.md`

> Placeholder — review checklist and detailed logic not yet defined.
