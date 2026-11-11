# Testing

**Single responsibility:** What must be tested, how utPLSQL test code is
named, organized and isolated, and what the CI gate must enforce. How to
set up CI lives in the `apex-ci-setup` skill; how to write and run a suite
step by step lives in the `utplsql-testing` skill.

> New file — authored from the CI and utPLSQL suite of
> `OracleAPEX-ErrorShield`, where every rule below was learned or
> verified.

## 1. Framework, Location and Naming

- Tests use **utPLSQL v3** and live in `tests/` at the repo root.

- One package per suite, named `ut_<prefix>_<area>` (e.g.
  `ut_ersh_masking`), spec in `.pks`, body in `.pkb`. The `ut_` prefix is
  what CI uses to find test packages and their compile errors.

- Test packages never ship: they are not listed in any release script
  (`all_packages.sql`, `_release.sql`).

- Test packages follow `plsql-standards.md` for formatting, but are exempt
  from its §8 logging and §9 JavaDoc tags — the `--%test(...)` description
  is their documentation.

## 2. What Needs a Test

- **Every bug fix** adds a regression test that fails without the fix. Put
  the ticket in the description: `--%test(get_message returns null for a
  deactivated code, ERSH-024)`.

- **Every business rule and every branch** of a public API — including
  the error and fail-safe paths, not only the happy path. When a fail-safe
  branch can only be reached through a real exception, force a real one
  (a null value is not an error).

- Private logic is tested **through the public unit that calls it**, never
  by making it public for the test.

## 3. Suite Structure

- `--%suite(<unit under test>: <aspect>)` and
  `--%suitepath(<prefix>.<area>)` on every spec.

- One behavior per `--%test`; the description is a sentence stating the
  expected behavior, not the procedure name.

- Verify with `ut.expect(...)` only — never `dbms_output`. An expected
  exception uses `--%throws(<code>)`, or a nested block with `ut.fail(...)`
  after the call when the message must be checked too.

## 4. Isolation and Test Data

- A suite creates its own fixtures and leaves nothing behind. It never
  depends on rows that already exist, on another suite, or on test order —
  running it twice in a row must pass twice.

- Mark every fixture row with a suite-specific constant (e.g.
  `gc_marker constant varchar2(30 char) := 'UT_ERSH_MASKING:'`) so cleanup
  finds exactly what the suite created.

- utPLSQL rolls back each test automatically. When the code under test
  commits — an autonomous transaction, an explicit `commit`,
  `logger.set_pref` — that rollback cannot undo it: use
  `--%rollback(manual)` and clean up explicitly in `--%aftereach`.

- A suite that changes configuration (preferences, settings rows) saves
  the original values in `--%beforeall` and restores them in
  `--%afterall`.

## 5. The CI Gate

- `main` only accepts changes through a PR whose `test` check is green
  (see `git-workflow.md` §3).

- CI installs the project **from scratch on a fresh schema** with the same
  release script people use, then fails on any of: an invalid object, an
  APEX app that was not imported, a test package that does not compile, a
  failing or erroring test, or fewer tests run than `tests/*.pks` declares.
  `templates/ci_workflow_template.yml` implements all of these.

- Never weaken a gate to get a green check. A test that cannot pass yet is
  disabled with `--%disabled(<reason>)` plus a `TODO_` comment
  (`sql-format.md` §3) that names the ticket fixing it.
