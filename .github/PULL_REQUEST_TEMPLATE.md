## Description

<!-- Describe your changes, the business logic implemented, or the bug fixed. -->

## Checklist

- [ ] **Naming conventions** match our standard (e.g., `snake_case` for DB objects, `l_`/`p_`/`g_` prefixes for variables).
- [ ] **No `SELECT *` executed**; all columns are explicitly defined.
- [ ] **SQL & PL/SQL Formatting** strictly adheres to leading-comma alignments and standard 2-space indentation.
- [ ] **Code Sectioning** (`===` and `---` comment blocks) has been applied to organize long files.
- [ ] **Proper Error Handling** (`logger.log_error`, `apex_error.add_error`) has been securely implemented.
- [ ] **Technical Debt & TODOs** have been properly marked with initials and dates (`-- TODO_[Initials]_<YYYY-MON-DD>`).
- [ ] **Comments are written in English**, specifically detailing business logic (what/why over how).
- [ ] **APEX Application Export** (`.sql` file) correlates strictly with the changes (if the UI logic was changed).
