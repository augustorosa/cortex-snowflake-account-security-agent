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

### 🤖 **AI Agents**

#### ⭐ **Generalist Agent** (Recommended - Deploy This)
The **comprehensive all-in-one solution** that monitors everything:
- ✅ Security + Cost + Performance + Governance + Operations
- ✅ 24 ACCOUNT_USAGE tables covering all monitoring domains
- ✅ 94 pre-built metrics across all areas
- ✅ Cross-domain analysis (e.g., "users with high costs AND failed logins")
- ✅ Perfect for: Overall health checks, complex correlations, complete visibility

**This is the agent you want!** It includes everything the specialists have, plus the ability to correlate across domains.

#### 🔧 **Specialist Agents** (Optional - For Focused Workflows)
If you prefer focused, single-domain agents:

1. **Cost/Performance Agent** - Fast, focused cost/performance queries only
2. **Security Agent** - Dedicated security monitoring only

**Note:** Specialists are subsets of the Generalist. Deploy them only if you want separate focused tools for specific teams.

---

## 🚀 Quick Start

### Prerequisites
- Snowflake account with ACCOUNTADMIN access
- Cortex features enabled in your region
- 5-10 minutes for deployment

### ⭐ Recommended Installation (Generalist Only)

```bash
# 1. Clone repository
git clone https://github.com/augustorosa/cortex-snowflake-account-security-agent.git
cd cortex-snowflake-account-security-agent

# 2. Deploy in 3 simple steps (5-7 minutes total)
snowsql -f "scripts/1. lab foundations.sql"                        # Foundation
snowsql -f "scripts/2. SNOWFLAKE_MAINTENANCE_SVW_GENERALIST.sql"   # Semantic View
snowsql -f "scripts/3. SNOWFLAKE_MAINTENANCE_AGENT_GENERALIST.sql" # AI Agent

# 3. Test it
SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_MAINTENANCE_AGENT(
    'What is my overall account health?'
);
```

**That's it!** 🎉 You now have complete monitoring coverage with just 3 commands.

### 🔧 Optional: Deploy Specialist Agents

If you want focused single-domain agents for specific teams:

```bash
# Cost/Performance Specialist (optional)
snowsql -f "scripts/2.2 COST_PERFORMANCE_SVW_SPECIALIST.sql"
snowsql -f "scripts/5.2 COST_PERFORMANCE_AGENT_SPECIALIST.sql"

# Security Specialist (optional)
snowsql -f "scripts/2.3 SECURITY_MONITORING_SVW_SPECIALIST.sql"
snowsql -f "scripts/5.3 SECURITY_MONITORING_AGENT_SPECIALIST.sql"

# Email alerts (optional)
snowsql -f "scripts/4. email integration.sql"

# Marketplace acceptance (optional - for specific use cases)
snowsql -f "scripts/5. accept marketplace terms.sql"
```

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

## 📊 What's Included (Generalist Agent)

**Data Coverage:**
- 24 Snowflake ACCOUNT_USAGE tables
- 100+ pre-built metrics
- 40+ dimensions for analysis
- 365 days of historical data

**Monitoring Domains:**
- 🔍 **Query Performance:** Execution metrics, slow queries, cache efficiency
- 🔒 **Security & Authentication:** Login tracking, MFA adoption, session monitoring, suspicious activity
- 💰 **Cost Analysis:** Warehouse credits, storage costs, task expenses, clustering, replication
- 👥 **Governance:** User/role management, permission auditing, grant distribution
- ⚡ **Operations:** Task execution, Snowpipe loading, warehouse queueing
- 🛡️ **Policy Compliance:** Password policies, session policies, network policies
- 🔧 **Advanced Operations:** Clustering, materialized views, cross-region transfers

**Testing:**
- 27+ automated validation tests
- Coverage across all monitoring areas
- System health verification

---

## 📁 Repository Structure

