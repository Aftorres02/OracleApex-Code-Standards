# Naming Conventions

## 1. Database Objects

- **Keywords**: ALL SQL keywords in lowercase (`create`, `table`, `select`, `from`, `where`...).
- **Objects**: ALL object names in `snake_case` (lowercase with underscores).
- **Prefixes/Suffixes**:
  - **Project Prefix**: All core architectural objects (Tables, Views, Packages) MUST begin with the approved project prefix (e.g., `tf_`).
  - **Validations**: `active_yn` (or `_yn` suffix) for boolean flags 'Y'/'N'.
  - **Tables**: Plural (e.g., `tf_tickets`).
  - **Views**: Plural names with suffix `_vw` (e.g., `tf_tickets_vw`).
  - **Packages**: `{module_name}_pkg` or `{module}_api`/`{module}_utils` (e.g., `tf_tickets_api`).

### 1.1 Constraints

Always use PREFIXES for constraints:

- **Foreign Key**: `fk_<table>_<ref_table>`
- **Unique**: `uk_<table>_<column>`
- **Check**: `ck_<table>_<description>`

### Examples

**GOOD**:

```sql
alter table tf_tickets add constraint fk_tickets_users foreign key (user_id) references users (user_id);
```

**BAD**:

```sql
alter table tf_tickets add constraint tickets_users_fk foreign key (user_id) references users (user_id);
```

## 2. PL/SQL Variables

Use standard prefixes to distinguish variable scope and type.

- **Local Variables**: Prefix `l_` (e.g., `l_count`).
- **Local Constants**: Prefix `lc_` (e.g., `lc_count`).
- **Parameters**: Prefix `p_` (e.g., `p_ticket_id`).
- **Output Parameters**: Prefix `o_` (e.g., `o_error_msg`).
- **In/Out Parameters**: Prefix `io_` (e.g., `io_error_msg`).
- **Global Variables**: Prefix `g_` (e.g., `g_user`).
- **Global Constants**: Prefix `gc_` (e.g., `gc_scope_prefix`).
- **Cursors**: Prefix `l_cursor`
- **Records**: Prefix `l_` (e.g., `l_{object_context}_rec`).

### Examples

**GOOD**:

```plsql
procedure get_ticket_info(
    p_ticket_id                        in number
  , o_status                           out varchar2
  , io_error                           in out varchar2
) is
  l_count number;
begin
  -- ... logic here
null;
end;
```

**BAD**:

```plsql
procedure get_ticket_info(
    ticket_id in number
  , status   out varchar2
) is
  count_val number;
begin
  -- ... logic here
null;
end;
```
