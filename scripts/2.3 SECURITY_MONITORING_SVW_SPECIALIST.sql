-- Security Monitoring Semantic View - Using ACCOUNT_USAGE.LOGIN_HISTORY directly
-- Based on https://docs.snowflake.com/en/sql-reference/account-usage/login_history
-- No helper views needed - query Account Usage directly

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.TOOLS;

CREATE OR REPLACE SEMANTIC VIEW 
    SNOWFLAKE_INTELLIGENCE.TOOLS.SECURITY_MONITORING_SVW
TABLES (
  login AS SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
)
-- DIMENSIONS: Categorical attributes from LOGIN_HISTORY
-- Note: Aliases must not conflict with column name parsing
DIMENSIONS (
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
  login.CONNECTION AS connection COMMENT='Connection name used'
)
-- METRICS: Aggregated security measures
METRICS (
  login.total_login_attempts AS COUNT(*) COMMENT='Total login attempts',
  login.failed_attempts AS COUNT(CASE WHEN IS_SUCCESS = 'NO' THEN 1 END) COMMENT='Failed login count',
  login.successful_attempts AS COUNT(CASE WHEN IS_SUCCESS = 'YES' THEN 1 END) COMMENT='Successful login count',
  login.unique_users AS COUNT(DISTINCT USER_NAME) COMMENT='Distinct users',
  login.unique_ips AS COUNT(DISTINCT CLIENT_IP) COMMENT='Distinct IP addresses',
  login.mfa_usage AS COUNT(CASE WHEN SECOND_AUTHENTICATION_FACTOR IS NOT NULL THEN 1 END) COMMENT='Logins using MFA',
  login.users_with_failures AS COUNT(DISTINCT CASE WHEN IS_SUCCESS = 'NO' THEN USER_NAME END) COMMENT='Users with failed attempts',
  login.ips_with_failures AS COUNT(DISTINCT CASE WHEN IS_SUCCESS = 'NO' THEN CLIENT_IP END) COMMENT='IPs with failed attempts',
  login.success_rate_pct AS (
    CAST(COUNT(CASE WHEN IS_SUCCESS = 'YES' THEN 1 END) AS FLOAT) * 100.0 / NULLIF(COUNT(*), 0)
  ) COMMENT='Success rate percentage',
  login.mfa_adoption_pct AS (
    CAST(COUNT(CASE WHEN SECOND_AUTHENTICATION_FACTOR IS NOT NULL THEN 1 END) AS FLOAT) * 100.0 / 
    NULLIF(COUNT(CASE WHEN IS_SUCCESS = 'YES' THEN 1 END), 0)
  ) COMMENT='Percentage of successful logins using MFA'
)
COMMENT='Security monitoring using ACCOUNT_USAGE.LOGIN_HISTORY. Tracks all login attempts, failures, MFA usage, and authentication patterns from the last 365 days.'
WITH EXTENSION (CA='{"tables":[
  {"name":"login","description":"Login history from ACCOUNT_USAGE (last 365 days with up to 2 hour latency). Includes authentication details, MFA status, client information, and success/failure data."}
],"verified_queries":[
  {
    "name":"Failed Login Count",
    "question":"How many failed login attempts are there?",
    "sql":"SELECT failed_attempts, users_with_failures, ips_with_failures FROM SECURITY_MONITORING_SVW"
  },
  {
    "name":"Login Success Rate",
    "question":"What is the login success rate?",
    "sql":"SELECT success_rate_pct, total_login_attempts, successful_attempts, failed_attempts FROM SECURITY_MONITORING_SVW"
  },
  {
    "name":"MFA Adoption",
    "question":"What percentage of users use MFA?",
    "sql":"SELECT mfa_adoption_pct, mfa_usage, successful_attempts FROM SECURITY_MONITORING_SVW"
  },
  {
    "name":"Failed Logins by User",
    "question":"Which users have failed login attempts?",
    "sql":"SELECT user_name, COUNT(*) as failures FROM SECURITY_MONITORING_SVW WHERE is_success = ''NO'' GROUP BY user_name ORDER BY failures DESC"
  },
  {
    "name":"Failed Logins by IP",
    "question":"Which IP addresses have the most failures?",
    "sql":"SELECT client_ip, COUNT(*) as failures FROM SECURITY_MONITORING_SVW WHERE is_success = ''NO'' GROUP BY client_ip ORDER BY failures DESC"
  },
  {
    "name":"Recent Failed Logins",
    "question":"Show me recent failed login attempts",
    "sql":"SELECT user_name, client_ip, event_time, error_code, error_message FROM SECURITY_MONITORING_SVW WHERE is_success = ''NO'' ORDER BY event_time DESC LIMIT 20"
  },
  {
    "name":"Authentication Methods",
    "question":"What authentication methods are being used?",
    "sql":"SELECT first_auth_factor, COUNT(*) as usage_count FROM SECURITY_MONITORING_SVW GROUP BY first_auth_factor ORDER BY usage_count DESC"
  }
]}');

GRANT SELECT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.SECURITY_MONITORING_SVW TO ROLE PUBLIC;

