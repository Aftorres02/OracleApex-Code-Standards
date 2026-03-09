# Code Review Guidelines

Code reviews are a critical part of our development lifecycle. All code MUST be reviewed before merging to the main branch.

## 1. Reviewer Expectations

1. **Verify Standards:** Ensure that the PL/SQL meets our formatting rules (leading commas, lowercase SQL keywords).
2. **Architecture:** Ensure the business logic belongs in the database packages and not directly inside APEX processes.
3. **Performance:** Check for `select *` usages and ensure queries are utilizing valid indexes.
4. **Security:** Verify `dbms_assert` is used for dynamic objects and bind variables are properly utilized.

## 2. Developer Expectations

1. Ensure the code works locally.
2. Ensure you have used `logger.log()` instrumentation for your new packages.
3. Fix all PR comments before requesting another review.
