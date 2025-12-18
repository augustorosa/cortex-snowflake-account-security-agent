-- ============================================================================
-- SECURITY MONITORING SEMANTIC VIEW - PHASE 7 ENHANCED
-- ============================================================================
-- Comprehensive security monitoring using multiple ACCOUNT_USAGE tables
--
-- PHASE 7 ADDITIONS:
-- - SESSIONS: Active session monitoring and tracking
-- - USERS: For MFA correlation and user security posture  
-- - PASSWORD_POLICIES: Password strength requirements (metrics-only)
-- - SESSION_POLICIES: Session timeout policies (metrics-only)
-- - NETWORK_POLICIES: IP whitelisting (metrics-only)
--
-- PREREQUISITES (run in order):
--   1. scripts/6.1 SECURITY_SOURCES_CREATE_AND_SEED.sql (Cloudflare + CrowdStrike sources)
--   2. scripts/6.5 KUBERNETES_AUDIT_CREATE_AND_SEED.sql (Kubernetes source)
--   3. scripts/6.7 NPM_SUPPLY_CHAIN_CREATE_AND_SEED.sql (npm source)
--   4. scripts/6.2 SECURITY_SOURCES_GENERATE_SYNTHETIC_DATA.sql (creates *_SYNTH tables)
--   5. scripts/6.3 FLATTENED_CLOUDFLARE_LOGS_VIEWS.sql (Cloudflare flatten)
--   6. scripts/6.6 FLATTENED_KUBERNETES_AUDIT_VIEWS.sql (Kubernetes flatten)
--   7. scripts/6.8 FLATTENED_NPM_SUPPLY_CHAIN_VIEWS.sql (npm flatten)
--   8. scripts/6.4 SECURITY_SOURCES_HELPER_VIEWS.sql (creates helper views for semantic view)
--   9. scripts/2.1B FLATTENED_CLOUDTRAIL_LOGS_VIEWS.sql (optional, if CloudTrail exists)
--
-- KEY LEARNING: Use exact column names (lowercase) as aliases!
-- ============================================================================

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.TOOLS;

CREATE OR REPLACE SEMANTIC VIEW 
    SNOWFLAKE_INTELLIGENCE.TOOLS.SECURITY_MONITORING_SVW
