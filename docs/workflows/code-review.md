# Code Review Guidelines

Code reviews are a critical part of our development lifecycle. All code should be reviewed before merging to the main branch.

## 1. Reviewer Expectations

1. **Verify Standards:** Ensure that the PL/SQL meets our formatting rules (leading commas, lowercase SQL keywords).
2. **Architecture:** Ensure the business logic belongs in the database packages and not directly inside APEX processes.
3. **Performance:** Check for `select *` usages and ensure queries are utilizing valid indexes.
4. **Security:** Verify `dbms_assert` is used for dynamic objects and bind variables are properly utilized.
5. **APEX Process Conditions:** Validate that **all** APEX processes in the Processing section have a Server-side Condition (button or `REQUEST IN ()`). A process without a condition is a blocking review finding.
6. **Column Aliases:** Ensure select statements use named aliases for every column, especially in joins.
7. **No HTML in SQL:** Verify that report queries return clean data and avoid embedding HTML tags. Rendering should be handled via APEX Template Directives.
8. **Packages Only:** Confirm there are no standalone procedures or functions; all logic must be in a package.
9. **`%type` Usage:** Prefer `table.column%type` over hardcoded data types in PL/SQL variable declarations and parameters.

## 2. Developer Expectations

1. Ensure the code works locally.
2. Ensure you have used `logger.log()` instrumentation for your new packages.
3. Fix all PR comments before requesting another review.
4. Use proper branch naming convention (see below).
5. Ensure compilation code path matches the branch name.

## 3. Branch Naming Convention

Branch names **must** follow this format:

```
<TICKET-NUMBER>-<short-description>
```

- Use the ticket/issue number as a prefix.
- Follow with a very short, lowercase, hyphen-separated description.

### Examples

**GOOD**:

```
NLM-21-adding-segments-to-client
TF-145-fix-invoice-totals
```

**BAD**:

```
fix-stuff
angel-branch
feature/adding-segments
```

## 4. Compilation Code Convention

Compilation scripts must be organized by ticket number **without spaces**, and should match the branch name as closely as possible.

### Example

```
@code/NLM-21-adding-segments-to-client
```

This ensures traceability between branches, tickets, and deployed scripts.
