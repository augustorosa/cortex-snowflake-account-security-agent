-- ============================================================================
-- 30_itops_demo/06_flatten_views.sql
-- Silver layer: typed, flattened views over the RAW native-JSON tables.
-- Agents and the semantic view never read VARIANT directly.
-- Scenario rows override baseline rows for the same device-day, job run and
-- capacity-day.
-- Requires 01-05. Re-runnable.
-- ============================================================================

USE ROLE cortex_role;
USE WAREHOUSE cortex_wh;
USE SCHEMA COWORK.IT_OPS;

CREATE OR REPLACE FUNCTION SDP_TS(o VARIANT)
RETURNS TIMESTAMP_NTZ
AS $$ IFF(o:value IS NULL, NULL, TO_TIMESTAMP_NTZ(o:value::NUMBER, 3)::TIMESTAMP_NTZ(9)) $$;

CREATE OR REPLACE FUNCTION PARSE_ISO(s VARCHAR)
RETURNS TIMESTAMP_NTZ
AS $$ TRY_TO_TIMESTAMP_NTZ(s, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') $$;

-- ============================================================================
-- ManageEngine ServiceDesk Plus
-- ============================================================================
CREATE OR REPLACE VIEW SDP_REASSIGNMENTS COMMENT = 'Reassignment counts per SDP request, derived from request history ASSIGN operations' AS
SELECT PAYLOAD:request_id::STRING AS request_id, COUNT(*) AS reassignment_count
FROM RAW_SDP_REQUEST_HISTORY
WHERE PAYLOAD:operation::STRING = 'ASSIGN'
GROUP BY 1;

CREATE OR REPLACE VIEW SDP_REQUESTS COMMENT = 'ManageEngine ServiceDesk Plus requests (incidents and service requests), one row per request' AS
WITH r AS (
  SELECT
    PAYLOAD:id::STRING AS request_id,
    PAYLOAD:display_id::STRING AS request_number,
    PAYLOAD:subject::STRING AS subject,
    PAYLOAD:request_type:name::STRING AS request_type,
    PAYLOAD:priority:name::STRING AS priority,
    PAYLOAD:category:name::STRING AS category,
    PAYLOAD:mode:name::STRING AS mode,
    PAYLOAD:status:name::STRING AS status,
    PAYLOAD:group:name::STRING AS support_group,
    LOWER(PAYLOAD:technician:email_id::STRING) AS technician_email,
    PAYLOAD:technician:name::STRING AS technician_name,
    LOWER(PAYLOAD:requester:email_id::STRING) AS requester_email,
    PAYLOAD:requester:is_vip_user::BOOLEAN AS is_vip_requester,
    PAYLOAD:department:name::STRING AS department,
    PAYLOAD:site:name::STRING AS site,
    SDP_TS(PAYLOAD:created_time) AS created_at,
    SDP_TS(PAYLOAD:responded_time) AS responded_at,
    SDP_TS(PAYLOAD:first_response_due_by_time) AS first_response_due_at,
    SDP_TS(PAYLOAD:due_by_time) AS due_by_at,
    SDP_TS(PAYLOAD:resolved_time) AS resolved_at,
    SDP_TS(PAYLOAD:completed_time) AS closed_at,
    PAYLOAD:is_overdue::BOOLEAN AS is_sla_breached,
    PAYLOAD:is_first_response_overdue::BOOLEAN AS is_first_response_breached,
    PAYLOAD:is_fcr::BOOLEAN AS is_fcr_flag,
    PAYLOAD:is_reopened::BOOLEAN AS is_reopened,
    UPPER(PAYLOAD:configuration_items[0]:name::STRING) AS ci_name,
    SOURCE AS record_source
  FROM RAW_SDP_REQUESTS
)
SELECT r.*,
  s.priority_code,
  DATE_TRUNC('day', r.created_at)::DATE AS created_date,
  DATE_TRUNC('month', r.created_at)::DATE AS created_month,
  r.status IN ('Open','In Progress','On Hold') AS is_open,
  COALESCE(h.reassignment_count, 0) AS reassignment_count,
  (r.is_fcr_flag AND COALESCE(h.reassignment_count, 0) = 0 AND NOT r.is_reopened) AS is_fcr,
  ROUND(DATEDIFF(minute, r.created_at, r.resolved_at) / 60.0, 2) AS resolution_hours,
  ROUND(DATEDIFF(minute, r.created_at, r.responded_at) / 60.0, 2) AS first_response_hours,
  IFF(r.status IN ('Open','In Progress','On Hold'), DATEDIFF(day, r.created_at, (SELECT demo_end_date FROM REF_DEMO_CONFIG)), NULL) AS open_age_days,
  CASE WHEN r.status NOT IN ('Open','In Progress','On Hold') THEN NULL
       WHEN DATEDIFF(day, r.created_at, (SELECT demo_end_date FROM REF_DEMO_CONFIG)) <= 2 THEN '0-2d'
       WHEN DATEDIFF(day, r.created_at, (SELECT demo_end_date FROM REF_DEMO_CONFIG)) <= 7 THEN '3-7d'
       WHEN DATEDIFF(day, r.created_at, (SELECT demo_end_date FROM REF_DEMO_CONFIG)) <= 30 THEN '8-30d'
       ELSE '30d+' END AS backlog_age_bucket
FROM r
LEFT JOIN REF_SLA_TARGETS s ON s.priority = r.priority
LEFT JOIN SDP_REASSIGNMENTS h ON h.request_id = r.request_id;

CREATE OR REPLACE VIEW SDP_WORKLOGS COMMENT = 'Technician time logged against SDP requests' AS
SELECT
  PAYLOAD:id::STRING AS worklog_id,
  PAYLOAD:request_id::STRING AS request_id,
  LOWER(PAYLOAD:owner:email_id::STRING) AS technician_email,
  PAYLOAD:owner:name::STRING AS technician_name,
  PAYLOAD:worklog_type:name::STRING AS worklog_type,
  SDP_TS(PAYLOAD:start_time) AS started_at,
  DATE_TRUNC('day', SDP_TS(PAYLOAD:start_time))::DATE AS worklog_date,
  ROUND(PAYLOAD:time_spent:hours::NUMBER + PAYLOAD:time_spent:minutes::NUMBER / 60.0, 2) AS hours_spent,
  SOURCE AS record_source
FROM RAW_SDP_WORKLOGS;

CREATE OR REPLACE VIEW SDP_CHANGES COMMENT = 'ManageEngine SDP change requests (RFCs)' AS
SELECT
  PAYLOAD:id::STRING AS change_id,
  PAYLOAD:display_id::STRING AS change_number,
  PAYLOAD:title::STRING AS title,
  PAYLOAD:change_type:name::STRING AS change_type,
  PAYLOAD:risk:name::STRING AS risk,
  PAYLOAD:stage:name::STRING AS stage,
  PAYLOAD:status:name::STRING AS status,
  PAYLOAD:closure_code:name::STRING AS closure_code,
  PAYLOAD:closure_code:name::STRING IN ('Failed','Rolled Back') AS is_failed_change,
  SDP_TS(PAYLOAD:scheduled_start_time) AS scheduled_start_at,
  SDP_TS(PAYLOAD:scheduled_end_time) AS scheduled_end_at,
  SDP_TS(PAYLOAD:completed_time) AS completed_at,
  DATE_TRUNC('day', SDP_TS(PAYLOAD:scheduled_start_time))::DATE AS change_date,
  LOWER(PAYLOAD:change_owner:email_id::STRING) AS owner_email,
  PAYLOAD:change_owner:name::STRING AS owner_name,
  PAYLOAD:group:name::STRING AS support_group,
  UPPER(PAYLOAD:configuration_items[0]:name::STRING) AS ci_name,
  PAYLOAD:reason_for_change::STRING AS reason_for_change,
  PAYLOAD:udf_fields:udf_cab_approval::STRING AS cab_approval,
  PAYLOAD:udf_fields:udf_backout_plan_tested::STRING AS backout_plan_tested,
  SOURCE AS record_source
FROM RAW_SDP_CHANGES;

CREATE OR REPLACE VIEW SDP_CI_RELATIONSHIPS COMMENT = 'SDP CMDB relationships (server Runs business service, server Depends on server)' AS
SELECT UPPER(PAYLOAD:ci:name::STRING) AS ci_name,
       PAYLOAD:relationship_type:name::STRING AS relationship_type,
       PAYLOAD:related_ci:name::STRING AS related_ci_name,
       PAYLOAD:related_ci:ci_type::STRING AS related_ci_type
FROM RAW_SDP_CI_RELATIONSHIPS;

CREATE OR REPLACE VIEW SDP_SOFTWARE_LICENSES COMMENT = 'SDP software license entitlements vs allocations' AS
SELECT PAYLOAD:software:name::STRING AS software_name,
       PAYLOAD:manufacturer:name::STRING AS manufacturer,
       PAYLOAD:license_type:name::STRING AS license_type,
       PAYLOAD:purchased_licenses::NUMBER AS purchased_licenses,
       PAYLOAD:allocated_licenses::NUMBER AS allocated_licenses,
       PAYLOAD:installations::NUMBER AS installations,
       PAYLOAD:cost::NUMBER(12,2) AS annual_cost_usd,
       SDP_TS(PAYLOAD:expiry_date)::DATE AS expiry_date,
       ROUND(PAYLOAD:allocated_licenses::NUMBER / NULLIF(PAYLOAD:purchased_licenses::NUMBER, 0) * 100, 1) AS allocation_pct,
       PAYLOAD:purchased_licenses::NUMBER - PAYLOAD:allocated_licenses::NUMBER AS unallocated_licenses
FROM RAW_SDP_SOFTWARE_LICENSES;

-- ============================================================================
-- LogicMonitor
-- ============================================================================
CREATE OR REPLACE VIEW LM_DEVICES COMMENT = 'LogicMonitor monitored devices' AS
SELECT
  PAYLOAD:id::NUMBER AS lm_device_id,
  UPPER(PAYLOAD:name::STRING) AS hostname,
  PAYLOAD:hostStatus::STRING AS host_status,
  FILTER(PAYLOAD:systemProperties, p -> p:name::STRING = 'system.sysinfo')[0]:value::STRING AS os,
  FILTER(PAYLOAD:systemProperties, p -> p:name::STRING = 'system.categories')[0]:value::STRING AS device_category,
  FILTER(PAYLOAD:customProperties, p -> p:name::STRING = 'tac.tier')[0]:value::STRING AS tier,
  FILTER(PAYLOAD:customProperties, p -> p:name::STRING = 'tac.environment')[0]:value::STRING AS environment,
  FILTER(PAYLOAD:customProperties, p -> p:name::STRING = 'tac.application')[0]:value::STRING AS application
FROM RAW_LM_DEVICES;

CREATE OR REPLACE VIEW LM_ALERTS COMMENT = 'LogicMonitor alerts. Noise = cleared in under 15 minutes without acknowledgement, or raised during scheduled downtime (SDT)' AS
WITH a AS (
  SELECT
    PAYLOAD:id::STRING AS alert_id,
    UPPER(PAYLOAD:monitorObjectName::STRING) AS hostname,
    PAYLOAD:severity::NUMBER AS severity_level,
    CASE PAYLOAD:severity::NUMBER WHEN 4 THEN 'Critical' WHEN 3 THEN 'Error' ELSE 'Warning' END AS severity,
    PAYLOAD:resourceTemplateName::STRING AS datasource,
    PAYLOAD:dataPointName::STRING AS datapoint,
    PAYLOAD:alertValue::STRING AS alert_value,
    PAYLOAD:rule::STRING AS alert_rule,
    TO_TIMESTAMP_NTZ(PAYLOAD:startEpoch::NUMBER) AS started_at,
    IFF(PAYLOAD:endEpoch::NUMBER > 0, TO_TIMESTAMP_NTZ(PAYLOAD:endEpoch::NUMBER), NULL) AS ended_at,
    PAYLOAD:acked::BOOLEAN AS is_acked,
    PAYLOAD:sdted::BOOLEAN AS is_in_sdt,
    PAYLOAD:cleared::BOOLEAN AS is_cleared,
    SOURCE AS record_source
  FROM RAW_LM_ALERTS
)
SELECT a.*,
  DATE_TRUNC('day', started_at)::DATE AS alert_date,
  DATEDIFF(minute, started_at, ended_at) AS duration_minutes,
  ((DATEDIFF(minute, started_at, ended_at) < 15 AND NOT is_acked) OR is_in_sdt) AS is_noise
FROM a;

CREATE OR REPLACE VIEW LM_DEVICE_DAILY COMMENT = 'Daily LogicMonitor datapoint roll-up per device: CPU, memory, disk, downtime and uptime' AS
WITH x AS (
  SELECT
    UPPER(PAYLOAD:deviceDisplayName::STRING) AS hostname,
    PAYLOAD:date::DATE AS metric_date,
    PAYLOAD:datapoints:CPUBusyPercent:avg::FLOAT AS cpu_avg_pct,
    PAYLOAD:datapoints:CPUBusyPercent:p95::FLOAT AS cpu_p95_pct,
    PAYLOAD:datapoints:MemoryUtilizationPercent:avg::FLOAT AS memory_avg_pct,
    PAYLOAD:datapoints:MemoryUtilizationPercent:p95::FLOAT AS memory_p95_pct,
    PAYLOAD:datapoints:DiskUsedPercent:max::FLOAT AS disk_used_max_pct,
    PAYLOAD:datapoints:HostStatus:downMinutes::NUMBER AS downtime_minutes,
    SOURCE AS record_source
  FROM RAW_LM_DEVICE_DAILY
  QUALIFY ROW_NUMBER() OVER (PARTITION BY hostname, metric_date ORDER BY IFF(SOURCE LIKE 'scenario:%', 0, 1)) = 1
)
SELECT x.*, d.tier, d.environment, d.application,
  ROUND(100 * (1 - x.downtime_minutes / 1440.0), 3) AS uptime_pct,
  -- Hot device: 30-day average p95 CPU >= 85% or p95 memory >= 90% (device-level flag, repeated on each day)
  (AVG(IFF(x.metric_date >= DATEADD(day, -30, (SELECT demo_end_date FROM REF_DEMO_CONFIG)), x.cpu_p95_pct, NULL)) OVER (PARTITION BY x.hostname) >= 85
   OR AVG(IFF(x.metric_date >= DATEADD(day, -30, (SELECT demo_end_date FROM REF_DEMO_CONFIG)), x.memory_p95_pct, NULL)) OVER (PARTITION BY x.hostname) >= 90) AS is_hot
FROM x LEFT JOIN LM_DEVICES d ON d.hostname = x.hostname;

-- ============================================================================
-- Smartsheet
-- ============================================================================
CREATE OR REPLACE VIEW PROJECTS COMMENT = 'Smartsheet IT PMO Portfolio projects (one row per sheet row)' AS
WITH sheet_rows AS (
  SELECT r.value:id::NUMBER AS row_id, r.value:cells AS cells
  FROM RAW_SMARTSHEET_SHEET s, LATERAL FLATTEN(s.PAYLOAD:rows) r
),
cells AS (
  SELECT row_id, c.value:columnId::NUMBER AS column_id, c.value:value AS v
  FROM sheet_rows sr, LATERAL FLATTEN(sr.cells) c
),
p AS (
  SELECT row_id,
    MAX(IFF(column_id = 101, v::STRING, NULL)) AS project_name,
    MAX(IFF(column_id = 102, LOWER(v::STRING), NULL)) AS project_manager_email,
    MAX(IFF(column_id = 103, LOWER(v::STRING), NULL)) AS assigned_to_email,
    MAX(IFF(column_id = 104, v::DATE, NULL)) AS start_date,
    MAX(IFF(column_id = 105, v::DATE, NULL)) AS due_date,
    MAX(IFF(column_id = 106, v::DATE, NULL)) AS actual_end_date,
    MAX(IFF(column_id = 107, v::FLOAT, NULL)) AS pct_complete,
    MAX(IFF(column_id = 108, v::STRING, NULL)) AS status,
    MAX(IFF(column_id = 109, v::STRING, NULL)) AS health,
    MAX(IFF(column_id = 110, v::NUMBER, NULL)) AS estimated_hours,
    MAX(IFF(column_id = 111, v::NUMBER, NULL)) AS actual_hours
  FROM cells GROUP BY row_id
)
SELECT p.*,
  (p.status = 'Complete') AS is_complete,
  CASE WHEN p.status = 'Complete' THEN p.actual_end_date > p.due_date
       ELSE p.due_date < (SELECT demo_end_date FROM REF_DEMO_CONFIG) END AS is_late,
  (p.status = 'Complete' AND p.actual_end_date <= p.due_date) AS is_on_time_complete,
  IFF(p.status = 'Complete', DATEDIFF(day, p.due_date, p.actual_end_date),
      DATEDIFF(day, p.due_date, (SELECT demo_end_date FROM REF_DEMO_CONFIG))) AS days_late
FROM p;

-- ============================================================================
-- Microsoft Entra ID / Azure / Defender / Sentinel
-- ============================================================================
CREATE OR REPLACE VIEW ENTRA_SIGNINS COMMENT = 'Microsoft Entra ID sign-in logs' AS
SELECT
  PAYLOAD:id::STRING AS signin_id,
  PARSE_ISO(PAYLOAD:createdDateTime::STRING) AS signin_at,
  DATE_TRUNC('day', PARSE_ISO(PAYLOAD:createdDateTime::STRING))::DATE AS signin_date,
  LOWER(PAYLOAD:userPrincipalName::STRING) AS user_email,
  PAYLOAD:appDisplayName::STRING AS app_name,
  PAYLOAD:ipAddress::STRING AS ip_address,
  PAYLOAD:clientAppUsed::STRING AS client_app,
  PAYLOAD:isInteractive::BOOLEAN AS is_interactive,
  PAYLOAD:conditionalAccessStatus::STRING AS conditional_access_status,
  PAYLOAD:authenticationRequirement::STRING AS authentication_requirement,
  PAYLOAD:authenticationRequirement::STRING = 'multiFactorAuthentication' AS is_mfa,
  PAYLOAD:riskLevelDuringSignIn::STRING AS risk_level,
  PAYLOAD:status:errorCode::NUMBER AS error_code,
  PAYLOAD:status:failureReason::STRING AS failure_reason,
  PAYLOAD:status:errorCode::NUMBER = 0 AS is_success,
  PAYLOAD:location:city::STRING AS city,
  PAYLOAD:location:countryOrRegion::STRING AS country,
  PAYLOAD:deviceDetail:operatingSystem::STRING AS device_os,
  PAYLOAD:deviceDetail:browser::STRING AS browser,
  PAYLOAD:deviceDetail:isCompliant::BOOLEAN AS is_compliant_device,
  SOURCE AS record_source
FROM RAW_ENTRA_SIGNINS;

CREATE OR REPLACE VIEW ENTRA_AUDITS COMMENT = 'Microsoft Entra ID directory audit events' AS
SELECT
  PAYLOAD:id::STRING AS audit_id,
  PARSE_ISO(PAYLOAD:activityDateTime::STRING) AS activity_at,
  PAYLOAD:activityDisplayName::STRING AS activity,
  PAYLOAD:category::STRING AS category,
  PAYLOAD:result::STRING AS result,
  LOWER(PAYLOAD:initiatedBy:user:userPrincipalName::STRING) AS initiated_by_email,
  PAYLOAD:initiatedBy:user:ipAddress::STRING AS initiated_from_ip,
  PAYLOAD:targetResources[0]:displayName::STRING AS target_name,
  PAYLOAD:targetResources[0]:type::STRING AS target_type,
  SOURCE AS record_source
FROM RAW_ENTRA_AUDITS;

CREATE OR REPLACE VIEW AZURE_ACTIVITY COMMENT = 'Azure Monitor AzureActivity control-plane operations' AS
SELECT
  PARSE_ISO(PAYLOAD:TimeGenerated::STRING) AS activity_at,
  DATE_TRUNC('day', PARSE_ISO(PAYLOAD:TimeGenerated::STRING))::DATE AS activity_date,
  PAYLOAD:OperationNameValue::STRING AS operation,
  PAYLOAD:ActivityStatusValue::STRING AS status,
  LOWER(PAYLOAD:Caller::STRING) AS caller_email,
  PAYLOAD:CallerIpAddress::STRING AS caller_ip,
  PAYLOAD:ResourceGroup::STRING AS resource_group,
  PAYLOAD:_ResourceId::STRING AS resource_id,
  UPPER(SPLIT_PART(PAYLOAD:_ResourceId::STRING, '/', -1)) AS resource_name,
  PAYLOAD:OperationNameValue::STRING ILIKE ANY ('%roleAssignments/write%', '%runCommand%', '%listKeys%', '%securityRules/write%') AS is_sensitive_operation,
  SOURCE AS record_source
FROM RAW_AZURE_ACTIVITY;

CREATE OR REPLACE VIEW DEFENDER_ALERTS COMMENT = 'Microsoft Defender XDR alerts (AlertInfo + AlertEvidence flattened to one row per alert)' AS
SELECT
  PAYLOAD:AlertId::STRING AS alert_id,
  PARSE_ISO(PAYLOAD:Timestamp::STRING) AS alert_at,
  DATE_TRUNC('day', PARSE_ISO(PAYLOAD:Timestamp::STRING))::DATE AS alert_date,
  PAYLOAD:Title::STRING AS title,
  PAYLOAD:Category::STRING AS category,
  PAYLOAD:Severity::STRING AS severity,
  PAYLOAD:ServiceSource::STRING AS service_source,
  PAYLOAD:DetectionSource::STRING AS detection_source,
  PAYLOAD:AttackTechniques::STRING AS attack_techniques,
  UPPER(FILTER(PAYLOAD:Evidence, e -> e:EntityType::STRING = 'Machine')[0]:DeviceName::STRING) AS device_name,
  LOWER(FILTER(PAYLOAD:Evidence, e -> e:EntityType::STRING = 'User')[0]:AccountUpn::STRING) AS account_upn,
  FILTER(PAYLOAD:Evidence, e -> e:EntityType::STRING = 'Ip')[0]:RemoteIP::STRING AS remote_ip,
  FILTER(PAYLOAD:Evidence, e -> e:EntityType::STRING = 'Process')[0]:FileName::STRING AS file_name,
  FILTER(PAYLOAD:Evidence, e -> e:EntityType::STRING = 'Process')[0]:ProcessCommandLine::STRING AS process_command_line,
  SOURCE AS record_source
FROM RAW_DEFENDER_ALERTS;

CREATE OR REPLACE VIEW SENTINEL_INCIDENTS COMMENT = 'Microsoft Sentinel SecurityIncident (MSSP-managed SOC)' AS
SELECT
  PAYLOAD:IncidentNumber::NUMBER AS incident_number,
  PAYLOAD:Title::STRING AS title,
  PAYLOAD:Severity::STRING AS severity,
  PAYLOAD:Status::STRING AS status,
  PAYLOAD:Classification::STRING AS classification,
  PAYLOAD:ClassificationComment::STRING AS classification_comment,
  PAYLOAD:Owner:assignedTo::STRING AS owner,
  PARSE_ISO(PAYLOAD:CreatedTime::STRING) AS created_at,
  DATE_TRUNC('day', PARSE_ISO(PAYLOAD:CreatedTime::STRING))::DATE AS created_date,
  PARSE_ISO(PAYLOAD:FirstActivityTime::STRING) AS first_activity_at,
  PARSE_ISO(PAYLOAD:ClosedTime::STRING) AS closed_at,
  ROUND(DATEDIFF(minute, PARSE_ISO(PAYLOAD:CreatedTime::STRING), PARSE_ISO(PAYLOAD:ClosedTime::STRING)) / 60.0, 1) AS hours_to_close,
  PAYLOAD:AdditionalData:alertsCount::NUMBER AS alert_count,
  ARRAY_TO_STRING(PAYLOAD:AdditionalData:tactics, ', ') AS tactics,
  PAYLOAD:AlertIds AS alert_ids,
  SOURCE AS record_source
FROM RAW_SENTINEL_INCIDENTS;

CREATE OR REPLACE VIEW SENTINEL_ALERTS COMMENT = 'Microsoft Sentinel SecurityAlert' AS
SELECT
  PAYLOAD:SystemAlertId::STRING AS system_alert_id,
  PARSE_ISO(PAYLOAD:TimeGenerated::STRING) AS alert_at,
  PAYLOAD:AlertName::STRING AS alert_name,
  PAYLOAD:AlertSeverity::STRING AS severity,
  PAYLOAD:ProviderName::STRING AS provider_name,
  PAYLOAD:ProductName::STRING AS product_name,
  PAYLOAD:Tactics::STRING AS tactics,
  PAYLOAD:Techniques::STRING AS techniques,
  PAYLOAD:CompromisedEntity::STRING AS compromised_entity,
  SOURCE AS record_source
FROM RAW_SENTINEL_ALERTS;

-- ============================================================================
-- Microsoft 365 + AI gateway
-- ============================================================================
CREATE OR REPLACE VIEW M365_SKUS COMMENT = 'Microsoft 365 subscribed SKUs with list price' AS
SELECT s.PAYLOAD:skuPartNumber::STRING AS sku_part_number,
       p.sku_display_name,
       s.PAYLOAD:prepaidUnits:enabled::NUMBER AS prepaid_units,
       s.PAYLOAD:consumedUnits::NUMBER AS consumed_units,
       p.monthly_price_usd
FROM RAW_M365_SUBSCRIBED_SKUS s
LEFT JOIN REF_LICENSE_PRICES p ON p.sku_part_number = s.PAYLOAD:skuPartNumber::STRING;

CREATE OR REPLACE VIEW M365_USER_ACTIVITY COMMENT = 'Microsoft 365 per-user license assignment and last activity' AS
SELECT
  LOWER(PAYLOAD:userPrincipalName::STRING) AS user_email,
  PAYLOAD:displayName::STRING AS display_name,
  PAYLOAD:department::STRING AS department,
  PAYLOAD:reportRefreshDate::DATE AS report_date,
  PAYLOAD:lastActivityDate::DATE AS last_activity_date,
  PAYLOAD:skuPartNumbers AS sku_part_numbers,
  PAYLOAD:skuPartNumbers[0]::STRING AS base_sku,
  ARRAY_CONTAINS('Microsoft_365_Copilot'::VARIANT, PAYLOAD:skuPartNumbers) AS has_copilot_license,
  DATEDIFF(day, PAYLOAD:lastActivityDate::DATE, PAYLOAD:reportRefreshDate::DATE) AS days_since_activity,
  DATEDIFF(day, PAYLOAD:lastActivityDate::DATE, PAYLOAD:reportRefreshDate::DATE) <= 30 AS is_active_30d
FROM RAW_M365_USER_ACTIVITY;

CREATE OR REPLACE VIEW M365_COPILOT_USAGE COMMENT = 'Microsoft 365 Copilot monthly usage per licensed user' AS
SELECT
  LOWER(PAYLOAD:userPrincipalName::STRING) AS user_email,
  DATE_TRUNC('month', PAYLOAD:reportRefreshDate::DATE) AS usage_month,
  PAYLOAD:lastActivityDate::DATE AS last_activity_date,
  PAYLOAD:lastActivityDate IS NOT NULL
    AND DATE_TRUNC('month', PAYLOAD:lastActivityDate::DATE) = DATE_TRUNC('month', PAYLOAD:reportRefreshDate::DATE) AS is_active_in_month,
  PAYLOAD:microsoftTeamsCopilotLastActivityDate IS NOT NULL AS used_teams_copilot,
  PAYLOAD:wordCopilotLastActivityDate IS NOT NULL AS used_word_copilot,
  PAYLOAD:excelCopilotLastActivityDate IS NOT NULL AS used_excel_copilot,
  PAYLOAD:outlookCopilotLastActivityDate IS NOT NULL AS used_outlook_copilot
FROM RAW_M365_COPILOT_USAGE;

CREATE OR REPLACE VIEW AI_GATEWAY_REQUESTS COMMENT = 'In-house AI gateway (prompt router) request log' AS
SELECT
  PAYLOAD:request_id::STRING AS request_id,
  PARSE_ISO(PAYLOAD:timestamp::STRING) AS requested_at,
  DATE_TRUNC('day', PARSE_ISO(PAYLOAD:timestamp::STRING))::DATE AS request_date,
  DATE_TRUNC('month', PARSE_ISO(PAYLOAD:timestamp::STRING))::DATE AS request_month,
  LOWER(PAYLOAD:user_email::STRING) AS user_email,
  PAYLOAD:department::STRING AS department,
  PAYLOAD:model::STRING AS model,
  PAYLOAD:provider::STRING AS provider,
  PAYLOAD:model::STRING = 'claude-opus-4-1' AS is_premium_model,
  PAYLOAD:route_reason::STRING AS route_reason,
  PAYLOAD:complexity::STRING AS complexity,
  PAYLOAD:prompt_tokens::NUMBER AS prompt_tokens,
  PAYLOAD:completion_tokens::NUMBER AS completion_tokens,
  PAYLOAD:prompt_tokens::NUMBER + PAYLOAD:completion_tokens::NUMBER AS total_tokens,
  PAYLOAD:cost_usd::FLOAT AS cost_usd,
  PAYLOAD:latency_ms::NUMBER AS latency_ms,
  PAYLOAD:status::STRING AS status,
  PAYLOAD:client_app::STRING AS client_app,
  SOURCE AS record_source
FROM RAW_AI_GATEWAY_REQUESTS;

-- ============================================================================
-- Microsoft Fabric CDW + Power BI
-- ============================================================================
CREATE OR REPLACE VIEW FABRIC_ITEMS COMMENT = 'Microsoft Fabric workspace items (lakehouses, warehouse, pipelines, notebooks, semantic models, reports)' AS
SELECT PAYLOAD:id::STRING AS item_id,
       PAYLOAD:displayName::STRING AS item_name,
       PAYLOAD:type::STRING AS item_type,
       PAYLOAD:workspaceName::STRING AS workspace_name,
       PAYLOAD:capacityName::STRING AS capacity_name,
       PAYLOAD:upstreamItem::STRING AS upstream_item,
       PAYLOAD:description::STRING AS description
FROM RAW_FABRIC_ITEMS;

CREATE OR REPLACE VIEW FABRIC_JOB_RUNS COMMENT = 'Fabric job instances: pipeline runs, notebook runs and semantic model refreshes' AS
WITH j AS (
  SELECT
    PAYLOAD:id::STRING AS job_id,
    PAYLOAD:itemName::STRING AS item_name,
    PAYLOAD:itemType::STRING AS item_type,
    PAYLOAD:workspaceName::STRING AS workspace_name,
    PAYLOAD:jobType::STRING AS job_type,
    PAYLOAD:invokeType::STRING AS invoke_type,
    PAYLOAD:status::STRING AS status,
    PARSE_ISO(PAYLOAD:startTimeUtc::STRING) AS started_at,
    PARSE_ISO(PAYLOAD:endTimeUtc::STRING) AS ended_at,
    PAYLOAD:failureReason:errorCode::STRING AS error_code,
    PAYLOAD:failureReason:message::STRING AS error_message,
    SOURCE AS record_source
  FROM RAW_FABRIC_JOB_RUNS
)
SELECT j.*,
  DATE_TRUNC('day', started_at)::DATE AS run_date,
  DATEDIFF(minute, started_at, ended_at) AS duration_minutes,
  status = 'Completed' AS is_success
FROM j
-- A scenario scheduled run replaces the baseline scheduled run for the same item and day
WHERE NOT (record_source = 'baseline' AND EXISTS (
  SELECT 1 FROM RAW_FABRIC_JOB_RUNS s
  WHERE s.SOURCE LIKE 'scenario:%' AND s.PAYLOAD:invokeType::STRING = 'Scheduled'
    AND s.PAYLOAD:itemName::STRING = j.item_name
    AND DATE_TRUNC('day', PARSE_ISO(s.PAYLOAD:startTimeUtc::STRING)) = DATE_TRUNC('day', j.started_at)));

CREATE OR REPLACE VIEW FABRIC_CAPACITY_DAILY COMMENT = 'Fabric Capacity Metrics: daily CU seconds and throttling per item' AS
SELECT
  PAYLOAD:capacityName::STRING AS capacity_name,
  PAYLOAD:capacitySku::STRING AS capacity_sku,
  PAYLOAD:capacityCUs::NUMBER AS capacity_cus,
  PAYLOAD:date::DATE AS metric_date,
  PAYLOAD:workspaceName::STRING AS workspace_name,
  PAYLOAD:itemName::STRING AS item_name,
  PAYLOAD:itemKind::STRING AS item_type,
  PAYLOAD:billingType::STRING AS billing_type,
  PAYLOAD:operationName::STRING AS operation_name,
  PAYLOAD:cuSeconds::NUMBER AS cu_seconds,
  PAYLOAD:capacityCUs::NUMBER * 86400 AS capacity_cu_seconds_per_day,
  PAYLOAD:throttlingMinutes::NUMBER AS throttling_minutes,
  SOURCE AS record_source
FROM RAW_FABRIC_CAPACITY_METRICS
QUALIFY ROW_NUMBER() OVER (PARTITION BY PAYLOAD:itemName::STRING, PAYLOAD:date::DATE
                           ORDER BY IFF(SOURCE LIKE 'scenario:%', 0, 1)) = 1;

CREATE OR REPLACE VIEW FABRIC_WAREHOUSE_QUERIES COMMENT = 'Fabric warehouse WH_CDW_Gold query insights (exec_requests_history)' AS
SELECT
  PAYLOAD:distributed_statement_id::STRING AS statement_id,
  PAYLOAD:session_id::NUMBER AS session_id,
  LOWER(PAYLOAD:login_name::STRING) AS login_name,
  PAYLOAD:program_name::STRING AS program_name,
  PARSE_ISO(PAYLOAD:start_time::STRING) AS started_at,
  DATE_TRUNC('day', PARSE_ISO(PAYLOAD:start_time::STRING))::DATE AS query_date,
  PAYLOAD:total_elapsed_time_ms::NUMBER AS elapsed_ms,
  PAYLOAD:status::STRING AS status,
  PAYLOAD:row_count::NUMBER AS row_count,
  PAYLOAD:data_scanned_remote_storage_mb::FLOAT AS data_scanned_mb,
  PAYLOAD:command::STRING AS command_text,
  'WH_CDW_Gold' AS warehouse_name,
  SOURCE AS record_source
FROM RAW_FABRIC_WAREHOUSE_QUERIES;

CREATE OR REPLACE VIEW POWERBI_ACTIVITY COMMENT = 'Power BI activity events (views, exports, refreshes, shares)' AS
SELECT
  PAYLOAD:Id::STRING AS event_id,
  PARSE_ISO(PAYLOAD:CreationTime::STRING) AS event_at,
  DATE_TRUNC('day', PARSE_ISO(PAYLOAD:CreationTime::STRING))::DATE AS event_date,
  PAYLOAD:Operation::STRING AS operation,
  LOWER(PAYLOAD:UserId::STRING) AS user_email,
  PAYLOAD:ClientIP::STRING AS client_ip,
  PAYLOAD:UserAgent::STRING AS user_agent,
  PAYLOAD:WorkSpaceName::STRING AS workspace_name,
  PAYLOAD:ReportName::STRING AS report_name,
  PAYLOAD:DatasetName::STRING AS dataset_name,
  PAYLOAD:ConsumptionMethod::STRING AS consumption_method,
  PAYLOAD:DistributionMethod::STRING AS distribution_method,
  PAYLOAD:ExportedArtifactInfo:ExportType::STRING AS export_type,
  PAYLOAD:RowCount::NUMBER AS exported_rows,
  PAYLOAD:Operation::STRING IN ('ExportReport','ExportArtifact') AS is_export,
  SOURCE AS record_source
FROM RAW_POWERBI_ACTIVITY;