TABLES (
  login AS SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY,
  sessions AS SNOWFLAKE.ACCOUNT_USAGE.SESSIONS,
  cloudtrail_flat AS SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDTRAIL_LOGS_FLATTENED_SVW_HELPER_VW,
  cloudflare AS SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SYNTH_SVW_HELPER_VW,
  crowdstrike AS SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SYNTH_SVW_HELPER_VW,
  kubernetes AS SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SYNTH_SVW_HELPER_VW,
  kubernetes_flat AS SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_FLATTENED_SVW_HELPER_VW,
  npm AS SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SYNTH_SVW_HELPER_VW,
  npm_flat AS SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_FLATTENED_SVW_HELPER_VW,
  users AS SNOWFLAKE.ACCOUNT_USAGE.USERS,
  pwd_policies AS SNOWFLAKE.ACCOUNT_USAGE.PASSWORD_POLICIES,
  sess_policies AS SNOWFLAKE.ACCOUNT_USAGE.SESSION_POLICIES,
  net_policies AS SNOWFLAKE.ACCOUNT_USAGE.NETWORK_POLICIES
)
-- ============================================================================
-- DIMENSIONS: Categorical attributes for filtering and grouping
-- ============================================================================
DIMENSIONS (
  -- === LOGIN HISTORY DIMENSIONS ===
  login.EVENT_TIMESTAMP AS event_timestamp COMMENT='When the login attempt occurred',
  login.EVENT_TYPE AS event_type COMMENT='Event type (LOGIN)',
  login.USER_NAME AS user_name COMMENT='User attempting login',
  login.CLIENT_IP AS client_ip COMMENT='IP address of login attempt',
  login.REPORTED_CLIENT_TYPE AS reported_client_type COMMENT='Client software type (JDBC, ODBC, etc)',
  login.REPORTED_CLIENT_VERSION AS reported_client_version COMMENT='Client software version',
  login.FIRST_AUTHENTICATION_FACTOR AS first_authentication_factor COMMENT='First authentication method',
  login.SECOND_AUTHENTICATION_FACTOR AS second_authentication_factor COMMENT='Second authentication factor (MFA)',
  login.IS_SUCCESS AS is_success COMMENT='YES if successful, NO if failed',
  login.ERROR_CODE AS error_code COMMENT='Error code if failed',
  login.ERROR_MESSAGE AS error_message COMMENT='Error message if failed',
  login.CONNECTION AS connection COMMENT='Connection name used',
  
  -- === SESSION DIMENSIONS (Using exact column names as aliases) ===
  sessions.SESSION_ID AS session_id COMMENT='Unique session identifier',
  sessions.CREATED_ON AS created_on COMMENT='Session creation timestamp',
  sessions.AUTHENTICATION_METHOD AS authentication_method COMMENT='Authentication method used for session',
  sessions.LOGIN_EVENT_ID AS login_event_id COMMENT='Related login event ID',
  sessions.CLIENT_APPLICATION_ID AS client_application_id COMMENT='Client application identifier',
  sessions.CLIENT_APPLICATION_VERSION AS client_application_version COMMENT='Client application version',
  sessions.CLIENT_ENVIRONMENT AS client_environment COMMENT='Client environment details',
  sessions.CLIENT_BUILD_ID AS client_build_id COMMENT='Client build identifier',
  sessions.CLIENT_VERSION AS client_version COMMENT='Client version',
  sessions.CLOSED_REASON AS closed_reason COMMENT='Reason for session closure (NULL if active)',
  
  -- === CLOUDTRAIL (FLATTENED HELPER) DIMENSIONS ===
  -- Note: These are pre-flattened columns (no raw JSON) with prefixed names to avoid conflicts
  cloudtrail_flat.cloudtrail_time AS cloudtrail_time COMMENT='CloudTrail event time (flattened helper)',
  cloudtrail_flat.cloudtrail_region AS cloudtrail_region COMMENT='AWS region (flattened helper)',
  cloudtrail_flat.cloudtrail_accountid AS cloudtrail_accountid COMMENT='AWS account id (flattened helper)',
  cloudtrail_flat.cloudtrail_class_name AS cloudtrail_class_name COMMENT='OCSF class name (flattened helper)',
  cloudtrail_flat.cloudtrail_activity_name AS cloudtrail_activity_name COMMENT='Activity/action name (flattened helper)',
  cloudtrail_flat.cloudtrail_type_name AS cloudtrail_type_name COMMENT='Type name (flattened helper)',
  cloudtrail_flat.cloudtrail_status AS cloudtrail_status COMMENT='Status/outcome (flattened helper)',
  cloudtrail_flat.cloudtrail_severity AS cloudtrail_severity COMMENT='Severity label (flattened helper)',
  cloudtrail_flat.cloudtrail_is_mfa AS cloudtrail_is_mfa COMMENT='Whether MFA was used (flattened helper)',
  cloudtrail_flat.cloudtrail_variant_col AS cloudtrail_variant_col COMMENT='VARIANT source column (flattened helper)',
  cloudtrail_flat.cloudtrail_json_path AS cloudtrail_json_path COMMENT='JSON path (flattened helper)',
  cloudtrail_flat.cloudtrail_json_key AS cloudtrail_json_key COMMENT='JSON key (flattened helper)',
  cloudtrail_flat.cloudtrail_json_value_type AS cloudtrail_json_value_type COMMENT='TYPEOF(JSON_VALUE) (flattened helper)',
  cloudtrail_flat.cloudtrail_is_leaf AS cloudtrail_is_leaf COMMENT='True if JSON value is scalar (flattened helper)',
  
  -- === CLOUDFLARE (SYNTHETIC HELPER) DIMENSIONS ===
  cloudflare.cloudflare_event_time AS cloudflare_event_time COMMENT='Cloudflare event timestamp (synthetic helper)',
  cloudflare.cloudflare_client_ip AS cloudflare_client_ip COMMENT='Client IP (synthetic helper)',
  cloudflare.cloudflare_client_request_host AS cloudflare_client_request_host COMMENT='Requested host (synthetic helper)',
  cloudflare.cloudflare_client_request_method AS cloudflare_client_request_method COMMENT='HTTP method (synthetic helper)',
  cloudflare.cloudflare_client_request_uri AS cloudflare_client_request_uri COMMENT='Request URI/path (synthetic helper)',
  cloudflare.cloudflare_edge_response_status AS cloudflare_edge_response_status COMMENT='Edge response status (synthetic helper)',
  cloudflare.cloudflare_client_country AS cloudflare_client_country COMMENT='Client country (synthetic helper)',
  cloudflare.cloudflare_edge_colo_code AS cloudflare_edge_colo_code COMMENT='Cloudflare colo (synthetic helper)',
  cloudflare.cloudflare_security_action AS cloudflare_security_action COMMENT='Security action (synthetic helper)',
  cloudflare.cloudflare_waf_flags AS cloudflare_waf_flags COMMENT='WAF flags (synthetic helper)',
  
  -- === CROWDSTRIKE (SYNTHETIC HELPER) DIMENSIONS ===
  crowdstrike.crowdstrike_dev_time AS crowdstrike_dev_time COMMENT='CrowdStrike event time (synthetic helper)',
  crowdstrike.crowdstrike_src_ip AS crowdstrike_src_ip COMMENT='Source IP (synthetic helper)',
  crowdstrike.crowdstrike_dst_ip AS crowdstrike_dst_ip COMMENT='Destination IP (synthetic helper)',
  crowdstrike.crowdstrike_dst_port AS crowdstrike_dst_port COMMENT='Destination port (synthetic helper)',
  crowdstrike.crowdstrike_domain AS crowdstrike_domain COMMENT='Domain (synthetic helper)',
  crowdstrike.crowdstrike_category AS crowdstrike_category COMMENT='Category (synthetic helper)',
  crowdstrike.crowdstrike_username AS crowdstrike_username COMMENT='Username (synthetic helper)',
  crowdstrike.crowdstrike_proto AS crowdstrike_proto COMMENT='Protocol (synthetic helper)',
  crowdstrike.crowdstrike_event_name AS crowdstrike_event_name COMMENT='Event name (synthetic helper)',
  
  -- === KUBERNETES AUDIT (SYNTHETIC HELPER) DIMENSIONS ===
  kubernetes.kubernetes_event_time AS kubernetes_event_time COMMENT='Kubernetes audit event time (synthetic helper)',
  kubernetes.kubernetes_hostname AS kubernetes_hostname COMMENT='Kubernetes hostname (synthetic helper)',
  kubernetes.kubernetes_level AS kubernetes_level COMMENT='Audit level (synthetic helper)',
  kubernetes.kubernetes_verb AS kubernetes_verb COMMENT='Kubernetes API verb (synthetic helper)',
  kubernetes.kubernetes_request_uri AS kubernetes_request_uri COMMENT='Kubernetes API request URI (synthetic helper)',
  kubernetes.kubernetes_username AS kubernetes_username COMMENT='Kubernetes user (synthetic helper)',
  kubernetes.kubernetes_source_ip AS kubernetes_source_ip COMMENT='Source IP (synthetic helper)',
  kubernetes.kubernetes_object_resource AS kubernetes_object_resource COMMENT='Kubernetes object resource (synthetic helper)',
  kubernetes.kubernetes_object_namespace AS kubernetes_object_namespace COMMENT='Kubernetes namespace (synthetic helper)',
  kubernetes.kubernetes_response_code AS kubernetes_response_code COMMENT='HTTP response code (synthetic helper)',
  kubernetes.kubernetes_authz_decision AS kubernetes_authz_decision COMMENT='Authorization decision (synthetic helper)',
  
  -- === KUBERNETES AUDIT (FLATTENED) DIMENSIONS ===
  kubernetes_flat.kubernetes_json_path AS kubernetes_json_path COMMENT='Flattened JSON path (k8s audit helper)',
  kubernetes_flat.kubernetes_json_key AS kubernetes_json_key COMMENT='Flattened JSON key (k8s audit helper)',
  kubernetes_flat.kubernetes_leaf_value AS kubernetes_leaf_value COMMENT='Flattened leaf value (k8s audit helper)',
  
  -- === NPM SUPPLY CHAIN (SYNTHETIC HELPER) DIMENSIONS ===
  npm.npm_event_time AS npm_event_time COMMENT='npm event time (synthetic helper)',
  npm.npm_environment AS npm_environment COMMENT='Environment (dev/ci/prod) (synthetic helper)',
  npm.npm_repository AS npm_repository COMMENT='Repository (synthetic helper)',
  npm.npm_pipeline_id AS npm_pipeline_id COMMENT='Pipeline run id (synthetic helper)',
  npm.npm_actor AS npm_actor COMMENT='Actor (bot/user) (synthetic helper)',
  npm.npm_event_type AS npm_event_type COMMENT='Event type (install/publish/runtime_alert) (synthetic helper)',
  npm.npm_package_name AS npm_package_name COMMENT='Package name (synthetic helper)',
  npm.npm_package_version AS npm_package_version COMMENT='Package version (synthetic helper)',
  npm.npm_install_command AS npm_install_command COMMENT='Install command (synthetic helper)',
  npm.npm_script_name AS npm_script_name COMMENT='Lifecycle script name (synthetic helper)',
  npm.npm_network_dest_host AS npm_network_dest_host COMMENT='Outbound dest host (synthetic helper)',
  npm.npm_indicator_type AS npm_indicator_type COMMENT='Indicator type (synthetic helper)',
  npm.npm_indicator_severity AS npm_indicator_severity COMMENT='Indicator severity (synthetic helper)',
  npm.npm_cwe_id AS npm_cwe_id COMMENT='Mapped CWE id (synthetic helper)',
  npm.npm_status AS npm_status COMMENT='Status (detected/blocked/allowed) (synthetic helper)',
  
  -- === NPM SUPPLY CHAIN (FLATTENED) DIMENSIONS ===
  npm_flat.npm_json_path AS npm_json_path COMMENT='Flattened JSON path (npm helper)',
  npm_flat.npm_json_key AS npm_json_key COMMENT='Flattened JSON key (npm helper)',
  npm_flat.npm_leaf_value AS npm_leaf_value COMMENT='Flattened leaf value (npm helper)'
  
  -- Note: USERS, PASSWORD_POLICIES, SESSION_POLICIES, NETWORK_POLICIES provide METRICS ONLY
  -- due to NAME column conflicts across tables
)
-- ============================================================================
-- METRICS: Aggregated security measures
-- ============================================================================
METRICS (
  -- === LOGIN METRICS ===
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
  
  -- === SESSION METRICS ===
  sessions.total_sessions AS COUNT(*) COMMENT='Total number of sessions',
  sessions.active_sessions AS COUNT(CASE WHEN sessions.CLOSED_REASON IS NULL THEN 1 END) COMMENT='Currently active sessions',
  sessions.closed_sessions AS COUNT(CASE WHEN sessions.CLOSED_REASON IS NOT NULL THEN 1 END) COMMENT='Closed sessions',
  sessions.unique_session_users AS COUNT(DISTINCT sessions.USER_NAME) COMMENT='Distinct users with sessions',
  sessions.unique_session_applications AS COUNT(DISTINCT sessions.CLIENT_APPLICATION_ID) COMMENT='Distinct client applications',
  sessions.avg_sessions_per_user AS (
    CAST(COUNT(*) AS FLOAT) / NULLIF(COUNT(DISTINCT sessions.USER_NAME), 0)
  ) COMMENT='Average sessions per user',
  
  -- === USER SECURITY METRICS ===
  users.total_users AS COUNT(*) COMMENT='Total number of users',
  users.active_users AS COUNT_IF(users.DISABLED IS NULL OR users.DISABLED = FALSE) COMMENT='Count of active users',
  users.disabled_users AS COUNT_IF(users.DISABLED = TRUE) COMMENT='Count of disabled users',
  users.mfa_enabled_users AS COUNT_IF(users.HAS_MFA = TRUE) COMMENT='Users with MFA enabled',
  users.mfa_disabled_users AS COUNT_IF(users.HAS_MFA = FALSE OR users.HAS_MFA IS NULL) COMMENT='Users without MFA',
  users.user_mfa_adoption_rate AS (
    CAST(COUNT_IF(users.HAS_MFA = TRUE) AS FLOAT) * 100.0 / NULLIF(COUNT(*), 0)
  ) COMMENT='Percentage of users with MFA enabled',
  
  -- === CLOUDTRAIL (FLATTENED HELPER) METRICS ===
  cloudtrail_flat.cloudtrail_events AS COUNT(*) COMMENT='Total CloudTrail flattened rows (helper)',
  cloudtrail_flat.cloudtrail_leaf_values AS COUNT_IF(cloudtrail_flat.cloudtrail_is_leaf) COMMENT='Flattened rows that are scalar leaf values (helper)',
  cloudtrail_flat.cloudtrail_unique_paths AS COUNT(DISTINCT cloudtrail_flat.cloudtrail_json_path) COMMENT='Distinct JSON paths seen (helper)',
  cloudtrail_flat.cloudtrail_failed_events AS COUNT_IF(cloudtrail_flat.cloudtrail_status != 'Success') COMMENT='Non-success CloudTrail outcomes (helper)',
  cloudtrail_flat.cloudtrail_mfa_events AS COUNT_IF(cloudtrail_flat.cloudtrail_is_mfa = TRUE) COMMENT='Events with MFA used (helper)',
  
  -- === CLOUDFLARE (SYNTHETIC HELPER) METRICS ===
  cloudflare.cloudflare_event_count AS COUNT(*) COMMENT='Total Cloudflare events (synthetic helper)',
  cloudflare.cloudflare_2xx_count AS COUNT_IF(cloudflare.cloudflare_edge_response_status BETWEEN 200 AND 299) COMMENT='2xx responses (synthetic helper)',
  cloudflare.cloudflare_block_count AS COUNT_IF(cloudflare.cloudflare_edge_response_status IN (401,403)) COMMENT='Blocked/unauthorized responses (synthetic helper)',
  cloudflare.cloudflare_5xx_count AS COUNT_IF(cloudflare.cloudflare_edge_response_status >= 500) COMMENT='5xx responses (synthetic helper)',
  cloudflare.cloudflare_edge_bytes AS SUM(cloudflare.cloudflare_edge_response_bytes) COMMENT='Total edge response bytes (synthetic helper)',
  cloudflare.cloudflare_unique_client_ips AS COUNT(DISTINCT cloudflare.cloudflare_client_ip) COMMENT='Distinct client IPs (synthetic helper)',
  
  -- === CROWDSTRIKE (SYNTHETIC HELPER) METRICS ===
  crowdstrike.crowdstrike_event_count AS COUNT(*) COMMENT='Total CrowdStrike events (synthetic helper)',
  crowdstrike.crowdstrike_unique_src_ips AS COUNT(DISTINCT crowdstrike.crowdstrike_src_ip) COMMENT='Distinct source IPs (synthetic helper)',
  crowdstrike.crowdstrike_unique_users AS COUNT(DISTINCT crowdstrike.crowdstrike_username) COMMENT='Distinct usernames (synthetic helper)',
  crowdstrike.crowdstrike_suspicious_events AS COUNT_IF(crowdstrike.crowdstrike_event_name ILIKE '%suspicious%') COMMENT='Events labeled suspicious (synthetic helper)',
  crowdstrike.crowdstrike_high_risk_ports AS COUNT_IF(crowdstrike.crowdstrike_dst_port IN (22,3389)) COMMENT='Events targeting high-risk ports (22,3389) (synthetic helper)',
  
  -- === KUBERNETES AUDIT (SYNTHETIC HELPER) METRICS ===
  kubernetes.kubernetes_audit_event_count AS COUNT(*) COMMENT='Total Kubernetes audit events (synthetic helper)',
  kubernetes.kubernetes_forbidden_count AS COUNT_IF(kubernetes.kubernetes_response_code = 403) COMMENT='Forbidden (403) Kubernetes audit events (synthetic helper)',
  kubernetes.kubernetes_secret_events AS COUNT_IF(kubernetes.kubernetes_object_resource = 'secrets') COMMENT='Kubernetes audit events involving secrets (synthetic helper)',
  kubernetes.kubernetes_delete_events AS COUNT_IF(kubernetes.kubernetes_verb = 'delete') COMMENT='Kubernetes delete operations (synthetic helper)',
  kubernetes.kubernetes_admin_events AS COUNT_IF(kubernetes.kubernetes_username = 'admin') COMMENT='Kubernetes events performed by admin (synthetic helper)',
  
  -- === KUBERNETES AUDIT (FLATTENED) METRICS ===
  kubernetes_flat.kubernetes_flat_row_count AS COUNT(*) COMMENT='Total flattened Kubernetes audit rows (helper)',
  kubernetes_flat.kubernetes_unique_paths AS COUNT(DISTINCT kubernetes_flat.kubernetes_json_path) COMMENT='Distinct Kubernetes audit JSON paths (helper)',
  
  -- === NPM SUPPLY CHAIN (SYNTHETIC HELPER) METRICS ===
  npm.npm_event_count AS COUNT(*) COMMENT='Total npm supply-chain events (synthetic helper)',
  npm.npm_critical_count AS COUNT_IF(npm.npm_indicator_severity = 'critical') COMMENT='Critical npm indicators (synthetic helper)',
  npm.npm_high_count AS COUNT_IF(npm.npm_indicator_severity = 'high') COMMENT='High severity npm indicators (synthetic helper)',
  npm.npm_typosquat_count AS COUNT_IF(npm.npm_indicator_type = 'typosquat') COMMENT='Typosquatting-like npm events (synthetic helper)',
  npm.npm_outbound_c2_count AS COUNT_IF(npm.npm_indicator_type = 'outbound_c2') COMMENT='Outbound C2-like npm events (synthetic helper)',
  npm.npm_unique_packages AS COUNT(DISTINCT npm.npm_package_name) COMMENT='Distinct npm packages observed (synthetic helper)',
  npm.npm_cwe_829_count AS COUNT_IF(npm.npm_cwe_id = 'CWE-829') COMMENT='Events mapped to CWE-829 (untrusted dependency) (synthetic helper)',
  
  -- === NPM SUPPLY CHAIN (FLATTENED) METRICS ===
  npm_flat.npm_flat_row_count AS COUNT(*) COMMENT='Total flattened npm JSON rows (helper)',
  npm_flat.npm_unique_paths AS COUNT(DISTINCT npm_flat.npm_json_path) COMMENT='Distinct npm JSON paths (helper)',
  
  -- === PASSWORD POLICY METRICS ===
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
  ) COMMENT='Policies meeting strong password criteria (12+ chars, mixed case, numbers, symbols)',
  
  -- === SESSION POLICY METRICS ===
  sess_policies.total_session_policies AS COUNT(*) COMMENT='Total session policies defined',
  sess_policies.active_session_policies AS COUNT_IF(sess_policies.DELETED IS NULL) COMMENT='Active session policies',
  sess_policies.avg_idle_timeout_mins AS AVG(sess_policies.SESSION_IDLE_TIMEOUT_MINS) COMMENT='Average session idle timeout in minutes',
  sess_policies.avg_ui_idle_timeout_mins AS AVG(sess_policies.SESSION_UI_IDLE_TIMEOUT_MINS) COMMENT='Average UI idle timeout in minutes',
  sess_policies.policies_with_idle_timeout AS COUNT_IF(sess_policies.SESSION_IDLE_TIMEOUT_MINS > 0) COMMENT='Policies with idle timeout configured',
  
  -- === NETWORK POLICY METRICS ===
  net_policies.total_network_policies AS COUNT(*) COMMENT='Total network policies defined',
  net_policies.active_network_policies AS COUNT_IF(net_policies.DELETED IS NULL) COMMENT='Active network policies',
  net_policies.policies_with_allowed_ips AS COUNT_IF(net_policies.ALLOWED_IP_LIST IS NOT NULL) COMMENT='Policies with IP whitelist',
  net_policies.policies_with_blocked_ips AS COUNT_IF(net_policies.BLOCKED_IP_LIST IS NOT NULL) COMMENT='Policies with IP blacklist'
)
COMMENT='Phase 7 Enhanced Security Monitoring: Comprehensive security posture across logins, sessions, users, and policies. Tracks authentication patterns, MFA adoption, active sessions, password/session/network policy compliance from 6 ACCOUNT_USAGE tables.'

