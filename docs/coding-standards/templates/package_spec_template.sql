create or replace package tf_<module>_api
as
-- =============================================================================
-- Package: tf_<module>_api
-- Purpose: <Short description of the package.>
--
-- =============================================================================


  procedure create_<entity>(
      p_<column_1>                              in tf_<table_name>.<column_1>%type
    , o_error_message                           out varchar2
  );


  function get_<entity>_name(
      p_<entity>_id                             in tf_<table_name>.<table_name>_id%type
  )
  return varchar2;


  procedure <action>_<entity>_ajax;


end tf_<module>_api;
/
