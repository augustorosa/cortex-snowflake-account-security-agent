# 🎯 Comprehensive Snowflake Operations Monitoring with Cortex AI

> **AI-Powered Monitoring, Security, Cost Control, and Performance Optimization**

[![Snowflake](https://img.shields.io/badge/Snowflake-Complete-29B5E8?logo=snowflake)](https://www.snowflake.com/)
[![Cortex AI](https://img.shields.io/badge/Cortex_AI-Enabled-00A3E0)](https://docs.snowflake.com/en/user-guide/ml-powered-features)
[![Status](https://img.shields.io/badge/Status-Production_Ready-success)]()

---

## 🌟 Overview

A **production-ready**, comprehensive Snowflake monitoring solution leveraging **Cortex AI Agents** and **Semantic Views** to provide complete visibility into your Snowflake environment through natural language questions.

**Ask questions like:**
- *"What's my overall Snowflake account health?"*
- *"Show me users with failed logins and expensive queries"*
- *"What are my total costs across all services?"*
- *"Which tables lack masking policies?"*

---

## ✨ Key Capabilities

### 🎯 **Triple-Agent Architecture**

1. **Generalist Agent (Comprehensive)**
   - All-in-one cross-domain analysis
   - 20 ACCOUNT_USAGE tables
   - 94 metrics spanning all operational areas
   - Best for: holistic insights, cross-domain correlations

2. **Cost/Performance Specialist**
   - Fast, focused cost and performance queries
   - Query execution, credits, resource usage
   - Best for: quick performance checks, cost analysis

3. **Security Specialist**
   - Dedicated security and authentication monitoring
   - Login tracking, MFA adoption, threats
   - Best for: security audits, compliance checks

---

## 📊 Complete Coverage (All 6 Phases)

### ✅ **Phase 1: Query Performance & Cost**
- 50+ query execution metrics
- Cost attribution and credit tracking
- Performance bottleneck detection
- Spilling, caching, partition pruning
- **Tables:** QUERY_HISTORY, QUERY_ATTRIBUTION_HISTORY

### ✅ **Phase 2: Security & Authentication**
- Login monitoring (365 days history)
- Failed login detection & MFA tracking
- Client IP/type analysis
- Suspicious pattern identification
- **Tables:** LOGIN_HISTORY

### ✅ **Phase 3: Cost & Storage**
- Warehouse credit consumption
- Storage growth tracking
- Database/stage storage breakdown
- Failsafe and Time Travel costs
- **Tables:** WAREHOUSE_METERING_HISTORY, STORAGE_USAGE, DATABASE_STORAGE_USAGE_HISTORY, STAGE_STORAGE_USAGE_HISTORY

### ✅ **Phase 4: Governance & Permissions**
- User and role management
- MFA adoption tracking
- Grant auditing (users→roles→privileges)
- Permission distribution analysis
- **Tables:** USERS, ROLES, GRANTS_TO_USERS, GRANTS_TO_ROLES

### ✅ **Phase 5: Task Operations**
- Task execution monitoring
- Success/failure rate tracking
- Serverless task credit consumption
- Task failure analysis
- **Tables:** TASK_HISTORY, SERVERLESS_TASK_HISTORY

### ✅ **Phase 6: Advanced Operations**
- **Snowpipe:** Data loading credits and files
- **Clustering:** Automatic clustering maintenance costs
- **Materialized Views:** Refresh credits
- **Replication:** Cross-region replication costs
- **Data Transfer:** Inter-cloud/region transfer tracking
- **Warehouse Load:** Queue metrics (5-min intervals)
- **Daily Metering:** Billable credit reconciliation
- **Tables:** PIPE_USAGE_HISTORY, AUTOMATIC_CLUSTERING_HISTORY, MATERIALIZED_VIEW_REFRESH_HISTORY, REPLICATION_USAGE_HISTORY, DATA_TRANSFER_HISTORY, WAREHOUSE_LOAD_HISTORY, METERING_DAILY_HISTORY

---

## 📈 By The Numbers

| Metric | Count |
|--------|-------|
| **ACCOUNT_USAGE Tables** | 20 |
| **Dimensions** | 35 |
| **Metrics** | 94 |
| **Verified Queries** | 17 |
| **Test Cases** | 27 |
| **Phases Complete** | 6/6 ✅ |

---

## 🚀 Quick Start (15 Minutes)

### Prerequisites
- Snowflake account with ACCOUNTADMIN access
- Cortex features enabled in your region
- SnowSQL CLI (optional, for automated deployment)

### Installation Steps

```bash
# 1. Clone repository
git clone <repository-url>
cd cortex-snowflake-account-info-lab

# 2. Configure SnowSQL connection (optional)
snowsql -a <account> -u <username>

# 3. Deploy foundation (2 min)
snowsql -f "scripts/1. lab foundations.sql"

# 4. Deploy schema (1 min)
snowsql -f "scripts/2. SNOWFLAKE_INTELLIGENCE.TOOLS schema.sql"

# 5. Deploy specialist agents (3 min)
snowsql -f "scripts/2.2 COST_PERFORMANCE_SVW_SPECIALIST.sql"
snowsql -f "scripts/5.2 COST_PERFORMANCE_AGENT_SPECIALIST.sql"
snowsql -f "scripts/2.3 SECURITY_MONITORING_SVW_SPECIALIST.sql"
snowsql -f "scripts/5.3 SECURITY_MONITORING_AGENT_SPECIALIST.sql"

# 6. Deploy generalist agent (5 min) ⭐ ALL 6 PHASES
snowsql -f "scripts/2.4 SNOWFLAKE_MAINTENANCE_SVW_GENERALIST.sql"
snowsql -f "scripts/5.4 SNOWFLAKE_MAINTENANCE_AGENT_GENERALIST.sql"

# 7. Optional: Email integration (2 min)
snowsql -f "scripts/3. email integration.sql"

# 8. Run automated tests (2 min)
snowsql -f "scripts/TEST_ALL_PHASES.sql" -o output_format=table
```

**That's it!** 🎉 Your comprehensive monitoring system is ready.

---

## 💬 Example Questions

### 🎯 **Comprehensive Health Checks (Generalist Agent)**
```
"What's my overall Snowflake account health?"
"Show me total costs across all services (warehouses, tasks, pipes, clustering)"
"Which users have both failed queries and failed logins?"
"What's my MFA adoption rate?"
"Show me warehouse queue metrics - any performance issues?"
```

### 💰 **Cost & Performance (Specialist Agent)**
```
"What are the most expensive queries by cloud services credits?"
"Which warehouses are consuming the most credits?"
"Show me queries that failed in the last hour"
"What's my storage growth trend over the last 30 days?"
"Which databases use the most storage?"
```

### 🔒 **Security & Authentication (Specialist Agent)**
```
"Show me failed login attempts"
"What's my login success rate?"
"Which IP addresses have failed login attempts?"
"How many users have MFA enabled?"
"Show me users without MFA"
```

### 📊 **Advanced Operations (Generalist Agent)**
```
"How much data has Snowpipe loaded this month?"
"What are my automatic clustering costs?"
"Show me materialized view refresh credits"
"What's my replication cost trend?"
"Which warehouses have the most queueing issues?"
"What's my daily billable credit consumption?"
```

### 🔗 **Cross-Domain Analysis (Generalist Agent)**
```
"Users with high costs + failed logins"
"Show expensive queries accessing masked data"
"Which users without MFA are running expensive queries?"
"How does my storage growth correlate with query performance?"
"What's my total operational cost including all services?"
```

---

## 📁 Repository Structure

```
cortex-snowflake-account-info-lab/
├── README.md                                       ⬅️ You are here
├── SECURITY_AGENT_ROADMAP.md                       📋 Future enhancements
├── docs/                                           📚 Documentation archive
│
├── scripts/
│   ├── 1. lab foundations.sql                      🏗️  Foundation setup
│   ├── 2. SNOWFLAKE_INTELLIGENCE.TOOLS schema.sql  📦 Schema creation
│   ├── 2.1A FLATTENED_ACCESS_HISTORY_VIEWS.sql     🔧 Helper views
│   │
│   ├── 2.2 COST_PERFORMANCE_SVW_SPECIALIST.sql     💰 Cost specialist semantic view
│   ├── 5.2 COST_PERFORMANCE_AGENT_SPECIALIST.sql   🤖 Cost specialist agent
│   │
│   ├── 2.3 SECURITY_MONITORING_SVW_SPECIALIST.sql  🔒 Security specialist semantic view
│   ├── 5.3 SECURITY_MONITORING_AGENT_SPECIALIST.sql 🤖 Security specialist agent
│   │
│   ├── 2.4 SNOWFLAKE_MAINTENANCE_SVW_GENERALIST.sql ⭐ Generalist semantic view (ALL 6 PHASES)
│   ├── 5.4 SNOWFLAKE_MAINTENANCE_AGENT_GENERALIST.sql ⭐ Generalist agent (20 tables, 94 metrics)
│   │
│   ├── 3. email integration.sql                    📧 Email notifications
│   ├── 4. accept marketplace terms.sql             📄 Documentation access
│   │
│   ├── CHECK_AVAILABLE_COLUMNS.sql                 🔍 Diagnostic utility
│   └── TEST_ALL_PHASES.sql                         ✅ Automated test suite (27 tests)
```

---

## 🏗️ Architecture

### **Triple-Agent Design**

```
┌─────────────────────────────────────────────────────────────────┐
│                       USER QUESTIONS                            │
│  Natural language queries about any operational aspect          │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
           ┌─────────────┴──────────────┐
           │                            │
    ┌──────▼──────┐              ┌─────▼──────┐
    │ SPECIALIST  │              │ GENERALIST │
    │   AGENTS    │              │   AGENT    │
    │             │              │            │
    │ • Cost/Perf │              │ • All 6    │
    │ • Security  │              │   Phases   │
    │             │              │ • Cross-   │
    │ Fast, Focus │              │   Domain   │
    └──────┬──────┘              └─────┬──────┘
           │                           │
           └─────────────┬─────────────┘
                         ▼
         ┌───────────────────────────────┐
         │   SEMANTIC VIEWS              │
         │   • 20 ACCOUNT_USAGE tables   │
         │   • 35 dimensions             │
         │   • 94 metrics                │
         │   • Pre-built queries         │
         └───────────────┬───────────────┘
                         ▼
         ┌───────────────────────────────┐
         │   SNOWFLAKE ACCOUNT_USAGE     │
         │   • Historical data (365 days)│
         │   • 45min-3hr latency         │
         │   • Complete audit trail      │
         └───────────────────────────────┘
```

### **Data Flow**

1. **User asks natural language question**
2. **Cortex AI Agent interprets intent**
3. **Semantic View translates to SQL**
4. **ACCOUNT_USAGE provides data**
5. **Agent analyzes and provides insights**
6. **Optional: Email alerts triggered**

---

## 🔑 Key Features

### 🎯 **Intelligent Question Routing**
- **Simple queries** → Specialist agents (faster)
- **Complex cross-domain** → Generalist agent (comprehensive)
- **AI automatically chooses best approach**

### 📊 **Comprehensive Metrics**

**Query & Performance:**
- Execution time, compilation, queueing
- Bytes scanned/written/spilled
- Cache efficiency, partition pruning
- 50+ performance metrics

**Security & Auth:**
- Login success/failure rates
- MFA adoption tracking
- Client IP/type analysis
- Authentication patterns

**Cost & Storage:**
- Warehouse credit consumption
- Storage growth (table/stage/failsafe)
- Database-level breakdown
- Cost per query/user/warehouse

**Governance:**
- User/role management
- Grant distribution
- MFA compliance
- Permission auditing

**Operations:**
- Task success rates
- Serverless credits
- Snowpipe throughput
- Clustering efficiency
- MV refresh costs
- Replication tracking
- Data transfer monitoring
- Warehouse queueing

### 🔍 **Cross-Domain Analytics**

Unique ability to correlate across domains:
- **Security + Cost:** "Users with failed logins and expensive queries"
- **Performance + Storage:** "Storage growth vs query performance"
- **Cost + Operations:** "Total credits across all services"
- **Security + Governance:** "Users without MFA by role"

### ✅ **Automated Testing**

27 comprehensive tests covering:
- Data availability checks
- Metric calculations
- Cross-domain queries
- Agent/semantic view validation

---

## 💡 Best Practices

### **When to Use Each Agent**

| Scenario | Agent | Why |
|----------|-------|-----|
| Quick cost check | Cost/Performance Specialist | Faster, focused |
| Security audit | Security Specialist | Dedicated security metrics |
| Overall health | Generalist | Comprehensive view |
| Cross-domain analysis | Generalist | Correlates multiple areas |
| Complex troubleshooting | Generalist | Access to all data |

### **Query Optimization**

1. **Be Specific:** "Show me expensive queries in PROD_WH" vs "Show me queries"
2. **Time Boundaries:** Include time ranges for faster results
3. **Use Specialists:** For single-domain questions
4. **Leverage Verified Queries:** Use built-in examples as templates

### **Security Best Practices**

1. **Monitor Daily:**
   - Failed login attempts
   - MFA adoption rate
   - Privilege escalation attempts

2. **Set Alerts:**
   - ACCOUNTADMIN grants
   - Repeated failed logins
   - Unusual access patterns

3. **Regular Reviews:**
   - User access quarterly
   - Role assignments monthly
   - Policy coverage weekly

### **Cost Optimization**

1. **Track Key Metrics:**
   - Daily credit consumption
   - Warehouse efficiency
   - Storage growth rate
   - Clustering ROI

2. **Identify Waste:**
   - Idle warehouses
   - Excessive spilling
   - Unnecessary clustering
   - Redundant tasks

3. **Right-Size Resources:**
   - Warehouse sizing
   - Storage retention
   - Task frequency
   - Clustering policies

---

## 📚 Documentation

- **[SECURITY_AGENT_ROADMAP.md](SECURITY_AGENT_ROADMAP.md)** - Future enhancements and roadmap
- **[scripts/TEST_ALL_PHASES.sql](scripts/TEST_ALL_PHASES.sql)** - Automated test suite
- [Snowflake Cortex AI Documentation](https://docs.snowflake.com/en/user-guide/ml-powered-features)
- [Account Usage Schema Reference](https://docs.snowflake.com/en/sql-reference/account-usage)
- [Semantic Views Guide](https://docs.snowflake.com/en/user-guide/views-semantic)

---

## 🧪 Testing & Validation

### Run Automated Tests

```bash
# Execute all 27 tests
snowsql -f scripts/TEST_ALL_PHASES.sql -o output_format=table

# Tests include:
# ✅ Phase 1: Query performance (4 tests)
# ✅ Phase 2: Security & auth (4 tests)
# ✅ Phase 3: Cost & storage (3 tests)
# ✅ Phase 4: Governance (3 tests)
# ✅ Phase 5: Task operations (2 tests)
# ✅ Phase 6: Advanced ops (7 tests)
# ✅ Cross-domain (2 tests)
# ✅ System validation (2 tests)
```

### Manual Testing

```sql
-- Test Generalist Agent
USE ROLE cortex_role;
SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_MAINTENANCE_AGENT(
    'What is my overall account health?'
);

-- Test Cost Specialist
SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.COST_PERFORMANCE_AGENT(
    'Show me my most expensive queries'
);

-- Test Security Specialist
SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.SECURITY_MONITORING_AGENT(
    'What is my MFA adoption rate?'
);
```

---

## 🚧 Roadmap & Future Enhancements

See **[SECURITY_AGENT_ROADMAP.md](SECURITY_AGENT_ROADMAP.md)** for detailed plans including:

### **Phase 7: Enhanced Security Agent**
- ACCESS_HISTORY integration
- POLICY_REFERENCES tracking
- SESSIONS monitoring
- Network policy enforcement
- Data classification support

### **Phase 8: Advanced Features**
- CORTEX_* usage tables (AI/ML costs)
- SEARCH_OPTIMIZATION_HISTORY
- COPY_HISTORY
- Real-time MONITORING schema integration
- ORGANIZATION_USAGE cross-account visibility

### **Phase 9: Enterprise Features**
- Custom security rules
- SIEM/SOAR integration
- Advanced alerting
- Compliance reporting
- Multi-account management

---

## 🛠️ Customization

### Add Custom Questions

Edit agent SQL files to include your specific use cases:

```json
"sample_questions": [
    { "question": "Monitor access to CUSTOMER_DATA table" },
    { "question": "Alert on queries to PROD_DB by contractors" },
    { "question": "Track storage growth in ANALYTICS_DB" }
]
```

### Adjust Query Timeout

For large environments:

```json
"execution_environment": {
    "type": "warehouse",
    "warehouse": "CORTEX_WH",
    "query_timeout": 300  // Increase from 180 seconds
}
```

### Configure Email Alerts

```sql
-- Security alerts
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_EMAIL(
    'security-team@company.com',
    'Security Alert: Failed Logins',
    '<html>Alert details...</html>'
);
```

---

## 📊 Monitoring & Maintenance

### Data Latency

| View Category | Latency | Use Case |
|---------------|---------|----------|
| QUERY_HISTORY | 45 min | Near real-time performance |
| LOGIN_HISTORY | 2 hours | Recent security events |
| WAREHOUSE_METERING | 3 hours | Cost tracking |
| STORAGE_USAGE | 2 hours | Storage monitoring |
| DAILY_METERING | 6 hours | Billing reconciliation |

### Warehouse Sizing

Recommended warehouse for Cortex agents:

```sql
-- For small environments (<100 queries/day)
CREATE WAREHOUSE CORTEX_WH
    WAREHOUSE_SIZE = XSMALL;

-- For medium environments (100-1000 queries/day)
CREATE WAREHOUSE CORTEX_WH
    WAREHOUSE_SIZE = SMALL;

-- For large environments (>1000 queries/day)
CREATE WAREHOUSE CORTEX_WH
    WAREHOUSE_SIZE = MEDIUM;
```

---

## 🤝 Contributing

We welcome contributions! Areas for enhancement:

### High Priority
- [ ] Additional security use cases
- [ ] SIEM integration patterns
- [ ] Custom alerting templates
- [ ] Performance optimization playbooks

### Medium Priority
- [ ] Cost optimization rules engine
- [ ] Compliance reporting templates
- [ ] Multi-region deployment guides
- [ ] Advanced visualization examples

### Low Priority
- [ ] Additional language translations
- [ ] Custom dashboards
- [ ] Integration examples

---

## 🆘 Troubleshooting

### Common Issues

**Problem:** "Semantic view not found"
```sql
-- Solution: Verify deployment
SHOW SEMANTIC VIEWS LIKE 'SNOWFLAKE_MAINTENANCE_SVW' 
    IN SCHEMA SNOWFLAKE_INTELLIGENCE.TOOLS;
```

**Problem:** "Permission denied"
```sql
-- Solution: Grant required privileges
USE ROLE ACCOUNTADMIN;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE cortex_role;
```

**Problem:** "Query timeout"
```sql
-- Solution: Increase warehouse size or timeout
ALTER WAREHOUSE CORTEX_WH SET WAREHOUSE_SIZE = MEDIUM;
```

**Problem:** "No data returned"
- **Cause:** Data latency (45min-6hr depending on view)
- **Solution:** Wait for data propagation or query earlier time periods

---

## 📈 Success Metrics

### Track Your ROI

**Security Improvements:**
- ⏱️ Time to detect threats (target: <1 hour)
- 🎯 Security incidents prevented
- 📊 MFA adoption rate (target: >90%)
- 🔒 Policy coverage percentage (target: >95%)

**Performance Gains:**
- ⚡ Average query time reduction
- 💾 Queries with spilling (target: <5%)
- 🎯 Cache hit rate (target: >80%)
- 📈 Query success rate (target: >99%)

**Cost Savings:**
- 💰 Monthly credit reduction
- 📉 Warehouse efficiency improvement
- 🗄️ Storage optimization savings
- ⏰ Operational time saved

---

## 📞 Support

### Getting Help

1. **Check Documentation:**
   - Review this README
   - Check SECURITY_AGENT_ROADMAP.md
   - Run TEST_ALL_PHASES.sql for diagnostics

2. **Common Solutions:**
   - Verify privileges (IMPORTED PRIVILEGES on SNOWFLAKE)
   - Check warehouse status (must be running)
   - Confirm Cortex availability in your region
   - Review data latency expectations

3. **Snowflake Support:**
   - Official documentation: [docs.snowflake.com](https://docs.snowflake.com)
   - Support portal: [community.snowflake.com](https://community.snowflake.com)

---

## 🎉 Acknowledgments

Built with comprehensive understanding of:
- Snowflake ACCOUNT_USAGE schema
- Cortex AI capabilities
- Semantic view best practices
- Real-world operational requirements

**Special Features:**
- ✅ All 6 phases complete
- ✅ 20 ACCOUNT_USAGE tables
- ✅ 94 metrics, 35 dimensions
- ✅ 27 automated tests
- ✅ Triple-agent architecture
- ✅ Production-ready

---

## 📜 License

This project is provided as-is for educational and operational purposes.

---

## 🌟 Get Started Now!

```bash
# 1. Clone repository
git clone <repository-url>

# 2. Deploy in 15 minutes
cd cortex-snowflake-account-info-lab
snowsql -f scripts/1.\ lab\ foundations.sql
snowsql -f scripts/2.\ SNOWFLAKE_INTELLIGENCE.TOOLS\ schema.sql
snowsql -f scripts/2.4\ SNOWFLAKE_MAINTENANCE_SVW_GENERALIST.sql
snowsql -f scripts/5.4\ SNOWFLAKE_MAINTENANCE_AGENT_GENERALIST.sql

# 3. Run tests
snowsql -f scripts/TEST_ALL_PHASES.sql

# 4. Start monitoring!
# Ask: "What's my overall Snowflake account health?"
```

---

**Built with ❄️ for Complete Snowflake Operations Excellence**

[![Star this repo](https://img.shields.io/github/stars/username/repo?style=social)]() 

---

*Last Updated: November 2024 - All 6 Phases Complete*
