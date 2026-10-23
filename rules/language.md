# Language

**Single responsibility:** Which human language code, code comments, and
this standards package are written in — independent of formatting
(`sql-format.md`, `javascript-standards.md`) and markdown layout
(`documentation-formatting.md`).

> New file — authored directly (not consolidated from a prior source).

## 1. English for Code and Standards

Write all of the following in English, even when the team, the client, or
the project's planning documents use another language:

- **Identifiers** — tables, columns, constraints, packages, procedures,
  variables, page items, CSS classes, JavaScript functions.

- **Code comments of every kind** — inline `--`/`//` comments, section
  banners, JavaDoc/JSDoc blocks, `@example` scripts, `TODO_`/`HINT_`
  comments.

- **Every file in this standards package** — rules, skills, agents,
  commands, templates, guides.

**GOOD**:
```plsql
-- Resolve the Web Credential static ID; null means no auth
l_static_id := prefix_auth_utils.resolve_credential_static_id(p_credential_id);
```

**BAD**:
```plsql
-- Obtener el static ID de la credencial; null significa sin auth
l_id_estatico := prefix_utilidades_auth.obtener_id_estatico(p_credential_id);
```

## 2. What Is Not Covered

- **Project prose** that is neither code nor standards — planning
  documents, concept/implementation notes — may use the team's working
  language.

- **User-facing text** shown in the application (labels, help text,
  messages) follows the application's language, not this rule.
