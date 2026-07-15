# Repo Structure

**Single responsibility:** How generated Oracle APEX project repos should be
laid out, and how APEX application changes are captured for version control.
Does not cover this package's own root layout — that's documented in
`STRUCTURE.md`. New file (previously scattered across
`guides/developer-guide.md` and a release-process skill's reference
material that has since moved to a separate repo — see below).

> Consolidated from `guides/developer-guide.md` §6 (APEX export strategy).
> Links to, rather than duplicates, the project scaffold and release
> process now maintained in a separate repo.

## 1. Downstream Project Repo Layout

Any new Oracle APEX project repository generated using this standards
package should mirror the standard base layout (`apex/`, `data/`, `lib/`,
`packages/`, `release/`, `scripts/`, `synonyms/`, `triggers/`, `views/`,
`www/`).

> Release/deployment process and full project scaffold now live in a
> separate repo: https://github.com/Aftorres02/OracleAPEX-Project-Template

## 2. Release Process

Versioned release/branching/tagging strategy (Dev → Test → Prod) is a
multi-step operational workflow, not a one-line rule.

> Release/deployment process and full project scaffold now live in a
> separate repo: https://github.com/Aftorres02/OracleAPEX-Project-Template

## 3. APEX Export Strategy

Use **YAML format** when exporting APEX application changes. This produces human-readable, diffable files that work well with version control and code review.

```bash
# Example: SQLcl APEX export in YAML format
apex export -applicationid 100 -split -skipExportDate -expType APPLICATION_SOURCE
```

> This generates a folder structure with individual `.yml` files per component, making it easy to see exactly what changed in a pull request.

`<PROJECT_PREFIX>` and the actual application ID(s) for this project are project-specific — fill in before relying on this as a runnable example.
