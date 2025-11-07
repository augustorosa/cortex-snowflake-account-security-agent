# Dual Agent Architecture

## Overview

The system has been split into **two specialized agents**, each optimized for their specific domain:

### 1. **COST_PERFORMANCE_AGENT** 💰⚡
**Purpose**: Query performance optimization and cost analysis

**Semantic View**: `COST_PERFORMANCE_SVW`
- Direct access to `QUERY_HISTORY` (50+ metrics)
- Direct access to `QUERY_ATTRIBUTION_HISTORY` (cost tracking)

**Capabilities**:
- ✅ Identify slow queries and bottlenecks
- ✅ Analyze query execution patterns
- ✅ Detect queries spilling to disk
- ✅ Review cache hit rates
- ✅ Track credit consumption by warehouse
- ✅ Identify expensive queries and users
- ✅ Analyze cost attribution
- ✅ Recommend warehouse sizing optimizations
- ✅ Monitor warehouse utilization
- ✅ Detect idle or oversized warehouses

**Usage**:
```sql
SELECT SNOWFLAKE_INTELLIGENCE.CORTEX_AGENT_RUN(
    'COST_PERFORMANCE_AGENT', 
    'What were the most expensive queries in the last hour?'
);

SELECT SNOWFLAKE_INTELLIGENCE.CORTEX_AGENT_RUN(
    'COST_PERFORMANCE_AGENT', 
    'Which queries are spilling to disk?'
);

SELECT SNOWFLAKE_INTELLIGENCE.CORTEX_AGENT_RUN(
    'COST_PERFORMANCE_AGENT', 
    'Show me failed queries with error details'
);
```

---

### 2. **SECURITY_MONITORING_AGENT** 🔒🚨
**Purpose**: Login security analysis and threat detection

**Semantic View**: `SECURITY_MONITORING_SVW`
- Provides SQL queries for 6 security helper views
- Analyzes login patterns (last 7 days, real-time)

**Capabilities**:
- ✅ Monitor failed login attempts
- ✅ Detect brute force attacks
- ✅ Identify suspicious IP addresses
- ✅ Track authentication patterns
- ✅ Analyze risk patterns (HIGH/MEDIUM/LOW)
- ✅ Identify network policy blocks
- ✅ Track user success rates
- ✅ Send security alert emails

**Available Helper Views**:
1. `LOGIN_ACTIVITY_VW` - Raw login events
2. `LOGIN_SECURITY_DASHBOARD_VW` - Summary metrics
3. `SUSPICIOUS_LOGIN_PATTERNS_VW` - Risk-scored threats
4. `FAILED_LOGIN_SUMMARY_VW` - Aggregated failures
5. `LOGIN_SUCCESS_RATE_VW` - User authentication health
6. `LOGIN_IP_ANALYSIS_VW` - IP reputation analysis

**Usage**:
```sql
SELECT SNOWFLAKE_INTELLIGENCE.CORTEX_AGENT_RUN(
    'SECURITY_MONITORING_AGENT', 
    'Show me failed login attempts'
);

SELECT SNOWFLAKE_INTELLIGENCE.CORTEX_AGENT_RUN(
    'SECURITY_MONITORING_AGENT', 
    'Are there any suspicious login attempts or brute force attacks?'
);

SELECT SNOWFLAKE_INTELLIGENCE.CORTEX_AGENT_RUN(
    'SECURITY_MONITORING_AGENT', 
    'Which IP addresses are suspicious?'
);
```

---

## Architecture Rationale

### Why Two Agents?

**1. Semantic View Limitations**
- Semantic views work best with "fact tables" like `QUERY_HISTORY`
- Login security data from helper views (wrapping table functions) cannot be effectively queried through semantic views
- Splitting allows each agent to use the optimal data access pattern

**2. Specialized Expertise**
- Cost/Performance agent can provide **direct analysis** of query metrics
- Security agent provides **SQL queries** for investigation (which is appropriate for security workflows)

