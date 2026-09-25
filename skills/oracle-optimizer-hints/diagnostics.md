# Diagnosing and Delivering Hints

How to prove a hint does what you think, find out why one "was ignored",
and deliver a hint *without* editing application code. Part of the
[`oracle-optimizer-hints`](SKILL.md) skill.

---

## Get a plan you can trust

`explain plan` shows what the optimizer *would* do, without real bind values
and without runtime adaptations. Tune from the **cursor cache** plan, with
actual row counts.

### Run the statement with row-source statistics

```sql
select /*+ gather_plan_statistics */
       o.order_id                                as order_id
     , o.status                                  as status
  from prefix_orders o
 where o.customer_id = :p_customer_id;
```

The alternative is `alter session set statistics_level = all;` for the
whole session.

### Display the last execution

```sql
select *
  from table(dbms_xplan.display_cursor(
           sql_id          => null      -- null = last statement in this session
         , cursor_child_no => null
         , format          => 'ALLSTATS LAST +PEEKED_BINDS +ALIAS +OUTLINE +HINT_REPORT +NOTE'
       ));
```

> **Note:** in SQL Workshop or any tool that runs extra statements between
> yours, "last statement" isn't yours. Look up the `sql_id` in `v$sql` first,
> or use Connor McDonald's
> [`apex_plan`](https://github.com/connormcd/misc-scripts/blob/master/apex_plan.sql)
> helper, which adds `gather_plan_statistics` and runs the SQL in one round
> trip.

### The format keywords that matter for hinting

| Keyword | Adds |
|---|---|
| `ALLSTATS LAST` | `Starts`, `E-Rows`, `A-Rows`, `A-Time`, `Buffers`, memory — for the last execution. It needs `gather_plan_statistics` or `statistics_level=all`. |
| `+PEEKED_BINDS` | The bind values the plan was optimized for |
| `+ALIAS` | The *Query Block Name / Object Alias* section — the names you need for `@qb` hints |
| `+OUTLINE` | *Outline Data*: the **complete** hint set that reproduces this exact plan |
| `+HINT_REPORT` (19c+) | Used **and** unused hints. `+HINT_REPORT_USED` / `+HINT_REPORT_UNUSED` restrict the list. |
| `+NOTE` | Notes such as "SQL patch … used", "SQL plan baseline … used", "Degree of Parallelism is 2 because of hint" |
| `+ADAPTIVE` | Inactive adaptive-plan lines |

`TYPICAL` (the default) already includes the hint report for **unused**
hints only. `ALL` shows used and unused.

---

## Read the Hint Usage Report (19c+)

Hint tracking is on by default. The report is printed by
`DBMS_XPLAN.DISPLAY`, `DISPLAY_CURSOR`, `DISPLAY_WORKLOAD_REPOSITORY`,
`DISPLAY_SQL_PLAN_BASELINE` and `DISPLAY_SQLSET`, and it appears in SQL
Monitor active reports. It covers every optimizer hint plus a subset of the
others, including `PARALLEL` and `INMEMORY`.

```text
Hint Report (identified by operation id / Query Block Name / Object Alias):
Total hints for statement: 10 (U - Unused (2), N - Unresolved (1), E - Syntax error (1))
----------------------------------------------------------------------------------------
   0 -  STATEMENT
           -  PARALLEL(2)
   0 -  SEL$5
         N -  MERGE(@SEL$5)
   0 -  SEL$2
         E -  NO_ORDER_SUBQ
  21 -  SEL$E0F432AE / T3@SEL$2
         U -  INDEX(t3)
  25 -  SEL$E0F432AE / T2@SEL$2
         U -  USE_MERGE(t2)
           -  INDEX(t2)
```

### What each marker means

| Marker | Meaning | Typical cause |
|---|---|---|
| *(none)* | Used | — |
| `E` | Syntax error | A misspelled name (`FULLL`), a missing argument (`dynamic_sampling`, `use_hash` with no alias), the wrong hint name (`merge(e d)` when you meant `use_merge`, `hash(e d)` when you meant `use_hash`), or arguments on an argument-less hint (`ordered(d e)`) |
| `N` | Unresolved | The alias doesn't exist in that query block: the table name used instead of its alias, an index name that doesn't exist, a `@qb` that doesn't exist, or an `index(pk_name)` with no alias |
| `U` | Unused | The hint was valid but not applicable in the final plan. `use_nl(x)` when `x` ended up as the *outer* table. `use_hash` on a non-equi join. `parallel` with a range scan of a non-partitioned index. Two conflicting hints. A hint "overridden by another in parent query block". A hint lost to a transformation. |
| Line `0` | The query block the hint lives in doesn't exist in the final plan — it was merged or unnested away | — |

### Known blind spots

- **Some syntax errors discard everything after them.** Verified on 26ai:

  - An unknown word **with parentheses** (`merg(v)`, `cell_flash_cache(keep)`)
    or **free text** (`this is a comment`) is reported as `E`, and every
    hint *after* it is dropped with no report line. With
    `/*+ index(t1) full(t2) merg(v) use_nl(t2) */`, `index` and `full` are
    honoured, `merg` is `E`, and `use_nl(t2)` never appears.

  - A **bare** unknown word (`bogus`, `APEX$USE_ROWNUM_PAGINATION`) is
    reported as `E`, but the hints after it still apply.

- **Schema-qualified hints.** On 19c, `full(hr.employees)` was simply
  absent from the report — Connor McDonald's 19c video and his 2024 "Get
  the HINT" post both show it. On 26ai it is reported as `N — unresolved`
  (verified). Either way, no line or `N` means it did nothing.

- **A comment that isn't a hint gives no report at all.** That covers
  `/* + full(c) */` (space before `+`), a second hint comment in the same
  block, and a hint that isn't right after the keyword. If you expected a
  report and got none, check the syntax first.

- **Direct path isn't in the report.** `append` / `append_values` never
  show up. Check the plan instead — `LOAD AS SELECT` vs `LOAD TABLE
  CONVENTIONAL` — and on 26ai read the *Note* for *"Direct Load disabled
  because …"*.

- **Compound join hints hide which half failed.** `use_hash(a b)` is two
  hints, and the report prints the same text as used on one line and unused
  on another. Write `use_hash(a) use_hash(b)` (Franck Pachot).

- **The report says what, rarely why.** For the why, read the plan: which
  table is outer vs inner, and whether the query block was transformed.

### Before 19c

Run a 10053 optimizer trace and search it for `Dumping Hints`. Each entry
shows `err=`, `resol=` and `used=` flags. A hint with a syntax error has no
entry at all.

---

## Find query block names

Most hints only apply inside the query block where they're written. To hint
a table inside an inline view, CTE or subquery from the outer `select` —
as you must in APEX, where your query becomes an inner block
([`apex.md`](apex.md)) — target its block.

### Name the blocks yourself

```sql
with w_open as (
  select /*+ qb_name(w_open) */
         o.order_id                              as order_id
       , o.customer_id                           as customer_id
    from prefix_orders o
   where o.status = 'OPEN'
)
select /*+ leading(@w_open o) index(@w_open o (status)) */
       w.order_id                                as order_id
     , c.customer_name                           as customer_name
  from w_open                         w
  join prefix_customers               c on c.customer_id = w.customer_id;
```

### Or read Oracle's generated names

Use `format => '… +ALIAS'`, which gives `SEL$1`, `SEL$2`, `SET$1` and so on.
The *final*, post-transformation names look like `SEL$5DA710D3`, a hash of
the merged blocks. To see the *original* names, explain the statement with
`/*+ no_query_transformation */`.

### Watch out for these

- Hints that address objects through a view with dot notation
  (`leading(v.e v.d t)`) are **ignored if they span multiple query blocks**.
  Use object aliases with query block qualifiers from the plan instead:
  `leading(e@sel$2 d@sel$2 t@sel$1)`.

- Dot-notation `tablespec` global hints **don't work with ANSI joins**,
  because the parser generates extra views. Use `@queryblock` targeting.

- If two blocks get the same `qb_name`, every hint referencing them is
  ignored.

- After a transformation, even *your* `qb_name` blocks can be renamed —
  always check `+ALIAS` on the final plan.

---

## The full hint set: Outline Data

The only way to *guarantee* a plan with hints is to pin every decision:
transformations, join order, join methods and access paths. Oracle prints
exactly that set as **Outline Data**:

```text
Outline Data
-------------
  /*+
      BEGIN_OUTLINE_DATA
      IGNORE_OPTIM_EMBEDDED_HINTS
      OPTIMIZER_FEATURES_ENABLE('19.1.0')
      DB_VERSION('19.1.0')
      ALL_ROWS
      OUTLINE_LEAF(@"SEL$1")
      FULL(@"SEL$1" "T1"@"SEL$1")
      FULL(@"SEL$1" "T2"@"SEL$1")
      LEADING(@"SEL$1" "T1"@"SEL$1" "T2"@"SEL$1")
      USE_HASH(@"SEL$1" "T2"@"SEL$1")
      END_OUTLINE_DATA
  */
```

Pasting that into application code is fragile and unreadable. It's exactly
what SQL Plan Management stores for you — so if you need plan stability,
**use a baseline, not the outline**.

The outline is also available programmatically, from
`v$sql_plan.other_xml`:

```sql
select extractvalue(value(h), '.')              as hint
  from v$sql_plan sp
     , table(xmlsequence(extract(xmltype(sp.other_xml), '/*/outline_data/hint'))) h
 where sp.sql_id       = :sql_id
   and sp.child_number = 0
   and sp.other_xml is not null;
```

---

## Deliver a hint without touching the code

### Pick the right mechanism

| Mechanism | What it stores | Use when | Licence |
|---|---|---|---|
| **In-code hint** | Hint text in the statement | A behavioural hint (`append`, `driving_site`, `result_cache`, `first_rows(n)`) that expresses intent and belongs with the code | — |
| **SQL Patch** (`DBMS_SQLDIAG.CREATE_SQL_PATCH`, public since 12.2) | A few hints, attached to the *normalized* text of one statement | You need one or two hints on SQL you can't or shouldn't edit — packaged apps, APEX-generated SQL, an emergency. Also to **switch off** bad embedded hints. | No extra licence. EE and SE2. |
| **SQL Plan Baseline** (`DBMS_SPM`) | The full outline of accepted plans | You want plan **stability** — lock in a known-good plan, including one you found with hints, while still letting better plans be verified later | No extra licence |
| **SQL Profile** (SQL Tuning Advisor) | Estimate corrections (`OPT_ESTIMATE`, stats), not a fixed plan | The advisor found a cardinality problem | Tuning Pack |

A **SQL Patch** matches on normalized text — whitespace and case of
non-literals don't matter, which was verified on 26ai — so the same patch
covers cosmetic variants of a statement. It survives restarts and can be exported between databases with
a staging table (`CREATE_STGTAB_SQLPATCH`, `PACK_STGTAB_SQLPATCH`,
`UNPACK_STGTAB_SQLPATCH`).

### Add a hint with a SQL Patch

```sql
declare
  l_patch_name varchar2(128);
begin
  l_patch_name := dbms_sqldiag.create_sql_patch(
                      sql_id      => 'amz7zfdk33czb'
                    , hint_text   => 'FULL(@"SEL$1" "T1"@"SEL$1")'
                    , name        => 'prefix_orders_full_patch'
                    , description => 'CWMS-412: force full scan until histogram fix ships'
                  );
end;
/
```

Hints in a patch **must carry query block names** (`@"SEL$1"`), because the
patch isn't written inside any query block. Copy them from `+OUTLINE` or
`+ALIAS`. The `sql_text` overload (a CLOB) also exists.

### Switch off the hints already in the code

```sql
begin
  dbms_output.put_line(dbms_sqldiag.create_sql_patch(
      sql_id    => 'amz7zfdk33czb'
    , hint_text => 'IGNORE_OPTIM_EMBEDDED_HINTS'
    , name      => 'prefix_orders_nohints_patch'
  ));
end;
/
```

You can also replace them in one go:
`hint_text => 'IGNORE_OPTIM_EMBEDDED_HINTS LEADING(@"SEL$1" t1 t2) FULL(@"SEL$1" "T1"@"SEL$1")'`.

> **Note:** `IGNORE_OPTIM_EMBEDDED_HINTS` only disables **CBO-class** hints
> (`V$SQL_HINT.PROPERTY` bit 16, marked `yes` in the catalog's **CBO**
> column). Behavioural hints such as `append`, `result_cache` or
> `driving_site` keep working — Neil Chandler hit exactly this. Verified on
> 26ai: the embedded `index` hint was reported as `U — rejected by
> IGNORE_OPTIM_EMBEDDED_HINTS`, while the patch's own `FULL` was used.

### Verify and remove a patch

```sql
select p.name                                    as patch_name
     , p.status                                  as status
     , p.created                                 as created
     , p.sql_text                                as sql_text
  from dba_sql_patches p;

select s.sql_id                                  as sql_id
     , s.sql_patch                               as sql_patch
  from v$sql s
 where s.sql_patch is not null;
```

The plan's *Note* section shows `SQL patch "…" used for this statement`.
To remove the patch:

```sql
exec dbms_sqldiag.drop_sql_patch(name => 'prefix_orders_full_patch', ignore => true);
```

### Copy a hinted plan onto the unhinted statement with SQL Plan Management

This is the recommended way to go from triage hints to a durable fix, and
it's what Maria Colgan recommends:

1. Run the **hinted** copy of the statement and get its `sql_id` and
   `plan_hash_value`.

2. Load that plan as a baseline for the **original, unhinted** statement.

3. Remove the hints from the code. The baseline keeps the plan, and SPM
   will still *capture* better plans after an upgrade and only accept them
   once they are verified as better.

Verified on 26ai: the unhinted statement then ran the hinted plan. The
hint report showed the stored outline hints, and the *Note* said *SQL plan
baseline … used for this statement*.

```sql
declare
  l_loaded pls_integer;
begin
  l_loaded := dbms_spm.load_plans_from_cursor_cache(
                  sql_id          => '2qtu6hy4rf1j9'         -- hinted statement
                , plan_hash_value => 2290436051               -- its good plan
                , sql_handle      => 'SQL_4bf04d85fcc170b0'   -- unhinted statement's handle
              );
  dbms_output.put_line('plans loaded: ' || l_loaded);         -- 0 means nothing was loaded
end;
/
```

Get the `sql_handle` from `dba_sql_plan_baselines` after capturing the
unhinted statement once. There's also an overload that takes `sql_text`
instead.

---

## Parameters that switch hints off

| Parameter | Default | Effect |
|---|---|---|
| `OPTIMIZER_IGNORE_HINTS` (18c+) | `FALSE` on-prem and on ADB Transaction Processing / JSON / **APEX Service**. `TRUE` on **ADB Lakehouse** (formerly ADW). | Embedded optimizer hints are ignored. Session- or system-modifiable. |
| `OPTIMIZER_IGNORE_PARALLEL_HINTS` (18c+) | Same split as above | Embedded parallel hints are ignored |
| `_OPTIMIZER_IGNORE_HINTS` | — | The hidden predecessor mentioned in older talks. Use the documented parameter above. |

**Verified on 26ai:** with `optimizer_ignore_hints = true`, optimizer
hints are reported as `U — rejected by IGNORE_OPTIM_EMBEDDED_HINTS` — the
parameter works like that hint applied to every statement. `append` still
loads direct path, and `result_cache` still caches. With
`optimizer_ignore_parallel_hints = true`, `parallel(n)` is reported as
`U — because of _optimizer_ignore_parallel_hints`.

An application on an ADB **Lakehouse** instance that relies on hints must
run `alter session set optimizer_ignore_hints = false;`, and the same for
parallel hints. See [`sql-and-plsql.md`](sql-and-plsql.md#autonomous-database),
and for APEX [`apex.md`](apex.md#apex-on-autonomous-database).

### Test whether your hints still earn their keep

Do this after every upgrade, and whenever you inherit hinted code
(Maria Colgan's advice):

```sql
alter session set optimizer_ignore_hints = true;
-- run the hinted workload, compare elapsed time / buffers / plans to the hinted run
alter session set optimizer_ignore_hints = false;
```

At scale, SQL Performance Analyzer does the same comparison over a SQL
Tuning Set.

---

## Other plan diagnostics that help decide

- **SQL Monitor** (`dbms_sqltune.report_sql_monitor(sql_id => …, type => 'ACTIVE')`)
  gives per-line runtime for long-running or parallel SQL, or anything with
  the `monitor` hint. It requires the **Tuning Pack**.

- **SQL Analysis Report** (23ai+). A section at the end of `DBMS_XPLAN`
  output, and a tab in SQL Monitor, that flags patterns like cartesian
  products, `union` vs `union all`, and predicates that prevent index range
  scans. It also points at a hint referencing a table that isn't in the query.

- **`V$SYSTEM_FIX_CONTROL`** lists optimizer bug-fix switches. For example,
  fix `22174392` ("first k row optimization for window function rownum
  predicate", 19.1) is why `fetch first n rows` top-N queries got
  index-friendly without hints (Franck Pachot).
