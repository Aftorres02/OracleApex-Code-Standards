-- =============================================================================
-- View:    tf_<view_name>_vw
-- Purpose: <Short description of the view.>
--
-- @author  <Author Name> (<Role>)
-- @created <Month DD, YYYY>
-- @ticket  <TICKET-NUMBER>
-- =============================================================================
create or replace view tf_<view_name>_vw
as
with w_base as (
  select t.<table_name>_id          as <table_name>_id
       , t.<column_1>               as <column_1>
       , t.<column_2>               as <column_2>
       , r.<ref_column>             as <ref_column>
    from tf_<table_name>             t
    left join tf_<ref_table>         r on r.<ref_table>_id = t.<ref_table>_id
                                      and r.active_yn = 'Y'
   where t.active_yn = 'Y'
)
select <table_name>_id
     , <column_1>
     , <column_2>
     , <ref_column>
  from w_base;
