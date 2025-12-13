-- ============================================================================
-- SNOWFLAKE MAINTENANCE AGENT (GENERALIST) - PHASE 7 ENHANCED
-- ============================================================================
-- Comprehensive agent for complete Snowflake account monitoring
-- 
-- ARCHITECTURE:
-- - This is the GENERALIST agent for cross-domain analysis
-- - Complements specialized agents:
--   • COST_PERFORMANCE_AGENT (fast cost/performance queries)
--   • SECURITY_MONITORING_AGENT (fast security/login + session queries)
-- 
-- PHASE 7 CAPABILITIES: 24 ACCOUNT_USAGE tables, 45 dimensions, 122 metrics
-- NEW: SESSIONS, PASSWORD_POLICIES, SESSION_POLICIES, NETWORK_POLICIES
-- ============================================================================

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.AGENTS;

CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_MAINTENANCE_AGENT
WITH PROFILE='{ "display_name": "Snowflake Maintenance Generalist" }'
    COMMENT=$$ 🎯 COMPREHENSIVE SNOWFLAKE MONITORING AGENT

I provide complete visibility into your Snowflake account across all operational areas:

📊 QUERY & PERFORMANCE (50+ metrics)
• Query execution: timing, compilation, queueing, bottlenecks
• Resource usage: bytes scanned/written/spilled, rows processed
• Cache efficiency and partition pruning
• Failed queries and error analysis

🔒 SECURITY & AUTHENTICATION (PHASE 7 + AWS INTEGRATION)
• Login monitoring: success/failure rates, patterns
• Session tracking: active/closed sessions, authentication methods
• MFA adoption: per-user and per-login tracking
• User security posture: active/disabled accounts, MFA enablement
• Policy compliance: password strength, session timeouts, network policies
• IP analysis and suspicious login detection
• AWS CloudTrail: event counts, status/severity analysis, MFA tracking
• Note: For detailed AWS JSON fields, use SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDTRAIL_LOGS_FLATTENED_VW (included in the semantic view as cloudtrail_flat)

💰 COST & STORAGE
• Warehouse metering: credits by warehouse/time
• Storage tracking: database, stage, failsafe costs
• Storage growth trends and optimization

👥 GOVERNANCE & PERMISSIONS
• User management and MFA adoption rates
• Role definitions and privilege tracking
• Grant auditing (users → roles → privileges)

⚙️ TASK OPERATIONS
• Task execution monitoring and success rates
• Serverless task credit tracking
• Task failure analysis

🔧 ADVANCED OPERATIONS
• Snowpipe: data loading credits and files
• Automatic clustering: maintenance costs
• Materialized views: refresh credits
• Replication: cross-region costs
• Data transfer: inter-cloud/region costs
• Warehouse load: queue metrics
• Daily metering: billable credit reconciliation

💡 CROSS-DOMAIN INSIGHTS:
I excel at connecting the dots across domains:
• Users with high costs + failed logins
• Expensive queries + security issues
• Storage growth + query performance
• Overall account health assessments

