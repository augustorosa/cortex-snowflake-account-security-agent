# 🔒 Snowflake Security Monitoring Use Cases

## Overview
This document outlines comprehensive security monitoring capabilities enabled by the Enhanced Security Diagnostics Semantic View and AI Agent.

---

## 🌐 External Network Access Monitoring

### Use Case 1: External Endpoint Call Tracking
**Scenario:** Monitor all outbound calls to external APIs and endpoints

**Questions you can ask:**
- "Show me all external endpoints called in the last 24 hours"
- "Which external functions are sending the most data?"
- "What failed external API calls occurred this week?"
- "Show external endpoint calls by user"
- "Which external endpoints are being called most frequently?"

**Security Value:**
- Detect data exfiltration attempts
- Monitor unauthorized external integrations
- Track API abuse or misuse
- Identify compromised external functions

**Data Source:** `EXTERNAL_ACCESS_HISTORY`

**Key Metrics:**
- `EXTERNAL_ENDPOINT` - The actual URL/endpoint accessed
- `BYTES_SENT` / `BYTES_RECEIVED` - Data volume
- `NUM_INVOCATIONS` - Call frequency
- `STATUS` - Success/failure
- `USER_NAME` / `ROLE_NAME` - Who made the call

---

### Use Case 2: Suspicious Data Transfer Detection
**Scenario:** Identify unusually large data transfers to external endpoints

**Questions you can ask:**
- "Show external calls that transferred more than 1GB"
- "Which user sent the most data to external endpoints?"
- "Alert on data transfers to non-approved domains"
- "Show overnight external API calls"

**Security Value:**
- Detect data exfiltration
- Identify compromised accounts
- Monitor insider threats
- Validate external integration policies

**Detection Logic:**
```sql
-- Example query the agent can generate:
SELECT 
    external_endpoint,
    user_name,
    SUM(bytes_sent) as total_bytes_sent,
    COUNT(*) as call_count
FROM external_access_history
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY external_endpoint, user_name
HAVING total_bytes_sent > 1073741824  -- 1GB
ORDER BY total_bytes_sent DESC
```

---

## 🛡️ Network Policy Enforcement

### Use Case 3: Network Policy Violation Detection
**Scenario:** Monitor blocked connection attempts due to network policy violations

**Questions you can ask:**
- "Show me connections blocked by network policy today"
- "Which users are trying to connect from unauthorized IPs?"
- "Show blocked connection attempts by IP address"
- "Are there repeated network policy violations?"
- "Which IP addresses should I investigate?"

**Security Value:**
- Detect unauthorized access attempts
- Identify potential attackers
- Monitor policy effectiveness
- Validate legitimate user access issues

**Data Source:** `SESSIONS.IS_CLIENT_IP_BLOCKED_BY_NETWORK_POLICY`

**Alert Triggers:**
- Multiple blocked attempts from same IP
- Blocked attempts from known user accounts
- Geographic anomalies (unusual countries)
- After-hours blocked attempts

---

### Use Case 4: Session Anomaly Detection
**Scenario:** Identify unusual session patterns that may indicate compromise

**Questions you can ask:**
- "Show sessions from unusual client applications"
- "Which users connected from new IP addresses?"
- "Show sessions with abnormally long duration"
- "Identify sessions from multiple geographic locations for same user"

**Security Value:**
- Detect account takeover
- Identify shared credentials
- Monitor for malicious tools
- Validate legitimate access patterns

**Data Source:** `SESSIONS`

**Key Indicators:**
- Unusual `CLIENT_APPLICATION` (unknown tools, custom scripts)
- Rapid IP address changes for same user
- Concurrent sessions from distant locations
- Sessions during unusual hours

---

## 🔑 Authentication & Access Control

### Use Case 5: Failed Login Analysis
**Scenario:** Track failed authentication attempts and potential brute force attacks

**Questions you can ask:**
- "Show failed login attempts in the last hour"
- "Which accounts have multiple failed logins?"
- "Show failed logins by IP address"
- "Are there any brute force attack patterns?"
- "Which users should be locked out?"

**Security Value:**
- Detect brute force attacks
- Identify credential stuffing
- Monitor account security
- Prevent unauthorized access

**Data Source:** `LOGIN_HISTORY`

**Alert Criteria:**
- 5+ failed attempts in 1 hour (same user)
- 10+ failed attempts from same IP
- Failed attempts across multiple accounts (credential stuffing)
- Failed attempts after successful login (session hijacking)

