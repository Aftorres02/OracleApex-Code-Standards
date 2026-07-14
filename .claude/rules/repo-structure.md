# Repo Structure

**Single responsibility:** How generated Oracle APEX project repos should be
laid out, and how APEX application changes are captured for version control.
Does not cover this standards repo's own `.claude/`/`docs/` layout — that's
documented in `.claude/STRUCTURE.md`. New file (previously scattered across
`docs/guides/developer-guide.md` and `docs/coding-standards/apex/repo_structure/`).

> Consolidated from `docs/guides/developer-guide.md` §6 (APEX export
> strategy). Links to, rather than duplicates, `docs/coding-standards/apex/repo_structure/README.md`
> (left in place — see constraint below) and the `release-process` skill.

## 1. Downstream Project Repo Layout

Any new Oracle APEX project repository generated from this standards repo should mirror the standard base layout documented in
[`docs/coding-standards/apex/repo_structure/README.md`](../../docs/coding-standards/apex/repo_structure/README.md)
(`apex/`, `data/`, `lib/`, `packages/`, `release/`, `scripts/`, `synonyms/`,
`triggers/`, `views/`, `www/`). That folder is kept in place, not migrated
here, since it's a scaffold template (with real utility scripts) rather than
prose — read it directly rather than duplicating its content.

## 2. Release Process

Versioned release/branching/tagging strategy (Dev → Test → Prod) is a
multi-step operational workflow, not a one-line rule — see the
`release-process` skill at `.claude/skills/release-process/SKILL.md`.

## 3. APEX Export Strategy

Use **YAML format** when exporting APEX application changes. This produces human-readable, diffable files that work well with version control and code review.

```bash
# Example: SQLcl APEX export in YAML format
apex export -applicationid 100 -split -skipExportDate -expType APPLICATION_SOURCE
```

> This generates a folder structure with individual `.yml` files per component, making it easy to see exactly what changed in a pull request.

`<PROJECT_PREFIX>` and the actual application ID(s) for this project are project-specific — fill in before relying on this as a runnable example.
