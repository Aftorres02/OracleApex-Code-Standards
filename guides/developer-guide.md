# Developer Onboarding Guide

Welcome to the project! Follow this guide to get up to speed.

## 1. Repository Structure

All core documentation is in the `docs/` folder. The database schema and scripts are typically separated into a `db/` folder (or equivalent), and APEX exports are maintained periodically. See `.claude/rules/repo-structure.md` for the standard layout of a generated APEX project repo.

## 2. How to run the project

1. Ensure you have access to the target Oracle Database and the Oracle APEX Workspace.
2. Compile the database objects (Tables, Packages) located in your feature branch.
3. Import the APEX application SQL file into your workspace if UI changes are needed.

## 3. Standards

Coding standards are not documented here — they live under
[`rules/`](../rules/) (this package's `rules/` folder, consumed as your
project's `.claude/rules/` via git submodule) and are always loaded into
Claude Code's context via the root `CLAUDE.md` index (copied from
[`CLAUDE.md.template`](../CLAUDE.md.template)). They're also the reference
for human code review. See [`STRUCTURE.md`](../STRUCTURE.md) for what each
rule file covers.

Ready-to-copy code templates live in [`templates/`](../templates/).

## 4. Pull Request Workflow

1. Branch from `main` following the naming convention in `.claude/rules/git-workflow.md`.
2. Write your code adhering to the standards in `.claude/rules/`.
3. Commit with descriptive messages.
4. Open a Pull Request on GitHub and fill out the provided Template checklist.
5. Wait for peer review and CI/CD lint pass.
