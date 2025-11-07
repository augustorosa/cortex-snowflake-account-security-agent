-- ============================================================================
-- BUSINESS INTELLIGENCE QUERIES FOR SNOWFLAKE_MAINTENANCE_SVW
-- ============================================================================
-- Advanced BI queries using semantic view syntax
-- Reference: https://docs.snowflake.com/en/user-guide/views-semantic/querying
--
-- IMPORTANT: These queries only use dimensions and metrics that actually exist
-- in the semantic view. Many tables (wh, users, roles, tasks, etc.) provide
-- METRICS ONLY due to column name conflicts.
-- ============================================================================

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.TOOLS;

-- ============================================================================
-- 1. QUERY PERFORMANCE & COST ANALYSIS
-- ============================================================================

-- Query 1.1: Cost by warehouse (QH dimensions only - cannot mix with QA metrics due to granularity)
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS qh.warehouse_name
    METRICS 
        qh.total_queries,
        qh.successful_queries,
        qh.failed_queries,
        qh.total_elapsed_time,
        qh.credits_used_cloud_services
)
ORDER BY credits_used_cloud_services DESC
LIMIT 20;

-- Query 1.2: Cost by user
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS qh.user_name
    METRICS 
        qh.total_queries,
        qh.total_elapsed_time,
        qh.credits_used_cloud_services,
        qa.credits_compute,
        qa.credits_acceleration
)
ORDER BY credits_compute DESC
LIMIT 20;

-- Query 1.3: Cost by database
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS qh.database_name
    METRICS 
        qh.total_queries,
        qh.bytes_scanned,
        qh.bytes_written,
        qh.credits_used_cloud_services
)
ORDER BY credits_used_cloud_services DESC;

-- Query 1.4: Query performance by type
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS qh.query_type
    METRICS 
        qh.total_queries,
        qh.total_elapsed_time,
        qh.execution_time,
        qh.compilation_time
)
ORDER BY total_queries DESC;

-- Query 1.5: Failed queries by error code
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS 
        qh.error_code,
        qh.error_message
    METRICS qh.failed_queries
)
WHERE qh.execution_status = 'FAIL'
ORDER BY failed_queries DESC
LIMIT 20;

-- ============================================================================
-- 2. QUERY PERFORMANCE DEEP DIVE
-- ============================================================================

-- Query 2.1: Spilling queries by user
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS qh.user_name
    METRICS 
        qh.total_queries,
        qh.bytes_spilled_to_local,
        qh.bytes_spilled_to_remote
)
ORDER BY bytes_spilled_to_remote DESC
LIMIT 20;

-- Query 2.2: Cache efficiency by warehouse
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS qh.warehouse_name
    METRICS 
        qh.total_queries,
        qh.bytes_scanned,
        qh.percentage_scanned_from_cache
)
ORDER BY percentage_scanned_from_cache ASC
LIMIT 20;

-- Query 2.3: Partition efficiency by database
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS qh.database_name
    METRICS 
        qh.total_queries,
        qh.partitions_scanned,
        qh.partitions_total
)
ORDER BY partitions_scanned DESC;

-- Query 2.4: Queueing analysis by warehouse
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS qh.warehouse_name
    METRICS 
        qh.total_queries,
        qh.queued_provisioning_time,
        qh.queued_repair_time,
        qh.queued_overload_time
)
ORDER BY queued_overload_time DESC;

-- Query 2.5: Data volume by user
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS qh.user_name
    METRICS 
        qh.bytes_scanned,
        qh.bytes_written,
        qh.rows_produced,
        qh.rows_inserted,
        qh.rows_updated,
        qh.rows_deleted
)
ORDER BY bytes_scanned DESC
LIMIT 20;

-- ============================================================================
-- 3. SECURITY & AUTHENTICATION ANALYSIS
-- ============================================================================

-- Query 3.1: Login success/failure by client IP
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS login.client_ip
    METRICS 
        login.total_login_attempts,
        login.successful_login_attempts,
        login.failed_login_attempts,
        login.login_success_rate_pct
)
ORDER BY failed_login_attempts DESC
LIMIT 20;

-- Query 3.2: MFA adoption by client type
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS login.reported_client_type
    METRICS 
        login.total_login_attempts,
        login.mfa_login_usage,
        login.mfa_adoption_pct
)
ORDER BY total_login_attempts DESC;

-- Query 3.3: Failed logins by error code
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS 
        login.error_code,
        login.error_message
    METRICS 
        login.failed_login_attempts,
        login.unique_login_users,
        login.unique_login_ips
)
WHERE login.is_success = 'NO'
ORDER BY failed_login_attempts DESC
LIMIT 20;

-- Query 3.4: Authentication patterns by client version
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS 
        login.reported_client_type,
        login.reported_client_version
    METRICS 
        login.total_login_attempts,
        login.unique_login_users
)
ORDER BY total_login_attempts DESC
LIMIT 20;

-- Query 3.5: Suspicious login patterns (users with failures and IPs with failures)
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        login.users_with_login_failures,
        login.ips_with_login_failures,
        login.failed_login_attempts,
        login.login_success_rate_pct
);

