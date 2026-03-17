# Developer Onboarding Guide

Welcome to the project! Follow this guide to get up to speed.

## 1. Repository Structure

All core documentation is in the `docs/` folder. The database schema and scripts are typically separated into a `db/` folder (or equivalent), and APEX exports are maintained periodically.

## 2. How to run the project

1. Ensure you have access to the target Oracle Database and the Oracle APEX Workspace.
2. Compile the database objects (Tables, Packages) located in your feature branch.
3. Import the APEX application SQL file into your workspace if UI changes are needed.

## 3. Coding standards

Read through our comprehensive standards:

**Database Layer (PL/SQL)**:

- [General Principles](../coding-standards/plsql/general.md) — Formatting, code sectioning, TODOs, security.
- [Naming Conventions](../coding-standards/plsql/naming.md) — Object naming, constraints, variable prefixes.
- [Table & DDL Standards](../coding-standards/plsql/tables.md) — PK naming, data types, audit columns, triggers, DDL file structure.
- [Query Standards](../coding-standards/plsql/queries.md) — SELECT, INSERT, MERGE, JOIN alignment, cursor rules.
- [Package Standards](../coding-standards/plsql/packages.md) — Package structure, templates, `%type`, procedure calls, logging.

**Application Layer (APEX)**:

- [APEX Specifics](../coding-standards/apex/apex.md) — Error handling, AJAX, process conditions, LOV, DML forms.
- [APEX Page Standards](../coding-standards/apex/page-standards.md) — Page numbering, regions, buttons.

**JavaScript Layer**:

- [General Standards](../coding-standards/javascript/general.md) — Naming, formatting, JSDoc, file headers.
- [Module Pattern](../coding-standards/javascript/modules.md) — Revealing Module Pattern, namespace, CONFIG, logger, public API.
- [AJAX & Server Communication](../coding-standards/javascript/ajax.md) — `apex.server.process`, callbacks, error handling.
- [DOM & Event Handling](../coding-standards/javascript/dom-events.md) — Event delegation, DOM queries, APEX items, dialogs.

**CSS / UI**:

- [CSS](../coding-standards/ui-ux/css.md) — Custom class naming, Universal Theme best practices.

## 4. Pull Request Workflow

1. Branch from `main` using the naming convention: `<TICKET-NUMBER>-<short-description>` (e.g., `NLM-21-adding-segments-to-client`).
2. Write your code adhering to our formatting rules.
3. Commit with descriptive messages.
4. Open a Pull Request on GitHub and fill out the provided Template checklist.
5. Wait for peer review and CI/CD lint pass.

## 5. Branch & Compilation Naming

### Branch Names

Branch names must be the ticket number followed by a very short description, all lowercase and hyphenated:

```
NLM-21-adding-segments-to-client
TF-145-fix-invoice-totals
```

### Compilation Code

Compilation scripts must use the ticket number with no spaces. Prefer matching the branch name:

```
@code/NLM-21-adding-segments-to-client
```

## 6. APEX Export Strategy

Use **YML format** when exporting APEX application changes. This produces human-readable, diffable files that work well with version control and code reviews.

```bash
# Example: SQLcl APEX export in YML format
apex export -applicationid 100 -split -skipExportDate -expType APPLICATION_SOURCE
```

> This generates a folder structure with individual `.yml` files per component, making it easy to see exactly what changed in a pull request.