WITH EXTENSION (CA='{"tables":[
  {
    "name":"login",
    "description":"Login history from ACCOUNT_USAGE (last 365 days with up to 2 hour latency). Includes authentication details, MFA status, client information, and success/failure data."
  },
  {
    "name":"sessions",
    "description":"Active and historical session data from ACCOUNT_USAGE (last 365 days). Tracks session creation, authentication methods, client details, and session closure reasons."
  },
  {
    "name":"users",
    "description":"User account information from ACCOUNT_USAGE. Includes MFA enablement status, email, default settings, and account status."
  },
  {
    "name":"pwd_policies",
    "description":"Password policy definitions from ACCOUNT_USAGE. Tracks password strength requirements, expiration rules, and complexity settings."
  },
  {
    "name":"sess_policies",
    "description":"Session policy definitions from ACCOUNT_USAGE. Tracks session timeout configurations and UI idle timeout settings."
  },
  {
    "name":"net_policies",
    "description":"Network policy definitions from ACCOUNT_USAGE. Tracks IP whitelists and blacklists for network access control."
  }
],"verified_queries":[
  {
    "name":"Failed Login Summary",
    "question":"Show me failed login attempts summary",
    "sql":"SELECT failed_login_attempts, users_with_login_failures, ips_with_login_failures, login_success_rate_pct FROM login"
  },
  {
    "name":"MFA Adoption Overview",
    "question":"What is our MFA adoption rate?",
    "sql":"SELECT mfa_adoption_pct, mfa_login_usage, total_login_attempts, user_mfa_adoption_rate, mfa_enabled_users, total_users FROM login, users"
  },
  {
    "name":"Active Sessions Count",
    "question":"How many active sessions do we have?",
    "sql":"SELECT active_sessions, closed_sessions, total_sessions, unique_session_users FROM sessions"
  },
  {
    "name":"Session Activity by User",
    "question":"Show me session activity by user",
    "sql":"SELECT user_name, COUNT(*) as session_count FROM sessions GROUP BY user_name ORDER BY session_count DESC LIMIT 10"
  },
  {
    "name":"Failed Logins by IP",
    "question":"Which IPs have the most failed login attempts?",
    "sql":"SELECT client_ip, COUNT(*) as failures FROM login WHERE is_success = ''NO'' GROUP BY client_ip ORDER BY failures DESC LIMIT 10"
  },
  {
    "name":"Recent Failed Logins",
    "question":"Show me recent failed login attempts with details",
    "sql":"SELECT event_timestamp, user_name, client_ip, error_code, error_message, reported_client_type FROM login WHERE is_success = ''NO'' ORDER BY event_timestamp DESC LIMIT 20"
  },
  {
    "name":"Password Policy Compliance",
    "question":"How many strong password policies do we have?",
    "sql":"SELECT strong_password_policies, active_password_policies, avg_min_password_length, policies_with_expiration FROM pwd_policies"
  },
  {
    "name":"Session Timeout Configuration",
    "question":"What are our session timeout settings?",
    "sql":"SELECT avg_idle_timeout_mins, avg_ui_idle_timeout_mins, active_session_policies FROM sess_policies"
  },
  {
    "name":"Network Policy Overview",
    "question":"How many network policies are configured?",
    "sql":"SELECT active_network_policies, policies_with_allowed_ips, policies_with_blocked_ips FROM net_policies"
  },
  {
    "name":"Security Posture Dashboard",
    "question":"Give me an overall security posture summary",
    "sql":"SELECT login_success_rate_pct, mfa_adoption_pct, user_mfa_adoption_rate, active_sessions, mfa_enabled_users, total_users, active_password_policies, active_network_policies FROM login, sessions, users, pwd_policies, net_policies"
  },
  {
    "name":"Users Without MFA",
    "question":"How many users don''t have MFA enabled?",
    "sql":"SELECT mfa_disabled_users, total_users, user_mfa_adoption_rate FROM users"
  },
  {
    "name":"Authentication Methods",
    "question":"What authentication methods are being used?",
    "sql":"SELECT first_authentication_factor, COUNT(*) as usage_count FROM login GROUP BY first_authentication_factor ORDER BY usage_count DESC"
  }
]}');

-- Semantic views require SEMANTIC VIEW grants (not VIEW grants)
GRANT SELECT ON SEMANTIC VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.SECURITY_MONITORING_SVW TO ROLE PUBLIC;