```
cortex-snowflake-account-security-agent/
├── README.md                                          ⬅️ You are here
│
├── scripts/
│   ├── 1. lab foundations.sql                         🏗️  Foundation & schema setup
│   ├── 2. SNOWFLAKE_MAINTENANCE_SVW_GENERALIST.sql    ⭐ Generalist semantic view
│   ├── 3. SNOWFLAKE_MAINTENANCE_AGENT_GENERALIST.sql  ⭐ Generalist AI agent
│   │
│   ├── 4. email integration.sql                       📧 Email notifications (optional)
│   ├── 5. accept marketplace terms.sql                📝 Marketplace (optional)
│   │
│   ├── 2.2 COST_PERFORMANCE_SVW_SPECIALIST.sql        💰 Cost specialist (optional)
│   ├── 5.2 COST_PERFORMANCE_AGENT_SPECIALIST.sql      🤖 Cost agent (optional)
│   │
│   ├── 2.3 SECURITY_MONITORING_SVW_SPECIALIST.sql     🔒 Security specialist (optional)
│   ├── 5.3 SECURITY_MONITORING_AGENT_SPECIALIST.sql   🤖 Security agent (optional)
│   │
│   └── TEST_ALL_PHASES.sql                            ✅ Automated tests
│
└── docs/
    ├── SECURITY_AGENT_ROADMAP.md                      📋 Future enhancements
    ├── HOW_TO_USE_SNOWFLAKE_SEMANTIC_VIEWS.md         📚 Semantic views guide
    └── .github-info.md                                📄 Project documentation
```

---

## 🎯 How to Use

### **Via SQL (Recommended):**

```sql
-- Ask the Generalist Agent anything - it knows everything!
SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_MAINTENANCE_AGENT(
    'What is my overall account health?'
);

SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_MAINTENANCE_AGENT(
    'Show me users with failed logins and expensive queries'
);

SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_MAINTENANCE_AGENT(
    'What are my total costs and storage growth?'
);
```

### **In Snowflake UI:**

1. Navigate to **AI & ML** → **Snowflake Cortex**
2. Select `SNOWFLAKE_MAINTENANCE_AGENT`
3. Type your question in plain English
4. Get instant insights and recommendations

### **If You Deployed Specialists (Optional):**

```sql
-- Cost/Performance specialist (subset of Generalist)
SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.COST_PERFORMANCE_AGENT(
    'Show me my most expensive queries'
);

-- Security specialist (subset of Generalist)
SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.SECURITY_MONITORING_AGENT(
    'What is my MFA adoption rate?'
);
```

---

## 💡 Best Practices

### **Agent Selection Guide**

**🎯 95% of Use Cases:** Use the **Generalist Agent**
- It has ALL the data and can answer ANY question
- Cross-domain analysis (correlate security + cost + performance)
- Single place to ask questions

**🔧 Special Cases:** Use Specialist Agents if:
- You have separate teams (security team only needs security agent)
- You want to limit scope for specific workflows
- You need faster responses for very focused queries (rare)

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

## 🌟 Get Started (3 Simple Steps)

```bash
# Clone repository
git clone https://github.com/augustorosa/cortex-snowflake-account-security-agent.git
cd cortex-snowflake-account-security-agent

# Deploy in 3 commands (5-7 minutes)
snowsql -f "scripts/1. lab foundations.sql"                        # Step 1: Foundation
snowsql -f "scripts/2. SNOWFLAKE_MAINTENANCE_SVW_GENERALIST.sql"   # Step 2: Semantic View
snowsql -f "scripts/3. SNOWFLAKE_MAINTENANCE_AGENT_GENERALIST.sql" # Step 3: AI Agent

# Start monitoring!
SELECT SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_MAINTENANCE_AGENT(
    'What is my overall Snowflake account health?'
);
```

**Optional:** Deploy specialists if you want focused single-domain agents (see Quick Start section above).

---

**Built with ❄️ for Snowflake Operations Excellence**

[![Star this repo](https://img.shields.io/github/stars/augustorosa/cortex-snowflake-account-security-agent?style=social)](https://github.com/augustorosa/cortex-snowflake-account-security-agent)

---

*Production-ready AI monitoring for Snowflake*
