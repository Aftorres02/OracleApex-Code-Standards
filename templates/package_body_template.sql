-- Implements: .claude/rules/plsql-standards.md (package body spacing, parameter alignment, logging, doc tags)
create or replace package body prefix_<module>_api
as

  gc_scope_prefix constant varchar2(31) := lower($$plsql_unit) || '.';








  -- ===========================================================================
  -- PROCEDURE: create_<entity>
  -- ===========================================================================
  /**
   * <Short description of procedure.>
   *
   * @example
   * set serveroutput on
   * declare
   *   l_error_message varchar2(4000 char);
   * begin
   *   prefix_<module>_api.create_<entity>(
   *     p_<column_1>                           => 'Value'
   *   , o_error_message                        => l_error_message
   *   );
   *   dbms_output.put_line('o_error_message=' || l_error_message);
   * end;
   * /
   *
   * @issue   TF-101
   * @issue   TF-118 Added validation for duplicate names
   *
   * @author  <Author Name> (<Role>)
   * @created <Month DD, YYYY>
   *
   * @param p_<column_1>    Description of input
   * @param o_error_message Output error message
   */
  procedure create_<entity>(
      p_<column_1>                              in prefix_<table_name>.<column_1>%type
    , o_error_message                           out varchar2
  )
  is
    l_scope  logger_logs.scope%type := gc_scope_prefix || 'create_<entity>';
    l_params logger.tab_param;
  begin
    logger.append_param(l_params, 'p_<column_1>', p_<column_1>);
    logger.log('START', l_scope, null, l_params);

    insert
      into prefix_<table_name> (
           <column_1>
    )
    values (
           p_<column_1>
    );

    logger.log('END', l_scope, null, l_params);
  exception
    when others then
      logger.log_error('Unhandled Exception', l_scope, null, l_params);
      raise;
  end create_<entity>;








  -- ===========================================================================
  -- FUNCTION: get_<entity>_name
  -- ===========================================================================
  /**
   * <Short description of function.>
   *
   * @example
   * l_result := prefix_<module>_api.get_<entity>_name(
   *     p_<entity>_id => 1
   * );
   *
   * @issue   TF-95
   *
   * @author  <Author Name> (<Role>)
   * @created <Month DD, YYYY>
   *
   * @param  p_<entity>_id  The identifier of the entity
   * @return varchar2       The name of the entity
   */
  function get_<entity>_name(
      p_<entity>_id                             in prefix_<table_name>.<table_name>_id%type
  )
  return varchar2
  is
    l_scope        logger_logs.scope%type := gc_scope_prefix || 'get_<entity>_name';
    l_params       logger.tab_param;
    l_return_value prefix_<table_name>.<column_1>%type;
  begin
    logger.append_param(l_params, 'p_<entity>_id', p_<entity>_id);
    logger.log('START', l_scope, null, l_params);

    select <column_1>
      into l_return_value
      from prefix_<table_name>
     where <table_name>_id = p_<entity>_id
       and active_yn = 'Y';

    logger.append_param(l_params, 'l_return_value', l_return_value);
    logger.log('END', l_scope, null, l_params);

    return l_return_value;
  exception
    when others then
      logger.log_error('Unhandled Exception', l_scope, null, l_params);
      raise;
  end get_<entity>_name;








  -- ===========================================================================
  -- AJAX PROCEDURE: <action>_<entity>_ajax
  -- ===========================================================================
  /**
   * <Short description of AJAX procedure.>
   *
   * @example
   * prefix_<module>_api.<action>_<entity>_ajax;
   *
   * @issue   TF-130
   *
   * @author  <Author Name> (<Role>)
   * @created <Month DD, YYYY>
   *
   * @input g_x01 <entity>_id (via apex_application)
   * @input g_x02 <column> (via apex_application)
   */
  procedure <action>_<entity>_ajax
  is
    l_scope       logger_logs.scope%type := gc_scope_prefix || '<action>_<entity>_ajax';
    l_params      logger.tab_param;

    l_<entity>_id prefix_<table_name>.<table_name>_id%type := apex_application.g_x01;
    l_<column_1>  prefix_<table_name>.<column_1>%type      := apex_application.g_x02;
  begin
    logger.append_param(l_params, 'l_<entity>_id', l_<entity>_id);
    logger.append_param(l_params, 'l_<column_1>', l_<column_1>);
    logger.log('START', l_scope, null, l_params);

    update prefix_<table_name>
       set <column_1> = l_<column_1>
     where <table_name>_id = l_<entity>_id;

    apex_json.open_object;
    apex_json.write('success', true);
    apex_json.close_object;

    logger.log('END', l_scope, null, l_params);
  exception
    when others then
      logger.log_error('Unhandled Exception', l_scope, null, l_params);

      apex_json.open_object;
      apex_json.write('success', false);
      apex_json.write('message', sqlerrm);
      apex_json.close_object;
  end <action>_<entity>_ajax;


end prefix_<module>_api;
/
