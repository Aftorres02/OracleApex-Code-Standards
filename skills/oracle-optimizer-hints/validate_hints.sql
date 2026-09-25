-- Implements: skills/oracle-optimizer-hints/validation-26ai.md (re-runnable checks)
-- =============================================================================
-- Script:  validate_hints.sql
-- Purpose: Re-run the hint behaviour checks behind the oracle-optimizer-hints
--          skill on YOUR database version. Creates zz_hint_* objects in the
--          current schema, prints plans + hint reports, then drops everything.
--
-- Needs:   create table/view/procedure/trigger, and select on v$sql
--          (e.g. SELECT_CATALOG_ROLE). Hint Report needs 19c+.
-- Run:     sql -nolog  ->  connect -name "<dev connection>"  ->  @validate_hints.sql
--          Use a DEV/local schema only. SQL Patch / SPM checks are manual —
--          see validation-26ai.md (they need ADMINISTER SQL MANAGEMENT OBJECT).
-- =============================================================================
set pagesize 0 linesize 200 feedback off serveroutput on trimspool on verify off define on

-- -----------------------------------------------------------------------------
-- Setup
-- -----------------------------------------------------------------------------
begin
  for t in (select table_name from user_tables where table_name like 'ZZ\_HINT\_%' escape '\'
             order by case when table_name = 'ZZ_HINT_PARENT' then 2 else 1 end) loop
    execute immediate 'drop table ' || t.table_name || ' cascade constraints purge';
  end loop;
end;
/
create table zz_hint_parent (id number primary key, name varchar2(100 char), region varchar2(10 char));
create table zz_hint_child (
    id          number primary key
  , parent_id   number not null references zz_hint_parent(id)
  , status      varchar2(10 char)
  , created_on  date
  , amount      number
  , padding     varchar2(200 char)
);
insert into zz_hint_parent
select level, 'P' || level, case when mod(level, 10) = 0 then 'NORTH' else 'SOUTH' end
  from dual connect by level <= 1000;
insert into zz_hint_child
select level, mod(level, 1000) + 1, case when mod(level, 100) = 0 then 'OPEN' else 'CLOSED' end
     , sysdate - mod(level, 365), mod(level, 500), rpad('x', 150, 'x')
  from dual connect by level <= 200000;
commit;
create index zz_hint_child_ix1 on zz_hint_child(parent_id);
create index zz_hint_child_ix2 on zz_hint_child(status, created_on);
create table zz_hint_load     (id number, val varchar2(100 char));
create table zz_hint_load_trg (id number, val varchar2(100 char), created_by varchar2(128 char));
create or replace trigger zz_hint_load_trg_bi before insert on zz_hint_load_trg for each row
begin
  :new.created_by := user;
end;
/
create table zz_hint_load_fk (id number, parent_id number references zz_hint_parent(id));
begin
  dbms_stats.gather_table_stats(user, 'ZZ_HINT_PARENT');
  dbms_stats.gather_table_stats(user, 'ZZ_HINT_CHILD');
end;
/
select 'DB: ' || banner_full from v$version;

-- -----------------------------------------------------------------------------
-- 1-2. Hint report behaviour (explain plan)
-- -----------------------------------------------------------------------------
prompt ###### 1a  table name instead of alias            expect: N
explain plan for select /*+ index(zz_hint_child zz_hint_child_ix1) */ count(*) from zz_hint_child c where c.parent_id = 5;
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 1b  schema-qualified name                  expect: N on 26ai (Connor McDonald saw no line at all on 19c)
-- built dynamically: SQL*Plus/SQLcl do not substitute &variables inside /*+ */ comments
begin
  execute immediate 'explain plan for select /*+ full(' || user || '.zz_hint_child) */ * from '
                 || user || '.zz_hint_child where id = 5';
