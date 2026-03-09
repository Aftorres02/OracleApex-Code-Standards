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

- [General Principles](../coding-standards/plsql/general.md)
- [Naming Conventions](../coding-standards/plsql/naming.md)
- [SQL & PL/SQL](../coding-standards/plsql/sql-plsql.md)
- [Provided Templates](../coding-standards/plsql/templates.md)
- [APEX Specifics](../coding-standards/apex/apex.md)
- [JavaScript](../coding-standards/ui-ux/javascript.md)
- [CSS](../coding-standards/ui-ux/css.md)

## 4. Pull Request Workflow

1. Branch from `main` (e.g., `feature/TICKET-123-description`).
2. Write your code adhering to our formatting rules.
3. Commit with descriptive messages.
4. Open a Pull Request on GitHub and fill out the provided Template checklist.
5. Wait for peer review and CI/CD lint pass.
