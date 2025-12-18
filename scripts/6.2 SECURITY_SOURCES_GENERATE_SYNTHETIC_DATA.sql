-- ============================================================================
-- SECURITY SOURCES (CLOUDFLARE + CROWDSTRIKE) - GENERATE SYNTHETIC DATA
-- ============================================================================
-- Uses SNOWFLAKE.DATA_PRIVACY.GENERATE_SYNTHETIC_DATA to create synthetic
-- ("real fake") datasets from the seeded source tables.
--
-- Docs: https://docs.snowflake.com/en/sql-reference/stored-procedures/generate_synthetic_data

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.TOOLS;

-- Optional: consistency secret for deterministic replacements across runs.
-- Comment out if you don't need consistency. (Some replacement modes require it.)
-- CREATE OR REPLACE SECRET SNOWFLAKE_INTELLIGENCE.TOOLS.SYNDATA_CONSISTENCY_SECRET
--   TYPE = SYMMETRIC_KEY
--   ALGORITHM = GENERIC;

CALL SNOWFLAKE.DATA_PRIVACY.GENERATE_SYNTHETIC_DATA(
  {
    'datasets': [
      {
        'input_table': 'SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SOURCE',
        'output_table': 'SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SYNTH',
        'columns': {
          'client_ip': { 'categorical': TRUE },
          'client_request_host': { 'categorical': TRUE },
          'client_request_method': { 'categorical': TRUE },
          'client_request_uri': { 'categorical': TRUE },
          'client_country': { 'categorical': TRUE },
          'edge_colo_code': { 'categorical': TRUE },
          'security_action': { 'categorical': TRUE },
          'waf_flags': { 'categorical': TRUE }
        }
      },
      {
        'input_table': 'SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SOURCE',
        'output_table': 'SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SYNTH',
        'columns': {
          'src_ip': { 'categorical': TRUE },
          'dst_ip': { 'categorical': TRUE },
          'domain': { 'categorical': TRUE },
          'category': { 'categorical': TRUE },
          'username': { 'categorical': TRUE },
          'proto': { 'categorical': TRUE },
          'url': { 'categorical': TRUE },
          'event_name': { 'categorical': TRUE }
        }
      },
      {
        'input_table': 'SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SOURCE',
        'output_table': 'SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SYNTH',
        'columns': {
          'hostname': { 'categorical': TRUE },
          'program': { 'categorical': TRUE },
          'audit_id': { 'categorical': TRUE },
          'stage': { 'categorical': TRUE },
          'level': { 'categorical': TRUE },
          'verb': { 'categorical': TRUE },
          'request_uri': { 'categorical': TRUE },
          'username': { 'categorical': TRUE },
          'source_ip': { 'categorical': TRUE },
          'user_agent': { 'categorical': TRUE },
          'object_resource': { 'categorical': TRUE },
          'object_namespace': { 'categorical': TRUE },
          'authz_decision': { 'categorical': TRUE },
          'raw_syslog': { 'categorical': FALSE },
          'raw_event_json': { 'categorical': FALSE }
        }
      },
      {
        'input_table': 'SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SOURCE',
        'output_table': 'SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SYNTH',
        'columns': {
          'environment': { 'categorical': TRUE },
          'hostname': { 'categorical': TRUE },
          'repository': { 'categorical': TRUE },
          'pipeline_id': { 'categorical': TRUE },
          'actor': { 'categorical': TRUE },
          'event_type': { 'categorical': TRUE },
          'package_name': { 'categorical': TRUE },
          'package_version': { 'categorical': TRUE },
          'package_scope': { 'categorical': TRUE },
          'registry': { 'categorical': TRUE },
          'install_command': { 'categorical': TRUE },
          'script_name': { 'categorical': TRUE },
          'script_command': { 'categorical': TRUE },
          'network_dest_host': { 'categorical': TRUE },
          'indicator_type': { 'categorical': TRUE },
          'indicator_severity': { 'categorical': TRUE },
          'cwe_id': { 'categorical': TRUE },
          'cwe_name': { 'categorical': TRUE },
          'status': { 'categorical': TRUE },
          'raw_event_json': { 'categorical': FALSE }
        }
      }
    ],
    'similarity_filter': FALSE,  -- Disabled: npm.network_dest_port has NULLs (NUMBER type), which breaks similarity_filter
    'replace_output_tables': TRUE
    -- 'consistency_secret': SYSTEM$REFERENCE('SECRET', 'SYNDATA_CONSISTENCY_SECRET', 'SESSION', 'READ')::STRING
  }
);

-- Grants for demos
GRANT SELECT ON TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SYNTH TO ROLE PUBLIC;
GRANT SELECT ON TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SYNTH TO ROLE PUBLIC;
GRANT SELECT ON TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SYNTH TO ROLE PUBLIC;
GRANT SELECT ON TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SYNTH TO ROLE PUBLIC;


