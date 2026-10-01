# Architecture Overview: Snowflake Security & Performance Monitoring Solution

## 🏗️ System Architecture

This solution uses a **hybrid architecture** to work around Snowflake semantic view limitations while providing comprehensive security and performance monitoring through Cortex AI.

```
┌─────────────────────────────────────────────────────────────────┐
│                     Cortex AI Agent                             │
│        (Natural Language Interface)                             │
└─────────────────┬───────────────────────────────────────────────┘
                  │
        ┌─────────┴──────────┐
        │                    │
        ▼                    ▼
┌───────────────┐    ┌──────────────────────┐
│  Semantic View│    │   Helper Views       │
│  (Query Data) │    │   (Security Data)    │
└───────┬───────┘    └──────┬───────────────┘
        │                   │
        ▼                   ▼
┌─────────────────────────────────────────┐
│     Snowflake Account Usage             │
│  - QUERY_HISTORY                        │
│  - QUERY_ATTRIBUTION_HISTORY            │
│  - LOGIN_HISTORY (table function)       │
│  - ACCESS_HISTORY                       │
└─────────────────────────────────────────┘
```

## 📊 Component Breakdown

### 1. **Semantic View** (`ENHANCED_SECURITY_DIAGNOSTICS_SVW`)
**Purpose:** Enable natural language queries for query performance and cost data

**Tables Included:**
- ✅ `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` (50+ metrics)
- ✅ `SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY` (credit attribution)

**Why Limited?**
Semantic views have strict requirements:
- ❌ Cannot reference table functions (like `LOGIN_HISTORY()`)
- ❌ Cannot reference views that wrap table functions
- ❌ Some Account Usage table columns aren't accessible to non-ACCOUNTADMIN roles
- ✅ Only works reliably with direct Account Usage tables with accessible columns

**Capabilities:**
- Query performance analysis
- Cost tracking and attribution
- Warehouse utilization
- Query execution patterns
- Failed query analysis

### 2. **Helper Views** (`01_flattened_access_history_views.sql`)
**Purpose:** Provide direct SQL access to security data not available in semantic views

**Views Created:**
- `LOGIN_ACTIVITY_VW` - Login attempts (last 7 days, real-time via table function)
- `ACCESS_BASE_OBJECTS_VW` - Base tables accessed through views
- `ACCESS_DIRECT_OBJECTS_VW` - Direct object access
- `ACCESS_OBJECTS_MODIFIED_VW` - Data modifications
- `ACCESS_POLICIES_APPLIED_VW` - Policy enforcement
- `SENSITIVE_TABLE_ACCESS_VW` - Access to sensitive data
- `SESSION_ACTIVITY_VW` - Session information
- `STAGE_INVENTORY_VW` - External stage security
- `CLUSTERING_ACTIVITY_VW` - Clustering operations
- `WAREHOUSE_METERING_VW` - Warehouse metrics
- `TASK_ACTIVITY_VW` - Task execution

**Why Separate?**
These views use:
- Table functions (not supported in semantic views)
- Complex JSON flattening (ARRAY/VARIANT columns)
- Columns not consistently exposed across Snowflake editions

**Access Pattern:**
Users and the AI agent query these views directly with SQL

### 3. **Cortex AI Agent** (`SNOWFLAKE_SECURITY_PERFORMANCE_AGENT`)
**Purpose:** Unified natural language interface for both semantic view and helper views

**Orchestration Strategy:**
```
User Question → Agent Analyzes
                     │
        ┌────────────┼────────────┐
        │                         │
        ▼                         ▼
Is it about queries/cost?   Is it about security?
        │                         │
        ▼                         ▼
Use Semantic View          Provide SQL for Helper Views
(Natural language)         (Direct SQL queries)
```

**Example Responses:**

**Query/Cost Questions** (Uses Semantic View):
- "Show me expensive queries" → Agent queries semantic view
- "Which users ran the most queries?" → Agent queries semantic view
- "What were failed queries yesterday?" → Agent queries semantic view

**Security Questions** (Uses Helper Views):
- "Show me failed logins" → Agent provides: `SELECT * FROM LOGIN_ACTIVITY_VW WHERE IS_SUCCESS = 'NO'`
- "Who accessed sensitive tables?" → Agent provides: `SELECT * FROM SENSITIVE_TABLE_ACCESS_VW`
- "Show data modifications" → Agent provides: `SELECT * FROM ACCESS_OBJECTS_MODIFIED_VW`

## 🔐 Security Data Access Patterns