end;
/
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 1c  use_hash on a non-equi join             expect: U
explain plan for select /*+ leading(p) use_hash(c) */ count(*) from zz_hint_parent p, zz_hint_child c where c.amount between p.id - 1 and p.id + 1 and p.region = 'NORTH';
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 1d  unknown word with () drops what follows expect: E merg, full(p) not listed
explain plan for select /*+ index(c zz_hint_child_ix1) merg(v) full(p) */ count(*) from zz_hint_parent p join zz_hint_child c on c.parent_id = p.id where p.id = 5;
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 1e  compound use_nl(p c), no leading       expect: same hint U on one line, used on another
explain plan for select /*+ use_nl(p c) */ count(*) from zz_hint_parent p join zz_hint_child c on c.parent_id = p.id where p.region = 'NORTH';
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 1f  complete set                           expect: 3 used
explain plan for select /*+ leading(p c) use_nl(c) index(c (parent_id)) */ count(*) from zz_hint_parent p join zz_hint_child c on c.parent_id = p.id where p.region = 'NORTH';
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 1g  ordered(args) / dynamic_sampling bare  expect: E
explain plan for select /*+ ordered(p c) */ count(*) from zz_hint_parent p join zz_hint_child c on c.parent_id = p.id;
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 1h  second hint comment                    expect: only full(c) listed
explain plan for select /*+ full(c) */ /*+ index(c zz_hint_child_ix1) */ count(*) from zz_hint_child c where c.parent_id = 5;
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 1i  space between * and +                  expect: no hint report (plain comment)
explain plan for select /* + full(c) */ count(*) from zz_hint_child c where c.parent_id = 5;
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 1j  bare unknown word before a hint        expect: E bogus, full(c) used
explain plan for select /*+ bogus full(c) */ count(*) from zz_hint_child c where c.parent_id = 5;
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 1k  prose before a hint                    expect: E this, full(c) NOT applied
explain plan for select /*+ this is a comment full(c) */ count(*) from zz_hint_child c where c.parent_id = 5;
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 2a  outer hint on inner alias (wrapper)    expect: N
explain plan for select /*+ full(c) */ * from (select a.*, row_number() over (order by a.created_on desc) as rn from (select c.id, c.status, c.created_on from zz_hint_child c where c.parent_id = 5) a) where rn between 1 and 25;
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 2b  qb_name + @qb from outside             expect: used
explain plan for select /*+ full(@src c) */ * from (select a.*, row_number() over (order by a.created_on desc) as rn from (select /*+ qb_name(src) */ c.id, c.status, c.created_on from zz_hint_child c where c.parent_id = 5) a) where rn between 1 and 25;
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 2c  statement-level first_rows from outside expect: used
explain plan for select /*+ first_rows(25) */ * from (select a.*, row_number() over (order by a.created_on desc) as rn from (select c.id, c.status, c.created_on from zz_hint_child c where c.status = 'OPEN') a) where rn between 1 and 25;
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 1g2 dynamic_sampling without a level     expect: E
explain plan for select /*+ dynamic_sampling */ count(*) from zz_hint_child c;
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 2d  CTE referenced twice                 expect: TEMP TABLE TRANSFORMATION
explain plan for with w_base as (select c.parent_id, sum(c.amount) as amt from zz_hint_child c where c.status = 'OPEN' group by c.parent_id) select a.parent_id, a.amt from w_base a join w_base b on b.parent_id = a.parent_id + 1;
select * from table(dbms_xplan.display(format => 'BASIC'));
-- -----------------------------------------------------------------------------
-- 3. Hints inside a PL/SQL package (static, cursor loop, dynamic)
-- -----------------------------------------------------------------------------
create or replace package zz_hint_pkg
as
  procedure run_all(p_parent_id in number);
end zz_hint_pkg;
/
create or replace package body zz_hint_pkg
as
  procedure run_all(p_parent_id in number)
  is
    l_cnt number;
  begin
    select /*+ full(c) */ count(*) into l_cnt from zz_hint_child c where c.parent_id = p_parent_id;
    for r in (select /*+ index(c (status created_on)) */ c.id from zz_hint_child c where c.status = 'OPEN' and rownum <= 5) loop
      null;
    end loop;
    execute immediate 'select /*+ full(c) */ count(*) from zz_hint_child c where c.parent_id = :b1 and 1 = 1'
       into l_cnt using p_parent_id;
  end run_all;
end zz_hint_pkg;
/
exec zz_hint_pkg.run_all(5)
prompt ###### 3a  static select into             expect: text normalized, hint kept + used
select t.plan_table_output
  from (select sql_id, child_number from v$sql
         where parsing_schema_name = user and sql_text like 'SELECT /*+ full(c) */ COUNT(*) FROM ZZ_HINT_CHILD C WHERE C.PARENT_ID = :B1%'
           and sql_text not like '%v$sql%'
         order by last_active_time desc fetch first 1 row only) s
     , table(dbms_xplan.display_cursor(s.sql_id, s.child_number, 'BASIC +HINT_REPORT')) t;
prompt ###### 3b  cursor for loop              expect: hint kept + used
select t.plan_table_output
  from (select sql_id, child_number from v$sql
         where parsing_schema_name = user and sql_text like 'SELECT /*+ index(c (status created_on)) */%'
           and sql_text not like '%v$sql%'
         order by last_active_time desc fetch first 1 row only) s
     , table(dbms_xplan.display_cursor(s.sql_id, s.child_number, 'BASIC +HINT_REPORT')) t;
