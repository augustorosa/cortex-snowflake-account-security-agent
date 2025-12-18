-- ============================================================================
-- SECURITY SOURCES - HELPER VIEWS FOR SEMANTIC VIEW COMPATIBILITY
-- ============================================================================
-- Semantic view rule (hard-won): DIMENSIONS aliases must match the underlying column
-- name (typically exact column name in lowercase). To safely add new sources with
-- unique, prefixed dimension names, we rename columns in helper views FIRST.

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.TOOLS;

-- ============================================================================
-- 1) CLOUDFLARE (SYNTHETIC) - helper view with prefixed column names
-- ============================================================================
CREATE OR REPLACE VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SYNTH_SVW_HELPER_VW AS
SELECT
  EVENT_TIME            AS cloudflare_event_time,
  CLIENT_IP             AS cloudflare_client_ip,
  CLIENT_REQUEST_HOST   AS cloudflare_client_request_host,
  CLIENT_REQUEST_METHOD AS cloudflare_client_request_method,
  CLIENT_REQUEST_URI    AS cloudflare_client_request_uri,
  EDGE_RESPONSE_STATUS  AS cloudflare_edge_response_status,
  EDGE_RESPONSE_BYTES   AS cloudflare_edge_response_bytes,
  CLIENT_COUNTRY        AS cloudflare_client_country,
  CLIENT_ASN            AS cloudflare_client_asn,
  EDGE_COLO_CODE        AS cloudflare_edge_colo_code,
  RAY_ID                AS cloudflare_ray_id,
  SECURITY_ACTION       AS cloudflare_security_action,
  WAF_FLAGS             AS cloudflare_waf_flags
FROM SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SYNTH;

COMMENT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SYNTH_SVW_HELPER_VW IS
'Helper view for semantic views: Cloudflare synthetic logs with prefixed, unique column names.';

GRANT SELECT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SYNTH_SVW_HELPER_VW TO ROLE PUBLIC;

-- ============================================================================
-- 2) CROWDSTRIKE (SYNTHETIC) - helper view with prefixed column names
-- ============================================================================
CREATE OR REPLACE VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SYNTH_SVW_HELPER_VW AS
SELECT
  DEV_TIME   AS crowdstrike_dev_time,
  SRC_IP     AS crowdstrike_src_ip,
  SRC_PORT   AS crowdstrike_src_port,
  DST_IP     AS crowdstrike_dst_ip,
  DST_PORT   AS crowdstrike_dst_port,
  DOMAIN     AS crowdstrike_domain,
  CATEGORY   AS crowdstrike_category,
  USERNAME   AS crowdstrike_username,
  CONN_DIR   AS crowdstrike_conn_dir,
  PROTO      AS crowdstrike_proto,
  URL        AS crowdstrike_url,
  EVENT_NAME AS crowdstrike_event_name
FROM SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SYNTH;

COMMENT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SYNTH_SVW_HELPER_VW IS
'Helper view for semantic views: CrowdStrike synthetic events with prefixed, unique column names.';

GRANT SELECT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SYNTH_SVW_HELPER_VW TO ROLE PUBLIC;

-- ============================================================================
-- 3) CLOUDTRAIL FLATTENED - helper view with prefixed column names
-- ============================================================================
CREATE OR REPLACE VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDTRAIL_LOGS_FLATTENED_SVW_HELPER_VW AS
SELECT
  TIME            AS cloudtrail_time,
  IP_ADDRESS      AS cloudtrail_ip_address,
  CLASS_NAME      AS cloudtrail_class_name,
  CLASS_UID       AS cloudtrail_class_uid,
  CATEGORY_UID    AS cloudtrail_category_uid,
  SEVERITY_ID     AS cloudtrail_severity_id,
  SEVERITY        AS cloudtrail_severity,
  ACTIVITY_NAME   AS cloudtrail_activity_name,
  ACTIVITY_ID     AS cloudtrail_activity_id,
  TYPE_NAME       AS cloudtrail_type_name,
  STATUS          AS cloudtrail_status,
  IS_MFA          AS cloudtrail_is_mfa,
  ACCOUNTID       AS cloudtrail_accountid,
  REGION          AS cloudtrail_region,
  VARIANT_COL     AS cloudtrail_variant_col,
  JSON_PATH       AS cloudtrail_json_path,
  JSON_KEY        AS cloudtrail_json_key,
  JSON_VALUE_TYPE AS cloudtrail_json_value_type,
  IS_LEAF         AS cloudtrail_is_leaf
FROM SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDTRAIL_LOGS_FLATTENED_VW;

COMMENT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDTRAIL_LOGS_FLATTENED_SVW_HELPER_VW IS
'Helper view for semantic views: CloudTrail flattened JSON with prefixed, unique column names.';

GRANT SELECT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDTRAIL_LOGS_FLATTENED_SVW_HELPER_VW TO ROLE PUBLIC;

-- ============================================================================
-- 4) KUBERNETES AUDIT (SYNTHETIC) - helper view with prefixed column names
-- ============================================================================
CREATE OR REPLACE VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SYNTH_SVW_HELPER_VW AS
SELECT
  EVENT_TIME        AS kubernetes_event_time,
  HOSTNAME          AS kubernetes_hostname,
  PROGRAM           AS kubernetes_program,
  SEVERITY          AS kubernetes_severity,
  AUDIT_ID          AS kubernetes_audit_id,
  STAGE             AS kubernetes_stage,
  LEVEL             AS kubernetes_level,
  VERB              AS kubernetes_verb,
  REQUEST_URI       AS kubernetes_request_uri,
  USERNAME          AS kubernetes_username,
  SOURCE_IP         AS kubernetes_source_ip,
  USER_AGENT        AS kubernetes_user_agent,
  OBJECT_RESOURCE   AS kubernetes_object_resource,
  OBJECT_NAMESPACE  AS kubernetes_object_namespace,
  RESPONSE_CODE     AS kubernetes_response_code,
  AUTHZ_DECISION    AS kubernetes_authz_decision
