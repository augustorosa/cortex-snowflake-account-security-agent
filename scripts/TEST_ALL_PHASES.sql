-- ============================================================================
-- COMPREHENSIVE AUTOMATED TEST SUITE FOR ALL AGENTS
-- ============================================================================
-- Tests all 6 phases of the Generalist Agent + 2 Specialist Agents
-- 
-- USAGE:
--   snowsql -f scripts/TEST_ALL_PHASES.sql -o output_format=table
--
-- AGENTS TESTED:
--   1. SNOWFLAKE_MAINTENANCE_AGENT (Generalist - All 6 Phases)
--   2. COST_PERFORMANCE_AGENT (Specialist)
--   3. SECURITY_MONITORING_AGENT (Specialist)
-- ============================================================================

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.TOOLS;

-- Set session for consistent results
ALTER SESSION SET TIMEZONE = 'UTC';

SELECT '═══════════════════════════════════════════════════════════════' AS test_section;
SELECT 'PHASE 1: QUERY PERFORMANCE & COST TESTS' AS test_name;
SELECT '═══════════════════════════════════════════════════════════════' AS test_section;

-- Test 1.1: Basic query metrics availability
SELECT 'Test 1.1: Query Metrics Availability' AS test_name;
SELECT 
  COUNT(*) as total_queries_tracked,
  COUNT(DISTINCT USER_NAME) as unique_users,
  COUNT(DISTINCT WAREHOUSE_NAME) as unique_warehouses,
  SUM(CASE WHEN EXECUTION_STATUS = 'SUCCESS' THEN 1 ELSE 0 END) as successful_queries,
  SUM(CASE WHEN EXECUTION_STATUS = 'FAIL' THEN 1 ELSE 0 END) as failed_queries
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD('hour', -24, CURRENT_TIMESTAMP());

-- Test 1.2: Cost attribution data
SELECT 'Test 1.2: Cost Attribution Data' AS test_name;
SELECT 
  COUNT(*) as attributed_queries,
  SUM(CREDITS_ATTRIBUTED_COMPUTE) as total_compute_credits,
  AVG(CREDITS_ATTRIBUTED_COMPUTE) as avg_credits_per_query,
  COUNT(DISTINCT QUERY_ID) as unique_queries_with_attribution
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY
WHERE START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP());

-- Test 1.3: Performance bottlenecks
SELECT 'Test 1.3: Performance Bottleneck Detection' AS test_name;
SELECT 
  'Queued Queries' as metric,
  COUNT(*) as count,
  AVG(QUEUED_OVERLOAD_TIME + QUEUED_PROVISIONING_TIME + QUEUED_REPAIR_TIME) as avg_queue_ms
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE (QUEUED_OVERLOAD_TIME > 0 OR QUEUED_PROVISIONING_TIME > 0 OR QUEUED_REPAIR_TIME > 0)
  AND START_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP());

-- Test 1.4: Spilling queries
SELECT 'Test 1.4: Spilling Query Detection' AS test_name;
SELECT 
  COUNT(*) as spilling_queries,
  SUM(BYTES_SPILLED_TO_LOCAL_STORAGE) / 1099511627776.0 as spilled_local_tb,
  SUM(BYTES_SPILLED_TO_REMOTE_STORAGE) / 1099511627776.0 as spilled_remote_tb
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE (BYTES_SPILLED_TO_LOCAL_STORAGE > 0 OR BYTES_SPILLED_TO_REMOTE_STORAGE > 0)
  AND START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP());

SELECT '═══════════════════════════════════════════════════════════════' AS test_section;
SELECT 'PHASE 2: SECURITY & AUTHENTICATION TESTS' AS test_name;
SELECT '═══════════════════════════════════════════════════════════════' AS test_section;

