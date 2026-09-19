---
name: apex-ci-image
description: Reuse or build a cached Docker image (Oracle Database + APEX + utPLSQL pre-installed) so CI pulls it instead of reinstalling everything on every run — includes lessons learned from a real end-to-end deployment.
---

# Caching Oracle Database + APEX + utPLSQL for CI

A from-scratch install of Oracle Database Free + Oracle APEX + utPLSQL takes
~30-40 minutes. Doing that on every PR is wasteful. The fix: build the
instance **once**, snapshot it as a Docker image, publish it to `ghcr.io`,
and have every CI run just pull and start that image (a few minutes, mostly
network transfer).

This is a two-workflow pattern:

- A **build workflow** (manual `workflow_dispatch` only): installs
  everything from scratch, then `docker commit`s the stopped container and
  pushes it.
- A **CI workflow** (runs on every PR): `docker pull` + `docker run`s that
  image — no install steps at all — then does only the project-specific
  work (install your own schema/app, run your tests).

Re-run the build workflow manually only when the pinned Oracle/APEX/utPLSQL
versions change. It is never automatic.

---

## Step 0 — check whether you can just reuse an existing image

Before building your own, check whether a project you (or your org) already
maintain publishes one. `OracleAPEX-ErrorShield` (the project this skill was
first written for) publishes:

```
ghcr.io/aftorres02/oracle-apex-utplsql:26.1-utplsql3.2.3   (+ latest tag)
```

built by the `.github/workflows/build-ci-image.yml` in the
`OracleAPEX-ErrorShield` repo (not this standards package itself — the
image is deliberately generic, with no ErrorShield objects baked in, so
any Oracle APEX project can pull it). If the Oracle/APEX/utPLSQL versions
you need match an existing tag, a new project's `ci.yml` can skip the
whole build step and go straight to:

```yaml
- name: Log in to ghcr.io
  run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u "${{ github.actor }}" --password-stdin

- name: Pull and start the pre-built base image
  run: |
    docker pull ghcr.io/aftorres02/oracle-apex-utplsql:26.1-utplsql3.2.3
    docker run -d --name db -p 1521:1521 ghcr.io/aftorres02/oracle-apex-utplsql:26.1-utplsql3.2.3
```

> **Caveat:** ghcr.io packages are private by default. `GITHUB_TOKEN` only
> auto-authorizes pulling a package published by *that same repository* —
> a different repo/org needs either the package made public (owner's
> GitHub profile → Packages → the package → Package settings → Change
> visibility → Public), or a PAT with `read:packages` scope stored as a
> secret in the consuming repo.

**Connection defaults already baked into the image:** service name
`FREEPDB1`, and a fixed (non-secret — see `build-ci-image.yml`'s
`DB_SYS_PASSWORD`) SYS password already set on the datafiles. No env vars
are needed on `docker run` — you're opening an existing instance, not
creating one.

If no existing image fits, build your own — see below.

---

## Building your own base image

1. **Build workflow**, `workflow_dispatch` only: start the official Oracle
   image, install APEX, install utPLSQL, verify nothing is invalid, `docker
   stop` the container, `docker commit` it, `docker push` to `ghcr.io`.
2. **CI workflow**: pull that image instead of installing anything, then
   run only what's specific to your project.

Copy `OracleAPEX-ErrorShield`'s `.github/workflows/build-ci-image.yml` and
`.github/workflows/ci.yml` as the concrete starting point — they already
encode every lesson below.

---

## Lessons learned (read before repeating this in a new project)

### The official Oracle image's SYS password variable has a different name than you'd expect

`container-registry.oracle.com/database/free` reads `ORACLE_PWD`.
`ORACLE_PASSWORD` is the *community*-image (`gvenzl/oracle-free`)
convention — setting only that on the official image silently leaves SYS
with an unknown/random password, and every later connection fails with
`ORA-01017: invalid credential or not authorized`.

> **Fix:** set both `ORACLE_PWD` and `ORACLE_PASSWORD` to the same value
> when creating the container the first time. Harmless if the image only
> reads one of them, correct if it reads the other.

### Docker/ghcr.io image references must be lowercase

