-- Security Analysis Stored Procedures using Flattened Access History
-- These procedures can be called by the Cortex Agent for detailed security analysis

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.TOOLS;

-- =====================================================
-- 1. WHO ACCESSED A SPECIFIC TABLE?
-- =====================================================
CREATE OR REPLACE PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.WHO_ACCESSED_TABLE(
    TABLE_NAME_PATTERN VARCHAR,
    DAYS_BACK NUMBER DEFAULT 7
)
RETURNS TABLE(
    access_time TIMESTAMP_LTZ,
    user_name VARCHAR,
    table_name VARCHAR,
    column_name VARCHAR,
    query_text VARCHAR,
    policy_applied VARCHAR
)
LANGUAGE SQL
AS
$$
BEGIN
    LET result_set RESULTSET := (
        SELECT 
            base.QUERY_START_TIME AS access_time,
            base.USER_NAME AS user_name,
            base.BASE_OBJECT_NAME AS table_name,
            base.COLUMN_NAME AS column_name,
            qh.QUERY_TEXT AS query_text,
            pol.POLICY_NAME AS policy_applied
        FROM SNOWFLAKE_INTELLIGENCE.TOOLS.ACCESS_BASE_OBJECTS_VW base
        LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh ON base.QUERY_ID = qh.QUERY_ID
        LEFT JOIN SNOWFLAKE_INTELLIGENCE.TOOLS.ACCESS_POLICIES_APPLIED_VW pol 
            ON base.QUERY_ID = pol.QUERY_ID
        WHERE base.BASE_OBJECT_NAME ILIKE :TABLE_NAME_PATTERN
          AND base.QUERY_START_TIME >= DATEADD(day, -:DAYS_BACK, CURRENT_TIMESTAMP())
        ORDER BY base.QUERY_START_TIME DESC
    );
    RETURN TABLE(result_set);
END;
$$;

COMMENT ON PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.WHO_ACCESSED_TABLE IS 
'Returns all users who accessed a specific table pattern in the last N days with query details.';

-- =====================================================
-- 2. SENSITIVE DATA ACCESS REPORT
-- =====================================================
CREATE OR REPLACE PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.SENSITIVE_DATA_ACCESS_REPORT(
    HOURS_BACK NUMBER DEFAULT 24
)
RETURNS TABLE(
    access_time TIMESTAMP_LTZ,
    user_name VARCHAR,
    table_accessed VARCHAR,
    masking_applied BOOLEAN,
    row_filter_applied BOOLEAN,
    query_text VARCHAR
)
LANGUAGE SQL
AS
$$
BEGIN
    LET result_set RESULTSET := (
        SELECT 
            base.QUERY_START_TIME AS access_time,
            base.USER_NAME AS user_name,
            base.BASE_OBJECT_NAME AS table_accessed,
            MAX(CASE WHEN pol.POLICY_KIND = 'MASKING_POLICY' THEN TRUE ELSE FALSE END) AS masking_applied,
            MAX(CASE WHEN pol.POLICY_KIND = 'ROW_ACCESS_POLICY' THEN TRUE ELSE FALSE END) AS row_filter_applied,
            qh.QUERY_TEXT AS query_text
        FROM SNOWFLAKE_INTELLIGENCE.TOOLS.ACCESS_BASE_OBJECTS_VW base
        LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh ON base.QUERY_ID = qh.QUERY_ID
        LEFT JOIN SNOWFLAKE_INTELLIGENCE.TOOLS.ACCESS_POLICIES_APPLIED_VW pol 
            ON base.QUERY_ID = pol.QUERY_ID
        WHERE base.BASE_OBJECT_NAME ILIKE ANY ('%CUSTOMER%', '%USER%', '%EMPLOYEE%', '%PAYMENT%', '%SSN%', '%PII%')
          AND base.QUERY_START_TIME >= DATEADD(hour, -:HOURS_BACK, CURRENT_TIMESTAMP())
        GROUP BY 1, 2, 3, 6
        ORDER BY base.QUERY_START_TIME DESC
    );
    RETURN TABLE(result_set);
END;
$$;

COMMENT ON PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.SENSITIVE_DATA_ACCESS_REPORT IS 
'Returns access to sensitive tables with policy enforcement status.';

