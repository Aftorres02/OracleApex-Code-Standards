# Consuming This Repo — Developer Guide

If you're setting this up for a project for the first time, see
[`consuming-this-repo-tech-lead.md`](consuming-this-repo-tech-lead.md)
instead.

## One-time setup — pick your scenario

**A) You already have the project cloned** (most common — the tech lead
already added the submodule and pushed it):
```bash
git pull
git submodule update --init --recursive
```

**B) You're cloning the project for the first time:**
```bash
git clone --recurse-submodules <project-repo-url>
```

## Then, either way — run this once, on your machine

```bash
git config submodule.recurse true
cp .claude/settings.local.example.json .claude/settings.local.json
```

> `submodule.recurse` is a LOCAL git config — every developer runs it once
> on their own machine, it can't be set from the repo itself. Once set, a
> plain `git pull` keeps `.claude/` in sync automatically from then on —
> you never need to run `git submodule update` manually again.

The root `CLAUDE.md` and `.gitmodules` are already committed by whoever
set up the project — you don't create or copy those yourself.

## Common mistake to avoid

Never edit files inside `.claude/` directly from this project expecting
the change to "just work" for everyone — `.claude/` here is a separate
git repo (the standards package). Local edits inside it need their own
commit+push from inside `.claude/`, and then whoever maintains the
standards package needs to pull that into the package repo itself — this
isn't something an individual consumer-project developer should be doing.

## Want to know what's actually in `.claude/`?

See `.claude/STRUCTURE.md` for what each folder (`rules/`, `agents/`,
`commands/`, `templates/`, etc.) is for.
