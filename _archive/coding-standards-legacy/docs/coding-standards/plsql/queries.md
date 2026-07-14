# Query Standards (SELECT, INSERT, MERGE)

## 1. SELECT Patterns

### 1.1 Column Formatting

- **First Column**: Place the first column on the same line as `select`, separated by **2 spaces**.
- **Alignment**: Align subsequent columns vertically. The comma should be indented to match the visual start of the columns (leading comma alignment).

**GOOD**:

```sql
select id
     , parent_id
     , nombre
     , description
  from demo_hierarchical_data
 where active_yn = 'Y'
 order by orden;
```

**BAD**:

```sql
SELECT ID, PARENT_ID, NOMBRE, DESCRIPTION
FROM DEMO_HIERARCHICAL_DATA
WHERE ACTIVE_YN='Y'
ORDER BY ORDEN;
```

### 1.2 Always Alias Columns

Name the alias for every column in your select statements. This makes the query self-documenting, prevents ambiguity in joins, and makes it easier to identify columns in reports and downstream logic.

**GOOD**:

```sql
select c.customer_id        as customer_id
     , c.customer_name      as customer_name
     , o.order_date         as last_order_date
     , o.total_amount       as order_total
  from tf_customers          c
  join tf_orders             o on o.customer_id = c.customer_id
 where c.active_yn = 'Y';
```

**BAD**:

```sql
-- No aliases, ambiguous column references
select customer_id
     , customer_name
     , order_date
     , total_amount
  from tf_customers
  join tf_orders on tf_orders.customer_id = tf_customers.customer_id
 where active_yn = 'Y';
```

### 1.3 LEFT JOIN Alignment

When using `left join`, align the `on` clause on the same line as the join. Place any additional conditions with `and` on the next line, aligned under the `on`. Always use the table alias.

**GOOD**:

```sql
select i.invoice_id             as invoice_id
     , c.client_name            as client_name
     , bus.business_name        as business_name
     , ba.bank_address          as bank_address
  from tf_invoices i
  left join tf_clients        c on c.client_id = i.client_id
                               and c.active_yn = 'Y'
  left join tf_businesses   bus on bus.business_id = i.business_id
                               and bus.active_yn = 'Y'
  left join tf_bank_info     ba on ba.bank_id = i.bank_id
 where i.active_yn = 'Y';
```

**BAD**:

```sql
-- Misaligned joins, no aliases, conditions scattered
select i.invoice_id, client_name, business_name
  from tf_invoices i
LEFT JOIN tf_clients ON tf_clients.client_id = i.client_id AND tf_clients.active_yn = 'Y'
LEFT JOIN tf_businesses ON tf_businesses.business_id = i.business_id;
```

### 1.4 Function Calls in SELECT

When a function call has multiple named parameters, break it across lines:

- Opening parenthesis stays on the same line as the function name.
- Each parameter on its own line, indented **2 spaces** inside the parentheses.
- Named parameter arrows (`=>`) vertically aligned.
- Closing parenthesis on its own line, aligned with the function start.
- Column alias (`as ...`) follows the closing parenthesis.
- Subsequent columns use the leading comma pattern.

**GOOD**:

```sql
select apex_item.checkbox2(
           p_idx   => 1
         , p_value => s.segment_num
       ) as copy_segment
     , s.segment_label
     , o.options_list
     , apex_item.checkbox2(
           p_idx   => 2
         , p_value => s.segment_num
       ) as copy_options
  from tf_segments s
```

**BAD**:

```sql
-- Parameters on one line breaks readability and column alignment
select apex_item.checkbox2(p_idx => 1, p_value => s.segment_num) as copy_segment
     , s.segment_label
```

## 2. Avoid Cursors — Use FOR Loop Queries

Prefer implicit cursor `for` loops over explicit cursors with `open`, `fetch`, `close`. They are cleaner, less error-prone, and automatically handle resource cleanup.

**GOOD**:

```plsql
for l_rec in (
  select ticket_id
       , description
    from tf_tickets
   where active_yn = 'Y'
)
loop
  process_ticket(
      p_ticket_id   => l_rec.ticket_id
    , p_description => l_rec.description
  );
end loop;
```

**BAD**:

```plsql
-- Explicit cursor: verbose, error-prone, and requires manual close
declare
  cursor c_tickets is
    select ticket_id
         , description
      from tf_tickets
     where active_yn = 'Y';
  l_rec c_tickets%rowtype;
begin
  open c_tickets;
  loop
    fetch c_tickets into l_rec;
    exit when c_tickets%notfound;
    process_ticket(
        p_ticket_id   => l_rec.ticket_id
      , p_description => l_rec.description
    );
  end loop;
  close c_tickets;
end;
```

## 3. INSERT Patterns

Always use the column list and leading commas.

**GOOD**:

```sql
insert
  into employees (
       employee_id
     , first_name
     , last_name
)
values (
       p_employee_id
     , p_first_name
     , p_last_name
);
```

**BAD**:

```sql
insert into employees values (p_employee_id, p_first_name, p_last_name);
```

## 4. MERGE Patterns

Use `merge` for sync/upsert operations.

**GOOD**:

```sql
merge into tf_task_list t
using (select p_task_id as task_id
         from dual
) s
   on (t.task_id = s.task_id)
 when matched then
  update
      set t.task_name = p_task_name
 when not matched then
  insert (
         task_name
       , active_yn
  )
  values (
         p_task_name
       , 'Y'
  );
```

**BAD**:

```sql
-- Separate select + conditional insert/update — race condition prone
begin
  select count(*)
    into l_count
    from tf_task_list
   where task_id = p_task_id;

  if l_count > 0 then
    update tf_task_list set task_name = p_task_name where task_id = p_task_id;
  else
    insert into tf_task_list (task_name, active_yn) values (p_task_name, 'Y');
  end if;
end;
```

### Seed/Data Scripts Formatting

When writing `merge` statements for seed data, align the `insert` columns and `values` closely:

```sql
 when not matched then
  insert (
         receiver_name
       , bank_name
       , routing_number
  )
  values (
         s.receiver_name
       , s.bank_name
       , s.routing_number
  );
```

## 5. Views and WITH Clause

- **Views**: Use a **WITH** clause (common table expressions) for the view body instead of a single flat `select`. This improves readability and enforces a clear structure.
- **CTE naming**: Names of CTEs (and subqueries in a WITH) must start with **`w_`** (e.g. `w_inv`, `w_line_subtotal`, `w_lines`).

### Examples

**GOOD**:

```sql
create or replace view tf_list_vw
as
with w_base as (
  select id
       , name 
    from my_table 
   where active_yn = 'Y'
)
select id
     , name
  from w_base;
```

**BAD**:

```sql
create or replace view tf_list_vw
as
  select id
       , name
    from my_table
   where active_yn = 'Y';
```
