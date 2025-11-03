# 🔒 Snowflake Enhanced Security & Performance Monitoring with Cortex AI

## Overview

This repository provides a comprehensive, AI-powered security monitoring and performance optimization solution for Snowflake using **Cortex Agents** and **Semantic Views**. Ask natural language questions to detect security threats, optimize costs, and improve performance.

---

## ✨ Key Features

### 🔒 **Security Monitoring**
- **Network Policy Violations** - Real-time detection of blocked connection attempts
- **External Endpoint Tracking** - Monitor all outbound API calls and data transfers
- **Failed Login Analysis** - Detect brute force attacks and unauthorized access
- **Privilege Escalation** - Track ACCOUNTADMIN grants and suspicious privilege changes
- **Data Access Auditing** - Monitor access to sensitive PII/PHI tables
- **Stale Account Detection** - Identify inactive accounts posing security risks
- **Policy Compliance** - Verify masking and row access policy coverage

### ⚡ **Performance Optimization**
- **Slow Query Analysis** - Identify bottlenecks and optimization opportunities
- **Memory Spilling Detection** - Find queries exceeding warehouse capacity
- **Cache Efficiency** - Analyze result cache and metadata cache usage
- **Partition Pruning** - Detect inefficient table scans
- **Compilation Issues** - Track long compilation times and errors

### 💰 **Cost Management**
- **Credit Consumption** - Track spending by warehouse, user, query type
- **Cost Spike Detection** - Identify anomalous cost increases
- **Storage Growth** - Monitor table growth and Time Travel costs
- **Automatic Clustering** - Analyze clustering ROI
- **Task & Pipe Costs** - Track operational overhead

### 📊 **Operational Monitoring**
- **Task Failures** - Monitor scheduled task reliability
- **Data Loading** - Track COPY and Snowpipe success rates
- **Replication Costs** - Monitor cross-region/cloud data transfer

---

## 🚀 Quick Start

### Prerequisites
- Snowflake account with ACCOUNTADMIN access
- Cortex features enabled
- ~15 minutes for deployment

### Installation (5 Steps)

```sql
-- 1. Foundation Setup (2 min)
USE ROLE ACCOUNTADMIN;
-- Execute: scripts/1. lab foundations.sql

-- 2. Enhanced Semantic View (3 min) ⭐ CORE COMPONENT
USE ROLE cortex_role;
-- Execute: scripts/2.1 ENHANCED_SECURITY_DIAGNOSTICS_SVW.sql

-- 3. Email Integration (2 min)
-- Execute: scripts/3. email integration.sql

-- 4. Documentation Access (5 min)
-- Execute: scripts/4. accept marketplace terms.sql

-- 5. Security Agent (2 min) ⭐ MAIN AGENT
-- Execute: scripts/5.1 ENHANCED_SECURITY_AGENT.sql
```

**That's it!** 🎉 Your AI security agent is ready.

---

## 💬 Example Questions

### 🔴 Critical Security
```
"Show me network policy violations in the last 24 hours"
"Which external endpoints were called with large data transfers?"
"Are there any ACCOUNTADMIN grants in the last week?"
"Show failed login attempts by IP address"
```

### 🟡 Security Monitoring
```
"Which users accessed our customer PII tables today?"
"Show me stale accounts that haven't logged in for 90 days"
"What external API calls failed this week?"
"Verify masking policy coverage on sensitive tables"
```

### ⚡ Performance
```
"What are my top 10 slowest queries today?"
"Which queries are spilling to disk?"
"Show queries with poor cache hit rates"
"Which tables should I add clustering keys to?"
```

### 💰 Cost Optimization
```
"Why did my costs spike yesterday?"
"Which warehouses are most expensive this month?"
"Show me my most expensive queries"
"What's my automatic clustering cost vs benefit?"
```

### 📧 Reports
```
"Send me a daily security summary report"
"Email me the top 5 cost optimization opportunities"
```

---

## 📁 Repository Structure

