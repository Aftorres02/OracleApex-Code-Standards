# Consuming This Repo — Tech Lead / Maintainer Guide

For whoever adds this coding-standards package to a project for the first
time, and for whoever is responsible for pulling in standards updates
afterward. If you're a developer joining a project that already has this
set up, see
[`consuming-this-repo-dev.md`](consuming-this-repo-dev.md) instead — you
don't need anything on this page.

## 1. Add this repo as a submodule (first time only)

```bash
cd <your-project-root>
git submodule add https://github.com/Aftorres02/OracleApex-Code-Standards.git .claude
```

Note: if `.claude` already exists as a regular (non-submodule) folder in
the target project, it must be removed from git's index first:

```bash
git rm -r --cached .claude
git submodule add https://github.com/Aftorres02/OracleApex-Code-Standards.git .claude
```

## 2. Pin the submodule to track a specific branch

By default a submodule sits on a detached commit, not a branch. Set it
explicitly (replace `main` with whatever branch this package uses, e.g.
`DEV` during active development phases):

```bash
git config -f .gitmodules submodule.claude.branch main
```

## 3. Bootstrap the project's root CLAUDE.md

```bash
# copy the CLAUDE.md template to your project ROOT (not inside .claude/)
cp .claude/CLAUDE.md.template ./CLAUDE.md
```

Open the new root `CLAUDE.md` and replace every `<PROJECT_PREFIX>`
placeholder with your project's actual prefix. This file gets committed
and shared with the whole team — each individual developer's own local
`.claude/settings.local.json` setup is covered in
[`consuming-this-repo-dev.md`](consuming-this-repo-dev.md), not here.

If your team uses a different agentic coding tool (e.g. Codex CLI) that
reads `AGENTS.md` instead of `CLAUDE.md`, also run:

```bash
cp .claude/AGENTS.md.template ./AGENTS.md
```

Both files can coexist in the same project — copy whichever your tool
needs, or both if your team uses more than one tool. Neither is
"primary"; they're parallel entry points into the same `.claude/rules/`
content.

## 4. Commit the initial setup

Do steps 1–3 on a branch, then commit and open a PR — the setup reaches
`main` the same way as any other change (see `rules/git-workflow.md` §3):

```bash
git add .gitmodules .claude CLAUDE.md
git commit -m "chore: add coding standards as git submodule"
git push -u origin <TICKET>-add-coding-standards
```

Once the PR merges, every other developer on the project just needs
[`consuming-this-repo-dev.md`](consuming-this-repo-dev.md) — they don't
repeat steps 1–4.

## 5. Updating later — pulling in newer standards

Whenever the standards repo changes and you want THIS project to adopt
the update (never automatic — always a deliberate choice):

Like every other change, the bump goes through a branch and a PR — never
straight to `main` (see `rules/git-workflow.md` §3):

```bash
git switch -c <TICKET>-update-coding-standards
git submodule update --remote .claude
git add .claude
git commit -m "chore: update coding standards submodule"
git push -u origin <TICKET>-update-coding-standards
```

Before opening the PR, check that every `.claude/...` path the project
references still exists in the new version — a renamed or removed rule,
skill, or template breaks those links silently:

```bash
git grep -ohE '\.claude/[A-Za-z0-9_./-]+' -- ':!.claude' | sed 's/\.*$//' | sort -u \
  | while read p; do [ -e "$p" ] || echo "MISSING $p"; done
```

Once the PR merges, every developer with `submodule.recurse` set (see the
dev guide) picks it up on their next `git pull` — no action needed from
them.

## 6. Checking what version the project is currently on

```bash
cd .claude
git log -1 --oneline
cd ..
```

## 7. If the remote URL of this package ever changes

(e.g. moving from a personal account to an org account)

```bash
git submodule set-url .claude <new-repo-url>
git submodule sync
cd .claude
git fetch origin
git checkout <branch>
cd ..
git add .gitmodules .claude
git commit -m "chore: point standards submodule to new remote"
```
