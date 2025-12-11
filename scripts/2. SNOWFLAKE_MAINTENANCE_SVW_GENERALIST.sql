-- ============================================================================
-- SNOWFLAKE MAINTENANCE SEMANTIC VIEW (GENERALIST)
-- ============================================================================
-- Comprehensive unified semantic view combining cost, performance, security,
-- governance, and operations monitoring across all Snowflake ACCOUNT_USAGE views
--
-- ARCHITECTURE:
-- - This is the GENERALIST semantic view for comprehensive cross-domain analysis
-- - Complements specialized views: 2.2 (Cost/Performance), 2.3 (Security)
--
-- DATA COVERAGE:
-- • Query & Performance
-- • Security & Authentication  
-- • Cost & Resource Usage
-- • Data Governance
-- • Operations & Monitoring
-- • Advanced Operations
-- ============================================================================

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.TOOLS;

-- ============================================================================
-- COMPREHENSIVE SNOWFLAKE OPERATIONS SEMANTIC VIEW (PHASE 7 ENHANCED)
-- ============================================================================
-- Includes: 24 ACCOUNT_USAGE tables, 45 dimensions, 122 metrics
-- 
-- Query & Performance: QUERY_HISTORY, QUERY_ATTRIBUTION_HISTORY
-- Security: LOGIN_HISTORY, SESSIONS (NEW), USERS
-- Security Policies: PASSWORD_POLICIES (NEW), SESSION_POLICIES (NEW), NETWORK_POLICIES (NEW)
-- Cost & Storage: WAREHOUSE_METERING, STORAGE_USAGE, DB/STAGE_STORAGE
-- Governance: ROLES, GRANTS
-- Operations: TASK_HISTORY, SERVERLESS_TASK_HISTORY
-- Advanced: PIPE, CLUSTERING, MV, REPLICATION, TRANSFER, LOAD, METERING
-- ============================================================================

CREATE OR REPLACE SEMANTIC VIEW 
    SNOWFLAKE_INTELLIGENCE.TOOLS.SNOWFLAKE_MAINTENANCE_SVW