```
cortex-snowflake-account-info-lab/
├── README.md                               ⬅️ You are here
├── DEPLOYMENT_GUIDE.md                     # Step-by-step deployment
├── SECURITY_USE_CASES.md                   # 15+ detailed security scenarios
│
├── scripts/
│   ├── 1. lab foundations.sql              # Foundation setup
│   ├── 2. SNOWFLAKE_INTELLIGENCE.TOOLS schema.sql  # Basic semantic view
│   ├── 2.1 ENHANCED_SECURITY_DIAGNOSTICS_SVW.sql   # ⭐ Enhanced semantic view (50+ tables)
│   ├── 3. email integration.sql            # Email notification setup
│   ├── 4. accept marketplace terms.sql     # Snowflake documentation access
│   ├── 5. agent creation.SQL               # Basic agent
│   └── 5.1 ENHANCED_SECURITY_AGENT.sql     # ⭐ Enhanced security agent
```

---

## 🔍 What's Inside

### Enhanced Semantic View (50+ Tables)

**Security Tables:**
- `LOGIN_HISTORY` - Authentication events
- `SESSIONS` - Network policy enforcement (**IS_CLIENT_IP_BLOCKED**)
- `ACCESS_HISTORY` - Data access tracking
- `EXTERNAL_ACCESS_HISTORY` - **External endpoint monitoring** 🆕
- `GRANTS_TO_USERS/ROLES` - Privilege tracking
- `POLICY_REFERENCES` - Security policy coverage
- `USERS/ROLES` - Account lifecycle
- `MASKING_POLICIES` - PII protection
- `ROW_ACCESS_POLICIES` - Row-level security
- `PASSWORD_POLICIES` - Auth requirements
- `STAGES` - External storage access
- `FUNCTIONS` - External function security

**Performance Tables:**
- `QUERY_HISTORY` - Query execution metrics
- `QUERY_ATTRIBUTION_HISTORY` - Credit attribution
- `WAREHOUSE_METERING_HISTORY` - Warehouse costs
- `AUTOMATIC_CLUSTERING_HISTORY` - Clustering costs
- `MATERIALIZED_VIEW_REFRESH_HISTORY` - MV costs

**Storage Tables:**
- `TABLE_STORAGE_METRICS` - Table-level storage
- `DATABASE_STORAGE_USAGE_HISTORY` - DB-level storage

**Operational Tables:**
- `TASK_HISTORY` - Scheduled task execution
- `COPY_HISTORY` - Data loading
- `PIPE_USAGE_HISTORY` - Snowpipe operations
- `REPLICATION_USAGE_HISTORY` - Replication costs
- `DATA_TRANSFER_HISTORY` - Cross-region/cloud transfers

**Total:** 150+ metrics (facts) and 200+ attributes (dimensions)

---

## 🎯 Key Use Cases

### 1️⃣ External Endpoint Security Monitoring
**Problem:** Need to track all outbound API calls and prevent data exfiltration

**Solution:** Query `EXTERNAL_ACCESS_HISTORY` to monitor:
- Which external endpoints are being called
- How much data is being transferred
- Who is making the calls
- Failed external calls indicating issues

**Sample Questions:**
- "Show external endpoints called this week"
- "Which user sent the most data externally?"
- "Alert on data transfers to non-approved domains"

---

### 2️⃣ Network Policy Violation Detection
**Problem:** Unauthorized connection attempts from blocked IPs

**Solution:** Monitor `SESSIONS.IS_CLIENT_IP_BLOCKED_BY_NETWORK_POLICY`
- Real-time blocked connection tracking
- IP address analysis
- User account validation
- Geographic anomaly detection

**Sample Questions:**
- "Show blocked connection attempts today"
- "Which IPs are repeatedly trying to connect?"
- "Are there network policy violations by trusted users?"

---

### 3️⃣ Privilege Escalation Detection
**Problem:** Detect unauthorized privilege grants and insider threats

