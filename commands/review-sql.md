---
description: Review one or more PL/SQL/APEX/SQL files against project standards — manual, file-path-based, no git integration.
---

# /review-sql

**Single responsibility:** Run a standards review over one or more
SQL/PL-SQL/APEX files the developer names explicitly, and report findings.
Purely manual and file-path-based — no git integration of any kind (no
staged-file detection, no diffs, no hooks, no reference to committed
state). Does not modify files or generate new code — see
`new-package.md` / `gen-crud-page.md` for generation.

**Invokes agent(s):**
- `../agents/plsql-reviewer.md`
- `../agents/apex-page-reviewer.md`
- `../agents/sql-perf-reviewer.md`

**Must follow rule(s):**
@../rules/sql-format.md
@../rules/plsql-standards.md
@../rules/ddl-conventions.md
@../rules/apex-ux.md
@../rules/security.md
@../rules/error-handling.md

## How this command works

1. **Get the file list.** The developer passes one or more file paths as
   arguments, e.g. `/review-sql packages/cwms_task_api.pkb`. If no path is
   given, **ask which file(s) to review** — never guess, never scan the
   repo looking for candidates.

2. **Route each file** to the reviewer(s) it needs, based on file
   extension/content:
   - `.pkb`, `.pks`, or a `.sql` file containing `create or replace
     package`/`create table`/`create trigger` (DDL or package code) →
     `plsql-reviewer.md`
   - A file that's clearly APEX-layer (an APEX page export, an AJAX
     callback procedure, or anything referencing
     `apex_application.g_x0`, `apex_error`, page items like `P\d+_`, or
     region/page attributes) → `apex-page-reviewer.md`, **in addition to**
     `plsql-reviewer.md` if it's also PL/SQL
   - Every `.sql`/`.pkb`/`.pks` file, regardless of the above → also run
     `sql-perf-reviewer.md` as a secondary, advisory-only pass
   - If a file's type is ambiguous, say so and ask rather than guessing
     which reviewer(s) apply
   - If a file doesn't match any reviewer's scope at all (not SQL/PLSQL,
     not APEX-related), say so plainly instead of forcing a review

3. **Run each applicable reviewer** against each file, passing the file
   path and noting this is a pre-commit check on a file the developer is
   about to commit — not a merged/committed artifact, and not something
   to diff against git history.

4. **Aggregate the results** into one summary:
   - Overall verdict: **PASS** (every file's blocking reviewers passed) or
     **FAIL** (at least one file has a blocking violation from
     `plsql-reviewer.md` or `apex-page-reviewer.md`)
   - A per-file list: file → clean, or file → violations found (with the
     specific rule + line for each)
   - `sql-perf-reviewer.md` notes reported separately as advisory — they
     never flip the overall verdict to FAIL
   - If **FAIL**: end with **"Fix these before committing:"** followed by
     the exact list of violations that need fixing, each as
     `file:line — issue — what the rule requires`

5. This command is **advisory only**. It does not block, stage, commit,
   or modify anything — the developer reads the report and decides what
   to do with it.

## Constraints

- No git commands, no git hooks, no reference to staged/committed state
  anywhere in this workflow — this is purely file-path-based.
- Never modify a reviewed file. If the developer wants fixes applied,
  that's a separate, explicit follow-up request.
- If a rule file a reviewer depends on is missing or incomplete, surface
  that rather than guessing at what the standard should be.
