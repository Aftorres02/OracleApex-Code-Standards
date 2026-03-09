--
define env_schema_name=
define env_apex_app_ids=
define env_apex_workspace=


prompt ENV variables
select 
  '&env_schema_name.' env_schema_name,
  '&env_apex_app_ids.' env_apex_app_ids,
  '&env_apex_workspace.' env_apex_workspace
from dual;


