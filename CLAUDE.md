# <PROJECT_PREFIX> — Oracle APEX / PL/SQL Code Standards

This file is an **index only**. It does not contain standards content itself —
it imports the rule files that Claude Code should always load into context.
Detailed standards live under `.claude/rules/`, consolidated from the
repo's various prior standards documents — see `STANDARDS-AUDIT.md` for the
consolidation map and `_archive/coding-standards-legacy/` for the originals.

See `.claude/STRUCTURE.md` for a full explanation of how this configuration
directory is organized (rules vs. agents vs. commands vs. skills vs. hooks).

## Rules (always loaded)

@.claude/rules/sql-format.md
@.claude/rules/plsql-standards.md
@.claude/rules/ddl-conventions.md
@.claude/rules/apex-ux.md
@.claude/rules/security.md
@.claude/rules/javascript-standards.md
@.claude/rules/git-workflow.md
@.claude/rules/repo-structure.md
@.claude/rules/documentation-formatting.md
@.claude/rules/error-handling.md

## Other configuration

- Reviewer/generator subagents: `.claude/agents/`
- Slash commands: `.claude/commands/`
- Multi-step guides: `.claude/skills/`
- Git hooks: `.claude/hooks/`