### Pattern 1: Real-Time Login Monitoring
```sql
-- Agent provides this SQL to users
SELECT 
    EVENT_TYPE,
    USER_NAME,
    CLIENT_IP,
    IS_SUCCESS,
    ERROR_CODE,
    ERROR_MESSAGE
FROM COWORK.TOOLS.LOGIN_ACTIVITY_VW
WHERE IS_SUCCESS = 'NO'
ORDER BY USER_NAME;
```

### Pattern 2: Data Access Audit
```sql
-- Agent provides this SQL to users
SELECT 
    BASE_OBJECT_NAME,
    USER_NAME,
    QUERY_START_TIME,
    COLUMN_NAME
FROM COWORK.TOOLS.ACCESS_BASE_OBJECTS_VW
WHERE BASE_OBJECT_NAME LIKE '%CUSTOMER%'
ORDER BY QUERY_START_TIME DESC;
```

### Pattern 3: Sensitive Data Access with Policy Enforcement
```sql
-- Agent provides this SQL to users
SELECT * 
FROM COWORK.TOOLS.SENSITIVE_TABLE_ACCESS_VW
ORDER BY ACCESS_TIME DESC;
```

## 📝 Why This Architecture?

### Limitations We Worked Around:
1. **Semantic Views Can't Use Table Functions**
   - `LOGIN_HISTORY()` is a table function
   - Solution: Create `LOGIN_ACTIVITY_VW` that wraps it, query directly

2. **Semantic Views Can't Handle Complex JSON**
   - `ACCESS_HISTORY` has ARRAY/VARIANT columns
   - Solution: Flatten into separate views, query directly

3. **Not All Account Usage Columns Accessible**
   - Role permissions limit column visibility
   - Solution: Only include proven-working columns in semantic view

4. **Timestamp Dimensions Limited**
   - Only `QUERY_HISTORY` timestamps work as dimensions
   - Solution: Use `QUERY_HISTORY.START_TIME` for time filtering

### Benefits of This Approach:
✅ **Best of Both Worlds**
   - Natural language for query/cost analysis (semantic view)
   - Direct SQL for security data (helper views)

✅ **Real-Time Security Data**
   - `LOGIN_HISTORY()` table function provides last 7 days real-time
   - No 45-minute latency like Account Usage tables

✅ **Comprehensive Coverage**
   - Query performance: Semantic view
   - Security monitoring: Helper views
   - Cost tracking: Semantic view
   - Access patterns: Helper views

✅ **Maintainable & Extensible**
   - Add new helper views without breaking semantic view
   - Proven patterns for each data type

## 🚀 Deployment Order

1. **Foundation** (`01_lab_foundations.sql`)
   - Create database, schema, role, warehouse

2. **Helper Views** (`01_flattened_access_history_views.sql`)
   - Create all security helper views
   - Grant SELECT to PUBLIC

3. **Semantic View** (`05_enhanced_security_diagnostics_svw.sql`)
   - Create semantic view for query/cost data
   - Grant SELECT to PUBLIC

4. **Email Integration** (`02_email_integration.sql` - Optional)
   - Setup notification capabilities

5. **Documentation** (`4. accept marketplace terms.sql` - Optional)
   - Accept Snowflake docs marketplace terms

6. **AI Agent** (`5.1 ENHANCED_SECURITY_AGENT.sql`)
   - Create Cortex agent with orchestration logic
   - Grant USAGE to PUBLIC

## 🎯 Success Metrics

With this architecture, the AI agent can answer:

**Query Performance (Semantic View):**
- ✅ "What were the slowest queries yesterday?"
- ✅ "Show me queries that spilled to disk"
- ✅ "Which warehouses are most expensive?"

**Security (Helper Views):**
- ✅ "Show me failed login attempts" (provides SQL)
- ✅ "Who accessed the CUSTOMERS table?" (provides SQL)
- ✅ "Show sensitive data access without policies" (provides SQL)

**Cost (Semantic View):**
- ✅ "What were the most expensive queries?"
- ✅ "Show credit consumption by user"
- ✅ "Which operations cost the most?"

## 📚 Key Documentation References

- [Snowflake Semantic Views](https://docs.snowflake.com/en/user-guide/views-semantic/sql)
- [LOGIN_HISTORY Table Function](https://docs.snowflake.com/en/sql-reference/functions/login_history)
- [Account Usage Views](https://docs.snowflake.com/en/sql-reference/account-usage)
- [Cortex AI Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)

## 🔄 Future Enhancements

When Snowflake adds support for:
- ✨ Table functions in semantic views
- ✨ Better JSON/ARRAY column handling
- ✨ More flexible timestamp dimensions

We can consolidate more data into the semantic view for true unified natural language access.

