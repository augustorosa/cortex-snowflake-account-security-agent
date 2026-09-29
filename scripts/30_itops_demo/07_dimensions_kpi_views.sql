-- ============================================================================
-- 30_itops_demo/07_dimensions_kpi_views.sql
-- Gold layer: conformed dimensions, asset/CMDB model, KPI helper views and a
-- unified cross-source event timeline for incident and security tracing.
-- Requires 06. Re-runnable.
-- ============================================================================

USE ROLE cortex_role;
USE WAREHOUSE cortex_wh;
USE SCHEMA COWORK.IT_OPS;

-- ============================================================================
-- Conformed dimensions
-- ============================================================================
CREATE OR REPLACE VIEW DIM_USER COMMENT = 'Conformed person / account dimension keyed on lower-case email (SDP, Entra, Smartsheet, M365, AI gateway, Fabric)' AS
SELECT email AS user_email, full_name, department, site, job_title,
       IFF(is_technician, 'IT Staff', 'Employee') AS account_type,
       support_group, is_technician, low_ticket_usage
FROM SEED_PEOPLE
UNION ALL
SELECT column1, column2, 'Information Technology', 'Azure', 'Service Account', 'Service Account', NULL, FALSE, FALSE
FROM VALUES ('svc_jde_integration@tacdemo.com','svc JDE Integration'),
            ('svc_fabric_etl@tacdemo.com','svc Fabric ETL'),
            ('svc_backup@tacdemo.com','svc Backup'),
            ('power bi service','Power BI Service');

CREATE OR REPLACE VIEW SDP_ASSETS COMMENT = 'ManageEngine SDP assets / CMDB CIs enriched with lifecycle (EOL/EOS), completeness and LogicMonitor coverage' AS
WITH a AS (
  SELECT
    PAYLOAD:id::STRING AS asset_id,
    UPPER(PAYLOAD:name::STRING) AS hostname,
    PAYLOAD:product_type:name::STRING AS asset_type,
    PAYLOAD:product:name::STRING AS product,
    PAYLOAD:state:name::STRING AS asset_state,
    PAYLOAD:vendor:name::STRING AS vendor,
    SDP_TS(PAYLOAD:acquisition_date)::DATE AS acquired_date,
    SDP_TS(PAYLOAD:warranty_expiry)::DATE AS warranty_expiry_date,
    SDP_TS(PAYLOAD:last_scan_time) AS last_scan_at,
    LOWER(COALESCE(PAYLOAD:udf_fields:udf_owner::STRING, PAYLOAD:user:email_id::STRING)) AS owner_email,
    PAYLOAD:department:name::STRING AS department,
    PAYLOAD:site:name::STRING AS site,
    PAYLOAD:operating_system:os::STRING AS os,
    PAYLOAD:udf_fields:udf_db_engine::STRING AS db_engine,
    PAYLOAD:udf_fields:udf_application::STRING AS application,
    PAYLOAD:udf_fields:udf_tier::STRING AS tier,
    PAYLOAD:udf_fields:udf_environment::STRING AS environment,
    PAYLOAD:udf_fields:udf_support_group::STRING AS support_group
  FROM RAW_SDP_ASSETS
),
rel AS (SELECT DISTINCT ci_name FROM SDP_CI_RELATIONSHIPS),
cfg AS (SELECT demo_end_date FROM REF_DEMO_CONFIG)
SELECT a.*,
  (rel.ci_name IS NOT NULL) AS has_ci_relationship,
  (lm.hostname IS NOT NULL) AS is_monitored_in_logicmonitor,
  ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(
      IFF(a.owner_email IS NULL, 'owner', NULL),
      IFF(a.support_group IS NULL, 'support_group', NULL),
      IFF(a.environment IS NULL, 'environment', NULL),
      IFF(a.site IS NULL, 'site', NULL),
      IFF(a.os IS NULL, 'os', NULL),
      IFF(a.asset_type = 'Server' AND rel.ci_name IS NULL, 'ci_relationship', NULL)), ', ') AS missing_fields,
  (missing_fields = '') AS is_cmdb_complete,
  (a.last_scan_at < DATEADD(day, -30, cfg.demo_end_date)) AS is_stale_scan,
  los.end_of_support_date AS os_end_of_support_date,
  ldb.end_of_support_date AS db_end_of_support_date,
  lhw.end_of_support_date AS hardware_end_of_support_date,
  LEAST(COALESCE(los.end_of_support_date, '9999-12-31'::DATE),
        COALESCE(ldb.end_of_support_date, '9999-12-31'::DATE),
        COALESCE(lhw.end_of_support_date, '9999-12-31'::DATE)) AS earliest_end_of_support_date,
  NULLIF(ARRAY_TO_STRING(ARRAY_CONSTRUCT_COMPACT(
      IFF(los.end_of_support_date < cfg.demo_end_date, a.os, NULL),
      IFF(ldb.end_of_support_date < cfg.demo_end_date, a.db_engine, NULL),
      IFF(lhw.end_of_support_date < cfg.demo_end_date, a.product, NULL)), ', '), '') AS end_of_support_components,
  (earliest_end_of_support_date < cfg.demo_end_date) AS is_end_of_support,
  (earliest_end_of_support_date BETWEEN cfg.demo_end_date AND DATEADD(month, 12, cfg.demo_end_date)) AS is_eos_within_12m,
  (a.warranty_expiry_date < cfg.demo_end_date) AS is_warranty_expired,
  ROUND(DATEDIFF(day, a.acquired_date, cfg.demo_end_date) / 365.25, 1) AS age_years,
  CASE WHEN DATEDIFF(day, a.acquired_date, cfg.demo_end_date) < 365 THEN '0-1y'
       WHEN DATEDIFF(day, a.acquired_date, cfg.demo_end_date) < 1095 THEN '1-3y'
       WHEN DATEDIFF(day, a.acquired_date, cfg.demo_end_date) < 1826 THEN '3-5y'
       ELSE '5y+' END AS age_band
