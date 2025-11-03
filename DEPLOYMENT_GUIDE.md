# 🚀 Deployment Guide - Enhanced Security & Performance Monitoring

## Overview
This guide walks you through deploying the enhanced Snowflake Cortex Agent with comprehensive security monitoring, performance optimization, and cost management capabilities.

---

## 📋 Prerequisites

### Required:
- ✅ Snowflake account with ACCOUNTADMIN access
- ✅ Cortex features enabled (AI/ML)
- ✅ Account Usage schema access
- ✅ Email integration capability (for alerts)

### Recommended:
- ✅ Warehouse for agent execution (X-Small is sufficient)
- ✅ Network policy configured
- ✅ Some historical query data (for meaningful analysis)

---

## 📁 File Structure

```
cortex-snowflake-account-info-lab/
├── scripts/
│   ├── 1. lab foundations.sql              # Foundation setup
│   ├── 2. SNOWFLAKE_INTELLIGENCE.TOOLS schema.sql  # Basic semantic view
│   ├── 2.1 ENHANCED_SECURITY_DIAGNOSTICS_SVW.sql   # ⭐ Enhanced semantic view
│   ├── 3. email integration.sql            # Email notification setup
│   ├── 4. accept marketplace terms.sql     # Documentation access
│   ├── 5. agent creation.SQL               # Basic agent
│   └── 5.1 ENHANCED_SECURITY_AGENT.sql     # ⭐ Enhanced security agent
├── SECURITY_USE_CASES.md                   # Security scenarios reference
└── DEPLOYMENT_GUIDE.md                     # This file
```

---

## 🎯 Deployment Steps

### Step 1: Foundation Setup (Required)
**File:** `1. lab foundations.sql`

**What it does:**
- Enables Cortex features account-wide
- Creates custom role (`cortex_role`) with necessary privileges
- Sets up SNOWFLAKE_INTELLIGENCE database and schemas
- Creates warehouse for agent execution
- Grants access to models and features

**Execute:**
```sql
-- Run in Snowflake worksheet as ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;
-- Then execute entire file: 1. lab foundations.sql
```

**Time:** ~2-3 minutes

**Verify:**
```sql
SHOW DATABASES LIKE 'SNOWFLAKE_INTELLIGENCE';
SHOW SCHEMAS IN DATABASE SNOWFLAKE_INTELLIGENCE;
SHOW ROLES LIKE 'cortex_role';
SHOW WAREHOUSES LIKE 'cortex_wh';
```

---

### Step 2: Enhanced Semantic View (Core Component)
**File:** `2.1 ENHANCED_SECURITY_DIAGNOSTICS_SVW.sql`

**What it does:**
- Creates comprehensive semantic view with 50+ tables
- Includes all security monitoring tables:
  - LOGIN_HISTORY, SESSIONS, ACCESS_HISTORY
  - EXTERNAL_ACCESS_HISTORY (external endpoint monitoring)
  - GRANTS_TO_USERS/ROLES (privilege tracking)
  - POLICY_REFERENCES (security policy coverage)
  - USERS, ROLES (account lifecycle)
  - And many more...
- Defines 150+ facts (metrics) and 200+ dimensions
- Provides sample queries for AI training

**Execute:**
```sql
USE ROLE cortex_role;
-- Execute entire file: 2.1 ENHANCED_SECURITY_DIAGNOSTICS_SVW.sql
```

**Time:** ~3-5 minutes (depends on metadata volume)

**Verify:**
```sql
SHOW SEMANTIC VIEWS IN DATABASE SNOWFLAKE_INTELLIGENCE;

-- Test the view
DESC SEMANTIC VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.ENHANCED_SECURITY_DIAGNOSTICS_SVW;

-- Verify it can query data
SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY 
WHERE START_TIME >= DATEADD(day, -1, CURRENT_TIMESTAMP());
```

