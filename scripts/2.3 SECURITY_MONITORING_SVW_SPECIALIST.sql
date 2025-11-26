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
-- KEY LEARNING: Use exact column names (lowercase) as aliases!
-- ============================================================================

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.TOOLS;

CREATE OR REPLACE SEMANTIC VIEW 
    SNOWFLAKE_INTELLIGENCE.TOOLS.SECURITY_MONITORING_SVW
TABLES (
  login AS SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY,
  sessions AS SNOWFLAKE.ACCOUNT_USAGE.SESSIONS,
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
  sessions.CLOSED_REASON AS closed_reason COMMENT='Reason for session closure (NULL if active)'
  
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

GRANT SELECT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.SECURITY_MONITORING_SVW TO ROLE PUBLIC;