**Example Detection:**
```sql
-- Brute force detection
SELECT 
    user_name,
    client_ip,
    COUNT(*) as failed_attempts,
    MAX(event_timestamp) as last_attempt
FROM login_history
WHERE is_success = FALSE
    AND event_timestamp >= DATEADD(hour, -1, CURRENT_TIMESTAMP())
GROUP BY user_name, client_ip
HAVING COUNT(*) >= 5
ORDER BY failed_attempts DESC
```

---

### Use Case 6: Stale Account Identification
**Scenario:** Find inactive user accounts that pose security risk

**Questions you can ask:**
- "Which users haven't logged in for 90+ days?"
- "Show disabled accounts that still have privileges"
- "Which service accounts haven't been used recently?"
- "Identify accounts created but never used"

**Security Value:**
- Reduce attack surface
- Enforce account lifecycle policy
- Comply with access review requirements
- Prevent dormant account compromise

**Data Source:** `USERS`, `LOGIN_HISTORY`

**Cleanup Recommendations:**
- Disable accounts inactive > 90 days
- Remove unused service accounts
- Revoke privileges from disabled accounts
- Archive or delete old user data

---

## 👑 Privilege Management

### Use Case 7: Privilege Escalation Detection
**Scenario:** Monitor for suspicious privilege grants and escalations

**Questions you can ask:**
- "Show any ACCOUNTADMIN grants in the last 30 days"
- "Who received OWNERSHIP privileges recently?"
- "Show privilege grants outside business hours"
- "Which users can grant ACCOUNTADMIN?"
- "Track privilege changes for sensitive schemas"

**Security Value:**
- Detect insider threats
- Monitor administrative access
- Prevent unauthorized privilege escalation
- Audit compliance requirements

**Data Source:** `GRANTS_TO_USERS`, `GRANTS_TO_ROLES`

**Critical Privileges to Monitor:**
- `ACCOUNTADMIN` role
- `SECURITYADMIN` role
- `OWNERSHIP` grants
- `MANAGE GRANTS` privilege
- Direct grants to users (vs roles - bad practice)

**Alert Examples:**
```sql
-- Monitor ACCOUNTADMIN grants
SELECT 
    grantee_name,
    granted_by,
    created_on,
    DATEDIFF(hour, created_on, CURRENT_TIMESTAMP()) as hours_ago
FROM grants_to_users
WHERE privilege = 'ACCOUNTADMIN'
    AND created_on >= DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY created_on DESC
```

---

### Use Case 8: Privilege Audit & Least Privilege
**Scenario:** Ensure users have only necessary privileges

**Questions you can ask:**
- "Which users have excessive privileges?"
- "Show all privileges for user X"
- "Which users can access sensitive databases?"
- "Identify privilege creep (accumulated unnecessary access)"
- "Compare privilege grants across similar roles"

**Security Value:**
- Enforce least privilege principle
- Reduce blast radius of compromised accounts
- Meet compliance requirements (SOC2, PCI-DSS)
- Simplify access management

**Analysis Approach:**
1. List all privileges per user
2. Compare with job function requirements
3. Identify unused high privileges
4. Recommend privilege removals

---

## 📊 Data Access Monitoring

### Use Case 9: Sensitive Data Access Tracking
**Scenario:** Monitor access to tables containing PII, PHI, or sensitive business data

**Questions you can ask:**
- "Who accessed our customer PII tables today?"
- "Show access to financial data tables this week"
- "Which queries accessed the most sensitive tables?"
- "Track data access by external consultants"
- "Show unusual access patterns to HR database"

**Security Value:**
- Detect unauthorized data access
- Support compliance auditing (GDPR, HIPAA, SOC2)
- Identify potential data breaches
- Monitor third-party access

**Data Source:** `ACCESS_HISTORY`

**Key Fields:**
- `DIRECT_OBJECTS_ACCESSED` - Tables/views queried directly
- `BASE_OBJECTS_ACCESSED` - Underlying tables (through views)
- `ROWS_ACCESSED` - Volume of data accessed
- `POLICIES_REFERENCED` - What security policies were applied
- `USER_NAME`, `QUERY_ID` - Who and what query

**Example Monitoring:**
```sql
-- Track access to sensitive tables
SELECT 
    user_name,
    query_start_time,
    direct_objects_accessed,
    rows_accessed,
    policies_referenced
FROM access_history
WHERE base_objects_accessed LIKE '%CUSTOMER_PII%'
    OR base_objects_accessed LIKE '%FINANCIAL_DATA%'
ORDER BY query_start_time DESC
```

