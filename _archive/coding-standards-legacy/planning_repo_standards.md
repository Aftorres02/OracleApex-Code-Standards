# Repository Architecture Guidelines

## 1. Proposed Directory Structure

This is the proposed directory structure to separate concerns and improve maintainability of our guidelines.

```text
/
├── docs/
│   ├── README.md                      # High-level overview of the repository
│   │
│   ├── guides/                        # General guides and documentation
│   │   ├── developer-guide.md         # Developer Onboarding Guide
│   │   └── tech-lead-guide.md         # Tech Lead Provisioning Scripts
│   ├── workflows/                     # Project lifecycle processes
│   │   └── code-review.md             # Code review expectations
│   │
│   └── coding-standards/              # Granular standards separated by tech stack
│       ├── plsql/                     # Database Layer
│       │   ├── general.md             # Formatting, code sectioning, TODOs, security
│       │   ├── naming.md              # Object naming, constraints, variable prefixes
│       │   ├── tables.md              # DDL, PK naming, data types, audit columns, triggers
│       │   ├── queries.md             # SELECT, INSERT, MERGE, JOINs, cursor rules
│       │   └── packages.md            # Package structure, templates, %type, logging
│       │
│       ├── apex/                      # Application Layer
│       │   ├── apex.md                # Error handling, AJAX, process conditions, DML forms
│       │   └── page-standards.md      # Page numbering, regions, buttons
│       │
│       └── ui-ux/                     # Browser Layer
│           ├── javascript.md          # JS, DOM, and AJAX client-side standards
│           └── css.md                 # Universal Theme custom CSS standards
│
├── .github/
│   ├── PULL_REQUEST_TEMPLATE.md       # Standardized template for PRs
│   └── workflows/
│       └── lint.yml                   # CI/CD pipelines (e.g., SQL linting)
│
└── AGENTS.md                          # Global agent instructions / Master rules
```

---

## 2. Developer Onboarding Guide (`docs/guides/developer-guide.md`)

The onboarding guide must contain at least the following baseline sections to help new developers spin up quickly:

1. **Repository Structure:** Explanation of where to find DB scripts, APEX application exports, and documentation.
2. **Environment Setup:** Instructions on how to compile database objects and import the APEX application into the local workspace.
3. **Coding Standards:** Link to `docs/coding-standards/` and the overarching `AGENTS.md` conventions.
4. **Contribution Workflow:** How to branch off the main line, commit with appropriate messages, and create a Pull Request.

---

## 3. Formatting Standards in Documentation

When documenting specific guidelines (e.g., in `docs/coding-standards/plsql/sql-plsql.md`), provide clear **GOOD** and **BAD** examples utilizing Markdown syntax highlighting to illustrate the standard.

### Example: SQL Formatting

**GOOD:**

```sql
select customer_id
     , customer_name
  from customers
 where status = 'ACTIVE';
```

**BAD:**

```sql
-- Missing formatting, no leading commas, capitalization inconsistencies
SELECT * FROM customers WHERE status='ACTIVE';
```

---

## 4. Pull Request Workflow Checklist (`.github/PULL_REQUEST_TEMPLATE.md`)

Every Pull Request must include a checklist to enforce standards before merging. Since we are working with Oracle APEX and PL/SQL, this has been specifically tailored.

### Example PR Checklist:

- [ ] **Naming conventions** match our standard (e.g., snake*case for DB objects, `l*`/`p*`/`g*` prefixes for variables).
- [ ] **No `select *` executed**; all columns are explicitly defined.
- [ ] **SQL & PL/SQL Formatting** strictly adheres to leading-comma alignments and standard 2-space indentation.
- [ ] **Code Sectioning** (`===` and `---` comment blocks) has been applied to organize long files.
- [ ] **Proper Error Handling** (`logger.log_error`, `apex_error.add_error`) has been securely implemented.
- [ ] **Technical Debt & TODOs** have been properly marked with initials and dates (`-- TODO_[Initials]_<MONTH-DD-YYYY>`).
- [ ] **Comments are written in English**, specifically detailing business logic (what/why over how).
- [ ] **APEX Application Export** (`.sql` file) correlates strictly with the changes (if the UI logic was changed).