-- Test 2.1: Login activity overview
SELECT 'Test 2.1: Login Activity Overview' AS test_name;
SELECT 
  COUNT(*) as total_login_attempts,
  COUNT(DISTINCT USER_NAME) as unique_users_logging_in,
  COUNT(DISTINCT CLIENT_IP) as unique_ip_addresses,
  SUM(CASE WHEN IS_SUCCESS = 'YES' THEN 1 ELSE 0 END) as successful_logins,
  SUM(CASE WHEN IS_SUCCESS = 'NO' THEN 1 ELSE 0 END) as failed_logins,
  ROUND(SUM(CASE WHEN IS_SUCCESS = 'YES' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as success_rate_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP >= DATEADD('day', -7, CURRENT_TIMESTAMP());

-- Test 2.2: MFA adoption
SELECT 'Test 2.2: MFA Adoption Analysis' AS test_name;
SELECT 
  COUNT(DISTINCT USER_NAME) as users_with_logins,
  COUNT(DISTINCT CASE WHEN SECOND_AUTHENTICATION_FACTOR IS NOT NULL THEN USER_NAME END) as users_using_mfa,
  ROUND(COUNT(DISTINCT CASE WHEN SECOND_AUTHENTICATION_FACTOR IS NOT NULL THEN USER_NAME END) * 100.0 / 
        NULLIF(COUNT(DISTINCT USER_NAME), 0), 2) as mfa_user_adoption_pct,
  SUM(CASE WHEN SECOND_AUTHENTICATION_FACTOR IS NOT NULL THEN 1 ELSE 0 END) as mfa_login_count,
  ROUND(SUM(CASE WHEN SECOND_AUTHENTICATION_FACTOR IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as mfa_login_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND IS_SUCCESS = 'YES';

-- Test 2.3: Failed login patterns
SELECT 'Test 2.3: Failed Login Pattern Detection' AS test_name;
SELECT 
  CLIENT_IP,
  COUNT(*) as failed_attempts,
  COUNT(DISTINCT USER_NAME) as unique_users_targeted,
  MAX(EVENT_TIMESTAMP) as last_failure
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE IS_SUCCESS = 'NO'
  AND EVENT_TIMESTAMP >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY CLIENT_IP
HAVING COUNT(*) > 3
ORDER BY failed_attempts DESC
LIMIT 10;

-- Test 2.4: Client type distribution
SELECT 'Test 2.4: Client Type Distribution' AS test_name;
SELECT 
  REPORTED_CLIENT_TYPE,
  COUNT(*) as login_count,
  COUNT(DISTINCT USER_NAME) as unique_users,
  SUM(CASE WHEN IS_SUCCESS = 'NO' THEN 1 ELSE 0 END) as failures
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY REPORTED_CLIENT_TYPE
ORDER BY login_count DESC;

SELECT '═══════════════════════════════════════════════════════════════' AS test_section;
SELECT 'PHASE 3: COST & STORAGE TESTS' AS test_name;
SELECT '═══════════════════════════════════════════════════════════════' AS test_section;

-- Test 3.1: Warehouse credit consumption
SELECT 'Test 3.1: Warehouse Credit Consumption' AS test_name;
SELECT 
  COUNT(DISTINCT WAREHOUSE_NAME) as active_warehouses,
  SUM(CREDITS_USED) as total_credits,
  SUM(CREDITS_USED_COMPUTE) as compute_credits,
  SUM(CREDITS_USED_CLOUD_SERVICES) as cloud_service_credits,
  AVG(CREDITS_USED) as avg_credits_per_hour
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP());

-- Test 3.2: Storage metrics
SELECT 'Test 3.2: Storage Usage Analysis' AS test_name;
SELECT 
  USAGE_DATE,
  STORAGE_BYTES / 1099511627776.0 as storage_tb,
  STAGE_BYTES / 1099511627776.0 as stage_tb,
  FAILSAFE_BYTES / 1099511627776.0 as failsafe_tb,
  (STORAGE_BYTES + STAGE_BYTES + FAILSAFE_BYTES) / 1099511627776.0 as total_tb
FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
WHERE USAGE_DATE >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY USAGE_DATE DESC
LIMIT 7;

-- Test 3.3: Database storage breakdown
SELECT 'Test 3.3: Database Storage Breakdown' AS test_name;
SELECT 
  DATABASE_NAME,
  ROUND(AVG(AVERAGE_DATABASE_BYTES) / 1099511627776.0, 2) as avg_storage_tb,
  ROUND(AVG(AVERAGE_FAILSAFE_BYTES) / 1099511627776.0, 2) as avg_failsafe_tb
FROM SNOWFLAKE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY
WHERE USAGE_DATE >= DATEADD('day', -1, CURRENT_TIMESTAMP())
GROUP BY DATABASE_NAME
ORDER BY avg_storage_tb DESC
LIMIT 10;

SELECT '═══════════════════════════════════════════════════════════════' AS test_section;
SELECT 'PHASE 4: GOVERNANCE & PERMISSIONS TESTS' AS test_name;
SELECT '═══════════════════════════════════════════════════════════════' AS test_section;

-- Test 4.1: User and role counts
SELECT 'Test 4.1: User and Role Governance' AS test_name;
SELECT 
  (SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.USERS WHERE DELETED_ON IS NULL) as total_users,
  (SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.USERS WHERE DELETED_ON IS NULL AND (DISABLED IS NULL OR DISABLED = FALSE)) as active_users,
  (SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.USERS WHERE DELETED_ON IS NULL AND HAS_MFA = TRUE) as mfa_enabled_users,
  (SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.ROLES WHERE DELETED_ON IS NULL) as total_roles;

-- Test 4.2: Grant distribution
SELECT 'Test 4.2: Grant Distribution Analysis' AS test_name;
SELECT 
  (SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS WHERE DELETED_ON IS NULL) as role_grants_to_users,
  (SELECT COUNT(DISTINCT GRANTEE_NAME) FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS WHERE DELETED_ON IS NULL) as users_with_role_grants,
  (SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES WHERE DELETED_ON IS NULL) as privilege_grants_to_roles,
  (SELECT COUNT(DISTINCT GRANTEE_NAME) FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES WHERE DELETED_ON IS NULL) as roles_with_privileges;

-- Test 4.3: MFA adoption by user
SELECT 'Test 4.3: User MFA Status Detail' AS test_name;
SELECT 
  HAS_MFA,
  COUNT(*) as user_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL
  AND (DISABLED IS NULL OR DISABLED = FALSE)
GROUP BY HAS_MFA;

SELECT '═══════════════════════════════════════════════════════════════' AS test_section;
SELECT 'PHASE 5: TASK OPERATIONS TESTS' AS test_name;
SELECT '═══════════════════════════════════════════════════════════════' AS test_section;

-- Test 5.1: Task execution summary
SELECT 'Test 5.1: Task Execution Summary' AS test_name;
SELECT 
  COUNT(*) as total_task_runs,
  COUNT(DISTINCT NAME) as unique_tasks,
  SUM(CASE WHEN STATE = 'SUCCEEDED' THEN 1 ELSE 0 END) as successful_runs,
  SUM(CASE WHEN STATE = 'FAILED' THEN 1 ELSE 0 END) as failed_runs,
  ROUND(SUM(CASE WHEN STATE = 'SUCCEEDED' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) as success_rate_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY
WHERE SCHEDULED_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP());

-- Test 5.2: Serverless task costs
SELECT 'Test 5.2: Serverless Task Credit Analysis' AS test_name;
SELECT 
  COUNT(*) as serverless_task_executions,
  COUNT(DISTINCT TASK_NAME) as unique_serverless_tasks,
  SUM(CREDITS_USED) as total_serverless_credits,
  AVG(CREDITS_USED) as avg_credits_per_execution,
  MAX(CREDITS_USED) as max_credits_single_execution
FROM SNOWFLAKE.ACCOUNT_USAGE.SERVERLESS_TASK_HISTORY
WHERE START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP());

SELECT '═══════════════════════════════════════════════════════════════' AS test_section;
SELECT 'PHASE 6: ADVANCED OPERATIONS TESTS' AS test_name;
SELECT '═══════════════════════════════════════════════════════════════' AS test_section;

-- Test 6.1: Snowpipe usage
SELECT 'Test 6.1: Snowpipe Data Loading' AS test_name;
SELECT 
  COUNT(*) as pipe_executions,
  SUM(CREDITS_USED) as total_pipe_credits,
  SUM(FILES_INSERTED) as total_files_loaded,
  SUM(BYTES_INSERTED) / 1099511627776.0 as total_tb_loaded,
  AVG(CREDITS_USED) as avg_credits_per_execution
FROM SNOWFLAKE.ACCOUNT_USAGE.PIPE_USAGE_HISTORY
WHERE START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP());

-- Test 6.2: Automatic clustering costs
SELECT 'Test 6.2: Automatic Clustering Analysis' AS test_name;
SELECT 
  COUNT(*) as clustering_operations,
  SUM(CREDITS_USED) as total_clustering_credits,
  SUM(NUM_BYTES_RECLUSTERED) / 1099511627776.0 as tb_reclustered,
  SUM(NUM_ROWS_RECLUSTERED) as rows_reclustered,
  AVG(CREDITS_USED) as avg_credits_per_operation
FROM SNOWFLAKE.ACCOUNT_USAGE.AUTOMATIC_CLUSTERING_HISTORY
WHERE START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP());