FROM a
CROSS JOIN cfg
LEFT JOIN rel ON rel.ci_name = a.hostname
LEFT JOIN (SELECT DISTINCT hostname FROM LM_DEVICES) lm ON lm.hostname = a.hostname
LEFT JOIN REF_PRODUCT_LIFECYCLE los ON los.product_name = a.os
LEFT JOIN REF_PRODUCT_LIFECYCLE ldb ON ldb.product_name = a.db_engine
LEFT JOIN REF_PRODUCT_LIFECYCLE lhw ON lhw.product_name = a.product;

CREATE OR REPLACE VIEW DIM_CI COMMENT = 'Conformed configuration item / host dimension across SDP CMDB, LogicMonitor and Defender (hostname key)' AS
SELECT COALESCE(s.hostname, l.hostname) AS hostname,
       COALESCE(s.asset_type, 'Network Device') AS ci_type,
       COALESCE(s.application, l.application) AS application,
       COALESCE(s.tier, l.tier) AS tier,
       COALESCE(s.environment, l.environment) AS environment,
       COALESCE(s.os, l.os) AS os,
       s.db_engine, s.support_group, s.owner_email, s.site, s.asset_state,
       s.is_end_of_support, s.end_of_support_components,
       (s.hostname IS NOT NULL) AS in_servicedesk_plus,
       (l.hostname IS NOT NULL) AS in_logicmonitor
FROM (SELECT * FROM SDP_ASSETS) s
FULL OUTER JOIN LM_DEVICES l ON l.hostname = s.hostname;

CREATE OR REPLACE TABLE DIM_DATE AS
SELECT d AS calendar_date, DATE_TRUNC('week', d) AS week_start, DATE_TRUNC('month', d) AS month_start,
       DATE_TRUNC('quarter', d) AS quarter_start, DAYNAME(d) AS day_name, DAYOFWEEKISO(d) >= 6 AS is_weekend
FROM (SELECT DATEADD(day, SEQ4(), (SELECT DATEADD(day, -400, demo_end_date) FROM REF_DEMO_CONFIG)) AS d
      FROM TABLE(GENERATOR(ROWCOUNT => 431)));

-- ============================================================================
-- KPI helper views
-- ============================================================================
CREATE OR REPLACE VIEW CMDB_RECONCILIATION COMMENT = 'Hosts present in SDP CMDB vs LogicMonitor (coverage gaps)' AS
SELECT hostname, ci_type, application, tier, in_servicedesk_plus, in_logicmonitor,
       CASE WHEN in_servicedesk_plus AND NOT in_logicmonitor THEN 'In SDP, not monitored in LogicMonitor'
            WHEN in_logicmonitor AND NOT in_servicedesk_plus THEN 'Monitored in LogicMonitor, missing from SDP CMDB'
            ELSE 'Matched' END AS reconciliation_status