`ghcr.io/<owner>/<name>` must be all-lowercase, but
`${{ github.repository_owner }}` is **not** guaranteed to be (e.g.
`Aftorres02`). Using it directly in an image ref fails with:

```
invalid reference format: repository name (Owner/name) must be lowercase
```

> **Fix:** always lowercase it before building the ref:
>
> ```bash
> owner_lower=$(echo "${{ github.repository_owner }}" | tr '[:upper:]' '[:lower:]')
> ```
>
> This bites both the `docker push` (build workflow) and the `docker pull`
> (consumer workflow) — fix it in both places.

### A committed image only captures data if the base image declares no volume

Before relying on `docker commit` to snapshot a database, check:

```bash
docker inspect <image> --format '{{.Config.Volumes}}'
```

If the base image declares a `VOLUME` (common for "persist your data
across container restarts" images), anything written there lives in a
separate volume layer that `docker commit` does **not** capture — you'd
silently commit an image with an empty database. Oracle's official
`database/free` image declares no volume, so running the builder container
**without** an external `-v` mount keeps the datafiles in the container's
own writable layer, where `docker commit` does capture them.

### Stop the container cleanly before committing

Use `docker stop` (not `docker kill`) — it sends the signal the Oracle
image's entrypoint expects and triggers a clean instance shutdown first. A
container committed after a clean stop reopens in seconds on next start
(it's opening an existing instance). A commit after a hard kill risks crash
recovery on first boot from the new image — slower at best, and a risk to
data integrity at worst.

### A manual-dispatch workflow that has never run on a feature branch can't be triggered yet

GitHub only registers a workflow with the Actions API once it either (a)
exists on the default branch, or (b) has executed at least once via some
trigger, on any branch. A brand-new `workflow_dispatch`-only workflow file
that only exists on a feature branch is invisible to `gh workflow run` /
the dispatch API:

```
HTTP 404: workflow build-ci-image.yml not found on the default branch
```

> **Bootstrap trick** (avoids merging to `main` prematurely just to unblock
> this): temporarily add a `push` trigger scoped to that exact branch, push
> once — this both registers the workflow *and* runs it — then revert the
> temporary trigger in a follow-up commit once it succeeds. The workflow
> file ends up exactly as designed (manual-only), just with one extra
> bootstrap run in its history.

### GitHub Actions runners need explicit disk-space cleanup for a 15-17GB image

A full Oracle DB + APEX install/image is large enough that the default
runner disk fills up. Add a disk-space-reclaiming step (e.g.
`jlumbroso/free-disk-space@main`, reclaiming `tool-cache`, `android`,
`dotnet`, `haskell`) before pulling *or* building the image — needed on
both the build workflow and the consumer workflow, since pulling a 15-17GB
image needs the same headroom building it did.

### A script validated only against a reused schema has not been validated against a truly fresh one

Every manual end-to-end validation of `OracleAPEX-ErrorShield`'s release
script reused a schema where the APEX application had already been
imported at least once. The very first time the release ran against a
genuinely blank environment — a schema that had never had the app imported
— a step that assumed the app already existed (disabling it before
re-importing) failed with `ORA-20987: Application not found` and aborted
the whole release before it ever reached the import step.

> **General lesson:** a "fresh install" code path only gets real coverage
> the first time it runs against an environment that has truly never seen
> the install before. Reusing a dev schema across iterations — even when
> uninstalling/reinstalling in between — is not equivalent, because
> uninstall/reinstall still leaves things behind that an install-from-
> nothing does not (in this case, the APEX application record itself).
> Guard any step that assumes prior state exists with an existence check
> before acting, the same way idempotent DDL guards `create table` /
> `create or replace`.

### Parsing utPLSQL JUnit XML output to gate CI

`select column_value from table(ut.run(user, ut_junit_reporter()))` spooled
to a file gives a standard JUnit XML report. A plain grep for the first
`failures="N"` and `errors="N"` attributes is enough to fail the CI job on
any test failure/error, with no XML-parser dependency:

```bash
failures=$(grep -o 'failures="[0-9]*"' test-results.xml | head -1 | grep -o '[0-9]*')
errors=$(grep -o 'errors="[0-9]*"' test-results.xml | head -1 | grep -o '[0-9]*')
[ "$failures" = "0" ] && [ "$errors" = "0" ]
```