**Troubleshooting:**
- If view creation fails, check `cortex_role` has access to `SNOWFLAKE.ACCOUNT_USAGE` schema
- Account Usage views have latency (45min - 3hrs), so recent data may not appear immediately

---

### Step 3: Email Integration (Optional but Recommended)
**File:** `3. email integration.sql`

**What it does:**
- Creates email notification integration
- Deploys `SEND_EMAIL` stored procedure
- Enables agent to send security alerts and reports

**Execute:**
```sql
USE ROLE cortex_role;
-- Execute entire file: 3. email integration.sql

-- Update with your email for testing:
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_EMAIL(
  'YOUR_EMAIL@domain.com',  -- ⚠️ CHANGE THIS
  'Test Email',
  '<h1>Test</h1><p>If you receive this, email integration works!</p>'
);
```

**Time:** ~2 minutes

**Verify:**
- Check your inbox for test email
- Look for email from Snowflake notification service
- Check spam folder if not received

---

### Step 4: Snowflake Documentation Access (Recommended)
**File:** `4. accept marketplace terms.sql`

**What it does:**
- Accepts terms for Snowflake Documentation listing
- Creates database with Cortex Search over Snowflake docs
- Enables agent to reference official documentation

**Execute:**
```sql
USE ROLE cortex_role;
-- Execute entire file: 4. accept marketplace terms.sql
```

**Time:** ~5 minutes (data share import)

**Verify:**
```sql
SHOW DATABASES LIKE 'SNOWFLAKE_DOCUMENTATION';
SHOW CORTEX SEARCH SERVICES IN DATABASE SNOWFLAKE_DOCUMENTATION;
```

---

### Step 5: Deploy Enhanced Security Agent (The Main Event!)
**File:** `5.1 ENHANCED_SECURITY_AGENT.sql`

**What it does:**
- Creates AI agent with comprehensive security & performance monitoring
- Configures access to enhanced semantic view
- Links email notification capability
- Provides 40+ sample security & performance questions
- Sets up orchestration logic for different query types

**Execute:**
```sql
USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.AGENTS;
-- Execute entire file: 5.1 ENHANCED_SECURITY_AGENT.sql
```

**Time:** ~2-3 minutes

**Verify:**
```sql
SHOW AGENTS IN DATABASE SNOWFLAKE_INTELLIGENCE;

-- Grant usage to others (optional)
GRANT USAGE ON AGENT 
    SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_SECURITY_PERFORMANCE_AGENT 
    TO ROLE PUBLIC;
```

---

## 🧪 Testing the Agent

### Test 1: Basic Security Query
```
Navigate to Snowflake UI → Snowflake Intelligence (left sidebar) → Agents
Select: SNOWFLAKE_SECURITY_PERFORMANCE_AGENT

Ask: "Show me any network policy violations in the last 24 hours"
```

**Expected Response:**
- Query results showing blocked connection attempts (if any)
- IP addresses, users, timestamps
- Security risk assessment
- Recommendations

---

### Test 2: External Endpoint Monitoring
```
Ask: "Which external endpoints were called this week?"
```

**Expected Response:**
- List of external endpoints accessed
- Data volume sent/received
- Users who made calls
- Security assessment of endpoints

---

### Test 3: Failed Login Analysis
```
Ask: "Show me failed login attempts in the last 7 days"
```

**Expected Response:**
- Failed login events
- Users and IPs involved
- Potential brute force patterns
- Recommendations for account security

---

### Test 4: Cost Analysis
```
Ask: "Which warehouses consumed the most credits yesterday?"
```

**Expected Response:**
- Warehouse credit consumption breakdown
- Cost trends
- Optimization opportunities
- Warehouse sizing recommendations

---

### Test 5: Email Report
```
Ask: "Send me a security summary report for today"
```

**Expected Response:**
- Confirmation that email is being sent
- Email should arrive with formatted HTML report
- Includes key security metrics and recommendations

---