FROM DIM_CI
WHERE ci_type <> 'Workstation';

CREATE OR REPLACE VIEW CHANGE_ALERT_CORRELATION COMMENT = 'For each SDP change: LogicMonitor alerts and SDP incidents on the same CI (and CIs that depend on it) 48h before vs 48h after the change start' AS
WITH scope AS (
  SELECT c.change_id, c.ci_name AS ci_name FROM SDP_CHANGES c
  UNION
  SELECT c.change_id, r.ci_name FROM SDP_CHANGES c
  JOIN SDP_CI_RELATIONSHIPS r ON r.related_ci_name = c.ci_name AND r.relationship_type = 'Depends on'
)
SELECT c.change_id, c.change_number, c.title, c.change_type, c.risk, c.closure_code, c.is_failed_change,
       c.scheduled_start_at, c.change_date, c.ci_name, c.owner_name, c.support_group, c.cab_approval, c.backout_plan_tested,
       COUNT(DISTINCT s.ci_name) AS cis_in_scope,
       COUNT(DISTINCT IFF(a.started_at BETWEEN DATEADD(hour, -48, c.scheduled_start_at) AND c.scheduled_start_at, a.alert_id, NULL)) AS alerts_48h_before,
       COUNT(DISTINCT IFF(a.started_at BETWEEN c.scheduled_start_at AND DATEADD(hour, 48, c.scheduled_start_at), a.alert_id, NULL)) AS alerts_48h_after,
       COUNT(DISTINCT IFF(a.severity = 'Critical' AND a.started_at BETWEEN c.scheduled_start_at AND DATEADD(hour, 48, c.scheduled_start_at), a.alert_id, NULL)) AS critical_alerts_48h_after,
       COUNT(DISTINCT IFF(q.created_at BETWEEN c.scheduled_start_at AND DATEADD(hour, 48, c.scheduled_start_at), q.request_id, NULL)) AS incidents_48h_after
FROM SDP_CHANGES c
JOIN scope s ON s.change_id = c.change_id
LEFT JOIN LM_ALERTS a ON a.hostname = s.ci_name
  AND a.started_at BETWEEN DATEADD(hour, -48, c.scheduled_start_at) AND DATEADD(hour, 48, c.scheduled_start_at)
LEFT JOIN SDP_REQUESTS q ON q.ci_name = s.ci_name AND q.request_type = 'Incident'
  AND q.created_at BETWEEN c.scheduled_start_at AND DATEADD(hour, 48, c.scheduled_start_at)
GROUP BY ALL;

CREATE OR REPLACE VIEW TECHNICIAN_WORKLOAD COMMENT = 'Per technician: SDP tickets, worklog hours, Smartsheet projects (where is staff time going)' AS
WITH t AS (SELECT user_email, full_name, support_group, low_ticket_usage FROM DIM_USER WHERE is_technician),
req AS (
  SELECT technician_email, COUNT(*) AS tickets_assigned,
         COUNT_IF(is_open) AS open_tickets,
         COUNT_IF(priority_code IN ('P1','P2')) AS p1_p2_tickets,
         COUNT_IF(is_sla_breached AND resolved_at IS NOT NULL) AS sla_breaches,
         COUNT_IF(resolved_at IS NOT NULL) AS resolved_tickets,
         COUNT_IF(is_fcr) AS fcr_tickets
  FROM SDP_REQUESTS GROUP BY 1
),
wl AS (SELECT technician_email, SUM(hours_spent) AS ticket_hours FROM SDP_WORKLOGS GROUP BY 1),
pr AS (
  SELECT assigned_to_email, COUNT(*) AS projects_assigned, COUNT_IF(NOT is_complete) AS active_projects,
         COUNT_IF(is_late) AS late_projects, SUM(actual_hours) AS project_hours
  FROM PROJECTS GROUP BY 1
)
SELECT t.user_email AS technician_email, t.full_name AS technician_name, t.support_group, t.low_ticket_usage,
       COALESCE(req.tickets_assigned, 0) AS tickets_assigned, COALESCE(req.open_tickets, 0) AS open_tickets,
       COALESCE(req.p1_p2_tickets, 0) AS p1_p2_tickets, COALESCE(req.sla_breaches, 0) AS sla_breaches,
       ROUND(100 * req.sla_breaches / NULLIF(req.resolved_tickets, 0), 1) AS sla_breach_pct,
       ROUND(100 * req.fcr_tickets / NULLIF(req.resolved_tickets, 0), 1) AS fcr_pct,
       COALESCE(wl.ticket_hours, 0) AS ticket_hours,
       COALESCE(pr.projects_assigned, 0) AS projects_assigned, COALESCE(pr.active_projects, 0) AS active_projects,
       COALESCE(pr.late_projects, 0) AS late_projects, COALESCE(pr.project_hours, 0) AS project_hours,
       COALESCE(wl.ticket_hours, 0) + COALESCE(pr.project_hours, 0) AS total_tracked_hours
