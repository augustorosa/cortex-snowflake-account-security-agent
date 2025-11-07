# 🔐 Login Security Helper Views - Complete Guide

**Location:** `SNOWFLAKE_INTELLIGENCE.TOOLS`  
**Total Views:** 6 specialized login security views + 1 base view  
**Data Source:** `INFORMATION_SCHEMA.LOGIN_HISTORY()` table function (last 7 days, real-time)  

---

## 📊 View Inventory

### 1. LOGIN_ACTIVITY_VW (Base View)
**Purpose:** Raw login history data from Snowflake  
**Columns:** EVENT_TYPE, USER_NAME, CLIENT_IP, REPORTED_CLIENT_TYPE, REPORTED_CLIENT_VERSION, IS_SUCCESS, ERROR_CODE, ERROR_MESSAGE, CONNECTION  
**Timeframe:** Last 7 days (real-time via table function)  

```sql
SELECT * FROM LOGIN_ACTIVITY_VW WHERE IS_SUCCESS = 'NO';
```

---

### 2. FAILED_LOGIN_SUMMARY_VW
**Purpose:** Aggregated view of failed authentication attempts  
**Use Case:** Daily security review, identify targeted accounts  

**Key Metrics:**
- Failed attempt count by user/IP/client
- Unique error codes
- Error messages aggregated
- Latest client version used

**Example Query:**
```sql
-- Show users with most failed login attempts
SELECT 
    USER_NAME,
    CLIENT_IP,
    FAILED_ATTEMPT_COUNT,
    ERROR_CODES,
    ERROR_MESSAGES
FROM FAILED_LOGIN_SUMMARY_VW
ORDER BY FAILED_ATTEMPT_COUNT DESC
LIMIT 10;
```

**Sample Output (Your Data):**
```
USER_NAME | CLIENT_IP       | FAILED_ATTEMPT_COUNT | ERROR_CODES | ERROR_MESSAGES
----------|-----------------|---------------------|-------------|------------------------
KINIAMA   | 174.95.66.197   | 2                   | ...         | INCOMING_REQUEST_BLOCKED
```

---

### 3. SUSPICIOUS_LOGIN_PATTERNS_VW ⚠️
**Purpose:** Detect potential brute force attacks and suspicious patterns  
**Use Case:** Real-time security monitoring, automated alerting  

**Risk Levels:**
- `HIGH`: 10+ failed attempts
- `MEDIUM`: 5-9 failed attempts
- `LOW`: 3-4 failed attempts
- `NORMAL`: < 3 failed attempts

**Threat Indicators:**
- "Possible Brute Force (Single User)" - Same user, 5+ failures
- "Possible Brute Force (Multiple Users, Same IP)" - 5+ users from same IP
- "Multiple Client Types (Suspicious)" - 3+ failures with different clients
- "Normal Activity" - No suspicious patterns

**Example Query:**
```sql
-- Show all HIGH and MEDIUM risk patterns
SELECT 
    USER_NAME,
    CLIENT_IP,
    FAILED_COUNT,
    RISK_LEVEL,
    THREAT_INDICATOR,
    ERROR_DETAILS
FROM SUSPICIOUS_LOGIN_PATTERNS_VW
WHERE RISK_LEVEL IN ('HIGH', 'MEDIUM')
ORDER BY FAILED_COUNT DESC;
```

---

### 4. LOGIN_SUCCESS_RATE_VW
**Purpose:** Track authentication success rates per user  
**Use Case:** Identify users with authentication issues, password problems  

**User Status Indicators:**
- `HIGH_FAILURE_RATE`: 5+ failed logins
- `MODERATE_FAILURES`: 2-4 failed logins
- `ALL_SUCCESS`: 100% success rate
- `NORMAL`: Standard activity

**Example Query:**
```sql
-- Users with authentication problems
SELECT 
    USER_NAME,
    TOTAL_ATTEMPTS,
    SUCCESSFUL_LOGINS,
    FAILED_LOGINS,
    SUCCESS_RATE_PCT,
    UNIQUE_IP_COUNT,
    CLIENT_TYPES_USED,
    USER_STATUS
FROM LOGIN_SUCCESS_RATE_VW
WHERE USER_STATUS IN ('HIGH_FAILURE_RATE', 'MODERATE_FAILURES')
ORDER BY FAILED_LOGINS DESC;
```

**Your Current Status:**
```
USER_NAME | TOTAL_ATTEMPTS | SUCCESS_RATE | FAILED_LOGINS | USER_STATUS
----------|----------------|--------------|---------------|-------------------
KINIAMA   | 29             | 89.66%       | 3             | MODERATE_FAILURES
```

---