-- Test 6.3: Materialized view refresh costs
SELECT 'Test 6.3: Materialized View Refresh' AS test_name;
SELECT 
  COUNT(*) as mv_refresh_operations,
  SUM(CREDITS_USED) as total_mv_credits,
  AVG(CREDITS_USED) as avg_credits_per_refresh
FROM SNOWFLAKE.ACCOUNT_USAGE.MATERIALIZED_VIEW_REFRESH_HISTORY
WHERE START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP());

-- Test 6.4: Replication usage
SELECT 'Test 6.4: Replication Analysis' AS test_name;
SELECT 
  COUNT(*) as replication_operations,
  SUM(CREDITS_USED) as total_replication_credits,
  SUM(BYTES_TRANSFERRED) / 1099511627776.0 as tb_replicated
FROM SNOWFLAKE.ACCOUNT_USAGE.REPLICATION_USAGE_HISTORY
WHERE START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP());

-- Test 6.5: Data transfer
SELECT 'Test 6.5: Data Transfer Analysis' AS test_name;
SELECT 
  COUNT(*) as transfer_operations,
  SUM(BYTES_TRANSFERRED) / 1099511627776.0 as tb_transferred,
  COUNT(DISTINCT SOURCE_CLOUD) as source_clouds,
  COUNT(DISTINCT TARGET_CLOUD) as target_clouds
FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_TRANSFER_HISTORY
WHERE START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP());

-- Test 6.6: Warehouse load metrics
SELECT 'Test 6.6: Warehouse Load/Queue Analysis' AS test_name;
SELECT 
  COUNT(*) as measurement_intervals,
  ROUND(AVG(AVG_RUNNING), 2) as avg_running_queries,
  ROUND(AVG(AVG_QUEUED_LOAD), 2) as avg_queued_load,
  ROUND(AVG(AVG_QUEUED_PROVISIONING), 2) as avg_queued_provisioning,
  ROUND(AVG(AVG_BLOCKED), 2) as avg_blocked_queries
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_LOAD_HISTORY
WHERE START_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP());

-- Test 6.7: Daily metering reconciliation
SELECT 'Test 6.7: Daily Metering (Billable Credits)' AS test_name;
SELECT 
  USAGE_DATE,
  SUM(CREDITS_USED) as total_billable_credits,
  SUM(CREDITS_USED_COMPUTE) as compute_credits,
  SUM(CREDITS_USED_CLOUD_SERVICES) as cloud_services_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE USAGE_DATE >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY USAGE_DATE
ORDER BY USAGE_DATE DESC;

SELECT '═══════════════════════════════════════════════════════════════' AS test_section;
SELECT 'CROSS-DOMAIN ANALYSIS TESTS' AS test_name;
SELECT '═══════════════════════════════════════════════════════════════' AS test_section;

-- Test X.1: Security + Cost correlation
SELECT 'Test X.1: Users with Failed Logins and Expensive Queries' AS test_name;
SELECT 
  qh.USER_NAME,
  COUNT(DISTINCT qh.QUERY_ID) as total_queries,
  SUM(qh.CREDITS_USED_CLOUD_SERVICES) as total_credits,
  COUNT(DISTINCT lh.EVENT_TIMESTAMP) as failed_login_count
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
JOIN SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY lh 
  ON qh.USER_NAME = lh.USER_NAME
WHERE qh.START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND lh.EVENT_TIMESTAMP >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND lh.IS_SUCCESS = 'NO'
GROUP BY qh.USER_NAME
HAVING SUM(qh.CREDITS_USED_CLOUD_SERVICES) > 0
ORDER BY total_credits DESC
LIMIT 10;

-- Test X.2: Comprehensive cost summary
SELECT 'Test X.2: Total Platform Costs (All Services)' AS test_name;
SELECT 
  'Warehouse (Metering)' as service,
  SUM(CREDITS_USED) as total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE START_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP())
UNION ALL
SELECT 
  'Serverless Tasks' as service,
  SUM(CREDITS_USED) as total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.SERVERLESS_TASK_HISTORY
WHERE START_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP())
UNION ALL
SELECT 
  'Snowpipe' as service,
  SUM(CREDITS_USED) as total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.PIPE_USAGE_HISTORY
WHERE START_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP())
UNION ALL
SELECT 
  'Clustering' as service,
  SUM(CREDITS_USED) as total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.AUTOMATIC_CLUSTERING_HISTORY
WHERE START_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP())
UNION ALL
SELECT 
  'Materialized Views' as service,
  SUM(CREDITS_USED) as total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.MATERIALIZED_VIEW_REFRESH_HISTORY
WHERE START_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP())
UNION ALL
SELECT 
  'Replication' as service,
  SUM(CREDITS_USED) as total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.REPLICATION_USAGE_HISTORY
WHERE START_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP())
ORDER BY total_credits DESC;

SELECT '═══════════════════════════════════════════════════════════════' AS test_section;
SELECT 'SEMANTIC VIEW VALIDATION' AS test_name;
SELECT '═══════════════════════════════════════════════════════════════' AS test_section;

-- Test S.1: Verify semantic view exists
SELECT 'Test S.1: Semantic View Existence' AS test_name;
SHOW SEMANTIC VIEWS LIKE 'SNOWFLAKE_MAINTENANCE_SVW' IN SCHEMA SNOWFLAKE_INTELLIGENCE.TOOLS;

-- Test S.2: Verify all three agents exist
SELECT 'Test S.2: Agent Existence Check' AS test_name;
SHOW AGENTS LIKE '%AGENT%' IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS;

SELECT '═══════════════════════════════════════════════════════════════' AS test_section;
SELECT '✅ ALL AUTOMATED TESTS COMPLETE' AS status;
SELECT 'Review results above for any anomalies or zero counts' AS note;
SELECT '═══════════════════════════════════════════════════════════════' AS test_section;