**3. Better User Experience**
- Users get clearer, more focused responses
- Each agent has deep expertise in its domain
- No confusion about data availability

**4. Maintenance & Evolution**
- Easier to enhance each agent independently
- Clearer separation of concerns
- Simpler testing and validation

---

## Agent Behavior Differences

### COST_PERFORMANCE_AGENT
**Directly answers questions** by querying the semantic view:
- ✅ "Your top 10 most expensive queries used X credits..."
- ✅ "You have 5 queries spilling to remote storage..."
- ✅ "Warehouse Y consumed 85% of your credits..."

### SECURITY_MONITORING_AGENT
**Provides SQL queries** for investigation:
- ✅ "To see failed login attempts, run this query: `SELECT...`"
- ✅ "Here's the SQL to check suspicious IPs: `SELECT...`"
- ✅ "Query the LOGIN_SECURITY_DASHBOARD_VW with: `SELECT...`"

This is intentional - security investigations benefit from having the raw SQL to:
- Customize queries for specific needs
- Combine with other security tools
- Integrate into monitoring workflows
- Maintain audit trails

---

## Deployment

All components are deployed and operational:

✅ **Semantic Views**:
- `SNOWFLAKE_INTELLIGENCE.TOOLS.COST_PERFORMANCE_SVW`
- `SNOWFLAKE_INTELLIGENCE.TOOLS.SECURITY_MONITORING_SVW`

✅ **Agents**:
- `SNOWFLAKE_INTELLIGENCE.AGENTS.COST_PERFORMANCE_AGENT`
- `SNOWFLAKE_INTELLIGENCE.AGENTS.SECURITY_MONITORING_AGENT`

✅ **Helper Views** (6 security views in `SNOWFLAKE_INTELLIGENCE.TOOLS`):
- All login security helper views are deployed and queryable

---

## Example Questions by Agent

### Cost & Performance Questions → COST_PERFORMANCE_AGENT
- "What were the most expensive queries in the last hour?"
- "Which queries are spilling to disk?"
- "Show me failed queries with error details"
- "Which users are running the slowest queries?"
- "Which warehouses are consuming the most credits?"
- "Show queries with low cache hit rates"
- "What's my average query execution time?"
- "Which queries scan the most data?"

### Security Questions → SECURITY_MONITORING_AGENT
- "Show me failed login attempts"
- "Are there any suspicious login attempts or brute force attacks?"
- "Which IP addresses are suspicious?"
- "Summarize failed login attempts by user"
- "Which users have authentication problems?"
- "Show me all login activity from the last 24 hours"
- "What's my overall login security status?"
- "Which users have the lowest success rates?"
- "Show me login attempts blocked by network policies"

---

## Benefits of This Architecture

✅ **Clear Separation**: Each agent knows exactly what it can and cannot do
✅ **Optimal Performance**: Each agent uses the best data access pattern for its domain
✅ **Better Responses**: Cost agent provides direct answers, security agent provides investigative SQL
✅ **Maintainability**: Easier to enhance and debug each agent independently
✅ **User Clarity**: Users know which agent to use for which questions
✅ **Future-Proof**: Easy to add more specialized agents (e.g., storage, compliance, automation)

---

## Migration from Single Agent

The original `ENHANCED_SECURITY_AGENT` has been replaced by these two specialized agents:
- **Query/Cost questions** → Use `COST_PERFORMANCE_AGENT`
- **Security/Login questions** → Use `SECURITY_MONITORING_AGENT`

All underlying data and helper views remain the same - only the agent interface has changed.

---

## Next Steps

1. **Test both agents** with your specific questions
2. **Integrate into workflows** (dashboards, alerts, reports)
3. **Consider additional specialized agents**:
   - Storage management agent
   - Compliance/audit agent
   - Data pipeline monitoring agent
   - Task & automation agent

Each new agent can leverage the existing helper views and semantic views.

