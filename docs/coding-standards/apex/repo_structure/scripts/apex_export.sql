-- =============================================================================
-- APEX Application Export
-- =============================================================================
-- Exports APEX application 100 into the /apex folder.
-- Run this script from SQLcl inside the repo root.
--
-- Usage:
--   @scripts/apex_export.sql              -- single-file export  → apex/f100.sql
--   apex export -applicationid 100 -dir apex -split  -- split files export
-- =============================================================================

set serveroutput on;

begin
  dbms_output.put_line('Exporting App ID: 100');
  dbms_output.put_line('Target directory: apex/');
end;
/

-- -----------------------------------------------------------------------------
-- Export the application (single file)
-- -----------------------------------------------------------------------------
apex export -applicationid 100 -dir apex
