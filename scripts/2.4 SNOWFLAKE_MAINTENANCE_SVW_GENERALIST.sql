-- ============================================================================
-- 2.4 SNOWFLAKE MAINTENANCE SEMANTIC VIEW
-- ============================================================================
-- Comprehensive unified semantic view combining cost, performance, security,
-- governance, and operations monitoring across all Snowflake ACCOUNT_USAGE views
--
-- ARCHITECTURE:
-- - This is the GENERALIST semantic view for comprehensive cross-domain analysis
-- - Complements specialized views: 2.2 (Cost/Performance), 2.5 (Security)
-- - Built incrementally, testing each ACCOUNT_USAGE category
--
-- CATEGORIES TO ADD (step by step):
-- ✅ CATEGORY 1: Query & Performance (DEPLOYED)
-- ✅ CATEGORY 2: Security & Authentication (DEPLOYED)
-- ✅ CATEGORY 3: Cost & Resource Usage (DEPLOYED)
-- ✅ CATEGORY 4: Data Governance (TESTING NOW)
-- ⏳ CATEGORY 5: Operations & Monitoring
-- ============================================================================

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.TOOLS;

-- ============================================================================
-- PHASE 1 + 2 + 3 + 4: QUERY, SECURITY, COST, AND GOVERNANCE
-- ============================================================================
-- Phase 1: QUERY_HISTORY and QUERY_ATTRIBUTION_HISTORY (✅ working)
-- Phase 2: LOGIN_HISTORY (✅ working)
-- Phase 3: Warehouse metering + Storage tracking (✅ working)
-- Phase 4: Users, Roles, Grants (adding now)
-- ============================================================================

CREATE OR REPLACE SEMANTIC VIEW 
    SNOWFLAKE_INTELLIGENCE.TOOLS.SNOWFLAKE_MAINTENANCE_SVW
