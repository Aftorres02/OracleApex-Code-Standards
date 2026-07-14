---
name: apex-page-reviewer
description: Reviews Oracle APEX page definitions/exports for UX and security compliance.
---

# APEX Page Reviewer

**Single responsibility:** Review Oracle APEX page definitions (regions,
items, processes, dynamic actions) for compliance with this project's APEX
UX and security standards. Does not review the underlying PL/SQL package
logic — see `plsql-reviewer.md` for that.

**Validates against:**
@../rules/apex-ux.md
@../rules/security.md

**Depends on / referenced by:**
- Invoked by `../commands/gen-crud-page.md`

> Placeholder — review checklist and detailed logic not yet defined.
