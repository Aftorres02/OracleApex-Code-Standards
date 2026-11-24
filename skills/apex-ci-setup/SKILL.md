---
name: apex-ci-setup
description: Set up CI on GitHub Actions for an Oracle APEX / PL/SQL project that consumes these standards — every PR (and every merge to main) starts a cached Oracle Database Free + APEX + utPLSQL image, installs the project from scratch with its own release script, imports the APEX app, and fails on invalid objects, a missing app, a test package that does not compile, failing tests, or tests that silently did not run. Covers what the repo must provide first, filling in the workflow template, making the check required, proving the gates with deliberately broken PRs, troubleshooting every failure seen in a real rollout, and the recommended shape for CD. Load when adding CI to a project, changing a CI workflow, or a CI run fails and the cause is not obvious.
---

# Setting Up CI for an Oracle APEX Project

This is the procedure `OracleAPEX-ErrorShield` went through, with every
failure it hit along the way. The result: each PR gets a fresh database,
a from-scratch install and the full utPLSQL suite in about 5-6 minutes.

Related:

- `rules/testing.md` — what the gate must enforce (the standard).

- `skills/utplsql-testing` — how to write and run the tests themselves.

- `skills/apex-ci-image` — the cached database image, and how to build
  your own if the public one doesn't fit.

---

## 1. How It Fits Together

```
build-ci-image.yml (manual, ~20 min, once per Oracle/APEX/utPLSQL version)
   └─ Oracle Database Free + APEX + utPLSQL ──docker commit──► ghcr.io image

ci.yml (every PR + every push to main, ~5-6 min)
   ├─ changes job: docs-only PR? → test job skipped (counts as passed)
   └─ test job:
        pull image ─► start DB (seconds: it opens an existing instance)
        create schema + APEX workspace
        release/_uninstall.sql + release/_release.sql   (the project's own install)
        verify: 0 invalid objects, every APEX app imported
        compile tests/*.pks, *.pkb ─► fail on any compile error
        ut.run ─► JUnit XML ─► fail on failures/errors or test-count mismatch
        ut.run with coverage reporters ─► summary table + HTML (never fails)
        upload results; on failure, DB log + release log
```

The expensive part (installing the database, APEX and utPLSQL, ~20-40
minutes) is paid once, in the image. Each run only installs the project.

---

## 2. What the Project Must Provide First

CI runs the project's install exactly as a person would. Before writing
any workflow, the repo needs:

### A non-interactive install

`release/_release.sql` (or equivalent) runs start to finish under
`sql -S user/pass@db @_release.sql` with no prompts: no `accept`, no
`pause`, environment values from a file (`release/load_env_vars.sql`).
Scripts with prompts can still be fed through stdin
(`printf 'a\nb\n' | sql ... @script.sql`), but a prompt-free script is
less fragile.

### Fatal errors that actually exit

The release must `whenever sqlerror exit sql.sqlcode` around anything
fatal (prerequisite checks, the final invalid-object validation). A
release that continues on every error ends green no matter what — the
workflow's own "Verify the install" step is the backstop, not a
substitute.

### An install that works on a schema that has never seen it

Guard every step that assumes earlier state (an app to disable, a row to
update, a job to drop). See §7, `ORA-20987`.

### A matching uninstall

`release/_uninstall.sql`, where every drop happens only if the object
exists (check `user_objects` first). CI runs it first, on an empty schema,
to mirror the documented reset flow; with unguarded `drop` statements that
step prints dozens of `ORA-04043`/`ORA-00942` lines on every run and a
real error there goes unnoticed.

### A tests folder

`tests/ut_<prefix>_<area>.pks/.pkb` — see `rules/testing.md` §1.

---

## 3. Pick the Database Image

Reuse the public image unless you need other versions:

```
ghcr.io/aftorres02/oracle-apex-utplsql:26.1-utplsql3.2.3
```

Oracle Database Free 23.26.1, APEX 26.1, utPLSQL 3.2.3, service
`FREEPDB1`, SYS password `CiErsh_2026Pwd` (baked in, not a secret). Public
— anonymous pulls work, no token needed (checked November 2026). It holds
no project objects.

Other versions → build your own with
`templates/ci_image_workflow_template.yml`; read `skills/apex-ci-image`
first.

### Pin every version in one file

Copy `templates/ci_versions_template.env` to `ci/versions.env`. Both
workflows read it: the database image, APEX zip, utPLSQL tag and CI image
(all baked into the image) and the SQLcl zip (installed on every run).
Never use `sqlcl-latest.zip` or `apex-latest.zip`: they change without
notice — by November 2026 `apex-latest.zip` was already a different file
from the `apex_26.1.zip` the image was built from.

Upgrading is a PR that edits `ci/versions.env`:

- **SQLcl:** change `SQLCL_URL`; the PR's own run uses it.

- **Database, APEX or utPLSQL:** set a **new** `CI_IMAGE_TAG`, run
  `build-ci-image.yml` on the PR's branch, then push. The build refuses to
  overwrite an existing tag, because other branches still pull it.

