-- Implements: .claude/rules/ddl-conventions.md (trigger patterns / audit automation)
-- =============================================================================
-- Trigger: prefix_<table_name>_compound_trg
-- Purpose: Automatically maintains audit columns (last_updated_by,
--          last_updated_on) on every update to prefix_<table_name>.
--
-- @author  <Author Name> (<Role>)
-- @created <Month DD, YYYY>
-- @ticket  <TICKET-NUMBER>
-- =============================================================================
create or replace trigger prefix_<table_name>_compound_trg
for insert or update on prefix_<table_name>
compound trigger

  before each row is
  begin
    if updating then
      :new.last_updated_on := localtimestamp;
      :new.last_updated_by := coalesce(
                                sys_context('APEX$SESSION','app_user')
                              , regexp_substr(sys_context('userenv','client_identifier'),'^[^:]*')
                              , sys_context('userenv','session_user')
                              );
    end if;
  end before each row;

end prefix_<table_name>_compound_trg;
/