FROM t
LEFT JOIN req ON req.technician_email = t.user_email
LEFT JOIN wl ON wl.technician_email = t.user_email
LEFT JOIN pr ON pr.assigned_to_email = t.user_email;

CREATE OR REPLACE VIEW LICENSE_UTILIZATION COMMENT = 'Microsoft 365 license utilization and annual waste per SKU (active = activity in last 30 days)' AS
WITH active AS (
  SELECT f.value::STRING AS sku_part_number, COUNT(*) AS assigned_users, COUNT_IF(u.is_active_30d) AS active_users
  FROM M365_USER_ACTIVITY u, LATERAL FLATTEN(u.sku_part_numbers) f
  GROUP BY 1
)
SELECT s.sku_part_number, s.sku_display_name, s.prepaid_units, s.consumed_units,
       COALESCE(a.assigned_users, s.consumed_units) AS assigned_users,
       COALESCE(a.active_users, s.consumed_units) AS active_users,
       s.prepaid_units - COALESCE(a.active_users, s.consumed_units) AS unused_seats,
       s.prepaid_units - s.consumed_units AS unassigned_seats,
       ROUND(100 * COALESCE(a.active_users, s.consumed_units) / NULLIF(s.prepaid_units, 0), 1) AS utilization_pct,
       s.monthly_price_usd,
       ROUND((s.prepaid_units - COALESCE(a.active_users, s.consumed_units)) * s.monthly_price_usd * 12, 0) AS annual_waste_usd
FROM M365_SKUS s
LEFT JOIN active a ON a.sku_part_number = s.sku_part_number;

CREATE OR REPLACE VIEW AI_ADOPTION_MONTHLY COMMENT = 'Monthly AI adoption by department: Copilot and AI gateway active users vs employees' AS
WITH months AS (SELECT DISTINCT usage_month AS m FROM M365_COPILOT_USAGE),
emp AS (SELECT department, COUNT(*) AS employees FROM DIM_USER WHERE account_type <> 'Service Account' GROUP BY 1),
act AS (
  SELECT x.m, x.user_email, x.channel, u.department
  FROM (
    SELECT c.usage_month AS m, c.user_email, 'copilot' AS channel FROM M365_COPILOT_USAGE c WHERE c.is_active_in_month
    UNION
    SELECT request_month, user_email, 'gateway' FROM AI_GATEWAY_REQUESTS
  ) x JOIN DIM_USER u ON u.user_email = x.user_email
)
SELECT months.m AS usage_month, emp.department, emp.employees,
       COUNT(DISTINCT IFF(act.channel = 'copilot', act.user_email, NULL)) AS copilot_active_users,
       COUNT(DISTINCT IFF(act.channel = 'gateway', act.user_email, NULL)) AS gateway_active_users,
       COUNT(DISTINCT act.user_email) AS ai_active_users,
       ROUND(100 * COUNT(DISTINCT act.user_email) / emp.employees, 1) AS ai_adoption_pct
FROM months CROSS JOIN emp
LEFT JOIN act ON act.m = months.m AND act.department = emp.department
GROUP BY 1, 2, 3;

