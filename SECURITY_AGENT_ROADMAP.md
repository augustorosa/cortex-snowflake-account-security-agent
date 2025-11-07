# 🔒 ENHANCED SECURITY AGENT ROADMAP

## Current State Analysis

### ✅ **What Security Specialist Agent Has Today:**
- `LOGIN_HISTORY` (365 days)
  - Login attempts, failures, MFA tracking
  - Client IP, type, version
  - Authentication factors
  - Success/failure rates

**Limitations:**
- Only LOGIN data (authentication only)
- No access/authorization monitoring
- No data governance visibility
- No policy enforcement tracking
- No network security monitoring

---

## 🎯 **Lessons from Generalist Agent Success**

### **Key Insights:**
1. **Column Name Conflicts Are Universal**
   - Most ACCOUNT_USAGE tables can only provide METRICS, not DIMENSIONS
   - Common conflicts: `NAME`, `START_TIME`, `END_TIME`, `STATE`, `USER_NAME`
   - Solution: Accept metrics-only approach for most tables

2. **Helper Views Work Well**
   - Use helper views for complex JSON data (e.g., ACCESS_HISTORY)
   - Reference in agent instructions, not directly in semantic view
   - Provides flexibility without semantic view limitations

3. **Cross-Domain Value**
   - Users love correlations: "failed logins + expensive queries"
   - Security + cost analysis is powerful
   - Health dashboards need multiple domains

4. **Verified Queries Are Critical**
   - Pre-built queries guide AI agent behavior
   - Examples help users understand capabilities
   - Reduces hallucination and improves accuracy

---

## 📊 **Available SNOWFLAKE Database Schemas**

Based on https://docs.snowflake.com/en/sql-reference/snowflake-db

### **Currently Used:**
- ✅ `ACCOUNT_USAGE` - Historical data (20 tables in generalist)

### **Available for Enhancement:**

#### 1. **CORE Schema** 
*System tags and data metric functions*
- **Opportunity:** Data classification support
- **Use Cases:**
  - Tag-based security monitoring
  - Sensitive data access tracking
  - Compliance reporting
- **Tables to Explore:**
  - System tags for PII/sensitive data
  - Data quality metric functions

#### 2. **DATA_PRIVACY Schema**
*Privacy functions and custom classifiers*
- **Opportunity:** Enhanced data privacy monitoring
- **Use Cases:**
  - Custom classification rules
  - Privacy policy enforcement
  - Sensitive data detection
- **Classes:**
  - `custom_classifier` class

#### 3. **MONITORING Schema**
*Real-time operational data*
- **Opportunity:** Near real-time security monitoring
- **Use Cases:**
  - Active session monitoring
  - Real-time query tracking
  - Current warehouse utilization
- **Note:** Eventually replaces some INFORMATION_SCHEMA functions

#### 4. **ORGANIZATION_USAGE Schema**
*Cross-account visibility*
- **Opportunity:** Enterprise-wide security
- **Use Cases:**
  - Multi-account security patterns
  - Organization-level threats
  - Cross-account policy enforcement

#### 5. **TELEMETRY Schema**
*Log messages, trace events, metrics*
- **Opportunity:** Deep operational security
- **Use Cases:**
  - Security event correlation
  - Audit trail completeness
  - Performance security analysis

---

## 🚀 **Enhanced Security Agent Phases**

### **PHASE 1: Expand Current Security Agent (PRIORITY 1)**

#### **Add to Security Semantic View:**

1. **ACCESS_HISTORY** (via helper views)
   - ✅ Already have helper views in `2.1A`
   - Track: what data was accessed, by whom, when
   - Columns: objects_accessed, base_objects, direct_objects
   - **Metrics Only** (due to JSON complexity)

2. **POLICY_REFERENCES**
   - Where masking/row access policies are applied
   - Track policy coverage and gaps
   - **Dimensions:** policy_name, ref_entity_name, ref_entity_domain, policy_kind
   - **Metrics:** total_policies, coverage_by_type

3. **MASKING_POLICIES**
   - Policy definitions and signatures
   - **Metrics:** total_masking_policies, active_policies

4. **ROW_ACCESS_POLICIES**
   - Row-level security definitions
   - **Metrics:** total_row_policies, tables_protected

5. **PASSWORD_POLICIES**
   - Password requirements tracking
   - **Metrics:** total_password_policies, policy_compliance_rate

6. **SESSION_POLICIES**
   - Session timeout and restrictions
   - **Metrics:** total_session_policies, average_timeout

7. **SESSIONS**
   - Active session monitoring
   - **Dimensions:** user_name, client_application_id, authentication_method
   - **Metrics:** active_sessions, session_duration_avg

8. **NETWORK_POLICIES**
   - IP whitelist/blacklist policies
   - **Metrics:** total_network_policies, blocked_ips

9. **NETWORK_POLICY_REFERENCES**
   - Where network policies are applied
   - **Metrics:** entities_protected, policy_coverage

---

### **PHASE 2: Data Classification & Privacy (PRIORITY 2)**

#### **Integrate CORE Schema:**

10. **DATA_CLASSIFICATION_LATEST**
    - Automated classification results
    - Track PII, sensitive data discovery
    - **Dimensions:** object_name, classification_category, tag_name
    - **Metrics:** total_classified_objects, pii_objects_count

11. **TAG_REFERENCES**
    - Object tagging for governance
    - **Metrics:** tagged_objects, tags_by_category

---

### **PHASE 3: Advanced Security Analytics (PRIORITY 3)**

#### **Add Advanced Tables:**