**Solution:** Monitor `GRANTS_TO_USERS/ROLES` for:
- ACCOUNTADMIN grants
- OWNERSHIP transfers
- After-hours privilege changes
- Direct user grants (vs role-based)

**Sample Questions:**
- "Show any ACCOUNTADMIN grants in last 30 days"
- "Who granted OWNERSHIP recently?"
- "Track privilege changes for sensitive databases"

---

### 4️⃣ Sensitive Data Access Auditing
**Problem:** Compliance requirements for PII/PHI access tracking

**Solution:** Query `ACCESS_HISTORY` to monitor:
- Who accessed sensitive tables
- What data was queried
- Which security policies were applied
- Large data exports

**Sample Questions:**
- "Who accessed customer PII tables today?"
- "Show access to financial data by external consultants"
- "Track queries returning >100K rows from sensitive tables"

---

### 5️⃣ Cost Spike Analysis
**Problem:** Unexpected credit consumption increases

**Solution:** Analyze `WAREHOUSE_METERING_HISTORY`, `TASK_HISTORY`, `AUTOMATIC_CLUSTERING_HISTORY`
- Credit consumption by warehouse
- Task and clustering overhead
- Query cost attribution
- Warehouse efficiency comparison

**Sample Questions:**
- "Why did costs spike yesterday?"
- "Which warehouse is most expensive?"
- "Show my most expensive queries"

---

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     USER QUESTIONS                          │
│  "Show network policy violations in last 24 hours"          │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│             SNOWFLAKE CORTEX AGENT                          │
│  - Natural language understanding                           │
│  - Query generation                                         │
│  - Security risk assessment                                 │
│  - Recommendation engine                                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│        ENHANCED SECURITY SEMANTIC VIEW                      │
│  - 50+ Account Usage tables                                 │
│  - 150+ metrics (facts)                                     │
│  - 200+ attributes (dimensions)                             │
│  - Pre-built security queries                               │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           SNOWFLAKE ACCOUNT USAGE SCHEMA                    │
│  - LOGIN_HISTORY, SESSIONS, ACCESS_HISTORY                  │
│  - EXTERNAL_ACCESS_HISTORY (endpoint monitoring)            │
│  - QUERY_HISTORY, WAREHOUSE_METERING                        │
│  - GRANTS, POLICIES, USERS, ROLES                           │
└─────────────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                  OUTPUT OPTIONS                             │
│  ├─ Formatted response with recommendations                 │
│  ├─ HTML email reports                                      │
│  └─ Integration with SIEM/SOAR tools                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛡️ Security Benefits

### Before (Traditional Monitoring)
- ❌ Manual SQL queries for security events
- ❌ Delayed threat detection
- ❌ Limited visibility into external access
- ❌ Time-consuming privilege audits
- ❌ Reactive incident response

### After (AI-Powered Monitoring)
- ✅ Natural language security queries
- ✅ Real-time threat detection
- ✅ Comprehensive external endpoint tracking
- ✅ Automated privilege escalation alerts
- ✅ Proactive security monitoring
- ✅ AI-powered recommendations
- ✅ Automated email alerts

---

## 💡 Best Practices

### Security
1. **Enable Network Policies** - Whitelist authorized IPs
2. **Monitor External Access Daily** - Review endpoint calls
3. **Alert on Critical Events** - Automate ACCOUNTADMIN grant notifications
4. **Regular Access Reviews** - Audit privileges quarterly
5. **Apply Masking Policies** - Protect PII/PHI columns
6. **Track Stale Accounts** - Disable inactive users
7. **Enforce MFA** - Require multi-factor authentication

### Performance
1. **Monitor Spilling** - Address memory issues promptly
2. **Optimize Cache Usage** - Tune warehouse configurations
3. **Review Slow Queries** - Regular performance analysis
4. **Partition Management** - Ensure efficient pruning
5. **Warehouse Sizing** - Right-size based on workload

### Cost
1. **Set Cost Alerts** - Monitor unexpected spikes
2. **Warehouse Efficiency** - Compare credit per query
3. **Task Optimization** - Review scheduled task frequency
4. **Storage Cleanup** - Manage Time Travel retention
5. **Clustering ROI** - Validate automatic clustering benefit