> **Note:** Oracle answers a download URL for a version that does not
> exist with `200 OK` and an HTML page, so `curl -f` succeeds. Both
> templates run `unzip -tq` on every download and fail with the URL.

---

## 4. Add the Workflow

### Copy the template

```bash
mkdir -p .github/workflows ci
cp .claude/templates/ci_workflow_template.yml .github/workflows/ci.yml
cp .claude/templates/ci_versions_template.env ci/versions.env
```

### Fill in every CHANGE_ME

| Value | What to put |
|---|---|
| `OWNER_SCHEMA` | The schema the release installs into — must match what `load_env_vars.sql` expects |
| `APEX_WORKSPACE` | The workspace name the release imports into (`apex import -workspace ...`) |
| `APEX_APP_IDS` | Comma-separated app IDs the release must import; `""` if the project has no app |
| The `grant` list | The privileges the release needs — the same ones your "create user" script grants. Missing one shows up as a prerequisite-check failure or invalid objects |
| "Install the project" step | The project's own install commands, from the folder they expect to run in |
| `COVERAGE_OBJECTS_LIKE` | SQL `LIKE` pattern (escape `\`) for the objects whose coverage is reported — the project prefix, e.g. `'ERSH\_%'`, so vendored code is left out |

`grep -n CHANGE_ME .github/workflows/ci.yml` must return nothing before
you push.

### Keep the run log useful

The template already uploads `test-results.xml` on every run, and the
database log plus `release/release_log_*.log` when a run fails. If your
release spools its log elsewhere, fix that path in "Collect logs on
failure".

---

## 5. First Run, Then Make the Check Required

### Open a PR with the workflow

The first run happens on that PR. Timings from `OracleAPEX-ErrorShield`'s
runs (November 2026):

| Step | Typical | Seen range |
|---|---|---|
| Free up disk space | 2m15s | 2m12s - 5m46s |
| Pull and start the image | 1m30s | 1m31s - 2m06s |
| Wait for the database | 20-30s | |
| Create schema + workspace | 4s | |
| Install the project (ErrorShield: uninstall + release + APEX import) | 25s | |
| Verify, compile tests, run 38 tests twice, check | 15s | |
| Code coverage (two more suite runs) | 7s | |
| **Total** | **5-6 min** | up to ~9 min |

About 75% of every run is infrastructure: freeing disk space and pulling
the image. Both vary with GitHub's runners (the 5m46s case ran while
four other runs started at the same time), not with the project.

### Require the check on main

Once the PR is green and merged, protect `main` so nothing merges on a red
check. Repo → Settings → Branches → *Add classic branch protection rule*:

1. Branch name pattern: `main`.

2. *Require a pull request before merging* — and **uncheck** *Require
   approvals* if one person does most merges: GitHub never lets you
   approve your own PR.

3. *Require status checks to pass before merging* → search `test` →
   select it.

4. *Do not allow bypassing the above settings*. Without it, admins can
   merge on a red check — and when the main contributor is also the repo
   admin, the rule then applies to nobody.

Or with `gh` (admin rights needed):

```bash
gh api -X PUT repos/<owner>/<repo>/branches/main/protection --input - <<'JSON'
{
  "required_status_checks": { "strict": false, "contexts": ["test"] },
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 0 },
  "restrictions": null
}
JSON
```

Check it: open a PR with a deliberately failing test — the merge button
must stay disabled.

> **Note:** require the `test` job, not the workflow. The template skips
> `test` on docs-only PRs through the `changes` job; a job skipped by
> `if:` counts as passed. A workflow skipped by `on.pull_request.paths-ignore`
> reports nothing at all, so a required check would sit on "Expected —
> waiting for status" forever. That is why the template does not use
> `paths-ignore`.

`"strict": false` lets a PR merge without first rebasing on the latest
`main`; the `push: main` trigger re-runs the suite on the merged result
instead. Use `true` if two PRs merging close together keep breaking
`main`.

---

## 6. Prove the Gates Work

A CI that has only ever been green has not been tested. Open a throwaway
draft PR per case below, confirm the result, then close it with
`gh pr close <n> --delete-branch`.

The results below are from `OracleAPEX-ErrorShield` (November 2026),
first against its previous `ci.yml`, then against this template:

| Broken on purpose | Previous `ci.yml` | This template |
|---|---|---|
| A test assertion (expected value changed) | Red at the final check: `38 tests, 1 failed` | Same `failures`/`errors` gate, now in "Check results" (not re-run against the template) |
| A test package **body** missing a `;` | Compile step **green** (`whenever sqlerror continue`); red only later, as 7 errored tests (`ORA-04063`) | Red **at the compile step**, with the error: `PACKAGE BODY UT_ERSH_DECISION_TREE line 34: PLS-00103 ...`, `ORA-20001: 1 test package object(s) do not compile` |
| A test package **spec** missing a `;` | Compile step **green**; **one test silently vanished (37 of 38 ran)** — red only because 5 other tests errored | Red **at the compile step**: `PACKAGE UT_ERSH_RELATED_LOGS line 21: PLS-00103 ...` plus the body's `PLS-00304` — the suite never gets to run with a test missing |
| A core package body missing a `;` | Red at the install: `ERSH_ERROR_HANDLER_API PACKAGE BODY INVALID`, `ORA-20002` from the release's own gate | Same — the release script is unchanged, so its gate fires before "Verify the install" (not re-run against the template) |
| A docs-only change | No run at all — fine without branch protection, but a required check would wait forever | `changes` passes, `test` reported as skipped — a required `test` check is satisfied |
| The APEX app (no break) | **Never imported**: `Workspace: LOGGER_USER from workspace input is invalid`, job green | Imported: `APEX application 10400 imported` (and its APEXlang compile warnings now visible in the log) |

Two lessons from the left column apply to any project:

- **"Compiled" is not "compiled without errors".** SQLcl prints `Package
  Body X compiled` and then the error list; with `whenever sqlerror
  continue` the step passes. Check `user_errors`/`user_objects` instead of
  trusting the step's color.

- **A syntax error in a spec can make a test disappear.** utPLSQL reads
  annotations from the source text; a missing `;` attached the next
  `--%test` to the wrong declaration and that test simply did not run (37
  of 38). That run still went red only because the suite's other tests
  errored — nothing checked for the missing one. Comparing the count of
  tests run with the count declared does.

---

## 7. Troubleshooting — Failures Seen in a Real Rollout

| Symptom | Cause | Fix |
|---|---|---|
| `ORA-01017: invalid credential` connecting as SYS while building the image | The official `database/free` image reads `ORACLE_PWD`; `ORACLE_PASSWORD` is the community-image name | Set both (`skills/apex-ci-image`) |
| `invalid reference format: repository name (Owner/name) must be lowercase` | `github.repository_owner` keeps its capitals; image refs must be lowercase | `tr '[:upper:]' '[:lower:]'` before building the ref |
| `ORA-20987: APEX - Application not found` early in the release, only in CI | First install on a schema that never had the app: the release tried to disable it before importing it. Every manual test had reused a schema where the app existed | Guard with `select count(1) from apex_applications where application_id = ...` before acting |
| `Workspace: X from workspace input is invalid` and the job still green | The workspace was never created; the release continues on SQL errors, so the app was silently not imported | The "Create the schema and APEX workspace" step; "Verify the install" now fails on a missing app |
| `HTTP 404: workflow ... not found on the default branch` running a new manual workflow | GitHub only registers a `workflow_dispatch`-only workflow once it is on the default branch or has run once | Temporarily add a `push` trigger for that branch, push once, revert |
| Disk full / `no space left on device` pulling or building the image | 15-17 GB image on a default runner | The "Free up disk space" step — in both workflows |
| Lots of `ORA-04043: object ... does not exist` / `ORA-00942` at the start of "Install the project" | Unguarded `drop` statements in `_uninstall.sql`, run on an empty schema | Drop only what exists in `user_objects` (§2) |
| "N test(s) ran but tests/*.pks declares M" | A test spec does not compile, so utPLSQL never read its annotations | Fix the spec; the compile step above shows the error |
| A run was cancelled | A newer push to the same PR — `cancel-in-progress` | None; the newer run is the one that counts |
| SQLcl behaves differently from one week to the next | `sqlcl-latest.zip` changed | Pin `SQLCL_URL` in `ci/versions.env` (§3) |
| "... did not return a zip" right after a version change | The URL names a version Oracle doesn't publish; Oracle answers `200 OK` with an HTML page | Copy the exact file name from Oracle's download page |
| "... already exists. Set a new CI_IMAGE_TAG" running the image build | Rebuilding would replace the image other branches use | New `CI_IMAGE_TAG`, or re-run with `overwrite_existing_tag` if you really mean it |

To dig into any failure:

```bash
gh run view <run-id> --log-failed          # failing step's output
gh run download <run-id> -n failure-logs   # DB log + release log
gh run download <run-id> -n utplsql-results
```

---

## 8. CD — Recommended Shape (Not Yet Built)

No project here deploys automatically yet; treat this as the design to
start from, not a validated recipe.

### Deploy with the same release script

CI already proves `release/_release.sql` installs from scratch; a deploy
runs that same script against a real environment. Never a separate
"deploy version" of the install.

### Trigger on a tag, not on every merge

A SemVer tag (`v1.2.0`) on `main` starts the deploy workflow. Merges to
`main` only run CI.

### One GitHub Environment per target

`test`, `prod` — each with its own secrets (connection, password; for
Autonomous Database a base64 wallet zip decoded at run time) and, for
`prod`, *Required reviewers* so a person approves before the job runs.

### Gate the deploy on CI

The deploy job needs the CI `test` job (or runs only from a commit whose
check is green), deploys to `test` first, then waits for approval before
`prod`.

### Keep the release log

Upload `release/release_log_*.log` as an artifact of every deploy — it is
the record of what ran where.