-- ============================================================================
-- 4. STORAGE ANALYSIS
-- ============================================================================

-- Query 4.1: Storage growth over time
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS storage.usage_date
    METRICS 
        storage.total_storage_bytes,
        storage.total_stage_bytes,
        storage.total_failsafe_bytes,
        storage.total_hybrid_table_bytes
)
ORDER BY usage_date DESC
LIMIT 30;

-- Query 4.2: Database storage breakdown
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS db_storage.database_name
    METRICS 
        db_storage.avg_database_bytes,
        db_storage.avg_failsafe_bytes,
        db_storage.total_database_storage
)
ORDER BY total_database_storage DESC
LIMIT 10;

-- Query 4.3: Stage storage analysis
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        stage_storage.avg_stage_bytes,
        stage_storage.total_stage_storage
);

-- ============================================================================
-- 5. GOVERNANCE & PERMISSIONS (METRICS ONLY)
-- ============================================================================

-- Query 5.1: Overall user and role metrics
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        users.total_users,
        users.active_users,
        users.mfa_enabled_users,
        users.mfa_adoption_rate,
        roles.total_roles
);

-- Query 5.2: Grant distribution metrics
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        grants_users.total_role_grants_to_users,
        grants_users.unique_users_with_roles,
        grants_roles.total_privilege_grants,
        grants_roles.unique_roles_with_grants
);

-- ============================================================================
-- 6. TASK & OPERATIONS (METRICS ONLY)
-- ============================================================================

-- Query 6.1: Task execution metrics
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        task_hist.total_task_runs,
        task_hist.successful_tasks,
        task_hist.failed_tasks,
        task_hist.unique_tasks,
        task_hist.task_success_rate
);

-- Query 6.2: Serverless task costs
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        serverless_task.total_serverless_credits,
        serverless_task.avg_serverless_credits,
        serverless_task.serverless_task_count,
        serverless_task.unique_serverless_tasks
);

-- ============================================================================
-- 7. ADVANCED OPERATIONS (METRICS ONLY)
-- ============================================================================

-- Query 7.1: Snowpipe data loading metrics
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        pipe_usage.total_pipe_credits,
        pipe_usage.total_files_inserted,
        pipe_usage.total_bytes_inserted,
        pipe_usage.avg_pipe_credits
);

-- Query 7.2: Automatic clustering metrics
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        clustering.total_clustering_credits,
        clustering.total_bytes_reclustered,
        clustering.total_rows_reclustered,
        clustering.avg_clustering_credits
);

-- Query 7.3: Materialized view refresh metrics
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        mv_refresh.total_mv_credits,
        mv_refresh.total_mv_refreshes,
        mv_refresh.avg_mv_credits
);

-- Query 7.4: Replication metrics
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        replication.total_replication_credits,
        replication.total_bytes_replicated,
        replication.avg_replication_credits
);

-- Query 7.5: Data transfer metrics
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        data_transfer.total_transfer_bytes,
        data_transfer.avg_transfer_bytes,
        data_transfer.total_transfer_operations
);

-- Query 7.6: Warehouse load metrics
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        wh_load.avg_running_queries,
        wh_load.avg_queued_load,
        wh_load.avg_queued_provisioning,
        wh_load.avg_blocked_queries
);

-- Query 7.7: Daily metering (billable credits)
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        metering_daily.total_daily_credits,
        metering_daily.total_compute_credits_daily,
        metering_daily.total_cloud_services_daily,
        metering_daily.avg_daily_credits
);

-- Query 7.8: Warehouse credit consumption (metrics only)
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        wh.total_credits_used,
        wh.total_credits_compute,
        wh.total_credits_cloud_services,
        wh.avg_credits_per_hour
);

-- ============================================================================
-- 8. CROSS-DOMAIN ANALYSIS
-- ============================================================================

-- Query 8.1: User cost and performance profile
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS qh.user_name
    METRICS 
        qh.total_queries,
        qh.successful_queries,
        qh.failed_queries,
        qh.total_elapsed_time,
        qh.bytes_scanned,
        qh.credits_used_cloud_services,
        qa.credits_compute
)
ORDER BY credits_compute DESC
LIMIT 20;

-- Query 8.2: Warehouse efficiency scorecard
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS qh.warehouse_name
    METRICS 
        qh.total_queries,
        qh.failed_queries,
        qh.total_elapsed_time,
        qh.percentage_scanned_from_cache,
        qh.bytes_spilled_to_remote,
        qa.credits_compute
)
ORDER BY credits_compute DESC;

-- Query 8.3: Database activity profile
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS qh.database_name
    METRICS 
        qh.total_queries,
        qh.bytes_scanned,
        qh.bytes_written,
        qh.rows_produced,
        qh.credits_used_cloud_services
)
ORDER BY total_queries DESC;

-- Query 8.4: Overall platform health metrics
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        qh.total_queries,
        qh.successful_queries,
        qh.failed_queries,
        qh.credits_used_cloud_services,
        qa.credits_compute,
        login.total_login_attempts,
        login.failed_login_attempts,
        login.login_success_rate_pct,
        login.mfa_adoption_pct,
        users.total_users,
        users.mfa_enabled_users,
        wh.total_credits_used,
        storage.total_storage_bytes,
        task_hist.task_success_rate
);

