# Claude Code Configuration Structure

This document explains the `.claude/` configuration directory (and the root
`CLAUDE.md`) for anyone — human or AI — who has zero prior context on this
repository's Claude Code setup. Read this before adding, moving, or renaming
any file under `.claude/`.

---

## CLAUDE.md (root)

**Purpose:** The single entry point Claude Code loads for this project. It
tells Claude which standards apply by importing every file under `rules/`
via `@path` syntax. It is intentionally an *index*, not a rulebook.

**When Claude Code reads it:** Always — it (and everything it `@`-imports)
is loaded into context at the start of every session in this repo.

**Expected content:** Import statements (`@.claude/rules/*.md`) and short
pointers to `agents/`, `commands/`, `skills/`, `hooks/`. It should NOT
contain actual coding standards, review checklists, or command logic —
that content belongs in the files it points to. If you find yourself
pasting rule text here, move it to `rules/` instead.

**Naming convention:** Fixed filename, must stay at repo root as `CLAUDE.md`.

**Example:**
```md
@.claude/rules/plsql-standards.md
@.claude/rules/security.md
```

---

## .claude/settings.json / .claude/settings.local.json

**Purpose:** Harness-level configuration — permissions (which tools/commands
are auto-allowed or denied) and hook wiring (which scripts under `hooks/`
run on which events). `settings.json` is shared/committed team config;
`settings.local.json` is per-developer, machine-specific overrides (should
typically be gitignored).

**When Claude Code reads it:** Always — evaluated at session start for
permission and hook configuration.

**Expected content:** JSON only — `permissions.allow`/`permissions.deny`
arrays, and a `hooks` map wiring event names (e.g. `PreToolUse`) to scripts
under `hooks/`. It should NOT contain prose standards or agent/command
definitions — those live in their own directories.

**Naming convention:** Fixed filenames; do not create additional
`settings.*.json` variants outside these two.

**Example:**
```json
{
  "hooks": {
    "PreCommit": [".claude/hooks/pre-commit-lint.sh"]
  }
}
```
> Note: hook wiring above is illustrative — this scaffold ships with
> `hooks` empty in `settings.json`; wire `pre-commit-lint.sh` in explicitly
> once you decide how it should be triggered (git hook vs. Claude Code
> hook event).

---

## .claude/rules/

**Purpose:** The source of truth for *what is and isn't allowed* in code —
SQL formatting, PL/SQL standards, DDL conventions, APEX UX, security,
JavaScript, git workflow, and repo structure. Each file owns exactly one
concern so agents/commands can cite the narrowest relevant rule instead of
one giant standards document.

**Current files (10):**

| File | Covers |
|---|---|
| `sql-format.md` | SELECT/INSERT/MERGE formatting, JOIN alignment, CTEs |
| `plsql-standards.md` | Package structure, `%type`, parameter/call formatting, logging, doc tags |
| `ddl-conventions.md` | Table/constraint naming, data types, audit columns, triggers, seed data |
| `apex-ux.md` | Error handling, AJAX, process conditions, page/region/button naming, CSS |
| `security.md` | SQL injection prevention, error-message exposure |
| `javascript-standards.md` | Module pattern, naming, AJAX, DOM/event handling |
| `git-workflow.md` | Branch naming, compilation code, PR/code-review checklist |
| `repo-structure.md` | Generated-project repo layout, release process pointer, APEX export strategy |
| `documentation-formatting.md` | Markdown conventions for standalone docs — headings, lists, dividers, callouts |
| `error-handling.md` | Layer separation between `raise_application_error` (business packages) and `apex_error.add_error` (APEX layer) |

**When Claude Code reads it:** Always — every file here is imported by root
`CLAUDE.md`, so all of it is in context for every session.

