---
name: utplsql-testing
description: Write, run and debug utPLSQL v3 test suites for Oracle PL/SQL and APEX-backed packages — suite layout, annotations, fixtures that clean up after themselves, code that commits (autonomous transactions, logger.set_pref) and --%rollback(manual), asserting exceptions and their messages, reaching private and fail-safe branches through the public API, regression tests per ticket, running one suite/test/suitepath, and reading the reports. Patterns verified in OracleAPEX-ErrorShield's 38-test suite. Load before writing or reviewing any tests/ut_*.pks/.pkb, when adding a test for a bug fix, or when a test passes locally but fails in CI.
---

# Writing and Running utPLSQL Tests

The rules — naming, what needs a test, isolation, the CI gate — are in
`rules/testing.md`. This skill is the how-to. Every pattern here comes
from `OracleAPEX-ErrorShield`'s suite (`tests/`, 6 suites, 38 tests),
which runs on every PR through `templates/ci_workflow_template.yml`.

---

## 1. Prerequisites

### Confirm utPLSQL is installed

```sql
select ut.version() as utplsql_version from dual;
```

`ORA-00904`/`PLS-00201` means it isn't. Installing it needs a DBA
(`install_headless.sql` from the utPLSQL release, run as SYS — see
`templates/ci_image_workflow_template.yml`, step "Install utPLSQL", for the
exact command). The CI image already has utPLSQL 3.2.3 in schema `UT3`.

### Install the project first

Tests run against the installed objects. Install with the project's own
release script (`release/_release.sql`), then compile the test packages.

### No local database with utPLSQL?

Run the same image CI uses (needs Docker and ~20 GB of disk):

```bash
docker run -d --name ci-db -p 1521:1521 ghcr.io/aftorres02/oracle-apex-utplsql:26.1-utplsql3.2.3
# wait for "DATABASE IS READY TO USE!" in `docker logs ci-db`, then:
sql sys/CiErsh_2026Pwd@localhost:1521/FREEPDB1 as sysdba
```

Then create the schema and workspace exactly as the CI workflow's step
"Create the schema and APEX workspace" does.

---

## 2. Running Tests

All commands run connected as the schema that owns the code and the tests.

| Goal | Command |
|---|---|
| Everything in the schema | `exec ut.run(user);` |
| One suite | `exec ut.run('ut_ersh_masking');` |
| One test | `exec ut.run('ut_ersh_masking.masks_when_environment_listed');` |
| Everything under a suitepath | `exec ut.run(user || ':ersh.core');` |
| JUnit XML (what CI parses) | `select column_value from table(ut.run(user, ut_junit_reporter()));` |

`set serveroutput on size unlimited` first, or the console report is
empty.

Keep a `tests/run_tests.sql` that compiles every test package and runs
the suite, so a developer runs the whole thing with one command:

```bash
cd tests
sql <owner-connection> @run_tests.sql
```

> **Note:** a hand-kept list of `@ut_*.pks`/`@ut_*.pkb` lines in
> `run_tests.sql` is fine for local runs, but CI must not depend on it — a
> new suite missing from the list would silently never run. The CI
> template compiles every `tests/*.pks` and `*.pkb` instead.

---

## 3. Writing a Suite

Start from `templates/ut_package_spec_template.sql` and
`templates/ut_package_body_template.sql`.

### Name it and place it

`tests/ut_<prefix>_<area>.pks` and `.pkb` — e.g. `ut_ersh_core_bugs`.
One suite per behavior area of one unit, not one giant suite per package.

### Declare the suite in the spec

```plsql
create or replace package ut_ersh_masking
as

  --%suite(ersh_error_handler_api: ENVIRONMENT / MASK_IN_ENVIRONMENTS masking)
  --%suitepath(ersh.core)

  --%test(Environment listed in MASK_IN_ENVIRONMENTS masks the message)
  procedure masks_when_environment_listed;

end ut_ersh_masking;
/
```

Leave a blank line between package-level annotations (`--%suite`,
`--%suitepath`, `--%rollback`) and the first procedure: an annotation
directly above a procedure belongs to that procedure.

### Write each test as Arrange / Act / Assert

```plsql
procedure no_mask_when_environment_not_listed
is
  l_error  apex_error.t_error := unexpected_error_fixture('not-listed');
  l_result apex_error.t_error_result;
begin
  logger.set_pref(p_pref_type => gc_pref_type, p_pref_name => 'ENVIRONMENT', p_pref_value => 'UT_MASK_ENV');
  logger.set_pref(p_pref_type => gc_pref_type, p_pref_name => 'MASK_IN_ENVIRONMENTS', p_pref_value => 'UT_OTHER_ENV');

  l_result := ersh_error_handler_api.apex_error_handling(p_error => l_error);

  ut.expect(l_result.message).to_equal(l_error.message);
end no_mask_when_environment_not_listed;
```

