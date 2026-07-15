# Consuming This Repo

A practical, command-first guide for adding this coding-standards package
to a new or existing project. Written for a developer or tech lead doing
this for the first time, on their own machine, against a real project
repo.

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

## 3. Bootstrap the two template files

```bash
# copy the CLAUDE.md template to your project ROOT (not inside .claude/)
cp .claude/CLAUDE.md.template ./CLAUDE.md

# copy the local settings template inside .claude/
cp .claude/settings.local.example.json .claude/settings.local.json
```

Then open the new root `CLAUDE.md` and replace every `<PROJECT_PREFIX>`
placeholder with your project's actual prefix.

## 4. Commit the initial setup

```bash
git add .gitmodules .claude CLAUDE.md
git commit -m "chore: add coding standards as git submodule"
```

## 5. Updating later — pulling in newer standards

Whenever the standards repo changes and you want THIS project to adopt
the update (never automatic — always a deliberate choice):

```bash
git submodule update --remote .claude
git add .claude
git commit -m "chore: update coding standards submodule"
```

## 6. Checking what version a project is currently on

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

## 8. Common mistake to avoid

Never edit files inside `.claude/` directly from a consumer project
expecting the change to "just work" for everyone — `.claude/` there is a
separate git repo (this one). Local edits inside it need their own
commit+push from inside `.claude/`, then step 5's update flow in every
other consumer project that wants that change.
