# Outstanding Work

Running list of things still open in this repo after the `.claude/`
scaffolding + standards consolidation work. The coding standards themselves
(`sql-format.md`, `plsql-standards.md`, `ddl-conventions.md`, `apex-ux.md`,
`security.md`, `javascript-standards.md`, `git-workflow.md`,
`repo-structure.md`) are complete, consolidated, validated, and internally
consistent — everything below is scaffolding/tooling that references those
rules but isn't fully built out yet, plus a few deliberately-unresolved
ambiguities and housekeeping notes.

## 1. Command/agent scaffolding has no real workflow logic yet

These files exist and correctly reference the (now complete) rule files,
but their own bodies still just say `> Placeholder — ... not yet defined`:

- `.claude/commands/review-sql.md`
- `.claude/commands/new-package.md`
- `.claude/commands/gen-crud-page.md`
- `.claude/agents/plsql-reviewer.md`
- `.claude/agents/sql-perf-reviewer.md`
- `.claude/agents/apex-page-reviewer.md`

**Impact:** `/review-sql`, `/new-package`, `/gen-crud-page` all "work" today
in the sense that Claude Code reads them and knows which rules/agents to
apply, but there's no defined checklist, output format, or step-by-step
procedure — review quality depends on general judgment rather than a
consistent, repeatable process.

**Suggested fix:** Flesh out each command/agent with a concrete checklist
pulled from the rule files (similar to what was used in
`TEMPLATE-COMPLIANCE-REPORT.md`), plus a defined output format.

## 2. `<PROJECT_PREFIX>` never resolved to a real value

Still a literal placeholder in:

- `CLAUDE.md`
- `.claude/STRUCTURE.md`
- `.claude/rules/repo-structure.md`
- `.claude/commands/gen-crud-page.md`
- `.claude/commands/new-package.md`

Note: this is separate from the `tf_`→`prefix_` rename done for
*illustrative code examples* — those are now intentionally generic. This
item is about the meta-level `<PROJECT_PREFIX>` token in docs/config files,
which was never filled in with this project's actual prefix (if one has
been decided) or explicitly confirmed as "stays generic."

**Needs your input:** does this repo have a real project prefix yet, or
does it intentionally stay as a template for multiple downstream projects?

## 3. Pre-commit hook exists but isn't wired up

`.claude/hooks/pre-commit-lint.sh` (checks staged `.sql`/`.pks`/`.pkb` for
tab characters) is a working, executable script, but
`.claude/settings.json` still has `"hooks": {}` — it never runs
automatically. Flagged as a known gap since the initial scaffolding pass.

**Suggested fix:** decide whether this should be a git-native pre-commit
hook or a Claude Code `hooks` entry, then wire it in.

## 4. CI lint workflow is a stub

`.github/workflows/lint.yml` only runs `echo "Linting step (Placeholder for
sqlplus/sqlcl validation or sqlfluff)"` — no real linting happens in CI yet.

## 5. `apex-migration` skill has no body

`.claude/skills/apex-migration/SKILL.md` still has only YAML frontmatter
(`name`, `description`) — zero step-by-step content. It was scaffolded as
a stub from the start and never followed up on (unlike `release-process`,
which was fully written out from `repo_structure/release/README.md`).

## 6. Deliberately-unresolved template ambiguities

Carried over from `TEMPLATE-COMPLIANCE-FIXES.md` — flagged at the time as
not cleanly fixable without guessing, still true:

- **AJAX `@example` in `package_body_template.sql`**: the `<action>_<entity>_ajax`
  example is a bare call with no `dbms_output` script. `plsql-standards.md`
  §11's runnable-example rule doesn't clearly address procedures that take
  no explicit parameters (they read `apex_application.g_x01`/`g_x02`
  globals instead) — needs a rule clarification before the template can be
  confidently "fixed."
- **`package_spec_template.sql` JavaDoc placement**: unclear whether the
  spec needs its own `/** ... */` blocks (currently only the body has them)
  — `plsql-standards.md` §9 doesn't say whether spec, body, or both.
- **`javascript_module_template.js` return-block grouping comments**:
  cosmetic-only gap (no `// Lifecycle` / `// Rendering` style grouping in
  the return block) — optional, low priority.

## 7. Housekeeping: report files at repo root

`STANDARDS-AUDIT.md`, `CONSOLIDATION-VALIDATION.md`, `CONSOLIDATION-FIXES.md`,
`TEMPLATE-COMPLIANCE-REPORT.md`, `TEMPLATE-COMPLIANCE-FIXES.md`,
`PREFIX-RENAME-REPORT.md`, and this file are all sitting at the repo root.
They're useful as a historical record of the consolidation work, but once
things settle you may want to move them into something like
`docs/history/` or a dedicated `reports/` folder instead of leaving them at
top level indefinitely — your call, not urgent.