### 5. LOGIN_IP_ANALYSIS_VW
**Purpose:** Analyze login attempts by IP address  
**Use Case:** Identify suspicious IPs, unusual geographic patterns  

**IP Risk Levels:**
- `MULTIPLE_USERS_HIGH_RISK`: 5+ different users from same IP
- `HIGH_FAILURE_COUNT`: 5+ failed attempts from IP
- `MULTIPLE_CLIENT_TYPES`: 3+ different client types
- `NORMAL`: Standard activity

**Example Query:**
```sql
-- Suspicious IP addresses
SELECT 
    CLIENT_IP,
    TOTAL_ATTEMPTS,
    UNIQUE_USERS,
    FAILED_ATTEMPTS,
    FAILURE_RATE_PCT,
    IP_RISK_LEVEL,
    USERS_ATTEMPTED
FROM LOGIN_IP_ANALYSIS_VW
WHERE IP_RISK_LEVEL != 'NORMAL'
ORDER BY FAILED_ATTEMPTS DESC;
```

---

### 6. LOGIN_CLIENT_ANALYSIS_VW
**Purpose:** Track which client applications are being used  
**Use Case:** Identify unauthorized client types, outdated versions  

**Client Status:**
- `OUTDATED_VERSION`: SnowSQL < 1.3.0
- `UNKNOWN_CLIENT`: Unrecognized client type
- `CUSTOM_CLIENT`: Custom/non-standard clients
- `STANDARD_CLIENT`: Approved clients

**Example Query:**
```sql
-- Audit client applications
SELECT 
    REPORTED_CLIENT_TYPE,
    REPORTED_CLIENT_VERSION,
    LOGIN_COUNT,
    UNIQUE_USERS,
    SUCCESS_RATE_PCT,
    CLIENT_STATUS,
    USERS
FROM LOGIN_CLIENT_ANALYSIS_VW
WHERE CLIENT_STATUS != 'STANDARD_CLIENT'
ORDER BY LOGIN_COUNT DESC;
```

---

### 7. LOGIN_SECURITY_DASHBOARD_VW 📊
**Purpose:** Comprehensive security overview combining all metrics  
**Use Case:** Executive dashboard, daily security briefing  

**Metrics Provided:**
1. Total login attempts (last 7 days)
2. Successful logins count
3. Failed logins count
4. Overall success rate %
5. Unique users count
6. Unique IPs count
7. High-risk IPs count
8. Users with failures count
9. Client types count

**Example Query:**
```sql
-- Daily security summary
SELECT * FROM LOGIN_SECURITY_DASHBOARD_VW ORDER BY METRIC;
```

**Your Current Dashboard:**
```
METRIC              | VALUE | DESCRIPTION
--------------------|-------|----------------------------------------
CLIENT_TYPES        | 2     | Distinct client application types
FAILED_LOGINS       | 3     | Failed authentication attempts
SUCCESSFUL_LOGINS   | 24    | Successful authentications
SUCCESS_RATE_PCT    | 88.89 | Overall authentication success rate
TOTAL_ATTEMPTS      | 27    | Total login attempts in last 7 days
UNIQUE_IPS          | 4     | Distinct IP addresses
UNIQUE_USERS        | 1     | Distinct users with login attempts
USERS_WITH_FAILURES | 1     | Users with at least one failed login
```

---

## 🎯 Common Use Cases

### Use Case 1: Daily Security Check
```sql
-- Morning security briefing
SELECT * FROM LOGIN_SECURITY_DASHBOARD_VW;

-- Check for any high-risk patterns
SELECT * FROM SUSPICIOUS_LOGIN_PATTERNS_VW 
WHERE RISK_LEVEL IN ('HIGH', 'MEDIUM');
```

### Use Case 2: Investigate Failed Logins
```sql
-- Step 1: See which users have failures
SELECT * FROM LOGIN_SUCCESS_RATE_VW 
WHERE FAILED_LOGINS > 0
ORDER BY FAILED_LOGINS DESC;

-- Step 2: Get detailed failure info
SELECT * FROM FAILED_LOGIN_SUMMARY_VW 
WHERE USER_NAME = 'KINIAMA';

-- Step 3: Check if it's suspicious
SELECT * FROM SUSPICIOUS_LOGIN_PATTERNS_VW 
WHERE USER_NAME = 'KINIAMA';
```

### Use Case 3: IP Address Investigation
```sql
-- Find suspicious IPs
SELECT * FROM LOGIN_IP_ANALYSIS_VW 
WHERE FAILED_ATTEMPTS >= 3 OR UNIQUE_USERS >= 2
ORDER BY FAILED_ATTEMPTS DESC;

-- See all activity from specific IP
SELECT * FROM LOGIN_ACTIVITY_VW 
WHERE CLIENT_IP = '174.95.66.197'
ORDER BY EVENT_TYPE;
```

