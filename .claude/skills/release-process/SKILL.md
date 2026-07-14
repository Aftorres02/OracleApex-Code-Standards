---
name: release-process
description: Multi-step guide for structuring and running a versioned Oracle APEX/DDL release (Dev → Test → Prod), including the release folder layout and two branching/tagging strategies.
---

# Release Process

> Moved from `docs/coding-standards/apex/repo_structure/release/README.md`
> (original archived under `_archive/coding-standards-legacy/`) because this
> is a multi-step operational workflow, not a one-line coding rule — see the
> rules-vs-skills split in `.claude/STRUCTURE.md`. This skill assumes a
> [Git workflow](../../rules/git-workflow.md) is already in place; some
> examples below may need to be adapted to the chosen branching model.

## Structure

The release folder (`docs/coding-standards/apex/repo_structure/release/` in
this template — mirror it at the root `release/` in a generated project)
ships with:

### `_release.sql`

Example release script — the only file run for each release. It references
the other files below. A single consistent entry-point file simplifies
release scripts when using automated tooling. Review and adapt this file
per project.

### `all_....sql` files

| File | Auto Generated | Description |
| --- | --- | --- |
| [`all_apex.sql`](../../../docs/coding-standards/apex/repo_structure/release/all_apex.sql) | Yes | Installs all APEX applications |
| [`all_data.sql`](../../../docs/coding-standards/apex/repo_structure/release/all_data.sql) | No | Runs all re-runnable data scripts — references must be added manually, order matters |
| [`all_packages.sql`](../../../docs/coding-standards/apex/repo_structure/release/all_packages.sql) | Yes | References all packages in `packages/` — `.pks` files first, then `.pkb` |
| [`all_views.sql`](../../../docs/coding-standards/apex/repo_structure/release/all_views.sql) | Yes | References all views in `views/` |
| [`load_env_vars.sql`](../../../docs/coding-standards/apex/repo_structure/release/load_env_vars.sql) | Yes | Loads environment variables into the SQL session |

"Auto generated" files are produced by the project's build process — adapt this to whatever build tooling the project actually uses.

### The `code` folder

Stores non-rerunnable code specific to each release — one file per ticket (e.g. `code/issue-123.sql`), which may contain DDL/DML. Re-runnable code (views, packages, etc.) belongs in its normal folder, not here. After each release, the `code` folder's contents are cleared.

Each file added to `code` must be referenced from `code/_run_code.sql`, which is cleared after each release:

```sql
@issue-123.sql
@issue-456.sql
```

## Release Process

Oracle releases are unforgiving — a failed DDL statement can corrupt the rest of a release and there's no cheap way to restore a schema to a point in time before the release. Making release scripts fully re-runnable or rollback-safe is possible but expensive, so the process below assumes:

- The release process is **not** re-runnable (a failed DDL statement means you can't tell if it already ran).
- There is **no** rollback script to undo a release.
- Code goes `Dev → Test → Prod`.
- Code can be run manually in Test.
- Development sprints are ~2 weeks; active development happens on `master`.

Two tagging strategies are described below — pick whichever fits your team's culture; neither is objectively "better."

Example variables used throughout:
```bash
RELEASE_VERSION=1.0.0
GIT_PRE_RELEASE_BRANCH=pre-release-$RELEASE_VERSION
```
([Semantic versioning](https://semver.org/) — `major.minor.patch` — is recommended.)

### Concept 1: Tag code each time it runs in Production

Code is tagged only when it **goes to Prod**. Every patch applied in Test requires manually updating the release script, so patch **order matters** — riskier, but the release itself stays simple.

```bash
# Once the sprint is complete, cut a pre-release branch:
git checkout -b $GIT_PRE_RELEASE_BRANCH master
git push --set-upstream origin

# Run the release manually in Test (see "Run Release Manually" below).

# If a bug is found in Test and needs a patch (example: one DDL + one view change):
git checkout $GIT_PRE_RELEASE_BRANCH
# edit release/code/issue-123.sql with the new DDL statement
# edit views/my_view.sql
#
# Connect to TEST and manually run the DDL statement, then the view:
# sqlcl <connection_string>
# alter table my_table add (new_col varchar2);
# @views/my_view.sql
# exit

git add *
git commit -m "patch fix"
git push

git checkout master
git merge $GIT_PRE_RELEASE_BRANCH
```

> **Critical**: when modifying a file that contains DDL, the DDL must be placed in the exact order it should have been run.

Once fully certified, tag the release and clean up:

```bash
git checkout $GIT_PRE_RELEASE_BRANCH
git tag $RELEASE_VERSION
git push origin --tags

git checkout master
git push --delete origin $GIT_PRE_RELEASE_BRANCH
git branch -d $GIT_PRE_RELEASE_BRANCH

# Cleanup the release folder (project-specific tooling), e.g.:
# reset_release <base_folder_name>
```

Then run the release in Production — see "Running a Release in Production" below.

### Concept 2: Tag code each time it leaves Dev

Same shape as Concept 1, but code is tagged every time it **leaves Dev** rather than when it reaches Prod. This reduces the risk of a mis-ordered patch breaking production, at the cost of creating more releases (e.g. `1.0.0`, `1.0.1`, `1.0.2` for a base release plus two Test-phase patches — all of which must eventually be deployed to Production).

```bash
git checkout -b $GIT_PRE_RELEASE_BRANCH master
git push --set-upstream origin

# Run the release manually in Test.

# Merge changes back into master (in case any were made during the release), tag, and clean up:
git checkout master
git pull origin master
git merge $GIT_PRE_RELEASE_BRANCH
git push origin master

git checkout $GIT_PRE_RELEASE_BRANCH
git tag $RELEASE_VERSION
git push origin --tags

git checkout master
git push --delete origin $GIT_PRE_RELEASE_BRANCH
git branch -d $GIT_PRE_RELEASE_BRANCH

# Cleanup the release folder (project-specific tooling), e.g.:
# reset_release <base_folder_name>
```

Repeat for each release that needs to go to Test. When it's time for Production, every release created since the last Prod deploy must be run (e.g. `1.0.0` through `1.0.3` in sequence) — see below.

### Running a Release in Production

```bash
# From the project root:
git checkout tags/<RELEASE_TAG_NAME>
cd release
sqlcl <prod_connection_string> @_release.sql

# Check the result:
if [ $? -eq 0 ] ; then
  echo "Release successful"
else
  echo "Release: **ERRORS**"
fi
```

## Tips

### Run a Release Manually

Running a release manually catches errors quickly, right where they occur. Recommended setup: an editor with a quick toggle between the file and an integrated terminal (e.g. VS Code with `Terminal: Focus Terminal` / `View: Focus First Editor Group` bound to easy shortcuts), so you can scroll a large SQL file, copy a section, and paste it directly into a SQLcl session.

```bash
cd <project directory>/release
code _release.sql          # open in editor

sqlcl <test_connection_string>
```

Then walk through `_release.sql` section by section, copying each into the terminal. Do the same for any files it references under `release/code/`.
