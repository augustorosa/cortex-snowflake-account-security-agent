-- ============================================================================
-- 00_foundation/01_lab_foundations.sql
-- Account settings, cortex_role, COWORK database, schemas,
-- warehouse. Safe to re-run. Run as ACCOUNTADMIN:
--   snow sql -c <connection> -f scripts/00_foundation/01_lab_foundations.sql
-- ============================================================================
USE ROLE ACCOUNTADMIN;
-- to get access to all the models to use
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION' ;
-- enable cortex analyst
ALTER ACCOUNT SET ENABLE_CORTEX_ANALYST = TRUE;

-- CREATE SAMPLE DATABASE is not needed but needed if you want to do extra testing
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_SAMPLE_DATA FROM SHARE SFC_SAMPLES.SAMPLE_DATA;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA TO ROLE PUBLIC;


-- YOUR CUSTOM ROLE FOR CORTEX ADMIN
SET role_name='cortex_role';
SET warehouse_name = 'cortex_wh';
SET current_user=CURRENT_USER();


CREATE ROLE IF NOT EXISTS IDENTIFIER($role_name);
GRANT ROLE IDENTIFIER($role_name) TO ROLE ACCOUNTADMIN;
GRANT ROLE IDENTIFIER($role_name) TO USER IDENTIFIER($current_user);

GRANT CREATE DATABASE ON ACCOUNT TO ROLE IDENTIFIER($role_name);
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE IDENTIFIER($role_name);
GRANT CREATE ROLE ON ACCOUNT TO ROLE IDENTIFIER($role_name);
GRANT MANAGE GRANTS ON ACCOUNT TO ROLE IDENTIFIER($role_name);
GRANT CREATE INTEGRATION ON ACCOUNT TO ROLE IDENTIFIER($role_name);
GRANT CREATE APPLICATION PACKAGE ON ACCOUNT TO ROLE IDENTIFIER($role_name);
GRANT CREATE APPLICATION ON ACCOUNT TO ROLE IDENTIFIER($role_name);
GRANT IMPORT SHARE ON ACCOUNT TO ROLE IDENTIFIER($role_name);


-- control who you want to use cortex
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE PUBLIC;


-- show models
SHOW MODELS IN SCHEMA SNOWFLAKE.MODELS;

-- to refresh all modesl use it , it will take few minutes to refresh
CALL SNOWFLAKE.MODELS.CORTEX_BASE_MODELS_REFRESH();

-- if you do not see all the model run above command to do modelrefresh
SHOW APPLICATION ROLES LIKE '%model%' IN APPLICATION SNOWFLAKE;
-- control which model to  use by whom, using following as example
GRANT APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-ALL" TO ROLE IDENTIFIER($role_name);


-- Create database and schemas as ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;

-- Lab database for Snowflake CoWork agents and tools. Agents can live in any
-- database; they appear in CoWork once added to the CoWork account object
-- (see scripts/90_cowork/01_register_cowork_agents.sql).
CREATE DATABASE IF NOT EXISTS COWORK;
--for agents used by Snowflake CoWork
CREATE SCHEMA IF NOT EXISTS COWORK.AGENTS;
-- for tools used by agents
CREATE SCHEMA IF NOT EXISTS COWORK.TOOLS;
-- IT Operations + Security demo module (scripts/30_itops_demo)
CREATE SCHEMA IF NOT EXISTS COWORK.IT_OPS;

-- Grant database ownership and privileges to cortex_role
-- Using REVOKE CURRENT GRANTS to handle any existing grants from previous runs
GRANT OWNERSHIP ON DATABASE COWORK TO ROLE IDENTIFIER($role_name) REVOKE CURRENT GRANTS;
GRANT ALL PRIVILEGES ON SCHEMA COWORK.AGENTS TO ROLE IDENTIFIER($role_name);
GRANT ALL PRIVILEGES ON SCHEMA COWORK.TOOLS TO ROLE IDENTIFIER($role_name);
GRANT ALL PRIVILEGES ON SCHEMA COWORK.IT_OPS TO ROLE IDENTIFIER($role_name);

-- Grant access to ACCOUNT_USAGE for semantic views
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE IDENTIFIER($role_name);

-- OPTIONAL: AWS Security Lake CloudTrail logs (only needed for
-- 10_account_monitoring/02_flattened_cloudtrail_logs_views.sql).
-- Uncomment if your account has ARCHETYPE.SECURITY_DL.CLOUDTRAIL_LOGS.
-- GRANT USAGE ON DATABASE ARCHETYPE TO ROLE IDENTIFIER($role_name);
-- GRANT USAGE ON SCHEMA ARCHETYPE.SECURITY_DL TO ROLE IDENTIFIER($role_name);
-- GRANT SELECT ON TABLE ARCHETYPE.SECURITY_DL.CLOUDTRAIL_LOGS TO ROLE IDENTIFIER($role_name);

-- Allow anyone to see and use the agents and semantic views
-- Please note that we are granting access to the public role, so all users can access
GRANT USAGE ON DATABASE COWORK TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA COWORK.AGENTS TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA COWORK.TOOLS TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA COWORK.IT_OPS TO ROLE PUBLIC;

-- Grant SELECT on future semantic views in TOOLS schema (so PUBLIC can query them)
GRANT SELECT ON ALL SEMANTIC VIEWS IN SCHEMA COWORK.TOOLS TO ROLE PUBLIC;
GRANT SELECT ON FUTURE SEMANTIC VIEWS IN SCHEMA COWORK.TOOLS TO ROLE PUBLIC;

-- Grant USAGE on future agents in AGENTS schema (so PUBLIC can use them)
GRANT USAGE ON ALL AGENTS IN SCHEMA COWORK.AGENTS TO ROLE PUBLIC;
GRANT USAGE ON FUTURE AGENTS IN SCHEMA COWORK.AGENTS TO ROLE PUBLIC;

-- Now switch to cortex_role for remaining setup
USE ROLE IDENTIFIER($role_name);

CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER($warehouse_name)
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

ALTER USER IDENTIFIER($CURRENT_USER) SET
    DEFAULT_ROLE = cortex_role, 
    DEFAULT_WAREHOUSE = cortex_wh;