CREATE OR REPLACE VIEW COST_PER_USER_MONTHLY COMMENT = 'Monthly technology cost per active user by department: M365 license cost + AI gateway spend' AS
WITH lic AS (
  SELECT u.department, SUM(p.monthly_price_usd) AS license_cost_usd, COUNT(DISTINCT u.user_email) AS licensed_users,
         COUNT(DISTINCT IFF(u.is_active_30d, u.user_email, NULL)) AS active_users
  FROM M365_USER_ACTIVITY u, LATERAL FLATTEN(u.sku_part_numbers) f
  JOIN REF_LICENSE_PRICES p ON p.sku_part_number = f.value::STRING
  GROUP BY 1
),
ai AS (SELECT department, request_month, SUM(cost_usd) AS ai_cost_usd FROM AI_GATEWAY_REQUESTS GROUP BY 1, 2)
SELECT ai.request_month AS cost_month, lic.department, lic.licensed_users, lic.active_users,
       ROUND(lic.license_cost_usd, 2) AS license_cost_usd, ROUND(COALESCE(ai.ai_cost_usd, 0), 2) AS ai_cost_usd,
       ROUND((lic.license_cost_usd + COALESCE(ai.ai_cost_usd, 0)) / NULLIF(lic.active_users, 0), 2) AS cost_per_active_user_usd
FROM lic JOIN ai ON ai.department = lic.department;

CREATE OR REPLACE VIEW FABRIC_DATA_FRESHNESS COMMENT = 'Daily freshness of the Fabric CDW gold layer at 08:00 UTC (hours since last successful PL_Silver_To_Gold)' AS
WITH d AS (SELECT calendar_date FROM DIM_DATE WHERE calendar_date BETWEEN (SELECT demo_start_date + 1 FROM REF_DEMO_CONFIG) AND (SELECT demo_end_date - 1 FROM REF_DEMO_CONFIG)),
ok AS (SELECT ended_at FROM FABRIC_JOB_RUNS WHERE item_name = 'PL_Silver_To_Gold' AND is_success)
SELECT d.calendar_date,
       MAX(ok.ended_at) AS last_successful_gold_load_at,
       ROUND(DATEDIFF(minute, MAX(ok.ended_at), DATEADD(hour, 8, d.calendar_date::TIMESTAMP_NTZ)) / 60.0, 1) AS gold_staleness_hours,
       DATEDIFF(minute, MAX(ok.ended_at), DATEADD(hour, 8, d.calendar_date::TIMESTAMP_NTZ)) > 24 * 60 AS is_stale
FROM d LEFT JOIN ok ON ok.ended_at <= DATEADD(hour, 8, d.calendar_date::TIMESTAMP_NTZ)
GROUP BY 1;

-- ============================================================================
-- Unified event timeline (for "trace what happened" questions)
-- One row per event across every source, with common actor / host / ip columns.
-- ============================================================================
CREATE OR REPLACE VIEW EVENT_TIMELINE COMMENT = 'Unified cross-source event timeline: SDP changes and incidents, LogicMonitor alerts, Fabric job failures, Entra sign-ins and audits, Azure activity, Defender, Sentinel, Fabric warehouse and Power BI activity' AS
SELECT scheduled_start_at AS event_at, 'ManageEngine SDP' AS source_system, 'IT Operations' AS domain,
       'Change' AS event_type, change_type || ' change ' || change_number || ': ' || title AS event_summary,
       IFF(is_failed_change, 'High', IFF(risk = 'High', 'Medium', 'Low')) AS severity,
       owner_email AS actor, ci_name AS host, NULL AS ip_address, 'Closure: ' || COALESCE(closure_code, 'n/a') AS detail
FROM SDP_CHANGES
UNION ALL
SELECT created_at, 'ManageEngine SDP', IFF(category = 'Security', 'Security', 'IT Operations'),
       'Incident', priority_code || ' request ' || request_number || ': ' || subject,
       CASE priority_code WHEN 'P1' THEN 'High' WHEN 'P2' THEN 'Medium' ELSE 'Low' END,
       requester_email, ci_name, NULL, 'Group: ' || support_group || '; status: ' || status
FROM SDP_REQUESTS WHERE request_type = 'Incident' AND (priority_code IN ('P1','P2') OR category = 'Security')
UNION ALL
SELECT started_at, 'LogicMonitor', 'IT Operations', 'Monitoring Alert',
       severity || ' ' || datasource || '/' || datapoint || ' on ' || hostname,
       IFF(severity = 'Critical', 'High', IFF(severity = 'Error', 'Medium', 'Low')),
       NULL, hostname, NULL, 'Duration ' || duration_minutes || ' min; acked: ' || is_acked