**Expected content:** Declarative standards and conventions — naming
patterns, formatting requirements, required constructs, prohibited
patterns. It should NOT contain review workflow/logic (that's `agents/`)
or step-by-step generation instructions (that's `commands/`/`skills/`).

**Naming convention:** `<topic>.md`, lowercase-kebab-case, one concern per
file (e.g. `sql-format.md`, not `sql-and-plsql-format.md`).

**Example (shape only):**
```md
# PL/SQL Standards
- Package names: <PROJECT_PREFIX>_<DOMAIN>_PKG
- Every public procedure must have an exception handler that logs via ...
```

---

## .claude/agents/

**Purpose:** Subagent definitions that *review* code (or generated output)
for compliance with one or more `rules/*.md` files. Agents are the
"judges" — they apply rules, they don't author them.

**When Claude Code reads it:** On invocation — only loaded when explicitly
called (e.g. by a command, or via the Agent/Task tool), not on every turn.

**Expected content:** YAML frontmatter (`name`, `description`) plus a short
statement of the agent's single review responsibility and an explicit
`@import` (or named reference) to the `rules/*.md` file(s) it checks
against. It should NOT restate the rule content itself, and should NOT
contain slash-command-style user-facing instructions — that's `commands/`.

**Naming convention:** `<domain>-reviewer.md`, e.g. `plsql-reviewer.md`.

**Example (shape only):**
```md
---
name: plsql-reviewer
description: Reviews PL/SQL code for standards compliance.
---
Validates against:
@../rules/plsql-standards.md
@../rules/security.md
```

---

## .claude/commands/

**Purpose:** User-invocable slash commands (`/new-package`, `/review-sql`,
`/gen-crud-page`) that either generate new code or trigger a review. They
are the entry points a developer types; they orchestrate rules + agents.

**When Claude Code reads it:** On invocation — only when the user types the
matching `/command-name`.

**Expected content:** YAML frontmatter (`description`), the command's single
responsibility, which `agents/*.md` it invokes (if any), and which
`rules/*.md` it must follow. It should NOT contain the full rule text or
duplicate an agent's review logic inline — reference, don't copy.

**Naming convention:** `<verb>-<noun>.md`, matching the slash command name,
e.g. `review-sql.md` → `/review-sql`.

**Example (shape only):**
```md
---
description: Review SQL/PL/SQL files against project standards.
---
Invokes agent(s): ../agents/sql-perf-reviewer.md
Must follow: @../rules/sql-format.md
```

---

## .claude/skills/

**Purpose:** Longer, multi-step operational guides for workflows too
involved for a single command or rule file (e.g. running a versioned APEX
migration end-to-end). Skills package process knowledge, not one-line
rules or one-shot commands.

**When Claude Code reads it:** On invocation — loaded when the skill is
explicitly invoked (by name or when its trigger conditions are met),
similar to agents/commands.

**Expected content:** A `SKILL.md` per skill directory with YAML
frontmatter (`name`, `description`) followed by step-by-step guidance,
optionally with supporting files alongside it in the same folder. It
should NOT contain single-fact style coding rules (belongs in `rules/`)
nor a bare review checklist (belongs in `agents/`).

**Naming convention:** One directory per skill, `skills/<skill-name>/SKILL.md`,
kebab-case directory name matching the skill's `name:` frontmatter field.

**Example (shape only):**
```md
---
name: apex-migration
description: Multi-step guide for versioned APEX/DDL migrations.
---
1. Snapshot current page/DDL state...
2. Generate migration script...
```

---

## .claude/hooks/

**Purpose:** Executable scripts that run automatically on repo/session
events (e.g. before a commit) to enforce mechanical checks that don't need
an LLM — such as rejecting tab characters in SQL/PL/SQL files.

**When Claude Code reads it:** On event — only executed when wired to a
trigger (a git hook, or a `hooks` entry in `settings.json`); not loaded
into context otherwise.

**Expected content:** Executable shell (or other) scripts with a clear
pass/fail exit code and error message. It should NOT contain style/standard
definitions (belongs in `rules/`) — a hook enforces a mechanical check, it
doesn't document the reasoning behind it.

**Naming convention:** `<event>-<check>.sh`, e.g. `pre-commit-lint.sh`.

**Example (shape only):**
```sh
#!/usr/bin/env bash
# fails if staged .sql/.pks/.pkb files contain tabs
```

---

## Decision guide

| New content is...                                   | Put it in    |
|------------------------------------------------------|--------------|
| A standard/convention ("must", "should", "never")     | `rules/`     |
| Logic that judges existing code against a standard    | `agents/`    |
| A user-facing `/slash-command` entry point            | `commands/`  |
| A multi-step process/workflow guide                    | `skills/`    |
| A mechanical, non-LLM check tied to an event (git, CI) | `hooks/`     |