---

### Use Case 10: Data Exfiltration Detection
**Scenario:** Identify queries that may be attempting to export large volumes of sensitive data

**Questions you can ask:**
- "Show queries that returned more than 1 million rows from sensitive tables"
- "Which users executed COPY INTO external stage commands?"
- "Show large SELECT queries by consultant accounts"
- "Identify bulk data downloads during off-hours"

**Security Value:**
- Prevent data theft
- Detect compromised accounts
- Monitor insider threats
- Enforce data loss prevention (DLP)

**Red Flags:**
- Large row counts (> 100K rows)
- COPY INTO external stages
- Unload operations to S3/Azure/GCS
- Off-hours access to sensitive data
- New users accessing large data volumes

---

## 🎭 Policy Compliance

### Use Case 11: Policy Coverage Verification
**Scenario:** Ensure security policies are properly applied across all sensitive data

**Questions you can ask:**
- "Which sensitive columns don't have masking policies?"
- "Show tables without row access policies"
- "Which users are assigned which password policies?"
- "Verify network policy is applied to all users"
- "Audit policy coverage for PCI compliance"

**Security Value:**
- Ensure comprehensive protection
- Meet regulatory requirements
- Identify policy gaps
- Validate security posture

**Data Source:** `POLICY_REFERENCES`, `MASKING_POLICIES`, `ROW_ACCESS_POLICIES`

**Policy Types to Audit:**
- **Masking Policies** - Protect PII/PHI in query results
- **Row Access Policies** - Enforce row-level security
- **Network Policies** - Control IP-based access
- **Password Policies** - Enforce password complexity
- **Session Policies** - Control timeout and security

---

### Use Case 12: Policy Change Tracking
**Scenario:** Monitor changes to security policies for audit trail

**Questions you can ask:**
- "Show all policy changes in the last 30 days"
- "Who modified the customer data masking policy?"
- "Track network policy assignment changes"
- "Show when password policy was relaxed"

**Security Value:**
- Maintain audit trail
- Detect unauthorized policy changes
- Support incident investigation
- Ensure policy governance

---

## 🏢 External Integration Security

### Use Case 13: External Stage Monitoring
**Scenario:** Track external storage access points (S3, Azure Blob, GCS)

**Questions you can ask:**
- "Show all external stages in our account"
- "Which external stages have been accessed this week?"
- "List stages pointing to external cloud providers"
- "Show storage integration credentials"
- "Identify unused external stages"

**Security Value:**
- Monitor data egress points
- Audit cloud storage access
- Identify misconfigured stages
- Reduce attack surface

**Data Source:** `STAGES`

**Security Checks:**
- Verify storage integrations use proper IAM roles
- Ensure stages don't expose credentials
- Monitor for publicly accessible stages
- Track stage usage and remove unused

---

### Use Case 14: External Function Security
**Scenario:** Audit external functions that can call external APIs

**Questions you can ask:**
- "List all external functions and their endpoints"
- "Which external functions use secrets?"
- "Show external functions created recently"
- "Identify functions with elevated privileges"

**Security Value:**
- Control external API access
- Prevent unauthorized integrations
- Secure credential management
- Monitor external dependencies

**Data Source:** `FUNCTIONS`

---

## 🚨 Incident Response

### Use Case 15: Security Incident Investigation
**Scenario:** Investigate a potential security breach or compromise

**Investigation Questions:**
1. "What did user X access in the last 48 hours?"
2. "Show all queries from IP address Y.Y.Y.Y"
3. "Which external endpoints were called during suspicious timeframe?"
4. "What privilege changes occurred before the incident?"
5. "Show failed login attempts preceding successful compromise"
6. "Track data accessed and potentially exfiltrated"

**Investigation Workflow:**
1. **Timeline Analysis** - When did suspicious activity start?
2. **User Behavior** - What actions did the user take?
3. **Data Access** - What sensitive data was accessed?
4. **Privilege Usage** - What privileges were used?
5. **External Activity** - Any external endpoint calls?
6. **Lateral Movement** - Did activity spread to other accounts?

**Data Sources:** All tables in semantic view provide complementary evidence

---

## 📧 Automated Security Alerts

### Use Case 16: Security Alert Email Reports
**Scenario:** Schedule automated security monitoring reports

**Sample Alert Configurations:**