## 🎛️ Configuration Options

### Customize Email Recipients

Edit in `5.1 ENHANCED_SECURITY_AGENT.sql`:
```json
"recipient_email": {
    "description": "Email recipient. If not provided, use YOUR_EMAIL@domain.com",
    "type": "string"
}
```

### Adjust Query Timeout

For large data volumes, increase timeout:
```json
"execution_environment": {
    "type": "warehouse",
    "warehouse": "CORTEX_WH",
    "query_timeout": 180  // Increase from 120 to 180 seconds
}
```

### Add Custom Sample Questions

Edit the `sample_questions` array to add domain-specific questions:
```json
{ "question": "Show access to CUSTOMER_TRANSACTIONS table" },
{ "question": "Monitor API calls to our production endpoints" }
```

---

## 🔍 Troubleshooting

### Issue: Agent can't access ACCOUNT_USAGE tables
**Solution:**
```sql
-- Grant access to cortex_role
USE ROLE ACCOUNTADMIN;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE cortex_role;
```

### Issue: No recent data in queries
**Problem:** Account Usage views have latency (45min - 3hrs)

**Solution:**
- Wait for data latency period
- Use date ranges like "last 24 hours" or "yesterday" instead of "last hour"
- For real-time monitoring, consider INFORMATION_SCHEMA views (limited history)

### Issue: Email not sending
**Check:**
```sql
-- Verify integration exists
SHOW INTEGRATIONS LIKE 'email_integration';

-- Verify procedure exists
SHOW PROCEDURES LIKE 'SEND_EMAIL' IN SCHEMA SNOWFLAKE_INTELLIGENCE.TOOLS;

-- Test directly
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_EMAIL(
    'test@domain.com', 
    'Test', 
    '<p>Test</p>'
);
```

### Issue: Semantic view query timeout
**Solution:**
- Increase warehouse size (Small or Medium)
- Narrow date ranges in queries
- Increase query_timeout in agent configuration

### Issue: Agent gives vague responses
**Solution:**
- Be more specific in questions
- Include timeframes: "in the last 24 hours", "this week"
- Reference specific users, tables, or warehouses
- Ask follow-up questions to drill down

---

## 📊 Monitoring Agent Performance

### Check Agent Usage
```sql
-- View agent execution history
SELECT * 
FROM SNOWFLAKE_INTELLIGENCE.INFORMATION_SCHEMA.AGENT_HISTORY
WHERE AGENT_NAME = 'SNOWFLAKE_SECURITY_PERFORMANCE_AGENT'
ORDER BY START_TIME DESC
LIMIT 10;
```

### Monitor Costs
```sql
-- Check credits used by agent warehouse
SELECT 
    warehouse_name,
    SUM(credits_used) as total_credits,
    COUNT(*) as query_count
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name = 'CORTEX_WH'
    AND start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_name;
```

---

## 🔐 Security Best Practices

### 1. Restrict Agent Access
```sql
-- Only grant to specific roles, not PUBLIC
REVOKE USAGE ON AGENT 
    SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_SECURITY_PERFORMANCE_AGENT 
    FROM ROLE PUBLIC;

GRANT USAGE ON AGENT 
    SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_SECURITY_PERFORMANCE_AGENT 
    TO ROLE SECURITY_TEAM;
```

### 2. Audit Agent Usage
```sql
-- Monitor who's using the agent
SELECT 
    user_name,
    role_name,
    COUNT(*) as agent_calls,
    MAX(start_time) as last_used
FROM SNOWFLAKE_INTELLIGENCE.INFORMATION_SCHEMA.AGENT_HISTORY
WHERE agent_name = 'SNOWFLAKE_SECURITY_PERFORMANCE_AGENT'
GROUP BY user_name, role_name
ORDER BY agent_calls DESC;
```

### 3. Secure Email Integration
- Use specific distribution lists for alerts
- Don't expose sensitive data in email subjects
- Consider encrypting sensitive reports
- Implement email retention policies

