-- Implements: .claude/rules/plsql-standards.md (package structure, documentation tags)
create or replace package prefix_<module>_api
as
-- =============================================================================
-- Package: prefix_<module>_api
-- Purpose: <Short description of the package.>
--
-- =============================================================================


  procedure create_<entity>(
      p_<column_1>                              in prefix_<table_name>.<column_1>%type
    , o_error_message                           out varchar2
  );


  function get_<entity>_name(
      p_<entity>_id                             in prefix_<table_name>.<table_name>_id%type
  )
  return varchar2;


  procedure <action>_<entity>_ajax;


end prefix_<module>_api;
/
