-- ============================================================================
-- 00_foundation/03_accept_marketplace_terms.sql
-- OPTIONAL: Snowflake Documentation listing (Cortex Search over Snowflake docs).
-- Requires ACCOUNTADMIN (or a role with IMPORT SHARE + legal-terms rights).
-- ============================================================================
USE ROLE ACCOUNTADMIN;

CALL SYSTEM$ACCEPT_LEGAL_TERMS('DATA_EXCHANGE_LISTING', 'GZSTZ67BY9OQ4');

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_DOCUMENTATION
    FROM LISTING 'GZSTZ67BY9OQ4';

GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_DOCUMENTATION TO ROLE PUBLIC;