**Daily Security Summary:**
```
Subject: "Daily Security Report - [DATE]"
Content:
- Failed login attempts (last 24 hours)
- Network policy violations
- New privilege grants
- Sensitive data access summary
- External endpoint call summary
```

**Critical Security Alert:**
```
Subject: "CRITICAL: Security Alert - [INCIDENT TYPE]"
Content:
- Incident description
- Affected users/systems
- Timeline of events
- Immediate action required
- Remediation steps
```

**Weekly Compliance Report:**
```
Subject: "Weekly Compliance & Security Audit"
Content:
- Policy coverage status
- Stale account summary
- Privilege audit findings
- External integration review
- Security metrics and trends
```

---

## 🎯 Implementation Priority

### Phase 1: Critical Security (Week 1)
1. ✅ Network policy violation monitoring
2. ✅ Failed login detection
3. ✅ ACCOUNTADMIN grant tracking
4. ✅ External endpoint monitoring

### Phase 2: Data Protection (Week 2)
1. ✅ Sensitive data access tracking
2. ✅ Data exfiltration detection
3. ✅ Policy coverage verification
4. ✅ Masking policy audit

### Phase 3: Compliance & Audit (Week 3)
1. ✅ Stale account identification
2. ✅ Privilege audit
3. ✅ External integration security
4. ✅ Policy change tracking

### Phase 4: Advanced Monitoring (Week 4)
1. ✅ Session anomaly detection
2. ✅ Behavioral analytics
3. ✅ Automated alerting
4. ✅ Incident response playbooks

---

## 📋 Quick Reference: Security Questions

### 🔴 Critical Security Questions
```
"Show me network policy violations in the last hour"
"Are there any failed login attempts I should investigate?"
"Show recent ACCOUNTADMIN grants"
"Which external endpoints were called with large data transfers?"
"Show me any suspicious after-hours activity"
```

### 🟡 Monitoring Questions
```
"Which users accessed sensitive PII tables today?"
"Show external API calls this week"
"What privilege changes occurred?"
"Which accounts haven't logged in for 90 days?"
"Show me policy coverage for compliance"
```

### 🟢 Audit Questions
```
"Generate a security compliance report"
"Show all security policy assignments"
"Audit external integration points"
"Review privilege grants by role"
"Compare user access against baseline"
```

---

## 🛠️ Configuration Files

### Key Scripts:
1. **`2.1 ENHANCED_SECURITY_DIAGNOSTICS_SVW.sql`** - Enhanced semantic view with all security tables
2. **`5.1 ENHANCED_SECURITY_AGENT.sql`** - AI agent configured for security monitoring
3. **`3. email integration.sql`** - Email notification setup

### Quick Start:
```sql
-- 1. Deploy enhanced semantic view
USE ROLE cortex_role;
@scripts/2.1 ENHANCED_SECURITY_DIAGNOSTICS_SVW.sql

-- 2. Deploy enhanced security agent  
@scripts/5.1 ENHANCED_SECURITY_AGENT.sql

-- 3. Test security queries
-- Ask the agent: "Show me network policy violations today"
```

---

## 📚 Additional Resources

- [Snowflake Security Overview](https://docs.snowflake.com/en/user-guide/security)
- [Network Policies](https://docs.snowflake.com/en/user-guide/network-policies)
- [Masking Policies](https://docs.snowflake.com/en/user-guide/security-column-ddm)
- [Row Access Policies](https://docs.snowflake.com/en/user-guide/security-row)
- [External Functions Security](https://docs.snowflake.com/en/sql-reference/external-functions)
- [Account Usage Views](https://docs.snowflake.com/en/sql-reference/account-usage)

---

## 💡 Best Practices

1. **Enable Network Policies** - Whitelist IP addresses for all users
2. **Monitor External Access** - Review external endpoints regularly
3. **Enforce MFA** - Require multi-factor authentication
4. **Apply Masking Policies** - Protect PII/PHI columns
5. **Regular Access Reviews** - Audit privileges quarterly
6. **Alert on Critical Events** - Automate security notifications
7. **Least Privilege** - Grant minimum necessary access
8. **Audit Trails** - Maintain comprehensive logs
9. **Incident Response Plan** - Prepare investigation procedures
10. **Security Training** - Educate users on threats

---

## 📞 Support

For questions or issues with security monitoring:
1. Review Snowflake documentation links above
2. Test queries in the semantic view directly
3. Refine agent prompts for better responses
4. Contact Snowflake support for platform issues