-- =====================================================
-- 3. UNPROTECTED SENSITIVE TABLE ACCESS (SECURITY ALERT!)
-- =====================================================
CREATE OR REPLACE PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.UNPROTECTED_SENSITIVE_ACCESS(
    HOURS_BACK NUMBER DEFAULT 24
)
RETURNS TABLE(
    alert_severity VARCHAR,
    access_time TIMESTAMP_LTZ,
    user_name VARCHAR,
    table_accessed VARCHAR,
    query_text VARCHAR,
    recommendation VARCHAR
)
LANGUAGE SQL
AS
$$
BEGIN
    LET result_set RESULTSET := (
        SELECT 
            '🔴 CRITICAL' AS alert_severity,
            base.QUERY_START_TIME AS access_time,
            base.USER_NAME AS user_name,
            base.BASE_OBJECT_NAME AS table_accessed,
            qh.QUERY_TEXT AS query_text,
            'Consider applying masking or row access policy to ' || base.BASE_OBJECT_NAME AS recommendation
        FROM SNOWFLAKE_INTELLIGENCE.TOOLS.ACCESS_BASE_OBJECTS_VW base
        LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh ON base.QUERY_ID = qh.QUERY_ID
        LEFT JOIN SNOWFLAKE_INTELLIGENCE.TOOLS.ACCESS_POLICIES_APPLIED_VW pol 
            ON base.QUERY_ID = pol.QUERY_ID
        WHERE base.BASE_OBJECT_NAME ILIKE ANY ('%CUSTOMER%', '%SSN%', '%CREDIT_CARD%', '%PASSWORD%', '%SECRET%')
          AND base.QUERY_START_TIME >= DATEADD(hour, -:HOURS_BACK, CURRENT_TIMESTAMP())
          AND pol.POLICY_ID IS NULL  -- NO POLICY APPLIED!
        ORDER BY base.QUERY_START_TIME DESC
    );
    RETURN TABLE(result_set);
END;
$$;

COMMENT ON PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.UNPROTECTED_SENSITIVE_ACCESS IS 
'SECURITY ALERT: Identifies sensitive tables accessed WITHOUT masking or row access policies.';

-- =====================================================
-- 4. DATA MODIFICATION AUDIT
-- =====================================================
CREATE OR REPLACE PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.DATA_MODIFICATION_AUDIT(
    TABLE_NAME_PATTERN VARCHAR DEFAULT '%',
    HOURS_BACK NUMBER DEFAULT 24
)
RETURNS TABLE(
    modification_time TIMESTAMP_LTZ,
    user_name VARCHAR,
    table_modified VARCHAR,
    query_type VARCHAR,
    execution_status VARCHAR,
    query_text VARCHAR
)
LANGUAGE SQL
AS
$$
BEGIN
    LET result_set RESULTSET := (
        SELECT 
            mod.QUERY_START_TIME AS modification_time,
            mod.USER_NAME AS user_name,
            mod.MODIFIED_OBJECT_NAME AS table_modified,
            qh.QUERY_TYPE AS query_type,
            qh.EXECUTION_STATUS AS execution_status,
            qh.QUERY_TEXT AS query_text
        FROM SNOWFLAKE_INTELLIGENCE.TOOLS.ACCESS_OBJECTS_MODIFIED_VW mod
        LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh ON mod.QUERY_ID = qh.QUERY_ID
        WHERE mod.MODIFIED_OBJECT_NAME ILIKE :TABLE_NAME_PATTERN
          AND mod.QUERY_START_TIME >= DATEADD(hour, -:HOURS_BACK, CURRENT_TIMESTAMP())
        ORDER BY mod.QUERY_START_TIME DESC
    );
    RETURN TABLE(result_set);
END;
$$;

COMMENT ON PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.DATA_MODIFICATION_AUDIT IS 
'Audit trail of all data modifications (INSERT/UPDATE/DELETE) to specified tables.';

-- =====================================================
-- Grant execute permissions
-- =====================================================
GRANT USAGE ON PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.WHO_ACCESSED_TABLE(VARCHAR, NUMBER) TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.SENSITIVE_DATA_ACCESS_REPORT(NUMBER) TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.UNPROTECTED_SENSITIVE_ACCESS(NUMBER) TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.DATA_MODIFICATION_AUDIT(VARCHAR, NUMBER) TO ROLE PUBLIC;

-- =====================================================
-- Example Usage
-- =====================================================

-- Example 1: Who accessed CUSTOMERS table in last 7 days?
-- CALL SNOWFLAKE_INTELLIGENCE.TOOLS.WHO_ACCESSED_TABLE('CUSTOMERS', 7);

-- Example 2: Sensitive data access in last 24 hours
-- CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SENSITIVE_DATA_ACCESS_REPORT(24);

-- Example 3: CRITICAL: Unprotected sensitive data access
-- CALL SNOWFLAKE_INTELLIGENCE.TOOLS.UNPROTECTED_SENSITIVE_ACCESS(24);

-- Example 4: Audit modifications to production tables
-- CALL SNOWFLAKE_INTELLIGENCE.TOOLS.DATA_MODIFICATION_AUDIT('PROD%', 24);