### 4. Network Policy for Agent Access
```sql
-- Restrict agent access by IP
CREATE NETWORK POLICY agent_access_policy
    ALLOWED_IP_LIST = ('203.0.113.0/24', '198.51.100.0/24')
    BLOCKED_IP_LIST = ();

-- Apply to users who access agents
ALTER USER security_analyst SET NETWORK_POLICY = agent_access_policy;
```

---

## 🎯 Next Steps

### Phase 1: Validate Deployment (Day 1)
- ✅ Run all test queries
- ✅ Verify email notifications work
- ✅ Check semantic view performance
- ✅ Review sample data accuracy

### Phase 2: Customize (Week 1)
- ✅ Add organization-specific sample questions
- ✅ Configure email distribution lists
- ✅ Define sensitive table patterns for your data
- ✅ Set up approved external endpoint list

### Phase 3: Operationalize (Week 2)
- ✅ Create scheduled security reports
- ✅ Set up critical security alerts
- ✅ Train security team on agent usage
- ✅ Establish incident response procedures

### Phase 4: Optimize (Week 3-4)
- ✅ Tune agent prompts based on usage
- ✅ Add custom security rules
- ✅ Integrate with SIEM/SOAR tools
- ✅ Implement automated remediation for common issues

---

## 📚 Additional Resources

- **Security Use Cases:** See `SECURITY_USE_CASES.md` for 15+ detailed security monitoring scenarios
- **Snowflake Docs:** [Cortex AI & ML](https://docs.snowflake.com/en/user-guide/ml-powered-features)
- **Account Usage:** [Account Usage Views Reference](https://docs.snowflake.com/en/sql-reference/account-usage)
- **Security:** [Snowflake Security Overview](https://docs.snowflake.com/en/user-guide/security)

---

## 🆘 Getting Help

### Check Logs
```sql
-- View agent execution errors
SELECT * 
FROM SNOWFLAKE_INTELLIGENCE.INFORMATION_SCHEMA.AGENT_HISTORY
WHERE AGENT_NAME = 'SNOWFLAKE_SECURITY_PERFORMANCE_AGENT'
    AND STATUS = 'FAILED'
ORDER BY START_TIME DESC;
```

### Common Issues
1. **Latency** - Account Usage views are NOT real-time
2. **Permissions** - Ensure cortex_role has all necessary grants
3. **Warehouse** - Agent needs running warehouse to execute queries
4. **Data Volume** - Large accounts may need bigger warehouse or narrower queries

### Support Channels
- Snowflake Support Portal
- Community Forums
- GitHub Issues (if applicable)

---

## ✅ Deployment Checklist

```
Foundation Setup:
☐ Script 1 executed successfully
☐ cortex_role created
☐ SNOWFLAKE_INTELLIGENCE database created
☐ cortex_wh warehouse created

Core Components:
☐ Enhanced semantic view deployed (2.1)
☐ Email integration configured (3)
☐ Documentation access enabled (4)
☐ Enhanced security agent deployed (5.1)

Verification:
☐ Test security query works
☐ Test email notification works
☐ Documentation search works
☐ Cost analysis query works

Configuration:
☐ Email addresses updated
☐ Network policies configured
☐ Access grants properly set
☐ Sample questions customized

Documentation:
☐ Security use cases reviewed
☐ Team trained on agent usage
☐ Incident response plan defined
☐ Monitoring dashboard created
```

---

## 🎉 Success!

Your enhanced Snowflake security and performance monitoring agent is now deployed!

**Start monitoring with questions like:**
- "Show me network policy violations today"
- "Which external endpoints are being called?"
- "Show failed login attempts"
- "Which warehouses are most expensive?"
- "Send me a daily security report"

**Remember:** The agent learns from your questions, so the more you use it, the better it gets at understanding your specific security and performance concerns!