prompt ###### 3c  execute immediate            expect: text verbatim, hint used
select t.plan_table_output
  from (select sql_id, child_number from v$sql
         where parsing_schema_name = user and sql_text like 'select /*+ full(c) */ count(*) from zz_hint_child c where c.parent_id = :b1 and 1 = 1%'
           and sql_text not like '%v$sql%'
         order by last_active_time desc fetch first 1 row only) s
     , table(dbms_xplan.display_cursor(s.sql_id, s.child_number, 'BASIC +HINT_REPORT')) t;
-- -----------------------------------------------------------------------------
-- 4. Direct path (APPEND / APPEND_VALUES) — check LOAD AS SELECT vs CONVENTIONAL
-- -----------------------------------------------------------------------------
prompt ###### 4a  append, plain table            expect: LOAD AS SELECT
insert /*+ append */ into zz_hint_load select level, 'a' from dual connect by level <= 1000;
select t.plan_table_output
  from (select sql_id, child_number from v$sql
         where parsing_schema_name = user and sql_text like 'insert /*+ append */ into zz_hint_load select%'
           and sql_text not like '%v$sql%'
         order by last_active_time desc fetch first 1 row only) s
     , table(dbms_xplan.display_cursor(s.sql_id, s.child_number, 'BASIC +HINT_REPORT +NOTE')) t;
prompt ###### 4b  same-transaction read after direct path   expect: ORA-12838 on 19c; works on 23ai/26ai (ASSM heap)
select 'same-txn count = ' || count(*) from zz_hint_load;
commit;
prompt ###### 4c  append, table with trigger     expect: LOAD TABLE CONVENTIONAL
insert /*+ append */ into zz_hint_load_trg (id, val) select level, 'a' from dual connect by level <= 1000;
select t.plan_table_output
  from (select sql_id, child_number from v$sql
         where parsing_schema_name = user and sql_text like 'insert /*+ append */ into zz_hint_load_trg%'
           and sql_text not like '%v$sql%'
         order by last_active_time desc fetch first 1 row only) s
     , table(dbms_xplan.display_cursor(s.sql_id, s.child_number, 'BASIC +HINT_REPORT +NOTE')) t;
commit;
prompt ###### 4d  append, table with FK          expect: LOAD TABLE CONVENTIONAL
insert /*+ append */ into zz_hint_load_fk select level, mod(level, 1000) + 1 from dual connect by level <= 1000;
select t.plan_table_output
  from (select sql_id, child_number from v$sql
         where parsing_schema_name = user and sql_text like 'insert /*+ append */ into zz_hint_load_fk%'
           and sql_text not like '%v$sql%'
         order by last_active_time desc fetch first 1 row only) s
     , table(dbms_xplan.display_cursor(s.sql_id, s.child_number, 'BASIC +HINT_REPORT +NOTE')) t;
commit;
prompt ###### 4e  append with values             expect: LOAD TABLE CONVENTIONAL
insert /*+ append */ into zz_hint_load values (1, 'values');
select t.plan_table_output
  from (select sql_id, child_number from v$sql
         where parsing_schema_name = user and sql_text like 'insert /*+ append */ into zz_hint_load values%'
           and sql_text not like '%v$sql%'
         order by last_active_time desc fetch first 1 row only) s
     , table(dbms_xplan.display_cursor(s.sql_id, s.child_number, 'BASIC +HINT_REPORT +NOTE')) t;
commit;
prompt ###### 4f  forall + append_values         expect: LOAD AS SELECT
declare
  type t_ids is table of number index by pls_integer;
  l_ids t_ids;
begin
  for i in 1 .. 500 loop
    l_ids(i) := i;
  end loop;
  forall i in 1 .. l_ids.count
    insert /*+ append_values */ into zz_hint_load (id, val) values (l_ids(i), 'forall');
end;
/
select t.plan_table_output
  from (select sql_id, child_number from v$sql
         where parsing_schema_name = user and sql_text like 'INSERT /*+ append_values */ INTO ZZ_HINT_LOAD%'
           and sql_text not like '%v$sql%'
         order by last_active_time desc fetch first 1 row only) s
     , table(dbms_xplan.display_cursor(s.sql_id, s.child_number, 'BASIC +HINT_REPORT +NOTE')) t;
