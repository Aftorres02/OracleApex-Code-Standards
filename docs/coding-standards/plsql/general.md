# General Coding Principles

## 1. Consistency & Formatting

- **Indentation**: Use **2 spaces** for indentation. Avoid using tabs.
- **Case Sensitivity**:
  - **SQL/PLSQL**: Lowercase for keywords and identifiers.
  - **JavaScript**: camelCase for variables/functions, UPPERCASE for constants.

### Examples

**GOOD**:

```sql
begin
  if l_count > 0 then
    process_data();
  end if;
end;
```

**BAD**:

```sql
BEGIN
    if l_count > 0 then
        process_data();
    end if;
END;
```

## 2. Code Sectioning

To improve scannability in long files, use standardized header blocks. The standard width is **80 characters**.

- **Level 1 (High Importance / Complex Blocks)**: Use `=`
- **Level 2 (Minor Blocks / Logic Separation)**: Use `-`
- **In-line Comments**: Use a single space after `--`

### Examples

**GOOD**:

```sql
-- =============================================================================
-- IMPORTANT UPDATE FOR SEARCH RESULTS
-- =============================================================================
update search_index
   set active_yn = 'N';

-- -----------------------------------------------------------------------------
-- Refresh cache
-- -----------------------------------------------------------------------------
refresh_cache();
```

**BAD**:

```sql
--========================================
--IMPORTANT UPDATE
--========================================

--refresh cache
refresh_cache();
```

## 3. Technical Debt & TODOs

When code requires future action, follow a mandatory format:
`-- TODO_[Initials/User]_<MONTH-DD-YYYY> [Description]`

### Examples

**GOOD**:

```sql
-- TODO_AFLORES_MARCH-09-2026 Pending validation with the business
```

**BAD**:

```sql
-- TODO: fix this later
```

## 4. Security & SQL Injection Prevention

- Avoid concatenating user input into dynamic SQL.
- Use `execute immediate ... using ...` for dynamic statements.
- Use `dbms_assert` when passing object names (tables, columns) dynamically.

### Examples

**GOOD**:

```sql
execute immediate 'select count(*) from ' || dbms_assert.enquote_name(p_table) || ' where id = :1' using p_id;
```

**BAD**:

```sql
execute immediate 'select count(*) from ' || p_table || ' where id = ' || p_id;
```

## 5. IF / THEN Formatting

Keep `if` condition and `then` on the **same line**. Avoid placing `then` on a separate line.

### Examples

**GOOD**:

```sql
if l_name is not null then
  -- logic
end if;
```

**BAD**:

```sql
if l_name is not null
then
  -- logic
end if;
```
