-- =============================================================================
-- FIND REAL EXECUTION PLAN — via V$SQL_MONITOR, not EXPLAIN PLAN FOR
-- =============================================================================
-- Run the real operation first (e.g. exec dbms_mview.refresh('MY_MV')),
-- then run this script with a substring of the target object's name as &1.
-- It finds the SQL_ID/CHILD_NUMBER of the matching long-running statement
-- (V$SQL_MONITOR auto-tracks anything running longer than ~5s) and displays
-- its real plan with real predicates — not a hypothetical re-parse.
--
-- Usage: @find_real_plan.sql MY_TARGET_OBJECT
-- =============================================================================

set linesize 200 pagesize 100
set verify off

prompt ==== Recent candidates touching &1 (most recent first) ====

select sql_id
     , sql_exec_id
     , to_char(sql_exec_start, 'YYYY-MM-DD HH24:MI:SS') as sql_exec_start
     , round(elapsed_time / 1000000, 3)                 as elapsed_seconds
     , status
     , substr(sql_text, 1, 120)                         as sql_text_preview
  from v$sql_monitor
 where upper(sql_text) like '%' || upper('&1') || '%'
 order by sql_exec_start desc
 fetch first 10 rows only;

prompt ==== Paste the SQL_ID from above below, plus CHILD_NUMBER (0 if it doesn't show up in v$sql) ====

column sql_id       new_value v_sql_id
column child_number new_value v_child_number

select sql_id, child_number
  from v$sql
 where sql_id = '&sql_id_to_use'
 order by child_number
 fetch first 1 rows only;

prompt ==== Real plan (predicates included) ====

select *
  from table(
    dbms_xplan.display_cursor(
        sql_id          => '&sql_id_to_use'
      , cursor_child_no => nvl('&v_child_number', 0)
      , format          => 'ALLSTATS LAST +COST +PREDICATE'
    )
  );