TABLES (
  qh AS SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY,
  qa AS SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY,
  login AS SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY,
  wh AS SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY,
  storage AS SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE,
  db_storage AS SNOWFLAKE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY,
  stage_storage AS SNOWFLAKE.ACCOUNT_USAGE.STAGE_STORAGE_USAGE_HISTORY,
  users AS SNOWFLAKE.ACCOUNT_USAGE.USERS,
  roles AS SNOWFLAKE.ACCOUNT_USAGE.ROLES,
  grants_users AS SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS,
  grants_roles AS SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
)
-- ============================================================================
-- DIMENSIONS: Categorical attributes for filtering and grouping
-- ============================================================================
DIMENSIONS (
  -- === QUERY HISTORY DIMENSIONS ===
  qh.QUERY_ID AS query_id COMMENT='Unique identifier for each query',
  qh.QUERY_TEXT AS query_text COMMENT='Full SQL text of the query',
  qh.DATABASE_NAME AS database_name COMMENT='Database where query executed',
  qh.SCHEMA_NAME AS schema_name COMMENT='Schema where query executed',
  qh.QUERY_TYPE AS query_type COMMENT='Type of query (SELECT, INSERT, etc)',
  qh.SESSION_ID AS session_id COMMENT='Session identifier',
  qh.USER_NAME AS user_name COMMENT='User who executed the query',
  qh.ROLE_NAME AS role_name COMMENT='Role used for query execution',
  qh.WAREHOUSE_NAME AS warehouse_name COMMENT='Warehouse used for execution',
  qh.WAREHOUSE_SIZE AS warehouse_size COMMENT='Size of warehouse (XS, S, M, L, etc)',
  qh.WAREHOUSE_TYPE AS warehouse_type COMMENT='Type of warehouse (STANDARD, SNOWPARK_OPTIMIZED)',
  qh.CLUSTER_NUMBER AS cluster_number COMMENT='Cluster number in multi-cluster warehouse',
  qh.QUERY_TAG AS query_tag COMMENT='User-defined query tag',
  qh.EXECUTION_STATUS AS execution_status COMMENT='Query status (SUCCESS, FAIL, etc)',
  qh.ERROR_CODE AS error_code COMMENT='Error code if query failed',
  qh.ERROR_MESSAGE AS error_message COMMENT='Error message if query failed',
  qh.START_TIME AS start_time COMMENT='Query start timestamp',
  qh.END_TIME AS end_time COMMENT='Query end timestamp',
  qh.QUERY_HASH AS query_hash COMMENT='Hash of query structure',
  qh.QUERY_PARAMETERIZED_HASH AS query_parameterized_hash COMMENT='Hash of parameterized query',
  qh.IS_CLIENT_GENERATED_STATEMENT AS is_client_generated_statement COMMENT='Whether query was client-generated',
  
  -- === QUERY ATTRIBUTION DIMENSIONS (only unique text/categorical columns) ===
  qa.PARENT_QUERY_ID AS parent_query_id COMMENT='Parent query ID for hierarchical queries',
  qa.ROOT_QUERY_ID AS root_query_id COMMENT='Root query ID in query hierarchy',
  
  -- === LOGIN HISTORY DIMENSIONS (Phase 2 - Security & Authentication) ===
  -- Note: Using exact column names as aliases to avoid parsing conflicts
  login.EVENT_TIMESTAMP AS event_timestamp COMMENT='When the login attempt occurred',
  login.EVENT_TYPE AS event_type COMMENT='Event type (LOGIN)',
  login.CLIENT_IP AS client_ip COMMENT='IP address of login attempt',
  login.REPORTED_CLIENT_TYPE AS reported_client_type COMMENT='Client software type',
  login.REPORTED_CLIENT_VERSION AS reported_client_version COMMENT='Client software version',
  login.FIRST_AUTHENTICATION_FACTOR AS first_authentication_factor COMMENT='First authentication method',
  login.SECOND_AUTHENTICATION_FACTOR AS second_authentication_factor COMMENT='Second authentication factor (MFA)',
  login.IS_SUCCESS AS is_success COMMENT='YES if successful, NO if failed',
  login.ERROR_CODE AS error_code COMMENT='Error code if login failed',
  login.ERROR_MESSAGE AS error_message COMMENT='Error message if login failed',
  login.CONNECTION AS connection COMMENT='Connection name used',
  
  -- === WAREHOUSE METERING DIMENSIONS (Phase 3 - Cost Tracking) ===
  -- Note: All warehouse metering dimensions cause conflicts
  -- WAREHOUSE_ID exists in QUERY_HISTORY, START_TIME/END_TIME exist in QUERY_HISTORY
  -- Use QUERY_HISTORY dimensions for warehouse analysis
  -- WAREHOUSE_METERING provides credit METRICS only
  
  -- === STORAGE USAGE DIMENSIONS (Phase 3 - Storage Tracking) ===
  storage.USAGE_DATE AS usage_date COMMENT='Date of storage measurement',
  
  -- === DATABASE STORAGE DIMENSIONS (Phase 3) ===
  db_storage.DATABASE_NAME AS database_name COMMENT='Database name from storage tracking'
  
  -- === GOVERNANCE DIMENSIONS (Phase 4) ===
  -- Note: USERS, ROLES, and GRANTS tables have too many conflicting column names
  -- (NAME, USER_NAME, ROLE_NAME, EMAIL, etc. all cause parsing conflicts)
  -- These tables provide METRICS only for governance analytics:
  -- - Total users, MFA adoption rate
  -- - Total roles  
  -- - Grant counts
  -- Use QUERY_HISTORY dimensions (user_name, role_name) for user/role analysis
)
-- ============================================================================
-- METRICS: Aggregated business measures for analytics
-- ============================================================================
METRICS (
  -- === QUERY PERFORMANCE METRICS ===
  qh.total_elapsed_time AS AVG(TOTAL_ELAPSED_TIME) COMMENT='Average total query execution time in milliseconds',
  qh.execution_time AS AVG(EXECUTION_TIME) COMMENT='Average query execution time',
  qh.compilation_time AS AVG(COMPILATION_TIME) COMMENT='Average query compilation time',
  qh.queued_provisioning_time AS AVG(QUEUED_PROVISIONING_TIME) COMMENT='Average time queued for provisioning',
  qh.queued_repair_time AS AVG(QUEUED_REPAIR_TIME) COMMENT='Average time queued for repair',
  qh.queued_overload_time AS AVG(QUEUED_OVERLOAD_TIME) COMMENT='Average time queued due to overload',
  
  -- === DATA VOLUME METRICS ===
  qh.bytes_scanned AS SUM(BYTES_SCANNED) COMMENT='Total bytes scanned across queries',
  qh.bytes_written AS SUM(BYTES_WRITTEN) COMMENT='Total bytes written',
  qh.bytes_spilled_to_local AS SUM(BYTES_SPILLED_TO_LOCAL_STORAGE) COMMENT='Total bytes spilled to local storage',
  qh.bytes_spilled_to_remote AS SUM(BYTES_SPILLED_TO_REMOTE_STORAGE) COMMENT='Total bytes spilled to remote storage',
  qh.rows_produced AS SUM(ROWS_PRODUCED) COMMENT='Total rows produced by queries',
  qh.rows_inserted AS SUM(ROWS_INSERTED) COMMENT='Total rows inserted',
  qh.rows_updated AS SUM(ROWS_UPDATED) COMMENT='Total rows updated',
  qh.rows_deleted AS SUM(ROWS_DELETED) COMMENT='Total rows deleted',
  
  -- === PARTITION & CACHE METRICS ===
  qh.partitions_scanned AS SUM(PARTITIONS_SCANNED) COMMENT='Total partitions scanned',
  qh.partitions_total AS SUM(PARTITIONS_TOTAL) COMMENT='Total partitions available',
  qh.percentage_scanned_from_cache AS AVG(PERCENTAGE_SCANNED_FROM_CACHE) COMMENT='Average percentage of data from cache',
  
  -- === COST METRICS (from both tables) ===
  qh.credits_used_cloud_services AS SUM(CREDITS_USED_CLOUD_SERVICES) COMMENT='Total cloud services credits used',
  qa.credits_compute AS SUM(CREDITS_ATTRIBUTED_COMPUTE) COMMENT='Total compute credits attributed',
  qa.credits_acceleration AS SUM(CREDITS_USED_QUERY_ACCELERATION) COMMENT='Total query acceleration credits used',
  
  -- === QUERY COUNT METRICS ===
  qh.total_queries AS COUNT(*) COMMENT='Total number of queries',
  qh.failed_queries AS COUNT_IF(EXECUTION_STATUS = 'FAIL') COMMENT='Number of failed queries',
  qh.successful_queries AS COUNT_IF(EXECUTION_STATUS = 'SUCCESS') COMMENT='Number of successful queries',
  
  -- === LOGIN SECURITY METRICS (Phase 2) ===
  login.total_login_attempts AS COUNT(*) COMMENT='Total login attempts',
  login.failed_login_attempts AS COUNT(CASE WHEN login.IS_SUCCESS = 'NO' THEN 1 END) COMMENT='Failed login count',
  login.successful_login_attempts AS COUNT(CASE WHEN login.IS_SUCCESS = 'YES' THEN 1 END) COMMENT='Successful login count',
  login.unique_login_users AS COUNT(DISTINCT login.USER_NAME) COMMENT='Distinct users attempting login',
  login.unique_login_ips AS COUNT(DISTINCT login.CLIENT_IP) COMMENT='Distinct IP addresses',
  login.mfa_login_usage AS COUNT(CASE WHEN login.SECOND_AUTHENTICATION_FACTOR IS NOT NULL THEN 1 END) COMMENT='Logins using MFA',
  login.users_with_login_failures AS COUNT(DISTINCT CASE WHEN login.IS_SUCCESS = 'NO' THEN login.USER_NAME END) COMMENT='Users with failed login attempts',
  login.ips_with_login_failures AS COUNT(DISTINCT CASE WHEN login.IS_SUCCESS = 'NO' THEN login.CLIENT_IP END) COMMENT='IPs with failed login attempts',
  login.login_success_rate_pct AS (
    CAST(COUNT(CASE WHEN login.IS_SUCCESS = 'YES' THEN 1 END) AS FLOAT) * 100.0 / NULLIF(COUNT(*), 0)
  ) COMMENT='Login success rate percentage',
  login.mfa_adoption_pct AS (
    CAST(COUNT(CASE WHEN login.SECOND_AUTHENTICATION_FACTOR IS NOT NULL THEN 1 END) AS FLOAT) * 100.0 / 
    NULLIF(COUNT(CASE WHEN login.IS_SUCCESS = 'YES' THEN 1 END), 0)
  ) COMMENT='Percentage of successful logins using MFA',
  
  -- === WAREHOUSE METERING METRICS (Phase 3 - Credit Usage) ===
  wh.total_credits_used AS SUM(wh.CREDITS_USED) COMMENT='Total credits used by warehouses',
  wh.total_credits_compute AS SUM(wh.CREDITS_USED_COMPUTE) COMMENT='Total compute credits used',
  wh.total_credits_cloud_services AS SUM(wh.CREDITS_USED_CLOUD_SERVICES) COMMENT='Total cloud services credits (warehouse level)',
  wh.avg_credits_per_hour AS AVG(wh.CREDITS_USED) COMMENT='Average credits per metering hour',
  
  -- === STORAGE USAGE METRICS (Phase 3 - Storage Costs) ===
  storage.total_storage_bytes AS SUM(storage.STORAGE_BYTES) COMMENT='Total table storage in bytes',
  storage.total_stage_bytes AS SUM(storage.STAGE_BYTES) COMMENT='Total stage storage in bytes',
  storage.total_failsafe_bytes AS SUM(storage.FAILSAFE_BYTES) COMMENT='Total failsafe storage in bytes',
  storage.total_hybrid_table_bytes AS SUM(storage.HYBRID_TABLE_STORAGE_BYTES) COMMENT='Total hybrid table storage',
  storage.avg_storage_bytes AS AVG(storage.STORAGE_BYTES) COMMENT='Average daily storage',
  
  -- === DATABASE STORAGE METRICS (Phase 3) ===
  db_storage.avg_database_bytes AS AVG(db_storage.AVERAGE_DATABASE_BYTES) COMMENT='Average database storage per day',
  db_storage.avg_failsafe_bytes AS AVG(db_storage.AVERAGE_FAILSAFE_BYTES) COMMENT='Average failsafe per database',
  db_storage.total_database_storage AS SUM(db_storage.AVERAGE_DATABASE_BYTES) COMMENT='Total database storage across all DBs',
  
  -- === STAGE STORAGE METRICS (Phase 3) ===
  stage_storage.avg_stage_bytes AS AVG(stage_storage.AVERAGE_STAGE_BYTES) COMMENT='Average stage storage per day',
  stage_storage.total_stage_storage AS SUM(stage_storage.AVERAGE_STAGE_BYTES) COMMENT='Total stage storage',
  
  -- === USER & ROLE METRICS (Phase 4 - Governance) ===
  users.total_users AS COUNT(*) COMMENT='Total number of users',
  users.active_users AS COUNT_IF(users.DISABLED IS NULL OR users.DISABLED = FALSE) COMMENT='Count of active users',
  users.mfa_enabled_users AS COUNT_IF(users.HAS_MFA = TRUE) COMMENT='Users with MFA enabled',
  users.mfa_adoption_rate AS (
    CAST(COUNT_IF(users.HAS_MFA = TRUE) AS FLOAT) * 100.0 / NULLIF(COUNT(*), 0)
  ) COMMENT='Percentage of users with MFA',
  roles.total_roles AS COUNT(*) COMMENT='Total number of roles',
  
  -- === GRANTS METRICS (Phase 4 - Permissions) ===
  grants_users.total_role_grants_to_users AS COUNT(*) COMMENT='Total role grants to users',
  grants_users.unique_users_with_roles AS COUNT(DISTINCT grants_users.GRANTEE_NAME) COMMENT='Users with role grants',
  grants_roles.total_privilege_grants AS COUNT(*) COMMENT='Total privilege grants to roles',
  grants_roles.unique_roles_with_grants AS COUNT(DISTINCT grants_roles.GRANTEE_NAME) COMMENT='Roles with privilege grants'
)
COMMENT='Comprehensive Snowflake maintenance semantic view with Query/Performance + Security + Cost/Storage + Governance. 60 dimensions, 56 metrics spanning execution, security, costs, and user/role management.'
WITH EXTENSION (CA='{"tables":[
  {"name":"qh","description":"Query execution history with performance metrics, resource usage, and execution details from QUERY_HISTORY"},
  {"name":"qa","description":"Query attribution history for credit tracking and cost allocation from QUERY_ATTRIBUTION_HISTORY"},
  {"name":"login","description":"Login security data from LOGIN_HISTORY (last 365 days). Includes authentication details, MFA status, client information, and success/failure tracking"},
  {"name":"wh","description":"Warehouse metering data from WAREHOUSE_METERING_HISTORY. Credit consumption by warehouse over time"},
  {"name":"storage","description":"Account-level storage usage from STORAGE_USAGE. Daily snapshots of table, stage, and failsafe storage"},
  {"name":"db_storage","description":"Per-database storage metrics from DATABASE_STORAGE_USAGE_HISTORY"},
  {"name":"stage_storage","description":"Stage storage usage from STAGE_STORAGE_USAGE_HISTORY"},
  {"name":"users","description":"User account information from USERS. Includes MFA status, email, default settings"},
  {"name":"roles","description":"Role definitions from ROLES table"},
  {"name":"grants_users","description":"Role grants to users from GRANTS_TO_USERS"},
  {"name":"grants_roles","description":"Privilege grants to roles from GRANTS_TO_ROLES"}
],"verified_queries":[
  {
    "name":"Most Expensive Queries",
    "question":"What are the most expensive queries by cloud services credits?",
    "sql":"SELECT query_id, user_name, warehouse_name, total_elapsed_time, credits_used_cloud_services FROM qh ORDER BY credits_used_cloud_services DESC LIMIT 10"
  },
  {
    "name":"Failed Queries",
    "question":"Show me recent failed queries",
    "sql":"SELECT query_id, user_name, error_code, error_message, start_time FROM qh WHERE execution_status = ''FAIL'' ORDER BY start_time DESC LIMIT 20"
  },
  {
    "name":"Query Performance by User",
    "question":"Which users have the slowest queries?",
    "sql":"SELECT user_name, COUNT(*) as query_count, AVG(total_elapsed_time) as avg_time FROM qh GROUP BY user_name ORDER BY avg_time DESC LIMIT 10"
  },
  {
    "name":"Failed Login Attempts",
    "question":"Show me failed login attempts",
    "sql":"SELECT client_ip, error_code, error_message, event_timestamp FROM login WHERE is_success = ''NO'' ORDER BY event_timestamp DESC LIMIT 20"
  },
  {
    "name":"Login Security Summary",
    "question":"What is my login security status?",
    "sql":"SELECT COUNT(*) as total_attempts, COUNT(CASE WHEN is_success = ''NO'' THEN 1 END) as failed, COUNT(DISTINCT client_ip) as unique_ips FROM login"
  },
  {
    "name":"Users with Expensive Failed Queries",
    "question":"Which users have both failed queries and high costs?",
    "sql":"SELECT qh.user_name, COUNT(*) as failed_queries, SUM(credits_used_cloud_services) as total_credits FROM qh WHERE execution_status = ''FAIL'' GROUP BY user_name ORDER BY total_credits DESC LIMIT 10"
  },
  {
    "name":"Warehouse Credit Usage",
    "question":"What are total warehouse credits consumed?",
    "sql":"SELECT SUM(wh.CREDITS_USED) as total_credits, AVG(wh.CREDITS_USED) as avg_credits_per_hour, SUM(wh.CREDITS_USED_COMPUTE) as compute_credits, SUM(wh.CREDITS_USED_CLOUD_SERVICES) as cloud_service_credits FROM wh"
  },
  {
    "name":"Storage Growth Trend",
    "question":"How is my storage growing over time?",
    "sql":"SELECT usage_date, SUM(storage.STORAGE_BYTES) / 1099511627776.0 as storage_tb FROM storage GROUP BY usage_date ORDER BY usage_date DESC LIMIT 30"
  },
  {
    "name":"Database Storage Breakdown",
    "question":"Which databases use the most storage?",
    "sql":"SELECT database_name, AVG(db_storage.AVERAGE_DATABASE_BYTES) / 1099511627776.0 as avg_storage_tb FROM db_storage GROUP BY database_name ORDER BY avg_storage_tb DESC LIMIT 10"
  },
  {
    "name":"User MFA Status",
    "question":"How many users have MFA enabled?",
    "sql":"SELECT COUNT(*) as total_users, COUNT_IF(users.HAS_MFA = TRUE) as mfa_enabled, CAST(COUNT_IF(users.HAS_MFA = TRUE) AS FLOAT) * 100.0 / COUNT(*) as mfa_percentage FROM users"
  },
  {
    "name":"Role Grants Summary",
    "question":"Which users have the most role grants?",
    "sql":"SELECT user_grantee_name, COUNT(*) as role_count FROM grants_users GROUP BY user_grantee_name ORDER BY role_count DESC LIMIT 10"
  }
]}');