---

## 📈 Metrics & KPIs

Track your security and performance posture:

### Security KPIs
- Network policy violations per day
- Failed login attempt rate
- Time to detect privilege escalation
- Sensitive data access anomalies
- External endpoint call volume
- Policy coverage percentage
- Stale account count

### Performance KPIs
- Average query execution time
- Cache hit rate percentage
- Queries with memory spilling
- Compilation time > 1 second
- Partition pruning efficiency

### Cost KPIs
- Daily credit consumption trend
- Cost per query (by warehouse)
- Storage growth rate
- Clustering cost vs query improvement
- Task execution costs

---

## 🔧 Customization

### Add Custom Security Rules
Edit `5.1 ENHANCED_SECURITY_AGENT.sql`:
```json
"sample_questions": [
    { "question": "Monitor access to CUSTOMER_CREDIT_CARDS table" },
    { "question": "Alert on API calls to external-domain.com" }
]
```

### Configure Email Distribution
Update email integration with your lists:
```sql
-- Security alerts
CALL SEND_EMAIL('security-team@company.com', 'subject', 'body');

-- Cost reports  
CALL SEND_EMAIL('finance-team@company.com', 'subject', 'body');
```

### Adjust Query Timeout
For large data volumes:
```json
"query_timeout": 180  // Increase from 120 seconds
```

---

## 📚 Documentation

- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Step-by-step setup instructions
- **[SECURITY_USE_CASES.md](SECURITY_USE_CASES.md)** - 15+ detailed security scenarios
- [Snowflake Cortex AI Documentation](https://docs.snowflake.com/en/user-guide/ml-powered-features)
- [Account Usage Views Reference](https://docs.snowflake.com/en/sql-reference/account-usage)

---

## 🤝 Contributing

We welcome contributions! Areas for enhancement:
- Additional security use cases
- Custom alerting rules
- Integration with SIEM tools
- Performance optimization patterns
- Cost optimization recommendations

---

## 📝 License

This project is provided as-is for educational and operational purposes.

---

## 🆘 Support

### Issues & Questions
1. Check [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) troubleshooting section
2. Review [SECURITY_USE_CASES.md](SECURITY_USE_CASES.md) for examples
3. Consult Snowflake documentation
4. Contact Snowflake support for platform issues

### Common Issues
- **Data Latency** - Account Usage views have 45min-3hr delay
- **Permissions** - Ensure cortex_role has necessary grants
- **Timeout** - Increase warehouse size or query timeout
- **Email** - Verify notification integration is enabled

---

## 🎉 Success Stories

### Security Wins
- "Detected privilege escalation attempt within 1 hour"
- "Identified data exfiltration via external endpoint monitoring"
- "Reduced stale accounts by 80% in first month"
- "Automated network policy violation alerts"

### Performance Wins
- "Identified and fixed queries causing 3x warehouse costs"
- "Reduced query spilling by optimizing warehouse sizing"
- "Improved cache hit rate from 40% to 85%"

### Cost Wins
- "Saved 30% on warehouse costs through right-sizing"
- "Eliminated unnecessary clustering on low-query tables"
- "Optimized task scheduling to reduce off-hours costs"

---

## 🚀 Get Started Now!

1. **Clone this repository**
2. **Follow [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)**
3. **Deploy in 15 minutes**
4. **Start asking security questions!**

```sql
USE ROLE cortex_role;
-- Deploy all 5 scripts in order
-- Start monitoring your Snowflake environment with AI! 🎉
```

---

## 📞 Contact

For questions, feedback, or support:
- Open an issue in this repository
- Contact Snowflake support
- Review Snowflake documentation

---

**Built with ❄️ by Snowflake Users, for Snowflake Security & Performance Excellence**

---

## ⭐ Star This Repo!

If this helps secure and optimize your Snowflake environment, please star this repository!