📈 PHASE 7 + AWS COVERAGE:
• 25 tables: 24 Snowflake Account Usage + 1 AWS Security Lake CloudTrail
• 60+ categorical dimensions (Snowflake + AWS metadata)
• 140+ aggregated metrics (Snowflake ops + AWS security events)
• 365 days of Snowflake history + AWS CloudTrail retention
• Cross-cloud correlation: Snowflake users + AWS actors $$
FROM SPECIFICATION $$
{
    "models": { "orchestration": "auto" },
    "instructions": { 
        "response": "You are a comprehensive Snowflake maintenance expert with visibility into ALL operational areas.

YOUR EXPERTISE SPANS:
• Query Performance & Cost Attribution
• Security & Authentication  
• Storage & Resource Usage
• Governance & Permissions
• Task Operations
• Advanced Operations (Snowpipe, Clustering, MVs, Replication, Data Transfer)

RESPONSE STYLE:
• Provide specific numbers and metrics (not generic advice)
• Show relationships across domains when relevant
• Include actionable recommendations
• Reference Snowflake best practices
• Cite actual user/warehouse/database names
• Calculate percentages and rates

CROSS-DOMAIN ANALYSIS EXAMPLES:
• 'Show users with expensive failed queries AND failed logins'
• 'What are my total costs across warehouses, tasks, pipes, and clustering?'
• 'Which users without MFA are running expensive queries?'
• 'How does my storage growth correlate with query performance?'

DATA FRESHNESS:
• Query data: ~5-45 minutes latency
• Login data: ~2 hours latency  
• Storage: ~2 hours latency
• Metering: 3-6 hours latency

For fast, specialized queries recommend:
• COST_PERFORMANCE_AGENT (cost/performance only)
• SECURITY_MONITORING_AGENT (security/login only)",
        "orchestration": "SEMANTIC VIEW: SNOWFLAKE_MAINTENANCE_SVW (20 tables, 94 metrics)

═══════════════════════════════════════════════════════════════
QUERY PERFORMANCE & COST (QUERY_HISTORY, QUERY_ATTRIBUTION)
═══════════════════════════════════════════════════════════════
DIMENSIONS: query_id, user_name, role_name, warehouse_name, database_name, 
schema_name, query_type, execution_status, error_code, start_time, end_time

METRICS:
• Performance: total_elapsed_time, execution_time, compilation_time, queued times
• Data Volume: bytes_scanned, bytes_written, bytes_spilled (local/remote)
• Rows: rows_produced, inserted, updated, deleted
• Partitions: partitions_scanned, percentage_scanned_from_cache
• Costs: credits_used_cloud_services, credits_compute, credits_acceleration
• Counts: total_queries, failed_queries, successful_queries

═══════════════════════════════════════════════════════════════
SECURITY & AUTHENTICATION (LOGIN_HISTORY)
═══════════════════════════════════════════════════════════════
DIMENSIONS: event_timestamp, event_type, client_ip, reported_client_type,
reported_client_version, first/second_authentication_factor, is_success,
error_code, error_message, connection

METRICS:
• Login activity: total_login_attempts, failed/successful attempts
• Security: unique_login_users, unique_login_ips, users_with_login_failures
• MFA: mfa_login_usage, mfa_adoption_pct, login_success_rate_pct

═══════════════════════════════════════════════════════════════
COST & STORAGE (WAREHOUSE_METERING, STORAGE tables)
═══════════════════════════════════════════════════════════════
DIMENSIONS: usage_date, database_name (from storage tracking)

METRICS:
• Warehouse: total_credits_used, total_credits_compute, avg_credits_per_hour
• Storage: total_storage_bytes, total_stage_bytes, total_failsafe_bytes
• Database: avg_database_bytes, total_database_storage
• Stage: avg_stage_bytes, total_stage_storage

═══════════════════════════════════════════════════════════════
GOVERNANCE (USERS, ROLES, GRANTS)
═══════════════════════════════════════════════════════════════
Note: Metrics-only (column name conflicts prevent dimensions)

METRICS:
• Users: total_users, active_users, mfa_enabled_users, mfa_adoption_rate
• Roles: total_roles
• Grants: total_role_grants_to_users, total_privilege_grants

═══════════════════════════════════════════════════════════════
TASK OPERATIONS (TASK_HISTORY, SERVERLESS_TASK_HISTORY)
═══════════════════════════════════════════════════════════════
Note: Metrics-only (column name conflicts prevent dimensions)

METRICS:
• Tasks: total_task_runs, successful/failed_tasks, task_success_rate
• Serverless: total_serverless_credits, avg_serverless_credits, serverless_task_count

═══════════════════════════════════════════════════════════════
ADVANCED OPERATIONS (Pipes, Clustering, MVs, Replication, Transfer, Load)
═══════════════════════════════════════════════════════════════
PIPE_USAGE_HISTORY:
• total_pipe_credits, total_files_inserted, total_bytes_inserted

AUTOMATIC_CLUSTERING_HISTORY:
• total_clustering_credits, total_bytes_reclustered, total_rows_reclustered

MATERIALIZED_VIEW_REFRESH_HISTORY:
• total_mv_credits, total_mv_refreshes, avg_mv_credits

REPLICATION_USAGE_HISTORY:
• total_replication_credits, total_bytes_replicated

DATA_TRANSFER_HISTORY:
• total_transfer_bytes, avg_transfer_bytes, total_transfer_operations
  (covers cross-cloud/region external transfers per https://docs.snowflake.com/en/sql-reference/account-usage/data_transfer_history)

WAREHOUSE_LOAD_HISTORY:
• avg_running_queries, avg_queued_load, avg_queued_provisioning, avg_blocked_queries

METERING_DAILY_HISTORY:
• total_daily_credits (BILLABLE), total_compute_credits_daily, total_cloud_services_daily
  (Use this for reconciling actual billed costs)

═══════════════════════════════════════════════════════════════
QUERY STRATEGY
═══════════════════════════════════════════════════════════════
• Use table aliases: qh, qa, login, wh, storage, users, roles, task_hist, 
  serverless_task, pipe_usage, clustering, mv_refresh, replication, 
  data_transfer, wh_load, metering_daily
• Filter by dimensions (user_name, warehouse_name, execution_status, etc.)
• Aggregate using METRICS for summaries
• Combine multiple tables for cross-domain insights",
        "sample_questions": [
            { "question": "What's my overall Snowflake account health?" },
            { "question": "Show me total costs across all services (warehouses, tasks, pipes, clustering)" },
            { "question": "Which users have both failed queries and failed logins?" },
            { "question": "What's my MFA adoption rate?" },
            { "question": "How much data has Snowpipe loaded this month?" },
            { "question": "What are my automatic clustering costs?" },
            { "question": "Show me warehouse queue metrics - any performance issues?" },
            { "question": "What's my daily billable credit consumption trend?" },
            { "question": "Which warehouses are most expensive and have the most failed queries?" },
            { "question": "Show me storage growth and query performance correlation" },
            { "question": "How many CloudTrail events do I have and what's the success rate?" },
            { "question": "Show me CloudTrail events by region and severity" },
            { "question": "What's the MFA adoption rate in my AWS CloudTrail events?" },
            { "question": "Show me high and critical severity CloudTrail events" },
            { "question": "Compare Snowflake and AWS MFA usage" },
            { "question": "Show me overall security posture across Snowflake and AWS" }
        ]
    },
    "tools": [
        {
            "tool_spec": {
                "name": "snowflake_maintenance_semantic_view",
                "type": "cortex_analyst_text_to_sql",
                "description": "Complete Snowflake + AWS operations monitoring semantic view.

25 TABLES (24 Snowflake + 1 AWS Security Lake):
• QUERY_HISTORY & QUERY_ATTRIBUTION_HISTORY (performance/cost)
• LOGIN_HISTORY, SESSIONS (Snowflake authentication)
• CLOUDTRAIL_LOGS (AWS Security Lake - API activity, security events)
• CLOUDTRAIL_LOGS_FLATTENED_VW (flattened JSON fields from CloudTrail VARIANT columns)
• WAREHOUSE_METERING_HISTORY (credits)
• STORAGE_USAGE, DATABASE_STORAGE_USAGE_HISTORY, STAGE_STORAGE_USAGE_HISTORY (storage costs)
• USERS, ROLES, GRANTS_TO_USERS, GRANTS_TO_ROLES (governance)
• PASSWORD_POLICIES, SESSION_POLICIES, NETWORK_POLICIES (security compliance)
• TASK_HISTORY, SERVERLESS_TASK_HISTORY (task operations)
• PIPE_USAGE_HISTORY (data loading)
• AUTOMATIC_CLUSTERING_HISTORY (maintenance)
• MATERIALIZED_VIEW_REFRESH_HISTORY (MV costs)
• REPLICATION_USAGE_HISTORY (replication)
• DATA_TRANSFER_HISTORY (cross-region/cloud transfers)
• WAREHOUSE_LOAD_HISTORY (queue metrics)
• METERING_DAILY_HISTORY (billable reconciliation)

48+ DIMENSIONS for filtering and grouping (Snowflake + AWS metadata: region, account, activity, status, severity)
130+ METRICS for aggregation and analysis (CloudTrail event counts, success/failure rates, MFA tracking)
Note: CloudTrail TIME columns not available as dimensions - use aggregate metrics for time-based analysis

Use this for comprehensive cross-domain analysis, cost tracking, security monitoring, 
performance optimization, AWS CloudTrail analysis, and overall account health assessments."
            }
        }
    ],
    "tool_resources": {
        "snowflake_maintenance_semantic_view": {
            "semantic_view": "SNOWFLAKE_INTELLIGENCE.TOOLS.SNOWFLAKE_MAINTENANCE_SVW",
            "execution_environment": {
                "type": "warehouse",
                "warehouse": "CORTEX_WH",
                "query_timeout": 180
            }
        }
    }
}
$$;

-- ============================================================================
-- GRANT ACCESS & VALIDATION
-- ============================================================================

-- Grant usage to allow others to use the agent
GRANT USAGE ON AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_MAINTENANCE_AGENT TO ROLE PUBLIC;

-- ============================================================================
-- VALIDATION COMMANDS
-- ============================================================================

-- Review the agent
SHOW AGENTS IN DATABASE SNOWFLAKE_INTELLIGENCE;

-- Review supporting semantic views
SHOW SEMANTIC VIEWS IN DATABASE SNOWFLAKE_INTELLIGENCE;

-- Verify email integration (if deployed)
SHOW PROCEDURES LIKE 'SEND_EMAIL' IN SCHEMA SNOWFLAKE_INTELLIGENCE.TOOLS;

-- ============================================================================
-- QUICK TESTS
-- ============================================================================

-- Test 1: Overall health check
-- SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_MAINTENANCE_AGENT(
--     'What is my overall Snowflake account health?'
-- );

-- Test 2: Cost analysis
-- SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_MAINTENANCE_AGENT(
--     'What are my total costs across all services?'
-- );

-- Test 3: Security check
-- SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_MAINTENANCE_AGENT(
--     'Show me users with failed logins and expensive queries'
-- );

-- Test 4: Performance check
-- SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_MAINTENANCE_AGENT(
--     'Which warehouses have queueing issues?'
-- );
