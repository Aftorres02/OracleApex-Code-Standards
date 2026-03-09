# Tech Lead Documentation

This guide contains administrative instructions and provisioning scripts typically executed by Technical Leads to spin up environments or initialize architectural foundations.

## 1. Environment Provisioning

When setting up a new Oracle APEX project or a new deployment environment (Dev/Test), a dedicated database schema and an associated APEX workspace must be provisioned.

### 1.1 Schema Creation Script

```sql
-- 1. Create the schema and specify a secure password
create user my_project_schema identified by "YourStrongPassword123#";

-- or
alter user my_project_schema identified by "YourStrongPassword123#";

-- 2. Grant basic connection and resource privileges
grant connect, resource to my_project_schema;

-- 3. Provide tablespace quota (adjust tablespace name 'users' as needed for your DB)
alter user my_project_schema quota unlimited on users;

-- 4. (Optional) Grant specific explicit privileges if the RESOURCE role lacks them in your environment
grant create view, create procedure, create sequence, create trigger, create type, create synonym to my_project_schema;
```

### 1.2 APEX Workspace Creation
