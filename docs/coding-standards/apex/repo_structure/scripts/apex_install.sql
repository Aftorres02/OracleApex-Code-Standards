-- =============================================================================
-- APEX Application Install
-- =============================================================================
-- Installs APEX application 100 into the target schema and workspace.
-- Run this script from SQLcl inside the repo root.
--
-- Usage:
--   @scripts/apex_install.sql
-- =============================================================================

set serveroutput on size unlimited;
set define off;

-- -----------------------------------------------------------------------------
-- Configure the install target
-- -----------------------------------------------------------------------------
begin
  apex_application_install.set_application_id(100);
  apex_application_install.set_schema('MY_SCHEMA');
  apex_application_install.set_workspace('MY_WORKSPACE');
end;
/

-- Run the exported application file
@../apex/f100.sql