FROM LM_ALERTS WHERE severity IN ('Critical','Error') AND NOT is_noise
UNION ALL
SELECT started_at, 'Microsoft Fabric', 'Data Platform', 'Fabric Job ' || status,
       job_type || ' ' || item_name || ' (' || invoke_type || ') ' || status,
       IFF(status = 'Failed', 'High', 'Medium'), NULL,
       IFF(item_name = 'PL_JDE_Ingest_Nightly', 'FABRIC-GW01', NULL), NULL, COALESCE(error_code || ': ' || error_message, '')
FROM FABRIC_JOB_RUNS WHERE status <> 'Completed' OR invoke_type = 'Manual'
UNION ALL
SELECT signin_at, 'Microsoft Entra ID', 'Security', IFF(is_success, 'Sign-in Success', 'Sign-in Failure'),
       app_name || ' sign-in by ' || user_email || ' from ' || ip_address || ' (' || country || ')',
       IFF(risk_level IN ('medium','high'), 'High', IFF(is_success, 'Low', 'Medium')),
       user_email, NULL, ip_address,
       authentication_requirement || '; CA ' || conditional_access_status || COALESCE('; ' || failure_reason, '')
FROM ENTRA_SIGNINS WHERE risk_level IN ('medium','high') OR country NOT IN ('US','CA','GB') OR (user_email LIKE 'svc\\_%' AND ip_address NOT LIKE '20.48.%')
UNION ALL
SELECT activity_at, 'Microsoft Entra ID', 'Security', 'Directory Audit', activity || ' on ' || target_name,
       IFF(category = 'ApplicationManagement', 'High', 'Low'), initiated_by_email, NULL, initiated_from_ip, result
FROM ENTRA_AUDITS WHERE category = 'ApplicationManagement' OR activity ILIKE '%conditional access%'
UNION ALL
SELECT activity_at, 'Azure Activity', 'Security', 'Azure Control Plane', operation || ' on ' || resource_name,
       'High', caller_email, resource_name, caller_ip, resource_group || ' ' || status
FROM AZURE_ACTIVITY WHERE is_sensitive_operation
UNION ALL
SELECT alert_at, 'Microsoft Defender XDR', 'Security', 'Endpoint Alert', title || ' on ' || device_name,
       severity, account_upn, device_name, remote_ip, category || ' ' || attack_techniques || COALESCE('; ' || process_command_line, '')
FROM DEFENDER_ALERTS WHERE severity IN ('High','Medium')
UNION ALL
SELECT created_at, 'Microsoft Sentinel', 'Security', 'SIEM Incident', 'Incident #' || incident_number || ': ' || title,
       severity, owner, NULL, NULL, status || ' / ' || COALESCE(classification, 'unclassified') || COALESCE(' - ' || classification_comment, '')
FROM SENTINEL_INCIDENTS WHERE severity IN ('High','Medium')
UNION ALL
SELECT started_at, 'Microsoft Fabric', 'Security', 'Warehouse Query', 'WH_CDW_Gold query by ' || login_name || ' returned ' || row_count || ' rows',
       IFF(row_count > 1000000, 'High', 'Medium'), login_name, 'WH_CDW_GOLD', NULL, LEFT(command_text, 200)
FROM FABRIC_WAREHOUSE_QUERIES WHERE row_count > 500000 AND login_name NOT IN ('svc_fabric_etl@tacdemo.com')
UNION ALL
SELECT event_at, 'Power BI', 'Security', 'Power BI Export', 'Export of ' || report_name || ' (' || export_type || ') by ' || user_email,
       IFF(exported_rows > 10000, 'High', 'Low'), user_email, NULL, client_ip, exported_rows || ' rows via ' || consumption_method
FROM POWERBI_ACTIVITY WHERE is_export AND (exported_rows > 10000 OR client_ip NOT LIKE '203.0.113.%');

SELECT 'gold_views' AS step,
  (SELECT COUNT(*) FROM SDP_ASSETS) AS assets,
  (SELECT ROUND(100 * AVG(IFF(is_cmdb_complete, 1, 0)), 1) FROM SDP_ASSETS) AS cmdb_complete_pct,
  (SELECT COUNT_IF(is_end_of_support) FROM SDP_ASSETS WHERE asset_state = 'In Use') AS eos_in_use,
  (SELECT COUNT(*) FROM EVENT_TIMELINE) AS timeline_events;
