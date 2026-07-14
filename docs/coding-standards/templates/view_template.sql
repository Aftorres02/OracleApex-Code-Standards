-- Implements: .claude/rules/sql-format.md (views and WITH clause)
-- =============================================================================
-- View:    prefix_<view_name>_vw
-- Purpose: <Short description of the view.>
--
-- @author  <Author Name> (<Role>)
-- @created <Month DD, YYYY>
-- @ticket  <TICKET-NUMBER>
-- =============================================================================
create or replace view prefix_<view_name>_vw
as
with w_base as (
  select t.<table_name>_id          as <table_name>_id
       , t.<column_1>               as <column_1>
       , t.<column_2>               as <column_2>
       , r.<ref_column>             as <ref_column>
    from prefix_<table_name>             t
   left join prefix_<ref_table>          r on r.<ref_table>_id = t.<ref_table>_id
                                           and r.active_yn = 'Y'
   where t.active_yn = 'Y'
)
select w.<table_name>_id            as <table_name>_id
     , w.<column_1>                 as <column_1>
     , w.<column_2>                 as <column_2>
     , w.<ref_column>               as <ref_column>
  from w_base w;