FROM SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SYNTH;

COMMENT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SYNTH_SVW_HELPER_VW IS
'Helper view for semantic views: Kubernetes audit synthetic logs with prefixed, unique column names.';

GRANT SELECT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SYNTH_SVW_HELPER_VW TO ROLE PUBLIC;

-- Flattened K8s JSON (from source seed) with prefixed column names
CREATE OR REPLACE VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_FLATTENED_SVW_HELPER_VW AS
SELECT
  EVENT_TIME      AS kubernetes_event_time,
  HOSTNAME        AS kubernetes_hostname,
  AUDIT_ID        AS kubernetes_audit_id,
  STAGE           AS kubernetes_stage,
  LEVEL           AS kubernetes_level,
  VERB            AS kubernetes_verb,
  REQUEST_URI     AS kubernetes_request_uri,
  USERNAME        AS kubernetes_username,
  SOURCE_IP       AS kubernetes_source_ip,
  OBJECT_RESOURCE AS kubernetes_object_resource,
  OBJECT_NAMESPACE AS kubernetes_object_namespace,
  RESPONSE_CODE   AS kubernetes_response_code,
  AUTHZ_DECISION  AS kubernetes_authz_decision,
  VARIANT_SOURCE  AS kubernetes_variant_source,
  PATH            AS kubernetes_json_path,
  KEY             AS kubernetes_json_key,
  VALUE_TYPE      AS kubernetes_json_value_type,
  IS_LEAF         AS kubernetes_is_leaf,
  LEAF_VALUE      AS kubernetes_leaf_value
FROM SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_FLATTENED_VW;

COMMENT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_FLATTENED_SVW_HELPER_VW IS
'Helper view for semantic views: Kubernetes audit flattened JSON with prefixed, unique column names.';

GRANT SELECT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_FLATTENED_SVW_HELPER_VW TO ROLE PUBLIC;

-- ============================================================================
-- 5) NPM SUPPLY CHAIN (SYNTHETIC) - helper view with prefixed column names
-- ============================================================================
CREATE OR REPLACE VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SYNTH_SVW_HELPER_VW AS
SELECT
  EVENT_TIME          AS npm_event_time,
  ENVIRONMENT         AS npm_environment,
  HOSTNAME            AS npm_hostname,
  REPOSITORY          AS npm_repository,
  PIPELINE_ID         AS npm_pipeline_id,
  ACTOR               AS npm_actor,
  EVENT_TYPE          AS npm_event_type,
  PACKAGE_NAME        AS npm_package_name,
  PACKAGE_VERSION     AS npm_package_version,
  REGISTRY            AS npm_registry,
  INSTALL_COMMAND     AS npm_install_command,
  SCRIPT_NAME         AS npm_script_name,
  SCRIPT_COMMAND      AS npm_script_command,
  NETWORK_DEST_HOST   AS npm_network_dest_host,
  NETWORK_DEST_PORT   AS npm_network_dest_port,
  INDICATOR_TYPE      AS npm_indicator_type,
  INDICATOR_SEVERITY  AS npm_indicator_severity,
  CWE_ID              AS npm_cwe_id,
  CWE_NAME            AS npm_cwe_name,
  STATUS              AS npm_status
FROM SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SYNTH;

COMMENT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SYNTH_SVW_HELPER_VW IS
'Helper view for semantic views: npm supply-chain synthetic events with prefixed, unique column names.';

GRANT SELECT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SYNTH_SVW_HELPER_VW TO ROLE PUBLIC;

-- Flattened npm JSON (from source seed) with prefixed column names
CREATE OR REPLACE VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_FLATTENED_SVW_HELPER_VW AS
SELECT
  EVENT_TIME         AS npm_event_time,
  ENVIRONMENT        AS npm_environment,
  HOSTNAME           AS npm_hostname,
  REPOSITORY         AS npm_repository,
  PIPELINE_ID        AS npm_pipeline_id,
  ACTOR              AS npm_actor,
  EVENT_TYPE         AS npm_event_type,
  PACKAGE_NAME       AS npm_package_name,
  PACKAGE_VERSION    AS npm_package_version,
  INDICATOR_TYPE     AS npm_indicator_type,
  INDICATOR_SEVERITY AS npm_indicator_severity,
  CWE_ID             AS npm_cwe_id,
  STATUS             AS npm_status,
  VARIANT_SOURCE     AS npm_variant_source,
  PATH               AS npm_json_path,
  KEY                AS npm_json_key,
  VALUE_TYPE         AS npm_json_value_type,
  IS_LEAF            AS npm_is_leaf,
  LEAF_VALUE         AS npm_leaf_value
FROM SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_FLATTENED_VW;

COMMENT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_FLATTENED_SVW_HELPER_VW IS
'Helper view for semantic views: npm supply-chain flattened JSON with prefixed, unique column names.';

GRANT SELECT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_FLATTENED_SVW_HELPER_VW TO ROLE PUBLIC;


