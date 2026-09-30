-- ============================================================================
-- 90_cowork/01_register_cowork_agents.sql
-- Make the lab agents visible in Snowflake CoWork (formerly Snowflake
-- Intelligence). CoWork shows agents that are added to the CoWork account
-- object. Snowflake still uses the SNOWFLAKE INTELLIGENCE keyword and the
-- default object name SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT for it.
-- Run after the agent scripts. Requires ACCOUNTADMIN (owner of the object).
-- ============================================================================

USE ROLE ACCOUNTADMIN;

CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;
GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE PUBLIC;

-- Idempotent: agents already registered (or not deployed) are skipped and reported.
EXECUTE IMMEDIATE $$
DECLARE
  agents ARRAY DEFAULT ARRAY_CONSTRUCT(
    'COWORK.AGENTS.IT_OPS_SECURITY_AGENT',
    'COWORK.AGENTS.SECURITY_MONITORING_AGENT',
    'COWORK.AGENTS.SNOWFLAKE_MAINTENANCE_AGENT',
    'COWORK.AGENTS.COST_PERFORMANCE_AGENT');
  agent_fqn VARCHAR;
  result VARCHAR DEFAULT '';
BEGIN
  FOR i IN 0 TO ARRAY_SIZE(agents) - 1 DO
    agent_fqn := agents[i];
    BEGIN
      EXECUTE IMMEDIATE 'ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT ADD AGENT ' || agent_fqn;
      result := result || agent_fqn || ': added; ';
    EXCEPTION
      WHEN OTHER THEN
        result := result || agent_fqn || ': skipped (' || SQLERRM || '); ';
    END;
  END FOR;
  RETURN result;
END;
$$;

SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;
