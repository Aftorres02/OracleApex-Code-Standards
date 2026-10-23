# Git Workflow

**Single responsibility:** Branch naming, compilation-code convention, and
the pull-request/code-review checklist — process rules around how code
moves through git, not the coding standards themselves. New file (previously
scattered across `developer-guide.md` and `docs/workflows/code-review.md`).

> Consolidated from `docs/workflows/code-review.md`, the branch/PR sections
> of `docs/guides/developer-guide.md` §4–5, and the PR-checklist proposal in
> `planning_repo_standards.md` §4. Originals archived under
> `_archive/coding-standards-legacy/` (`developer-guide.md` was edited in
> place rather than archived — see its "Contribution Workflow" section,
> which now links here).

## 1. Branch Naming

Branch names **must** follow: `<TICKET-NUMBER>-<short-description>` — ticket/issue number prefix, then a short, lowercase, hyphen-separated description.

**GOOD**: `NLM-21-adding-segments-to-client`, `TF-145-fix-invoice-totals`
**BAD**: `fix-stuff`, `angel-branch`, `feature/adding-segments`

## 2. Compilation Code Convention

Compilation scripts are organized by ticket number **without spaces**, preferably matching the branch name:

```
@code/NLM-21-adding-segments-to-client
```

This keeps branches, tickets, and deployed scripts traceable to each other.

## 3. Pull Request Workflow

1. Branch from `main` using the convention in §1.
2. Write code adhering to the standards in `.claude/rules/`.
3. Commit with descriptive messages.
4. Open a PR and fill out `.github/pull_request_template.md`.
5. Wait for peer review and CI/CD lint pass.

**Every change reaches `main` through a branch and a PR — no exceptions.** That includes doc-only fixes, one-line changes, and submodule pointer bumps (`git submodule update --remote .claude`). Never commit or push directly to `main`.

### Resolving merge conflicts

When a conflict appears (typically merging `main` into a feature branch), keep both sides unless one is deliberately superseded — two PRs editing the same doc section usually both belong in the result. After committing the merge, confirm nothing from `main` was silently dropped:

```bash
git diff HEAD^2 HEAD -- <conflicted-file>
```

That diff compares the merge result with the `main` side: every `-` line is `main` content the resolution removed. Any `-` line you didn't mean to remove is a lost change — restore it before pushing.

## 4. Code Review Checklist

Reviewer expectations — each item enforces a standard defined elsewhere; this list is the enforcement surface, not the source of truth:

| Check | Standard |
|---|---|
| Formatting (leading commas, lowercase SQL keywords, 2-space indent) | `sql-format.md` |
| Business logic lives in database packages, not APEX processes | `plsql-standards.md` |
| No `select *`; queries use valid indexes | `sql-format.md` |
| `dbms_assert` for dynamic objects; bind variables used | `security.md` |
| All APEX processes have a Server-side Condition | `apex-ux.md` |
| Column aliases on every `select`, especially in joins | `sql-format.md` |
| No HTML embedded in report SQL | `apex-ux.md` |
| No standalone procedures/functions — packages only | `plsql-standards.md` |
| `%type` preferred over hardcoded datatypes | `plsql-standards.md` |
| `varchar2` columns use `char` semantics | `ddl-conventions.md` |
| `logger.log_error` / `apex_error.add_error` used for error handling | `security.md`, `apex-ux.md` |
| TODOs use `-- TODO_[Initials]_<MONTH-DD-YYYY>` | `sql-format.md` |
| Identifiers and comments in English | `language.md` |
| Private package units have no leading `_` | `plsql-standards.md` |
| Committed optimizer hints have a `-- HINT_...` justification and show as used in the hint report | `sql-format.md` §13 |
| Branch name and compilation code follow convention | §1–2 above |

Developer expectations: verify the code works locally, ensure `logger.log()` instrumentation is present for new packages, fix all PR comments before re-requesting review, and confirm branch/compilation naming before opening the PR.

The authoritative, current checklist a reviewer actually ticks through lives in `.github/pull_request_template.md` — keep it in sync with this table rather than duplicating standard text into it.
