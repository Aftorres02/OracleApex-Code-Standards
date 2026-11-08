-- Implements: .claude/rules/plsql-standards.md (package structure, documentation tags)
create or replace package prefix_<module>_api
as
-- =============================================================================
-- Package: prefix_<module>_api
-- Purpose: <Short description of the package.>
--
-- =============================================================================


  -- Spec comments are short (what it does, @return for functions). The full
  -- JavaDoc block (@example, @issue, @author, ...) lives in the package body.

  /** <One-sentence description of what the procedure does.> */
  procedure create_<entity>(
      p_<column_1>                              in prefix_<table_name>.<column_1>%type
    , o_error_message                           out varchar2
  );


  /**
   * <One-sentence description of what the function returns.>
   *
   * @return <What the returned value is.>
   */
  function get_<entity>_name(
      p_<entity>_id                             in prefix_<table_name>.<table_name>_id%type
  )
  return varchar2;


  /** <One-sentence description of the AJAX callback.> */
  procedure <action>_<entity>_ajax;


end prefix_<module>_api;
/