commit;
-- -----------------------------------------------------------------------------
-- 5. What survives optimizer_ignore_hints = true
-- -----------------------------------------------------------------------------
alter session set optimizer_ignore_hints = true;
prompt ###### 5a  index hint                     expect: U rejected by IGNORE_OPTIM_EMBEDDED_HINTS
select /*+ index(c zz_hint_child_ix2) */ count(*) from zz_hint_child c where c.parent_id = 6;
select t.plan_table_output
  from (select sql_id, child_number from v$sql
         where parsing_schema_name = user and sql_text like 'select /*+ index(c zz_hint_child_ix2) */ count(*) from zz_hint_child c where c.parent_id = 6%'
           and sql_text not like '%v$sql%'
         order by last_active_time desc fetch first 1 row only) s
     , table(dbms_xplan.display_cursor(s.sql_id, s.child_number, 'BASIC +HINT_REPORT +NOTE')) t;
prompt ###### 5b  append                         expect: still LOAD AS SELECT
insert /*+ append */ into zz_hint_load select level * 10, 'b' from dual connect by level <= 10;
select t.plan_table_output
  from (select sql_id, child_number from v$sql
         where parsing_schema_name = user and sql_text like 'insert /*+ append */ into zz_hint_load select level * 10%'
           and sql_text not like '%v$sql%'
         order by last_active_time desc fetch first 1 row only) s
     , table(dbms_xplan.display_cursor(s.sql_id, s.child_number, 'BASIC +HINT_REPORT +NOTE')) t;
commit;
prompt ###### 5c  result_cache                   expect: still RESULT CACHE line
select /*+ result_cache */ count(*) from zz_hint_parent p where p.region = 'NORTH';
select t.plan_table_output
  from (select sql_id, child_number from v$sql
         where parsing_schema_name = user and sql_text like 'select /*+ result_cache */ count(*) from zz_hint_parent p where p.region =%'
           and sql_text not like '%v$sql%'
         order by last_active_time desc fetch first 1 row only) s
     , table(dbms_xplan.display_cursor(s.sql_id, s.child_number, 'BASIC +HINT_REPORT +NOTE')) t;
alter session set optimizer_ignore_hints = false;
-- -----------------------------------------------------------------------------
-- 6. WITH_PLSQL and views
-- -----------------------------------------------------------------------------
prompt ###### 6a/6b with function in a subquery   expect: ORA-32034 without the hint once the function is really used; ok with /*+ with_plsql */
declare
  l_cnt number;
  procedure try(p_label in varchar2, p_sql in varchar2) is
  begin
    execute immediate p_sql into l_cnt;
    dbms_output.put_line(p_label || ': ok, result = ' || l_cnt);
  exception
    when others then
      dbms_output.put_line(p_label || ': ' || sqlerrm);
  end;
begin
  try('6a no hint, function used  ', 'select max(d) from (with function zz_dbl(p in number) return number is begin return p * 2; end; '
                 || 'select zz_dbl(p.id) as d from zz_hint_parent p where p.id <= 2)');
  try('6b with_plsql, function used', 'select /*+ with_plsql */ max(d) from (with function zz_dbl(p in number) return number is begin return p * 2; end; '
                 || 'select zz_dbl(p.id) as d from zz_hint_parent p where p.id <= 2)');
  -- trap: when the outer query doesn't need the function column (count(*)), it is pruned and no error is raised
  try('6c no hint, function pruned', 'select count(*) from (with function zz_dbl(p in number) return number is begin return p * 2; end; '
                 || 'select zz_dbl(p.id) as d from zz_hint_parent p where p.id <= 2)');
end;
/
create or replace view zz_hint_v as
select /*+ full(c) */ c.id, c.parent_id from zz_hint_child c where c.amount >= 0;
prompt ###### 6d  hint inside view, view alone            expect: used
explain plan for select count(*) from zz_hint_v v where v.parent_id = 5;
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
prompt ###### 6e  same view joined to another table       expect: U discarded during view merging
explain plan for select count(*) from zz_hint_v v join zz_hint_parent p on p.id = v.parent_id where p.id = 5;
select * from table(dbms_xplan.display(format => 'BASIC +HINT_REPORT'));
-- -----------------------------------------------------------------------------
-- Cleanup
-- -----------------------------------------------------------------------------
drop package zz_hint_pkg;
drop view zz_hint_v;
begin
  for t in (select table_name from user_tables where table_name like 'ZZ\_HINT\_%' escape '\'
             order by case when table_name = 'ZZ_HINT_PARENT' then 2 else 1 end) loop
    execute immediate 'drop table ' || t.table_name || ' cascade constraints purge';
  end loop;
end;
/
select 'zz_hint objects left: ' || count(*) from user_objects where object_name like 'ZZ\_HINT%' escape '\';
