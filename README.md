# Oracle APEX / PL/SQL Code Standards

A shared Oracle APEX / PL/SQL coding-standards package for Claude Code.
This repo **is** the package — it's meant to be consumed by other
projects as a git submodule at their own `.claude/` directory, not cloned
and edited in place per project.

> New to consuming this package? Two guides, by role:
> [`guides/consuming-this-repo-dev.md`](guides/consuming-this-repo-dev.md)
> (joining a project that already uses this) and
> [`guides/consuming-this-repo-tech-lead.md`](guides/consuming-this-repo-tech-lead.md)
> (setting it up / maintaining updates for a project).

## Consuming this package

Add it as a submodule at `.claude` in your project:

```bash
git submodule add <this-repo-url> .claude
git submodule update --init --recursive
```

## Bootstrapping a new consumer project

1. Add the submodule as shown above.
2. Copy `.claude/CLAUDE.md.template` to your project root as `CLAUDE.md`,
   and fill in `<PROJECT_PREFIX>`.
3. Copy `.claude/settings.local.example.json` to
   `.claude/settings.local.json` (gitignored — machine-specific overrides
   only; `.claude/settings.json` is the shared, committed config).
4. Open the project in Claude Code — `CLAUDE.md` will `@`-import every
   file under `.claude/rules/` automatically.

## What's in this package

| Folder | Contains |
|---|---|
| `rules/` | The 10 coding standards, always loaded into context — SQL formatting, PL/SQL, DDL, APEX UX, security, JavaScript, git workflow, repo structure, documentation formatting, error handling |
| `agents/` | Reviewer subagents that check code against `rules/*.md` (PL/SQL, APEX pages, SQL performance) |
| `commands/` | Slash commands (`/new-package`, `/review-sql`, `/gen-crud-page`) that generate code or trigger a review |
| `skills/` | Multi-step process guides — versioned APEX migrations. (Release process + full project scaffold now live in a separate repo — see `rules/repo-structure.md`.) |
| `templates/` | Ready-to-copy `.sql`/`.js` skeletons that already implement the `rules/` conventions |
| `guides/` | Human-facing onboarding narrative for developers and tech leads |

See [`STRUCTURE.md`](STRUCTURE.md) for a full explanation of every folder,
what belongs in it, and what doesn't.