Common matchers: `to_equal`, `not_to_equal`, `to_be_null`,
`to_be_not_null`, `to_be_like('%x%')`, `to_be_true`, `to_be_greater_than`,
and `to_equal` on a `sys_refcursor` to compare whole result sets.

### Build fixtures with small helpers

When several tests need the same input, a private function returning it
keeps each test to the line that differs
(`unexpected_error_fixture(p_marker)` in `ut_ersh_masking`).

---

## 4. Patterns That Matter

### Code under test commits

`logger.set_pref` and any procedure with `pragma autonomous_transaction`
commit on their own; utPLSQL's per-test rollback cannot undo that. Three
of ErrorShield's six suites hit this. The fix, in this order:

1. `--%rollback(manual)` on the suite.

2. A marker constant on every row the suite creates.

3. `--%aftereach` deleting by marker and committing:

```plsql
procedure cleanup_test_incidents
is
begin
  delete
    from ersh_incident_occurrences
   where shield_incident_id in (
           select shield_incident_id
             from ersh_shield_incidents
            where error_summary like gc_message_prefix || '%'
         );

  delete
    from ersh_shield_incidents
   where error_summary like gc_message_prefix || '%';

  commit;
end cleanup_test_incidents;
```

Delete children before parents. Without manual mode, a commit inside a
test ends utPLSQL's savepoint and the run reports a warning — treat that
warning as a bug in the suite.

### Configuration the suite changes

Save it in `--%beforeall`, restore it in `--%afterall` — otherwise the
next suite (or the next developer) inherits a test value:

```plsql
procedure save_original_prefs
is
begin
  g_orig_environment := logger.get_pref('ENVIRONMENT', gc_pref_type);
  g_orig_mask_list   := logger.get_pref('MASK_IN_ENVIRONMENTS', gc_pref_type);
end save_original_prefs;
```

### Asserting an exception

When only the code matters, annotate the test:

```plsql
--%test(Raises -20001 for an unknown code)
--%throws(-20001)
procedure raises_for_unknown_code;
```

When the message matters too — e.g. it must not leak internal state — use
a nested block. `ut.fail` records a failure without raising, so the
handler does not swallow it:

```plsql
procedure raise_custom_error_inactive_code
is
begin
  begin
    ersh_error_handler_api.raise_custom_error(p_error_code => gc_inactive_code);
    ut.fail('Expected raise_custom_error to raise an exception for a deactivated code.');
  exception
    when others then
      ut.expect(sqlcode).to_equal(-20001);
      ut.expect(sqlerrm).not_to_be_like('%' || gc_inactive_message || '%');
  end;
end raise_custom_error_inactive_code;
```

### Reaching a fail-safe branch

A `when others` fallback only runs on a real exception. A missing or null
value usually takes the normal path instead and proves nothing. Find an
input that genuinely raises inside the unit. In ErrorShield, masking
must fail safe (mask) when reading configuration fails; the test stores
an `ENVIRONMENT` value longer than the `varchar2(30 char)` it is read
into, which raises `ORA-06502` inside the package and reaches the real
handler. Document why in a comment above the test — the trick is not
obvious.

### Testing private logic

Call the public unit that reaches it, with inputs that drive the branch
you want. ErrorShield's masking logic is private to
`ersh_error_handler_api`; its suite drives it entirely through the public
`apex_error_handling` function.

### One regression test per bug

Write the test first, watch it fail against the unfixed code, then fix.
Put the ticket in the description so the CI report ties a failure back to
its history: `--%test(raise_custom_error treats a deactivated code as not
implemented, ERSH-022)`.

---

## 5. When It Passes Locally but Fails in CI

| Symptom in CI | Usual cause |
|---|---|
| Test fails only on the first run of the day / in CI | It depends on data that exists in your dev schema but not in a fresh install — seed it in the suite |
| Passes alone, fails in the full run | Another suite left data or settings behind — check its `--%aftereach`/`--%afterall` |
| "N test(s) ran but tests/*.pks declares M" | A spec does not compile (utPLSQL cannot read its annotations), or an annotation is malformed |
| "test package object(s) do not compile" | Compile errors are listed right above, from `user_errors` |
| Warning about a savepoint / automatic rollback | The code commits; the suite needs `--%rollback(manual)` |

To reproduce CI exactly, run the CI image locally (§1) and repeat the
workflow steps by hand.

---

## 6. Review Checklist for a Test PR

- Each new `--%test` states a behavior, and bug fixes cite their ticket.

- No assertion through `dbms_output`; every test has at least one
  `ut.expect`, `--%throws` or `ut.fail`.

- Running the suite twice in a row passes twice.

- Suites whose code commits use `--%rollback(manual)` and clean up by
  marker, children first.

- Changed settings are restored in `--%afterall`.