-- ============================================================================
-- 9. TIME-BASED ANALYSIS
-- ============================================================================

-- Query 9.1: Query volume by start time
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS qh.start_time
    METRICS 
        qh.total_queries,
        qh.failed_queries,
        qh.credits_used_cloud_services
)
ORDER BY start_time DESC
LIMIT 168;  -- Last 7 days if hourly

-- Query 9.2: Login patterns by timestamp
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS login.event_timestamp
    METRICS 
        login.total_login_attempts,
        login.successful_login_attempts,
        login.failed_login_attempts
)
ORDER BY event_timestamp DESC
LIMIT 30;

-- Query 9.3: Storage growth trend
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS storage.usage_date
    METRICS 
        storage.total_storage_bytes,
        storage.avg_storage_bytes
)
ORDER BY usage_date DESC
LIMIT 30;

-- ============================================================================
-- 10. ADVANCED WHERE CLAUSE EXAMPLES
-- ============================================================================

-- Query 10.1: High-cost queries by specific warehouse
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS 
        qh.warehouse_name,
        qh.user_name,
        qh.query_type
    METRICS 
        qh.total_queries,
        qh.total_elapsed_time,
        qh.credits_used_cloud_services
)
WHERE qh.warehouse_name = 'COMPUTE_WH'  -- Replace with your warehouse
ORDER BY credits_used_cloud_services DESC
LIMIT 20;

-- Query 10.2: Failed queries in production databases
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS 
        qh.database_name,
        qh.schema_name,
        qh.error_code
    METRICS qh.failed_queries
)
WHERE qh.database_name LIKE '%PROD%'
  AND qh.execution_status = 'FAIL'
ORDER BY failed_queries DESC;

-- Query 10.3: Security issues from specific IPs
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS 
        login.client_ip,
        login.error_code
    METRICS 
        login.failed_login_attempts,
        login.unique_login_users
)
WHERE login.is_success = 'NO'
ORDER BY failed_login_attempts DESC
LIMIT 20;

-- Query 10.4: Queries by specific user with performance details
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    DIMENSIONS 
        qh.user_name,
        qh.warehouse_name,
        qh.database_name
    METRICS 
        qh.total_queries,
        qh.total_elapsed_time,
        qh.bytes_scanned,
        qh.credits_used_cloud_services
)
WHERE qh.user_name = 'YOUR_USERNAME'  -- Replace with actual username
ORDER BY credits_used_cloud_services DESC;

-- ============================================================================
-- 11. COMBINED METRICS EXAMPLES
-- ============================================================================

-- Query 11.1: Complete cost breakdown
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        qh.credits_used_cloud_services,
        qa.credits_compute,
        wh.total_credits_used,
        serverless_task.total_serverless_credits,
        pipe_usage.total_pipe_credits,
        clustering.total_clustering_credits,
        mv_refresh.total_mv_credits,
        replication.total_replication_credits,
        metering_daily.total_daily_credits
);

-- Query 11.2: Complete security posture
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        login.total_login_attempts,
        login.failed_login_attempts,
        login.login_success_rate_pct,
        login.mfa_adoption_pct,
        users.total_users,
        users.active_users,
        users.mfa_enabled_users,
        users.mfa_adoption_rate
);

-- Query 11.3: Complete operational health
SELECT * FROM SEMANTIC_VIEW(
    SNOWFLAKE_MAINTENANCE_SVW
    METRICS 
        qh.total_queries,
        qh.successful_queries,
        qh.failed_queries,
        task_hist.total_task_runs,
        task_hist.task_success_rate,
        wh_load.avg_queued_load,
        wh_load.avg_blocked_queries
);

-- ============================================================================
-- NOTES ON QUERY LIMITATIONS
-- ============================================================================
-- 
-- IMPORTANT CONSTRAINTS:
-- 1. Many tables provide METRICS ONLY (no dimensions) due to column conflicts:
--    - wh (WAREHOUSE_METERING_HISTORY)
--    - users, roles, grants_users, grants_roles
--    - task_hist, serverless_task
--    - pipe_usage, clustering, mv_refresh, replication, data_transfer
--    - wh_load, metering_daily
--
-- 2. Available DIMENSIONS are limited to:
--    - qh.* (QUERY_HISTORY) - most columns available
--    - qa.* (QUERY_ATTRIBUTION) - parent_query_id, root_query_id only
--    - login.* (LOGIN_HISTORY) - all login columns available
--    - storage.usage_date
--    - db_storage.database_name
--
-- 3. You can combine:
--    - DIMENSIONS from one table with METRICS from any table
--    - Multiple METRICS together (without dimensions)
--    - But cannot use FACTS and METRICS in same query
--
-- 4. WHERE clauses work on dimensions that exist
--
-- For more details: https://docs.snowflake.com/en/user-guide/views-semantic/querying
-- ============================================================================
