# 🗺️ SNOWFLAKE INTELLIGENCE PLATFORM ROADMAP

**Status:** Phase 1-6 Complete | 20 Tables | 94 Metrics | 3 Agents Deployed

Based on comprehensive analysis of the [SNOWFLAKE database](https://docs.snowflake.com/en/sql-reference/snowflake-db) and lessons learned from Phase 1-6 implementation.

---

## 📊 **CURRENT STATE (✅ COMPLETE)**

### **Architecture:**
- **Generalist Agent:** `SNOWFLAKE_MAINTENANCE_AGENT` - Cross-domain analysis (20 tables)
- **Specialist Agent 1:** `COST_PERFORMANCE_AGENT` - Fast cost/performance queries
- **Specialist Agent 2:** `SECURITY_MONITORING_AGENT` - Fast security/login queries

### **Coverage:**
| Domain | Tables | Dimensions | Metrics | Status |
|--------|--------|------------|---------|--------|
| **Query & Performance** | 2 | 21 | 20 | ✅ Complete |
| **Security & Auth** | 1 | 12 | 10 | ✅ Complete |
| **Cost & Storage** | 4 | 2 | 16 | ✅ Complete |
| **Governance** | 4 | 0 | 10 | ✅ Complete (metrics-only) |
| **Task Operations** | 2 | 0 | 10 | ✅ Complete (metrics-only) |
| **Advanced Operations** | 7 | 0 | 28 | ✅ Complete (metrics-only) |
| **TOTAL** | **20** | **35** | **94** | **✅** |

---

## 🎯 **PHASE 7-10: SECURITY & GOVERNANCE EXPANSION**

### **Phase 7: Enhanced Security Monitoring** 🔒 *[HIGH PRIORITY]*

**Objective:** Expand security agent to full threat detection and compliance monitoring

**New Tables to Add:**
1. **SESSIONS** - Active session monitoring
   - Track concurrent sessions per user
   - Identify long-running sessions
   - Session timeout compliance
   - **Estimated:** 5 dimensions, 8 metrics

2. **NETWORK_POLICIES** + **NETWORK_POLICY_REFERENCES**
   - IP whitelist/blacklist monitoring
   - Policy compliance tracking
   - Policy assignment audit
   - **Estimated:** 3 dimensions, 6 metrics

3. **PASSWORD_POLICIES** + **SESSION_POLICIES**
   - Password strength requirements
   - Session timeout policies
   - Policy enforcement tracking
   - **Estimated:** 0 dimensions (conflicts), 8 metrics

**Enhancement: Security Specialist Semantic View**
```sql
-- Expand SECURITY_MONITORING_SVW to include:
TABLES (
  login AS SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY,
  sessions AS SNOWFLAKE.ACCOUNT_USAGE.SESSIONS,          -- NEW
  users AS SNOWFLAKE.ACCOUNT_USAGE.USERS,                -- For MFA correlation
  net_policies AS SNOWFLAKE.ACCOUNT_USAGE.NETWORK_POLICIES  -- NEW
)
```

**Lessons from Generalist:**
- ⚠️ Most tables can only provide METRICS (not dimensions) due to column name conflicts
- ✅ Use exact column names as aliases to avoid parsing issues
- ✅ Focus on aggregated security metrics rather than row-level details
- ✅ Create helper views for complex JSON or array data

**New Capabilities:**
- Session anomaly detection
- Network policy violation tracking
- MFA adoption by user/department
- Compliance dashboard metrics

**Timeline:** 2-3 weeks
**Dependencies:** None
**Risk:** LOW - follows established patterns

---

### **Phase 8: Data Governance & Lineage** 📋 *[MEDIUM PRIORITY]*

**Objective:** Track data usage, lineage, and policy enforcement

**New Tables to Add:**
1. **ACCESS_HISTORY** (via helper views - complex JSON)
   - Data lineage tracking
   - Column-level access patterns
   - Sensitive data access audit
   - **Note:** Requires flattened helper views (already have `2.1A`)
   - **Estimated:** 0 dimensions (helper view only), 12 metrics

2. **POLICY_REFERENCES**
   - Where masking policies are applied
   - Row access policy assignments
   - Policy coverage gaps
   - **Estimated:** 0 dimensions (conflicts), 6 metrics

3. **MASKING_POLICIES** + **ROW_ACCESS_POLICIES**
   - Policy definitions
   - Policy effectiveness tracking
   - **Estimated:** 0 dimensions (conflicts), 8 metrics

4. **DATA_CLASSIFICATION_LATEST**
   - Automated PII/sensitive data discovery
   - Classification coverage
   - **Estimated:** 0 dimensions, 6 metrics

**New Specialist Agent:**
```sql
GOVERNANCE_AGENT:
- Data lineage visualization queries
- Policy compliance reporting
- Sensitive data access tracking
- Classification coverage analysis
```

**Lessons from Phase 1-6:**
- ⚠️ ACCESS_HISTORY has complex nested JSON - requires helper views
- ✅ Use `2.1A FLATTENED_ACCESS_HISTORY_VIEWS.sql` pattern
- ⚠️ Policy tables likely have NAME/TYPE conflicts - metrics-only approach

**Timeline:** 3-4 weeks
**Dependencies:** ACCESS_HISTORY helper views (already exist)
**Risk:** MEDIUM - JSON flattening complexity

---

### **Phase 9: Real-Time Monitoring** ⚡ *[HIGH VALUE]*

**Objective:** Add near real-time data sources to complement ACCOUNT_USAGE

**New Data Sources:**
1. **INFORMATION_SCHEMA views** (real-time, last 7 days)
   - `INFORMATION_SCHEMA.LOGIN_HISTORY` (table function)
   - `INFORMATION_SCHEMA.QUERY_HISTORY` (table function)
   - **Advantage:** Near real-time (vs 2-hour latency)
   - **Challenge:** Cannot be directly used in semantic views
   - **Solution:** Helper views that wrap table functions

2. **SNOWFLAKE.MONITORING schema**
   - Future replacement for some Information Schema views
   - Per [SNOWFLAKE database docs](https://docs.snowflake.com/en/sql-reference/snowflake-db)
   - **Status:** Not yet fully migrated by Snowflake

**Implementation Pattern:**
```sql
-- Create helper view wrapping table function
CREATE VIEW REALTIME_LOGIN_ACTIVITY_VW AS
SELECT * FROM TABLE(INFORMATION_SCHEMA.LOGIN_HISTORY(
  DATEADD('hours', -1, CURRENT_TIMESTAMP())
));

-- Add to semantic view
TABLES (
  realtime_login AS SNOWFLAKE_INTELLIGENCE.TOOLS.REALTIME_LOGIN_ACTIVITY_VW
)
```

**Lessons:**
- ✅ Table functions need helper view wrappers
- ⚠️ 7-day retention vs 365-day ACCOUNT_USAGE
- ✅ Use for real-time alerting, ACCOUNT_USAGE for historical analysis

**New Capabilities:**
- Real-time security alerts (< 5 min latency)
- Live query performance monitoring
- Immediate threat detection

**Timeline:** 2 weeks
**Dependencies:** Phase 7 (security) should be complete first
**Risk:** LOW - extends existing patterns

---

## 🚀 **PHASE 10-12: AI/ML & ADVANCED ANALYTICS**

### **Phase 10: Cortex AI Cost Tracking** 🤖 *[EMERGING IMPORTANCE]*

**Objective:** Track AI/ML feature usage and costs

**New Tables to Add:**
1. **CORTEX_ANALYST_USAGE_HISTORY** ⭐ *Monitor this agent's own costs!*
2. **CORTEX_FUNCTIONS_USAGE_HISTORY** - ML functions (LLM, sentiment, etc.)
3. **CORTEX_SEARCH_SERVING_USAGE_HISTORY** - Cortex Search costs
4. **CORTEX_FINE_TUNING_USAGE_HISTORY** - Model fine-tuning costs
5. **SNOWPARK_CONTAINER_SERVICES_HISTORY** - Container compute costs

**Per [SNOWFLAKE database documentation](https://docs.snowflake.com/en/sql-reference/snowflake-db):**
- **CORE schema:** System tags and data metric functions
- **ML schema:** ML functions and Document AI classes
- **DATA_PRIVACY schema:** Custom classifiers

**Estimated Impact:**
- 5 new tables
- 0 dimensions (likely all have conflicts)
- 20+ new metrics
- **High business value** - AI costs can be significant

**New Specialist Agent:**
```sql
AI_COST_AGENT:
- Cortex feature usage tracking
- Model invocation costs
- ROI analysis for AI features
- Cost optimization recommendations
```

**Timeline:** 2-3 weeks
**Dependencies:** None
**Risk:** LOW - follows established metrics-only pattern

---

### **Phase 11: Performance Optimization** ⚡ *[HIGH VALUE]*

**Objective:** Advanced performance diagnostics

**New Tables to Add:**
1. **SEARCH_OPTIMIZATION_HISTORY** - Search optimization costs
2. **COPY_HISTORY** - Bulk data loading monitoring
3. **QUERY_ACCELERATION_HISTORY** - Query acceleration service usage
4. **DYNAMIC_TABLE_REFRESH_HISTORY** - Dynamic table costs
5. **LOCK_WAIT_HISTORY** - Transaction locking issues
6. **TABLE_STORAGE_METRICS** - Per-table storage details

**Estimated Impact:**
- 6 new tables
- 0 dimensions (conflicts expected)
- 24 new metrics

**New Capabilities:**
- Query acceleration ROI analysis
- Lock contention detection
- Copy operation optimization
- Per-table cost allocation

**Timeline:** 2-3 weeks
**Dependencies:** None
**Risk:** LOW

---

### **Phase 12: Data Movement & Replication** 🌐 *[ENTERPRISE FOCUS]*

**Objective:** Complete data movement cost tracking

**New Tables to Add:**
1. **INTERNAL_DATA_TRANSFER_HISTORY** - Internal data movement
   - Per [internal data transfer docs](https://docs.snowflake.com/en/sql-reference/account-usage/internal_data_transfer_history)
   - Complements existing DATA_TRANSFER_HISTORY (external only)
2. **DATABASE_REPLICATION_USAGE_HISTORY** - Per-database replication
3. **REPLICATION_GROUP_* tables** - Replication group management
4. **SNOWPIPE_STREAMING_* tables** - Streaming ingestion

**Estimated Impact:**
- 6 new tables
- 0 dimensions
- 18 new metrics

**Timeline:** 2 weeks
**Dependencies:** None
**Risk:** LOW

---

## 📊 **PHASE 13+: ORGANIZATION-LEVEL MONITORING**

### **Phase 13: Organization Usage** 🏢 *[MULTI-ACCOUNT]*

**Objective:** Cross-account monitoring for organizations

**New Schema:**
```sql
SNOWFLAKE.ORGANIZATION_USAGE:
- RATE_SHEET_DAILY
- USAGE_IN_CURRENCY_DAILY
- CONTRACT_ITEMS
- REMAINING_BALANCE_DAILY
```

**Per [SNOWFLAKE database docs](https://docs.snowflake.com/en/sql-reference/snowflake-db):**
> "ORGANIZATION_USAGE: Views that display historical usage data across all the accounts in your organization."

**Use Cases:**
- Cross-account cost allocation
- Organization-wide compliance
- Multi-account security posture
- Billing reconciliation

**New Agent:**
```sql
ORGANIZATION_MONITORING_AGENT:
- Multi-account dashboards
- Cross-account cost comparison
- Organization-wide policy compliance
- Consolidated billing analysis
```

**Requirements:**
- ORGADMIN role access
- Multiple accounts in organization
- Organization-level semantic view

**Timeline:** 3-4 weeks
**Dependencies:** Requires ORGADMIN privileges
**Risk:** MEDIUM - requires elevated permissions

---

## 🎯 **SPECIALIZED AGENTS ENHANCEMENTS**

### **Enhance Existing Specialist Agents:**

#### **1. SECURITY_MONITORING_AGENT (Phase 7)**
**Current:** 1 table (LOGIN_HISTORY), 10 metrics
**Enhanced:** 4-5 tables, 32 metrics

**Add:**
- Session monitoring
- Network policy enforcement
- Password/session policy compliance
- Real-time alerting integration (Phase 9)

**New Features:**
- Threat scoring (failed logins + MFA disabled + policy violations)
- Security posture dashboard
- Compliance reporting
- Anomaly detection queries

---

#### **2. COST_PERFORMANCE_AGENT (Current)**
**Current:** 2 tables, 36 metrics
**No Changes:** Already comprehensive

**Potential Additions from Generalist:**
- Warehouse load metrics (queueing analysis)
- Daily metering (billable reconciliation)
- Query acceleration tracking

---

#### **3. New: GOVERNANCE_AGENT (Phase 8)**
**Focus:** Data lineage, policy enforcement, classification

**Tables:**
- ACCESS_HISTORY (via helper views)
- POLICY_REFERENCES
- MASKING_POLICIES
- ROW_ACCESS_POLICIES
- DATA_CLASSIFICATION_LATEST

**Estimated:** 5 tables, 32 metrics

---

#### **4. New: AI_COST_AGENT (Phase 10)**
**Focus:** Cortex AI/ML cost tracking

**Tables:**
- All CORTEX_* usage tables
- SNOWPARK_CONTAINER_SERVICES

**Estimated:** 5 tables, 20 metrics

---

## 📈 **SUCCESS METRICS & KPIs**

### **Phase 7-9 Success Criteria:**
- [ ] Security agent detects threats in < 5 minutes
- [ ] 100% MFA adoption tracking accuracy
- [ ] Data lineage covers 80%+ of sensitive tables
- [ ] Real-time alerting latency < 5 minutes

### **Phase 10-12 Success Criteria:**
- [ ] Cortex costs tracked to individual function calls
- [ ] Query acceleration ROI analysis available
- [ ] Lock contention detected and reported
- [ ] Complete data movement cost visibility

### **Phase 13 Success Criteria:**
- [ ] Cross-account dashboards operational
- [ ] Organization-wide cost allocation
- [ ] Multi-account security posture tracking

---

## ⚠️ **KEY LESSONS & DESIGN PATTERNS**

### **From Phase 1-6 Implementation:**

#### **1. Column Name Conflicts Pattern** ⚠️
**Problem:** Most ACCOUNT_USAGE tables have common column names:
- `NAME`, `START_TIME`, `END_TIME`, `STATE`, `DATABASE_NAME`, `SCHEMA_NAME`
- These cause "invalid identifier" errors in semantic views

**Solution:**
- Default to **metrics-only** for history tables
- Only add dimensions if unique or non-conflicting
- Use exact column names as aliases (not custom names)

**Example:**
```sql
-- ❌ BAD: Custom alias causes conflict
clustering.TASK_NAME AS clustering_task_name

-- ✅ GOOD: Exact column name or metrics-only
clustering.total_clustering_credits AS SUM(clustering.CREDITS_USED)
```

#### **2. Alias Sensitivity** ⚠️
**Problem:** Semantic views are very sensitive to alias naming

**Solution:**
- Use exact column name as alias: `REPORTED_CLIENT_VERSION AS reported_client_version`
- Avoid prefixes/suffixes: `client_version` ❌ causes errors
- Test each new dimension carefully

#### **3. Helper Views for Complex Data** ✅
**Problem:** JSON arrays, table functions, complex nesting

**Solution:**
- Create helper views to flatten/simplify
- Reference helper views in semantic view
- Pattern established in `2.1A FLATTENED_ACCESS_HISTORY_VIEWS.sql`

**Example:**
```sql
-- Helper view
CREATE VIEW ACCESS_HISTORY_FLATTENED AS
SELECT 
  query_id,
  f.value:objectName::STRING AS object_name
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah,
LATERAL FLATTEN(input => ah.BASE_OBJECTS_ACCESSED) f;

-- Use in semantic view
TABLES (
  access_flat AS SNOWFLAKE_INTELLIGENCE.TOOLS.ACCESS_HISTORY_FLATTENED
)
```

#### **4. Metrics-Only Strategy** ✅
**When to Use:** For any table with common column names

**Benefits:**
- Avoids all conflicts
- Still provides aggregated insights
- Faster compilation
- Cross-domain queries still possible via QUERY_HISTORY dimensions

**Tables Using This:**
- USERS, ROLES, GRANTS (Phase 4)
- TASK_HISTORY, SERVERLESS_TASK_HISTORY (Phase 5)
- All Phase 6 tables (Pipe, Clustering, MV, etc.)

---

## 🔧 **IMPLEMENTATION PRIORITIES**

### **High Priority (Q1):**
1. **Phase 7:** Security expansion (Sessions, Network Policies)
2. **Phase 9:** Real-time monitoring
3. **Phase 10:** Cortex AI cost tracking

### **Medium Priority (Q2):**
4. **Phase 8:** Data governance & lineage
5. **Phase 11:** Performance optimization tables

### **Low Priority (Q3+):**
6. **Phase 12:** Advanced data movement
7. **Phase 13:** Organization-level monitoring

---

## 📚 **DOCUMENTATION REFERENCES**

1. **[SNOWFLAKE Database Overview](https://docs.snowflake.com/en/sql-reference/snowflake-db)**
2. **[ACCOUNT_USAGE Schema](https://docs.snowflake.com/en/sql-reference/account-usage)**
3. **[MONITORING Schema](https://docs.snowflake.com/en/sql-reference/account-usage)** (future migration)
4. **[ORGANIZATION_USAGE Schema](https://docs.snowflake.com/en/sql-reference/organization-usage)**
5. **[Information Schema](https://docs.snowflake.com/en/sql-reference/info-schema)** (real-time data)
6. **[Data Transfer History](https://docs.snowflake.com/en/sql-reference/account-usage/data_transfer_history)**
7. **[Internal Data Transfer History](https://docs.snowflake.com/en/sql-reference/account-usage/internal_data_transfer_history)**

---

## 🎯 **ESTIMATED FINAL STATE**

### **By End of Phase 13:**
| Component | Current | Target | Growth |
|-----------|---------|--------|--------|
| **Total Tables** | 20 | 50+ | +150% |
| **Total Dimensions** | 35 | 60+ | +71% |
| **Total Metrics** | 94 | 250+ | +166% |
| **Specialist Agents** | 2 | 5 | +150% |
| **Verified Queries** | 17 | 100+ | +488% |
| **Coverage** | Basics | Comprehensive | 100% |

### **Agent Architecture (Target):**
```
GENERALIST AGENT (cross-domain)
├── SNOWFLAKE_MAINTENANCE_AGENT (50+ tables, 250+ metrics)
│
SPECIALIST AGENTS (fast, focused)
├── COST_PERFORMANCE_AGENT (cost/performance)
├── SECURITY_MONITORING_AGENT (security/auth)
├── GOVERNANCE_AGENT (lineage/policies) [NEW]
├── AI_COST_AGENT (Cortex/ML costs) [NEW]
└── ORGANIZATION_AGENT (multi-account) [NEW]
```

---

## 📝 **NEXT STEPS**

1. **Immediate (Week 1):**
   - Review and approve roadmap
   - Prioritize Phase 7-9
   - Test automated test suite (`TEST_ALL_PHASES.sql`)

2. **Week 2-3:**
   - Begin Phase 7 (Security expansion)
   - Update SECURITY_MONITORING_SVW
   - Deploy enhanced security agent

3. **Week 4-6:**
   - Phase 9 (Real-time monitoring)
   - Phase 10 (Cortex AI tracking)

4. **Ongoing:**
   - Monitor Snowflake releases for new ACCOUNT_USAGE tables
   - Track MONITORING schema migration
   - Update agents with new capabilities

---

**Roadmap Version:** 1.0
**Last Updated:** 2025-11-07
**Next Review:** After Phase 7 completion