### Use Case 4: Client Application Audit
```sql
-- Check all client types in use
SELECT * FROM LOGIN_CLIENT_ANALYSIS_VW
ORDER BY LOGIN_COUNT DESC;

-- Find non-standard or outdated clients
SELECT * FROM LOGIN_CLIENT_ANALYSIS_VW
WHERE CLIENT_STATUS != 'STANDARD_CLIENT';
```

### Use Case 5: User Account Security
```sql
-- Users with authentication issues
SELECT 
    USER_NAME,
    FAILED_LOGINS,
    SUCCESS_RATE_PCT,
    UNIQUE_IP_COUNT,
    CLIENT_TYPES_USED,
    USER_STATUS
FROM LOGIN_SUCCESS_RATE_VW
WHERE FAILED_LOGINS >= 2
ORDER BY FAILED_LOGINS DESC;
```

---

## 🚨 Security Alert Scenarios

### Scenario 1: Brute Force Attack
**Detection:**
```sql
SELECT * FROM SUSPICIOUS_LOGIN_PATTERNS_VW 
WHERE THREAT_INDICATOR LIKE '%Brute Force%';
```

**Action:**
1. Check user account for compromise
2. Review IP address for blocking
3. Force password reset if needed
4. Enable MFA if not already

### Scenario 2: Multiple Failed Logins
**Detection:**
```sql
SELECT * FROM LOGIN_SUCCESS_RATE_VW 
WHERE USER_STATUS = 'HIGH_FAILURE_RATE';
```

**Action:**
1. Contact user to verify login issues
2. Check if account is locked
3. Review error messages for root cause
4. Verify user has correct credentials

### Scenario 3: Suspicious IP Activity
**Detection:**
```sql
SELECT * FROM LOGIN_IP_ANALYSIS_VW 
WHERE IP_RISK_LEVEL = 'MULTIPLE_USERS_HIGH_RISK';
```

**Action:**
1. Investigate IP geolocation
2. Verify if IP is VPN/proxy
3. Review all users from that IP
4. Consider IP allowlist/blocklist

### Scenario 4: Unknown Client Application
**Detection:**
```sql
SELECT * FROM LOGIN_CLIENT_ANALYSIS_VW 
WHERE CLIENT_STATUS IN ('UNKNOWN_CLIENT', 'CUSTOM_CLIENT');
```

**Action:**
1. Identify the client application
2. Verify if approved for use
3. Check for unauthorized API access
4. Review authentication method

---

## 🔔 Recommended Monitoring Schedule

### Real-Time (Automated Alerts)
- HIGH risk patterns from `SUSPICIOUS_LOGIN_PATTERNS_VW`
- Multiple users from same IP
- Unknown client applications

### Daily (Morning Check)
- Review `LOGIN_SECURITY_DASHBOARD_VW`
- Check for any MEDIUM/HIGH risk patterns
- Verify no high-failure-rate users

### Weekly (Security Review)
- Trend analysis of success rates
- IP address reputation review
- Client application compliance audit
- User authentication health check

### Monthly (Executive Report)
- Success rate trends
- Top failure reasons
- Geographic distribution of logins
- Client application inventory

---

## 💡 Pro Tips

1. **Baseline Your Metrics**: Run queries for a week to understand normal patterns
2. **Set Thresholds**: Customize risk levels based on your environment
3. **Automate Alerts**: Create tasks to check high-risk patterns every hour
4. **Correlate with Query History**: Join with `QUERY_HISTORY` to see what failed logins were trying to do
5. **Geographic Analysis**: Use external IP geolocation services to map login sources
6. **Combine with MFA Data**: Cross-reference with MFA logs for complete picture

---

## 🔗 Integration with AI Agent

All these views are available to query via the Cortex AI agent:

```sql
-- Ask the agent:
"Show me the login security dashboard"
"Which users have failed login attempts?"
"Are there any suspicious login patterns?"
"What client applications are being used?"
```

The agent will provide SQL to query these views or explain the security findings!

---

## 📚 Related Documentation

- [Snowflake LOGIN_HISTORY Function](https://docs.snowflake.com/en/sql-reference/functions/login_history)
- [Snowflake Account Usage Views](https://docs.snowflake.com/en/sql-reference/account-usage)
- [Snowflake Security Best Practices](https://docs.snowflake.com/en/user-guide/security-access-control)

---

**Created:** November 6, 2025  
**Last Updated:** November 6, 2025  
**Total Views:** 18 helper views (12 operational + 6 login security)  
**Data Retention:** 7 days (real-time via table function)