TABLES (
  qh AS SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY,
  qa AS SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY,
  login AS SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY,
  sessions AS SNOWFLAKE.ACCOUNT_USAGE.SESSIONS,
  wh AS SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY,
  storage AS SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE,
  db_storage AS SNOWFLAKE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY,
  stage_storage AS SNOWFLAKE.ACCOUNT_USAGE.STAGE_STORAGE_USAGE_HISTORY,
  users AS SNOWFLAKE.ACCOUNT_USAGE.USERS,
  roles AS SNOWFLAKE.ACCOUNT_USAGE.ROLES,
  grants_users AS SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS,
  grants_roles AS SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES,
  pwd_policies AS SNOWFLAKE.ACCOUNT_USAGE.PASSWORD_POLICIES,
  sess_policies AS SNOWFLAKE.ACCOUNT_USAGE.SESSION_POLICIES,
  net_policies AS SNOWFLAKE.ACCOUNT_USAGE.NETWORK_POLICIES,
  task_hist AS SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY,
  serverless_task AS SNOWFLAKE.ACCOUNT_USAGE.SERVERLESS_TASK_HISTORY,
  pipe_usage AS SNOWFLAKE.ACCOUNT_USAGE.PIPE_USAGE_HISTORY,
  clustering AS SNOWFLAKE.ACCOUNT_USAGE.AUTOMATIC_CLUSTERING_HISTORY,
  mv_refresh AS SNOWFLAKE.ACCOUNT_USAGE.MATERIALIZED_VIEW_REFRESH_HISTORY,
  replication AS SNOWFLAKE.ACCOUNT_USAGE.REPLICATION_USAGE_HISTORY,
  data_transfer AS SNOWFLAKE.ACCOUNT_USAGE.DATA_TRANSFER_HISTORY,
  wh_load AS SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_LOAD_HISTORY,
  metering_daily AS SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
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
  
  -- === SESSION DIMENSIONS (Phase 7 - Security Enhancement) ===
  sessions.SESSION_ID AS session_id COMMENT='Unique session identifier',
  sessions.CREATED_ON AS created_on COMMENT='Session creation timestamp',
  sessions.AUTHENTICATION_METHOD AS authentication_method COMMENT='Authentication method used for session',
  sessions.CLIENT_APPLICATION_ID AS client_application_id COMMENT='Client application identifier',
  sessions.CLIENT_VERSION AS client_version COMMENT='Client version',
  sessions.CLOSED_REASON AS closed_reason COMMENT='Reason for session closure (NULL if active)',
  
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
  
  -- === SECURITY POLICY DIMENSIONS (Phase 7) ===
  -- Note: PASSWORD_POLICIES, SESSION_POLICIES, NETWORK_POLICIES all have NAME column conflicts
  -- These tables provide METRICS only for policy compliance tracking:
  -- - Password policy strength requirements
  -- - Session timeout configurations
  -- - Network policy coverage (IP whitelist/blacklist)
  
  -- === TASK OPERATIONS (Phase 5) ===
  -- Note: TASK_HISTORY and SERVERLESS_TASK_HISTORY have too many conflicts
  -- (NAME, TASK_NAME, STATE, START_TIME, END_TIME, SCHEDULED_TIME, QUERY_ID, etc.)
  -- These tables provide METRICS only for task monitoring:
  -- - Total task runs, success/failure rates
  -- - Serverless task credits
  -- Use QUERY_HISTORY for query-level task analysis (via task_hist.QUERY_ID join)
  
  -- === ADVANCED OPERATIONS (Phase 6) ===
  -- Note: Phase 6 tables (PIPE_USAGE, CLUSTERING, MV_REFRESH, REPLICATION, etc.)
  -- Expected to have similar conflicts (NAME, START_TIME, END_TIME, etc.)
  -- Providing METRICS only for advanced operational analytics:
  -- - Snowpipe credits and files loaded
  -- - Clustering costs and bytes reclustered
  -- - MV refresh costs
  -- - Replication and data transfer costs
  -- - Warehouse load metrics (queueing)
  -- - Daily metering reconciliation
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
  
  -- === SESSION METRICS (Phase 7 - Security Enhancement) ===
  sessions.total_sessions AS COUNT(*) COMMENT='Total number of sessions',
  sessions.active_sessions AS COUNT(CASE WHEN sessions.CLOSED_REASON IS NULL THEN 1 END) COMMENT='Currently active sessions',
  sessions.closed_sessions AS COUNT(CASE WHEN sessions.CLOSED_REASON IS NOT NULL THEN 1 END) COMMENT='Closed sessions',
  sessions.unique_session_users AS COUNT(DISTINCT sessions.USER_NAME) COMMENT='Distinct users with sessions',
  sessions.unique_session_applications AS COUNT(DISTINCT sessions.CLIENT_APPLICATION_ID) COMMENT='Distinct client applications',
  sessions.avg_sessions_per_user AS (
    CAST(COUNT(*) AS FLOAT) / NULLIF(COUNT(DISTINCT sessions.USER_NAME), 0)
  ) COMMENT='Average sessions per user',
  
  -- === PASSWORD POLICY METRICS (Phase 7 - Security Policies) ===
  pwd_policies.total_password_policies AS COUNT(*) COMMENT='Total password policies defined',
  pwd_policies.active_password_policies AS COUNT_IF(pwd_policies.DELETED IS NULL) COMMENT='Active password policies',
  pwd_policies.avg_min_password_length AS AVG(pwd_policies.PASSWORD_MIN_LENGTH) COMMENT='Average minimum password length',
  pwd_policies.policies_with_expiration AS COUNT_IF(pwd_policies.PASSWORD_MAX_AGE_DAYS > 0) COMMENT='Policies with password expiration',
  pwd_policies.strong_password_policies AS COUNT_IF(
    pwd_policies.PASSWORD_MIN_LENGTH >= 12 AND
    pwd_policies.PASSWORD_MIN_UPPER_CASE_CHARS >= 1 AND
    pwd_policies.PASSWORD_MIN_LOWER_CASE_CHARS >= 1 AND
    pwd_policies.PASSWORD_MIN_NUMERIC_CHARS >= 1 AND
    pwd_policies.PASSWORD_MIN_SPECIAL_CHARS >= 1
  ) COMMENT='Policies meeting strong password criteria',
  
  -- === SESSION POLICY METRICS (Phase 7 - Session Security) ===
  sess_policies.total_session_policies AS COUNT(*) COMMENT='Total session policies defined',
  sess_policies.active_session_policies AS COUNT_IF(sess_policies.DELETED IS NULL) COMMENT='Active session policies',
  sess_policies.avg_idle_timeout_mins AS AVG(sess_policies.SESSION_IDLE_TIMEOUT_MINS) COMMENT='Average session idle timeout',
  sess_policies.avg_ui_idle_timeout_mins AS AVG(sess_policies.SESSION_UI_IDLE_TIMEOUT_MINS) COMMENT='Average UI idle timeout',
  sess_policies.policies_with_idle_timeout AS COUNT_IF(sess_policies.SESSION_IDLE_TIMEOUT_MINS > 0) COMMENT='Policies with idle timeout configured',
  
  -- === NETWORK POLICY METRICS (Phase 7 - Network Security) ===
  net_policies.total_network_policies AS COUNT(*) COMMENT='Total network policies defined',
  net_policies.active_network_policies AS COUNT_IF(net_policies.DELETED IS NULL) COMMENT='Active network policies',
  net_policies.policies_with_allowed_ips AS COUNT_IF(net_policies.ALLOWED_IP_LIST IS NOT NULL) COMMENT='Policies with IP whitelist',
  net_policies.policies_with_blocked_ips AS COUNT_IF(net_policies.BLOCKED_IP_LIST IS NOT NULL) COMMENT='Policies with IP blacklist',
  
  -- === GRANTS METRICS (Phase 4 - Permissions) ===
  grants_users.total_role_grants_to_users AS COUNT(*) COMMENT='Total role grants to users',
  grants_users.unique_users_with_roles AS COUNT(DISTINCT grants_users.GRANTEE_NAME) COMMENT='Users with role grants',
  grants_roles.total_privilege_grants AS COUNT(*) COMMENT='Total privilege grants to roles',
  grants_roles.unique_roles_with_grants AS COUNT(DISTINCT grants_roles.GRANTEE_NAME) COMMENT='Roles with privilege grants',
  
  -- === TASK EXECUTION METRICS (Phase 5 - Operations) ===
  task_hist.total_task_runs AS COUNT(*) COMMENT='Total task executions',
  task_hist.successful_tasks AS COUNT_IF(task_hist.STATE = 'SUCCEEDED') COMMENT='Successful task runs',
  task_hist.failed_tasks AS COUNT_IF(task_hist.STATE = 'FAILED') COMMENT='Failed task runs',
  task_hist.unique_tasks AS COUNT(DISTINCT task_hist.NAME) COMMENT='Distinct tasks executed',
  task_hist.task_success_rate AS (
    CAST(COUNT_IF(task_hist.STATE = 'SUCCEEDED') AS FLOAT) * 100.0 / NULLIF(COUNT(*), 0)
  ) COMMENT='Task success rate percentage',
  
  -- === SERVERLESS TASK METRICS (Phase 5 - Serverless Costs) ===
  serverless_task.total_serverless_credits AS SUM(serverless_task.CREDITS_USED) COMMENT='Total serverless task credits',
  serverless_task.avg_serverless_credits AS AVG(serverless_task.CREDITS_USED) COMMENT='Average credits per serverless task',
  serverless_task.serverless_task_count AS COUNT(*) COMMENT='Count of serverless task executions',
  serverless_task.unique_serverless_tasks AS COUNT(DISTINCT serverless_task.TASK_NAME) COMMENT='Distinct serverless tasks',
  
  -- === SNOWPIPE METRICS (Phase 6 - Data Loading) ===
  pipe_usage.total_pipe_credits AS SUM(pipe_usage.CREDITS_USED) COMMENT='Total Snowpipe credits consumed',
  pipe_usage.total_files_inserted AS SUM(pipe_usage.FILES_INSERTED) COMMENT='Total files loaded via Snowpipe',
  pipe_usage.total_bytes_inserted AS SUM(pipe_usage.BYTES_INSERTED) COMMENT='Total bytes loaded via Snowpipe',
  pipe_usage.avg_pipe_credits AS AVG(pipe_usage.CREDITS_USED) COMMENT='Average Snowpipe credits per execution',
  
  -- === CLUSTERING METRICS (Phase 6 - Maintenance Costs) ===
  clustering.total_clustering_credits AS SUM(clustering.CREDITS_USED) COMMENT='Total automatic clustering credits',
  clustering.total_bytes_reclustered AS SUM(clustering.NUM_BYTES_RECLUSTERED) COMMENT='Total bytes reclustered',
  clustering.total_rows_reclustered AS SUM(clustering.NUM_ROWS_RECLUSTERED) COMMENT='Total rows reclustered',
  clustering.avg_clustering_credits AS AVG(clustering.CREDITS_USED) COMMENT='Average clustering credits per operation',
  
  -- === MATERIALIZED VIEW METRICS (Phase 6 - MV Costs) ===
  mv_refresh.total_mv_credits AS SUM(mv_refresh.CREDITS_USED) COMMENT='Total MV refresh credits',
  mv_refresh.total_mv_refreshes AS COUNT(*) COMMENT='Total MV refresh operations',
  mv_refresh.avg_mv_credits AS AVG(mv_refresh.CREDITS_USED) COMMENT='Average credits per MV refresh',
  
  -- === REPLICATION METRICS (Phase 6 - Replication Costs) ===
  replication.total_replication_credits AS SUM(replication.CREDITS_USED) COMMENT='Total replication credits',
  replication.total_bytes_replicated AS SUM(replication.BYTES_TRANSFERRED) COMMENT='Total bytes replicated',
  replication.avg_replication_credits AS AVG(replication.CREDITS_USED) COMMENT='Average replication credits',
  
  -- === DATA TRANSFER METRICS (Phase 6 - Transfer Costs) ===
  data_transfer.total_transfer_bytes AS SUM(data_transfer.BYTES_TRANSFERRED) COMMENT='Total bytes transferred cross-region/cloud',
  data_transfer.avg_transfer_bytes AS AVG(data_transfer.BYTES_TRANSFERRED) COMMENT='Average bytes per transfer',
  data_transfer.total_transfer_operations AS COUNT(*) COMMENT='Total data transfer operations',
  
  -- === WAREHOUSE LOAD METRICS (Phase 6 - Performance) ===
  wh_load.avg_running_queries AS AVG(wh_load.AVG_RUNNING) COMMENT='Average running queries',
  wh_load.avg_queued_load AS AVG(wh_load.AVG_QUEUED_LOAD) COMMENT='Average queued query load',
  wh_load.avg_queued_provisioning AS AVG(wh_load.AVG_QUEUED_PROVISIONING) COMMENT='Average provisioning queue',
  wh_load.avg_blocked_queries AS AVG(wh_load.AVG_BLOCKED) COMMENT='Average blocked queries',
  
  -- === DAILY METERING METRICS (Phase 6 - Reconciliation) ===
  metering_daily.total_daily_credits AS SUM(metering_daily.CREDITS_USED) COMMENT='Total billable credits (daily)',
  metering_daily.total_compute_credits_daily AS SUM(metering_daily.CREDITS_USED_COMPUTE) COMMENT='Total compute credits (daily)',
  metering_daily.total_cloud_services_daily AS SUM(metering_daily.CREDITS_USED_CLOUD_SERVICES) COMMENT='Total cloud services credits (daily)',
  metering_daily.avg_daily_credits AS AVG(metering_daily.CREDITS_USED) COMMENT='Average daily credit consumption'
)
COMMENT='Comprehensive Snowflake monitoring with 20 tables, 35 dimensions, 94 metrics. Covers queries, security, storage, governance, tasks, Snowpipe, clustering, MVs, replication, data transfer, and warehouse load.'
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
  {"name":"grants_roles","description":"Privilege grants to roles from GRANTS_TO_ROLES"},
  {"name":"task_hist","description":"Task execution history from TASK_HISTORY. Task runs, states, errors"},
  {"name":"serverless_task","description":"Serverless task credit usage from SERVERLESS_TASK_HISTORY"},
  {"name":"pipe_usage","description":"Snowpipe data loading credits and files from PIPE_USAGE_HISTORY"},
  {"name":"clustering","description":"Automatic clustering costs and bytes reclustered from AUTOMATIC_CLUSTERING_HISTORY"},
  {"name":"mv_refresh","description":"Materialized view refresh credits from MATERIALIZED_VIEW_REFRESH_HISTORY"},
  {"name":"replication","description":"Database replication credits and bytes from REPLICATION_USAGE_HISTORY"},
  {"name":"data_transfer","description":"Cross-region/cloud data transfer costs from DATA_TRANSFER_HISTORY"},
  {"name":"wh_load","description":"Warehouse queue metrics (5-min intervals) from WAREHOUSE_LOAD_HISTORY"},
  {"name":"metering_daily","description":"Daily billable credit reconciliation from METERING_DAILY_HISTORY"}
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
  },
  {
    "name":"Task Execution Status",
    "question":"What is my task success rate?",
    "sql":"SELECT COUNT(*) as total_tasks, COUNT_IF(task_hist.STATE = ''SUCCEEDED'') as successful, COUNT_IF(task_hist.STATE = ''FAILED'') as failed, CAST(COUNT_IF(task_hist.STATE = ''SUCCEEDED'') AS FLOAT) * 100 / COUNT(*) as success_rate_pct FROM task_hist"
  },
  {
    "name":"Serverless Task Costs",
    "question":"How much are serverless tasks costing me?",
    "sql":"SELECT SUM(serverless_task.CREDITS_USED) as total_credits, COUNT(*) as total_runs, AVG(serverless_task.CREDITS_USED) as avg_credits_per_run FROM serverless_task"
  },
  {
    "name":"Snowpipe Usage Summary",
    "question":"How much data has Snowpipe loaded?",
    "sql":"SELECT SUM(pipe_usage.CREDITS_USED) as total_credits, SUM(pipe_usage.FILES_INSERTED) as total_files, SUM(pipe_usage.BYTES_INSERTED) / 1099511627776.0 as total_tb_loaded FROM pipe_usage"
  },
  {
    "name":"Clustering Costs",
    "question":"What are my automatic clustering costs?",
    "sql":"SELECT SUM(clustering.CREDITS_USED) as total_credits, SUM(clustering.BYTES_RECLUSTERED) / 1099511627776.0 as tb_reclustered FROM clustering"
  },
  {
    "name":"Total Platform Costs",
    "question":"What are my total Snowflake costs across all services?",
    "sql":"SELECT SUM(metering_daily.CREDITS_USED) as total_billable_credits, SUM(metering_daily.CREDITS_USED_COMPUTE) as compute_credits, SUM(metering_daily.CREDITS_USED_CLOUD_SERVICES) as cloud_services_credits FROM metering_daily"
  }
]}');