12. **EXTERNAL_ACCESS_HISTORY**
    - External function/API calls
    - Track data exfiltration risks
    - **Metrics:** total_external_calls, unique_endpoints

13. **TRUST_CENTER_FINDINGS**
    - Security recommendations
    - **Metrics:** open_findings, critical_findings

14. **LOCK_WAIT_HISTORY**
    - Transaction locking (potential DoS)
    - **Metrics:** lock_timeouts, blocked_transactions

---

### **PHASE 4: Cross-Account Security (PRIORITY 4)**

#### **Leverage ORGANIZATION_USAGE:**

15. **Organization-level security views**
    - Cross-account login patterns
    - Org-wide policy effectiveness
    - Enterprise threat detection

---

## 🎨 **Enhanced Security Agent Capabilities**

### **New Questions It Could Answer:**

**Data Access & Governance:**
- "Which sensitive tables were accessed today?"
- "Show me data access patterns for user X"
- "What data does each user have access to?"
- "Which tables lack masking policies?"

**Policy Enforcement:**
- "Where are my masking policies applied?"
- "Which users don't have row-level security?"
- "Show me policy coverage gaps"
- "What's my password policy compliance rate?"

**Network Security:**
- "Which IPs are blocked by network policies?"
- "Show me access attempts from unknown IPs"
- "What's my network policy coverage?"

**Session Monitoring:**
- "How many active sessions right now?"
- "Show me sessions without MFA"
- "What's the average session duration?"

**Classification:**
- "Which objects contain PII?"
- "Show me unclassified sensitive data"
- "What's my data classification coverage?"

**External Access:**
- "Are there any external function calls to suspicious endpoints?"
- "Show me data exfiltration risk indicators"

**Cross-Domain Security:**
- "Users with sensitive data access + no MFA + failed logins"
- "Expensive queries accessing masked data"
- "Session anomalies + data access patterns"

---

## 💡 **Improvements from Generalist Experience**

### **Apply to Security Agent:**

1. **Metrics-First Design**
   - Accept that most tables will be metrics-only
   - Focus on aggregations and KPIs
   - Use helper views for detailed analysis

2. **Cross-Domain Integration**
   - Connect security metrics to cost (from generalist)
   - Security + performance insights
   - User behavior + access patterns

3. **Comprehensive Verified Queries**
   - Include 20+ verified queries
   - Cover all security domains
   - Show cross-domain examples

4. **Clear Documentation**
   - Document each table's limitations
   - Explain metrics-only approach
   - Reference helper views clearly

5. **Incremental Deployment**
   - Test each table addition
   - Validate before proceeding
   - Document column conflicts as discovered

---

## 📋 **Implementation Checklist**

### **Phase 1A: Immediate (Data Access)**
- [ ] Add ACCESS_HISTORY metrics (use existing helper views)
- [ ] Add POLICY_REFERENCES
- [ ] Add SESSIONS
- [ ] Update Security Agent instructions
- [ ] Add 10 new verified queries
- [ ] Test and validate

### **Phase 1B: Policy Monitoring**
- [ ] Add MASKING_POLICIES metrics
- [ ] Add ROW_ACCESS_POLICIES metrics
- [ ] Add PASSWORD_POLICIES metrics
- [ ] Add SESSION_POLICIES metrics
- [ ] Add NETWORK_POLICIES + NETWORK_POLICY_REFERENCES
- [ ] Add 10 more verified queries

### **Phase 2: Classification**
- [ ] Research CORE schema access requirements
- [ ] Add DATA_CLASSIFICATION_LATEST
- [ ] Add TAG_REFERENCES
- [ ] Integrate with DATA_PRIVACY schema if accessible
- [ ] Add classification-focused queries

### **Phase 3: Advanced**
- [ ] Add EXTERNAL_ACCESS_HISTORY
- [ ] Add TRUST_CENTER_FINDINGS
- [ ] Add LOCK_WAIT_HISTORY
- [ ] Cross-domain security analytics

---

## 🔗 **References**

- [SNOWFLAKE Database Overview](https://docs.snowflake.com/en/sql-reference/snowflake-db)
- [ACCOUNT_USAGE Schema](https://docs.snowflake.com/en/sql-reference/account-usage)
- [CORE Schema (Tags & Data Metrics)](https://docs.snowflake.com/en/sql-reference/snowflake-db#core)
- [DATA_PRIVACY Schema](https://docs.snowflake.com/en/sql-reference/snowflake-db#data-privacy)
- [MONITORING Schema](https://docs.snowflake.com/en/sql-reference/snowflake-db#monitoring)
- [Data Classification](https://docs.snowflake.com/en/user-guide/governance-classify)
- [Masking Policies](https://docs.snowflake.com/en/user-guide/security-column-ddm)
- [Row Access Policies](https://docs.snowflake.com/en/user-guide/security-row-intro)

---

## 📊 **Projected Final State**

### **Enhanced Security Specialist Agent:**

| Category | Tables | Dimensions | Metrics |
|----------|--------|------------|---------|
| **Current (Phase 0)** | 1 | 11 | 10 |
| **After Phase 1A** | 4 | 18 | 30 |
| **After Phase 1B** | 9 | 25 | 55 |
| **After Phase 2** | 11 | 32 | 70 |
| **After Phase 3** | 14 | 38 | 85 |
| **TOTAL** | **14** | **~38** | **~85** |

**Value Proposition:**
- Comprehensive security monitoring
- Data access visibility
- Policy enforcement tracking
- Classification coverage
- Cross-domain security analytics
- Enterprise-wide threat detection

---

*Last Updated: Phase 6 Complete - Generalist Agent*
*Next Priority: Enhanced Security Agent Phase 1A*

