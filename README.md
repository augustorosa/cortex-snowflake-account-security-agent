# 🎯 Snowflake Operations Monitoring with Cortex AI

> **Ask natural language questions to monitor your Snowflake environment**

[![Snowflake](https://img.shields.io/badge/Snowflake-Complete-29B5E8?logo=snowflake)](https://www.snowflake.com/)
[![Cortex AI](https://img.shields.io/badge/Cortex_AI-Enabled-00A3E0)](https://docs.snowflake.com/en/user-guide/ml-powered-features)
[![Status](https://img.shields.io/badge/Status-Production_Ready-success)]()

---

## 🌟 Overview

Transform how you monitor Snowflake with AI-powered agents that answer questions in plain English. No more writing complex SQL queries—just ask what you need to know.

**Example questions:**
- *"What's my overall Snowflake account health?"*
- *"Show me users with failed logins and expensive queries"*
- *"What are my total costs across all services?"*
- *"Which warehouses have queueing issues?"*

---

## ✨ What This Does

### 💬 **Natural Language Monitoring**

Ask questions in plain English and get instant answers about:

**🔒 Security & Authentication**
- Login attempts, failures, and patterns
- MFA adoption tracking
- Suspicious IP activity
- User authentication analysis

**💰 Cost & Resource Usage**
- Warehouse credit consumption
- Storage costs and growth trends
- Query attribution and expenses
- Serverless task costs
- Data transfer and replication costs

**⚡ Performance & Operations**
- Query execution metrics
- Slow query identification
- Cache efficiency analysis
- Warehouse queueing and load
- Task execution monitoring
- Snowpipe data loading

**👥 Governance & Compliance**
- User and role management
- Permission auditing
- Grant distribution
- MFA compliance rates

**🔧 Advanced Operations**
- Automatic clustering costs
- Materialized view refresh tracking
- Replication monitoring
- Cross-region data transfers
- Daily billable credit reconciliation

### 🤖 **Three AI Agents**

1. **Generalist Agent** - Comprehensive cross-domain analysis
   - Best for: Overall health checks, complex correlations
   - Example: *"Show users with high costs AND failed logins"*

2. **Cost/Performance Agent** - Fast, focused queries
   - Best for: Quick cost checks, performance analysis
   - Example: *"What are my most expensive queries?"*

3. **Security Agent** - Dedicated security monitoring
   - Best for: Security audits, compliance checks
   - Example: *"What's my MFA adoption rate?"*

---

## 🚀 Quick Start

### Prerequisites
- Snowflake account with ACCOUNTADMIN access
- Cortex features enabled in your region
- 15 minutes for deployment

### Installation

```bash
# 1. Clone repository
git clone https://github.com/augustorosa/cortex-snowflake-account-security-agent.git
cd cortex-snowflake-account-security-agent

# 2. Deploy all components (15 minutes)
snowsql -f "scripts/1. lab foundations.sql"
snowsql -f "scripts/2. SNOWFLAKE_INTELLIGENCE.TOOLS schema.sql"
snowsql -f "scripts/2.2 COST_PERFORMANCE_SVW_SPECIALIST.sql"
snowsql -f "scripts/5.2 COST_PERFORMANCE_AGENT_SPECIALIST.sql"
snowsql -f "scripts/2.3 SECURITY_MONITORING_SVW_SPECIALIST.sql"
snowsql -f "scripts/5.3 SECURITY_MONITORING_AGENT_SPECIALIST.sql"
snowsql -f "scripts/2.4 SNOWFLAKE_MAINTENANCE_SVW_GENERALIST.sql"
snowsql -f "scripts/5.4 SNOWFLAKE_MAINTENANCE_AGENT_GENERALIST.sql"

# 3. Optional: Email alerts
snowsql -f "scripts/3. email integration.sql"

# 4. Test everything
snowsql -f "scripts/TEST_ALL_PHASES.sql"
```

**That's it!** 🎉 Start asking questions.

---

## 💬 Example Questions

### 🎯 **Overall Health**
```
"What's my overall Snowflake account health?"
"Show me total costs across all services"
"What are my biggest operational issues?"
```

### 💰 **Cost Analysis**
```
"Which warehouses are most expensive this month?"
"Show me queries costing more than $10"
"What's my storage growth trend?"
"How much am I spending on clustering?"
```

### 🔒 **Security Monitoring**
```
"Show me failed login attempts"
"What's my MFA adoption rate?"
"Which IP addresses have suspicious activity?"
"Show users without MFA"
```

### ⚡ **Performance**
```
"What are my slowest queries today?"
"Which warehouses have queueing issues?"
"Show queries spilling to disk"
"What's my cache hit rate?"
```

### 🔗 **Cross-Domain**
```
"Users with high costs + failed logins"
"Show expensive queries with security issues"
"Which users without MFA are running expensive queries?"
```

---

## 📊 What's Included

**Data Coverage:**
- 20 Snowflake ACCOUNT_USAGE tables
- 94 pre-built metrics
- 35 dimensions for analysis
- 365 days of historical data

**Monitoring Areas:**
- Query execution and performance
- Authentication and login security
- Cost tracking (warehouses, storage, tasks, pipes, clustering, MVs)
- User and role governance
- Task and serverless operations
- Data loading and replication
- Warehouse load and queueing

**Testing:**
- 27 automated validation tests
- Coverage across all monitoring areas
- System health verification

---

## 📁 Repository Structure

```
cortex-snowflake-account-security-agent/
├── README.md                                       ⬅️ You are here
├── SECURITY_AGENT_ROADMAP.md                       📋 Future enhancements
│
├── scripts/
│   ├── 1. lab foundations.sql                      🏗️  Foundation setup
│   ├── 2. SNOWFLAKE_INTELLIGENCE.TOOLS schema.sql  📦 Schema creation
│   │
│   ├── 2.2 COST_PERFORMANCE_SVW_SPECIALIST.sql     💰 Cost specialist
│   ├── 5.2 COST_PERFORMANCE_AGENT_SPECIALIST.sql   🤖 Cost agent
│   │
│   ├── 2.3 SECURITY_MONITORING_SVW_SPECIALIST.sql  🔒 Security specialist
│   ├── 5.3 SECURITY_MONITORING_AGENT_SPECIALIST.sql 🤖 Security agent
│   │
│   ├── 2.4 SNOWFLAKE_MAINTENANCE_SVW_GENERALIST.sql ⭐ Generalist view
│   ├── 5.4 SNOWFLAKE_MAINTENANCE_AGENT_GENERALIST.sql ⭐ Generalist agent
│   │
│   ├── 3. email integration.sql                    📧 Email notifications
│   └── TEST_ALL_PHASES.sql                         ✅ Automated tests
│
└── docs/                                           📚 Additional documentation
```

---

## 🎯 How to Use

### **In Snowflake UI:**

1. Navigate to AI & ML → Snowflake Cortex
2. Select one of the agents:
   - `SNOWFLAKE_MAINTENANCE_AGENT` (generalist)
   - `COST_PERFORMANCE_AGENT` (specialist)
   - `SECURITY_MONITORING_AGENT` (specialist)
3. Type your question in plain English
4. Get instant insights and recommendations

### **Via SQL:**

```sql
-- Ask the generalist agent
SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_MAINTENANCE_AGENT(
    'What is my overall account health?'
);

-- Ask the cost specialist
SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.COST_PERFORMANCE_AGENT(
    'Show me my most expensive queries'
);

-- Ask the security specialist
SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.SECURITY_MONITORING_AGENT(
    'What is my MFA adoption rate?'
);
```

---

## 💡 Best Practices

### **Choosing the Right Agent**

| Scenario | Agent | Why |
|----------|-------|-----|
| Quick cost check | Cost/Performance | Faster, focused results |
| Security audit | Security | Dedicated security metrics |
| Overall health | Generalist | Complete picture |
| Complex analysis | Generalist | Cross-domain insights |

### **Query Tips**

1. **Be Specific:** Include time ranges, warehouse names, user names
2. **Use Natural Language:** Write as if asking a colleague
3. **Start Simple:** Begin with overview questions, then drill down
4. **Combine Contexts:** Generalist agent can correlate across domains

### **Security Best Practices**

✅ Monitor daily: Failed logins, MFA adoption, privilege changes  
✅ Set alerts: ACCOUNTADMIN grants, repeated failures  
✅ Regular reviews: User access (quarterly), roles (monthly)  

### **Cost Optimization**

✅ Track trends: Daily credit consumption, storage growth  
✅ Identify waste: Idle warehouses, excessive spilling  
✅ Right-size: Warehouses, storage retention, task frequency  

---

## 🧪 Testing & Validation

```bash
# Run all 27 automated tests
snowsql -f scripts/TEST_ALL_PHASES.sql -o output_format=table
```

Tests cover:
- Data availability
- Metric calculations
- Cross-domain queries
- System validation

---

## 🚧 Future Enhancements

See **[SECURITY_AGENT_ROADMAP.md](SECURITY_AGENT_ROADMAP.md)** for upcoming features:

- Enhanced security agent with data access tracking
- Policy compliance monitoring
- Data classification support
- SIEM/SOAR integration
- Multi-account management
- Real-time monitoring capabilities

---

## 🛠️ Customization

### Add Custom Questions

Edit agent SQL files to include your specific use cases in the `sample_questions` section.

### Configure Email Alerts

```sql
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_EMAIL(
    'security-team@company.com',
    'Security Alert',
    '<html>Alert details...</html>'
);
```

### Adjust Timeouts

For large environments, modify `query_timeout` in agent definitions.

---

## 📊 Data Latency

| Data Source | Latency | Use Case |
|-------------|---------|----------|
| Query data | 45 min | Near real-time performance |
| Login data | 2 hours | Recent security events |
| Storage data | 2 hours | Storage monitoring |
| Metering data | 3-6 hours | Cost tracking |

---

## 🆘 Troubleshooting

### Common Issues

**"Semantic view not found"**
```sql
-- Verify deployment
SHOW SEMANTIC VIEWS IN SCHEMA SNOWFLAKE_INTELLIGENCE.TOOLS;
```

**"Permission denied"**
```sql
-- Grant required privileges
USE ROLE ACCOUNTADMIN;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE cortex_role;
```

**"Query timeout"**
```sql
-- Increase warehouse size
ALTER WAREHOUSE CORTEX_WH SET WAREHOUSE_SIZE = MEDIUM;
```

**"No data returned"**
- Wait for data propagation (45min-6hr depending on source)
- Check time range in your question
- Verify warehouse is running

---

## 📚 Documentation

- **[SECURITY_AGENT_ROADMAP.md](SECURITY_AGENT_ROADMAP.md)** - Future enhancements
- **[scripts/TEST_ALL_PHASES.sql](scripts/TEST_ALL_PHASES.sql)** - Test suite
- [Snowflake Cortex AI Docs](https://docs.snowflake.com/en/user-guide/ml-powered-features)
- [Account Usage Reference](https://docs.snowflake.com/en/sql-reference/account-usage)
- [Semantic Views Guide](https://docs.snowflake.com/en/user-guide/views-semantic)

---

## 🤝 Contributing

Areas for enhancement:
- Additional security use cases
- SIEM integration patterns
- Cost optimization rules
- Performance playbooks
- Custom alerting templates

---

## 📈 Success Metrics

**Track your ROI:**

🔒 **Security:** Time to detect threats, MFA adoption rate, policy coverage  
⚡ **Performance:** Query time reduction, cache hit rate, spilling reduction  
💰 **Cost:** Monthly credit savings, warehouse efficiency, storage optimization  

---

## 📞 Support

1. **Documentation:** Review README and SECURITY_AGENT_ROADMAP.md
2. **Diagnostics:** Run `TEST_ALL_PHASES.sql` for system health
3. **Snowflake Support:** [docs.snowflake.com](https://docs.snowflake.com)

---

## 🌟 Get Started

```bash
git clone https://github.com/augustorosa/cortex-snowflake-account-security-agent.git
cd cortex-snowflake-account-security-agent

# Deploy in 15 minutes
snowsql -f scripts/1.\ lab\ foundations.sql
snowsql -f scripts/2.\ SNOWFLAKE_INTELLIGENCE.TOOLS\ schema.sql
snowsql -f scripts/2.4\ SNOWFLAKE_MAINTENANCE_SVW_GENERALIST.sql
snowsql -f scripts/5.4\ SNOWFLAKE_MAINTENANCE_AGENT_GENERALIST.sql

# Start monitoring!
# Ask: "What's my overall Snowflake account health?"
```

---

**Built with ❄️ for Snowflake Operations Excellence**

[![Star this repo](https://img.shields.io/github/stars/augustorosa/cortex-snowflake-account-security-agent?style=social)](https://github.com/augustorosa/cortex-snowflake-account-security-agent)

---

*Production-ready AI monitoring for Snowflake*
