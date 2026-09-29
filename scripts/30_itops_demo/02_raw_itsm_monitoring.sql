-- ============================================================================
-- 30_itops_demo/02_raw_itsm_monitoring.sql
-- RAW landing tables (native API JSON shape) for:
--   ManageEngine ServiceDesk Plus (requests, history, worklogs, changes,
--   assets, CI relationships, software licenses)
--   LogicMonitor (devices, alerts, daily datapoint roll-ups)
--   Smartsheet (IT PMO portfolio sheet)
-- Baseline data only. Storyline events are added by 05_inject_scenarios.sql.
-- Requires 01_seed_reference_data.sql. Re-runnable.
-- ============================================================================

USE ROLE cortex_role;
USE WAREHOUSE cortex_wh;
USE SCHEMA COWORK.IT_OPS;

SET demo_start = (SELECT demo_start_date FROM REF_DEMO_CONFIG);
SET demo_end   = (SELECT demo_end_date FROM REF_DEMO_CONFIG);

-- SDP v3 datetime object: {"value": "<epoch ms>", "display_value": "..."}
CREATE OR REPLACE FUNCTION SDP_DT(ts TIMESTAMP_NTZ)
RETURNS OBJECT
AS $$
  IFF(ts IS NULL, NULL,
      OBJECT_CONSTRUCT('value', TO_VARCHAR(DATE_PART(epoch_millisecond, ts)),
                       'display_value', TO_VARCHAR(ts, 'Mon DD, YYYY HH12:MI AM')))
$$;

-- Technician lookup: group index k in (0..5); technicians are person_idx = k + 6*j
CREATE OR REPLACE TEMPORARY TABLE TMP_GROUPS AS
SELECT column1 AS support_group, column2 AS k, column3 AS n_techs FROM VALUES
  ('Business Applications',0,7),('Service Desk',1,7),('Infrastructure',2,7),
  ('Network',3,7),('Security',4,6),('Cloud Platform',5,6);

-- ============================================================================
-- SDP REQUESTS
-- ============================================================================
CREATE OR REPLACE TEMPORARY TABLE TMP_REQ AS
WITH g AS (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 3000))),
b AS (
  SELECT
    i,
    DATEADD(minute, 420 + FLOOR(R(i,'min') * 600),
            DATEADD(day, FLOOR(R(i,'day') * 180), $demo_start)::TIMESTAMP_NTZ) AS created_at,
    CASE WHEN R(i,'pri') < 0.02 THEN 'Urgent' WHEN R(i,'pri') < 0.15 THEN 'High'
         WHEN R(i,'pri') < 0.60 THEN 'Medium' ELSE 'Low' END AS priority,
    ARRAY_CONSTRUCT('Hardware','Software','Network','Access Management','Email','JD Edwards',
                    'OneStream','Printing','Security','Microsoft Fabric / Power BI')[(FLOOR(R(i,'cat') * 10))::INT]::STRING AS category,
    IFF(R(i,'type') < 0.75, 'Incident', 'Service Request') AS request_type,
    ARRAY_CONSTRUCT('E-Mail','E-Mail','E-Mail','Web Form','Web Form','Phone Call','Chat')[(FLOOR(R(i,'mode') * 7))::INT]::STRING AS mode,
    40 + FLOOR(R(i,'req') * 600) AS requester_idx,
    CASE WHEN R(i,'ra') < 0.70 THEN 0 WHEN R(i,'ra') < 0.90 THEN 1 ELSE 2 END AS reassignment_count,
    (R(i,'reopen') < 0.05) AS is_reopened
  FROM g
),
grp AS (
  SELECT b.*,
    CASE category
      WHEN 'JD Edwards' THEN 'Business Applications' WHEN 'OneStream' THEN 'Business Applications'
      WHEN 'Network' THEN 'Network' WHEN 'Email' THEN 'Infrastructure' WHEN 'Security' THEN 'Security'
      WHEN 'Microsoft Fabric / Power BI' THEN 'Cloud Platform' ELSE 'Service Desk' END AS support_group
  FROM b
),
tech AS (
  SELECT grp.*, t.k, t.n_techs,
    -- Jordan Patel (idx 0) takes ~35% of Business Applications work
    CASE WHEN grp.support_group = 'Business Applications' AND R(i,'jordan') < 0.35 THEN 0
         ELSE FLOOR(R(i,'tech') * t.n_techs) END AS j0
  FROM grp JOIN TMP_GROUPS t ON t.support_group = grp.support_group
),
tech2 AS (
  SELECT tech.*,
    -- Low-ticket-usage technicians (last j in each group): 80% of their tickets go elsewhere
    IFF(j0 = n_techs - 1 AND R(i,'lowuse') < 0.8, FLOOR(R(i,'tech2') * (n_techs - 1)), j0) AS j
  FROM tech
)
SELECT
  t.*,
  t.k + 6 * t.j AS technician_idx,
  s.priority_code,
  s.first_response_hours,
  s.resolution_hours,
  DATEADD(minute, s.resolution_hours * 60, t.created_at) AS due_by_at,
  DATEADD(minute, s.first_response_hours * 60, t.created_at) AS first_response_due_at,
  -- SLA breach: 10% baseline, 30% for Jordan, 15% for P1
  (R(t.i,'breach') < CASE WHEN t.k + 6 * t.j = 0 THEN 0.30 WHEN s.priority_code = 'P1' THEN 0.15 ELSE 0.09 END) AS will_breach,
  -- Open backlog: 25% of the last 21 days, plus a small tail of stale tickets
  ((t.created_at >= DATEADD(day, -21, $demo_end) AND R(t.i,'open') < 0.25)
    OR (t.created_at < DATEADD(day, -30, $demo_end) AND R(t.i,'open') < 0.012)) AS is_open
FROM tech2 t
JOIN REF_SLA_TARGETS s ON s.priority = t.priority;

CREATE OR REPLACE TEMPORARY TABLE TMP_REQ2 AS
SELECT r.*,
  IFF(is_open, NULL,
      DATEADD(minute,
              FLOOR(resolution_hours * 60 * IFF(will_breach, 1.1 + R(i,'rt') * 1.5, 0.08 + R(i,'rt') * 0.85)),
              created_at)) AS resolved_at,
  DATEADD(minute, FLOOR(first_response_hours * 60 * IFF(R(i,'fr') < 0.06, 1.2 + R(i,'fr2'), 0.1 + R(i,'fr2') * 0.8)), created_at) AS responded_at,
  (NOT is_open AND reassignment_count = 0 AND NOT is_reopened AND R(i,'fcr') < 0.92) AS is_fcr,
  CASE category
    WHEN 'JD Edwards' THEN ARRAY_CONSTRUCT('JDE-APP01','JDE-APP02','JDE-APP03','JDE-WEB01','JDE-SQL01','JDE-BATCH01')[(FLOOR(R(i,'ci') * 6))::INT]::STRING
    WHEN 'OneStream' THEN ARRAY_CONSTRUCT('ONESTREAM-APP01','ONESTREAM-APP02','ONESTREAM-SQL01')[(FLOOR(R(i,'ci') * 3))::INT]::STRING
    WHEN 'Network' THEN 'VPN-GW01'
    WHEN 'Email' THEN 'EXCH-HYB01'
    WHEN 'Printing' THEN 'PRINT01'
    WHEN 'Microsoft Fabric / Power BI' THEN IFF(R(i,'ci') < 0.5, 'FABRIC-GW01', NULL)
    WHEN 'Hardware' THEN 'WS-' || LPAD(requester_idx + 1, 4, '0')
    ELSE NULL END AS ci_name,
  CASE category
    WHEN 'Hardware' THEN ARRAY_CONSTRUCT('Laptop will not power on','Docking station not detecting monitors','Need an external monitor','Keyboard not working')[(FLOOR(R(i,'sub') * 4))::INT]::STRING
    WHEN 'Software' THEN ARRAY_CONSTRUCT('Install Visio','Excel crashes on open','Teams not signing in','Adobe Acrobat license request')[(FLOOR(R(i,'sub') * 4))::INT]::STRING
    WHEN 'Network' THEN ARRAY_CONSTRUCT('VPN disconnects frequently','Wi-Fi slow in Denver office','Cannot reach file share over VPN')[(FLOOR(R(i,'sub') * 3))::INT]::STRING
    WHEN 'Access Management' THEN ARRAY_CONSTRUCT('Password reset','MFA device replacement','Access to Finance SharePoint','New hire account setup')[(FLOOR(R(i,'sub') * 4))::INT]::STRING
    WHEN 'Email' THEN ARRAY_CONSTRUCT('Shared mailbox access','Emails stuck in outbox','Distribution list change')[(FLOOR(R(i,'sub') * 3))::INT]::STRING
    WHEN 'JD Edwards' THEN ARRAY_CONSTRUCT('JDE report running slowly','JDE login error','JDE batch job failed','JDE role change request')[(FLOOR(R(i,'sub') * 4))::INT]::STRING
    WHEN 'OneStream' THEN ARRAY_CONSTRUCT('OneStream consolidation error','OneStream access request','OneStream data load mismatch')[(FLOOR(R(i,'sub') * 3))::INT]::STRING
    WHEN 'Printing' THEN ARRAY_CONSTRUCT('Printer offline','Print queue stuck','Add printer')[(FLOOR(R(i,'sub') * 3))::INT]::STRING
    WHEN 'Security' THEN ARRAY_CONSTRUCT('Suspicious email reported','Phishing link clicked','Lost laptop')[(FLOOR(R(i,'sub') * 3))::INT]::STRING
    ELSE ARRAY_CONSTRUCT('Power BI report not refreshing','Request access to Fabric workspace','Power BI dataset error','New Power BI report request')[(FLOOR(R(i,'sub') * 4))::INT]::STRING
  END AS subject
FROM TMP_REQ r;

CREATE OR REPLACE TABLE RAW_SDP_REQUESTS (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_SDP_REQUESTS
SELECT OBJECT_CONSTRUCT(
    'id', TO_VARCHAR(2079997950000000 + r.i),
    'display_id', TO_VARCHAR(10000 + r.i),
    'subject', r.subject,
    'request_type', OBJECT_CONSTRUCT('name', r.request_type),
    'priority', OBJECT_CONSTRUCT('name', r.priority),
    'category', OBJECT_CONSTRUCT('name', r.category),
    'mode', OBJECT_CONSTRUCT('name', r.mode),
    'status', OBJECT_CONSTRUCT('name',
        CASE WHEN r.is_open THEN ARRAY_CONSTRUCT('Open','In Progress','On Hold')[(FLOOR(R(r.i,'st') * 3))::INT]::STRING
             WHEN r.resolved_at < DATEADD(day, -3, $demo_end) THEN 'Closed' ELSE 'Resolved' END),
    'group', OBJECT_CONSTRUCT('name', r.support_group),
    'technician', OBJECT_CONSTRUCT('name', t.full_name, 'email_id', t.email),
    'requester', OBJECT_CONSTRUCT('name', q.full_name, 'email_id', q.email, 'is_vip_user', q.department = 'Executive'),
    'department', OBJECT_CONSTRUCT('name', q.department),
    'site', OBJECT_CONSTRUCT('name', q.site),
    'created_time', SDP_DT(r.created_at),
    'first_response_due_by_time', SDP_DT(r.first_response_due_at),
    'responded_time', SDP_DT(r.responded_at),
    'due_by_time', SDP_DT(r.due_by_at),
    'resolved_time', SDP_DT(r.resolved_at),
    'completed_time', SDP_DT(IFF(r.resolved_at < DATEADD(day, -3, $demo_end), DATEADD(day, 3, r.resolved_at), NULL)),
    'is_overdue', IFF(r.is_open, $demo_end::TIMESTAMP_NTZ > r.due_by_at, r.resolved_at > r.due_by_at),
    'is_first_response_overdue', r.responded_at > r.first_response_due_at,
    'is_fcr', r.is_fcr,
    'is_reopened', r.is_reopened,
    'configuration_items', IFF(r.ci_name IS NULL, NULL, ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('name', r.ci_name)))
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM TMP_REQ2 r
JOIN SEED_PEOPLE t ON t.person_idx = r.technician_idx
JOIN SEED_PEOPLE q ON q.person_idx = r.requester_idx;

-- Request history: one ASSIGN operation per reassignment
CREATE OR REPLACE TABLE RAW_SDP_REQUEST_HISTORY (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_SDP_REQUEST_HISTORY
SELECT OBJECT_CONSTRUCT(
    'request_id', TO_VARCHAR(2079997950000000 + r.i),
    'id', TO_VARCHAR(3000000000 + r.i * 10 + n.n),
    'operation', 'ASSIGN',
    'time', SDP_DT(DATEADD(minute, 20 + n.n * 90, r.created_at)),
    'by', OBJECT_CONSTRUCT('name', 'Auto Assign'),
    'diff', OBJECT_CONSTRUCT('group',
        OBJECT_CONSTRUCT('old', OBJECT_CONSTRUCT('name', IFF(n.n = 0, 'Service Desk', r.support_group)),
                         'new', OBJECT_CONSTRUCT('name', r.support_group)))
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM TMP_REQ2 r
JOIN (SELECT SEQ4() AS n FROM TABLE(GENERATOR(ROWCOUNT => 2))) n ON n.n < r.reassignment_count;

-- Worklogs: 1-3 per resolved request; P1/P2 take longer
CREATE OR REPLACE TABLE RAW_SDP_WORKLOGS (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_SDP_WORKLOGS
WITH w AS (
  SELECT r.i, r.created_at, r.technician_idx, n.n,
    FLOOR(CASE r.priority_code WHEN 'P1' THEN 90 WHEN 'P2' THEN 60 WHEN 'P3' THEN 35 ELSE 20 END
          * (0.4 + R(r.i * 7 + n.n,'mins') * 1.6)) AS mins
  FROM TMP_REQ2 r
  JOIN (SELECT SEQ4() AS n FROM TABLE(GENERATOR(ROWCOUNT => 3))) n
    ON n.n < 1 + FLOOR(R(r.i,'wl') * 3)
  WHERE r.resolved_at IS NOT NULL OR n.n = 0
)
SELECT OBJECT_CONSTRUCT(
    'request_id', TO_VARCHAR(2079997950000000 + w.i),
    'id', TO_VARCHAR(4000000000 + w.i * 10 + w.n),
    'owner', OBJECT_CONSTRUCT('name', t.full_name, 'email_id', t.email),
    'worklog_type', OBJECT_CONSTRUCT('name', IFF(w.n = 0, 'Troubleshooting', 'Follow-up')),
    'start_time', SDP_DT(DATEADD(minute, 30 + w.n * 120, w.created_at)),
    'end_time', SDP_DT(DATEADD(minute, 30 + w.n * 120 + w.mins, w.created_at)),
    'time_spent', OBJECT_CONSTRUCT('hours', TO_VARCHAR(FLOOR(w.mins / 60)), 'minutes', TO_VARCHAR(MOD(w.mins, 60)))
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM w
JOIN SEED_PEOPLE t ON t.person_idx = w.technician_idx;

-- ============================================================================
-- SDP CHANGES (200 baseline)
-- ============================================================================
CREATE OR REPLACE TABLE RAW_SDP_CHANGES (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_SDP_CHANGES
WITH c AS (
  SELECT i,
    DATEADD(hour, 19 + FLOOR(R(i,'h') * 5), DATEADD(day, FLOOR(R(i,'d') * 178), $demo_start)::TIMESTAMP_NTZ) AS sched_start,
    CASE WHEN R(i,'type') < 0.45 THEN 'Standard' WHEN R(i,'type') < 0.75 THEN 'Minor'
         WHEN R(i,'type') < 0.92 THEN 'Major' ELSE 'Emergency' END AS change_type,
    CASE WHEN R(i,'cls') < 0.92 THEN 'Success' WHEN R(i,'cls') < 0.97 THEN 'Failed' ELSE 'Rolled Back' END AS closure_code,
    FLOOR(R(i,'srv') * 150) AS server_idx,
    FLOOR(R(i,'own') * 40) AS owner_idx
  FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 200)))
)
SELECT OBJECT_CONSTRUCT(
    'id', TO_VARCHAR(5000000000 + c.i),
    'display_id', TO_VARCHAR(1200 + c.i),
    'title', ARRAY_CONSTRUCT('Monthly Windows patching','Firmware update','Certificate renewal',
                             'Firewall rule change','Application release','Storage expansion',
                             'SQL Server cumulative update','Backup policy change')[(FLOOR(R(c.i,'t') * 8))::INT]::STRING
             || ' - ' || s.hostname,
    'change_type', OBJECT_CONSTRUCT('name', c.change_type),
    'risk', OBJECT_CONSTRUCT('name', CASE c.change_type WHEN 'Major' THEN 'High' WHEN 'Emergency' THEN 'High'
                                                      WHEN 'Minor' THEN 'Medium' ELSE 'Low' END),
    'stage', OBJECT_CONSTRUCT('name', IFF(c.sched_start > $demo_end::TIMESTAMP_NTZ, 'Approval', 'Close')),
    'status', OBJECT_CONSTRUCT('name', IFF(c.sched_start > $demo_end::TIMESTAMP_NTZ, 'Pending Approval', 'Completed')),
    'closure_code', IFF(c.sched_start > $demo_end::TIMESTAMP_NTZ, NULL, OBJECT_CONSTRUCT('name', c.closure_code)),
    'scheduled_start_time', SDP_DT(c.sched_start),
    'scheduled_end_time', SDP_DT(DATEADD(hour, 2, c.sched_start)),
    'completed_time', SDP_DT(IFF(c.sched_start > $demo_end::TIMESTAMP_NTZ, NULL, DATEADD(hour, 2, c.sched_start))),
    'change_owner', OBJECT_CONSTRUCT('name', p.full_name, 'email_id', p.email),
    'group', OBJECT_CONSTRUCT('name', COALESCE(s.support_group, 'Infrastructure')),
    'configuration_items', ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('name', s.hostname))
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM c
JOIN SEED_SERVERS s ON s.server_idx = c.server_idx
JOIN SEED_PEOPLE p ON p.person_idx = c.owner_idx;

-- ============================================================================
-- SDP ASSETS (servers + workstations) and CMDB relationships
-- Missing CMDB attributes are omitted from the payload (OBJECT_CONSTRUCT drops NULLs)
-- ============================================================================
CREATE OR REPLACE TABLE RAW_SDP_ASSETS (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_SDP_ASSETS
SELECT OBJECT_CONSTRUCT(
    'id', TO_VARCHAR(6000000000 + s.server_idx),
    'name', s.hostname,
    'product', OBJECT_CONSTRUCT('name', s.product),
    'product_type', OBJECT_CONSTRUCT('name', 'Server'),
    'state', OBJECT_CONSTRUCT('name', s.asset_state),
    'vendor', OBJECT_CONSTRUCT('name', IFF(s.product LIKE 'Dell%', 'Dell', 'Microsoft Azure')),
    'acquisition_date', SDP_DT(s.acquisition_date::TIMESTAMP_NTZ),
    'warranty_expiry', SDP_DT(DATEADD(year, IFF(s.product LIKE 'Dell%', 5, 50), s.acquisition_date)::TIMESTAMP_NTZ),
    'last_scan_time', SDP_DT(DATEADD(hour, -IFF(s.stale_scan, 24 * (45 + FLOOR(R(s.server_idx,'scan') * 90)), FLOOR(R(s.server_idx,'scan') * 72)), $demo_end::TIMESTAMP_NTZ)),
    'site', OBJECT_CONSTRUCT('name', s.site),
    'operating_system', OBJECT_CONSTRUCT('os', s.os),
    'udf_fields', OBJECT_CONSTRUCT(
        'udf_application', s.application,
        'udf_db_engine', s.db_engine,
        'udf_tier', s.tier,
        'udf_environment', IFF(s.missing_environment, NULL, s.environment),
        'udf_owner', IFF(s.missing_owner, NULL, s.owner_email),
        'udf_support_group', IFF(s.missing_support_group, NULL, s.support_group))
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM SEED_SERVERS s
UNION ALL
SELECT OBJECT_CONSTRUCT(
    'id', TO_VARCHAR(7000000000 + w.ws_idx),
    'name', w.hostname,
    'product', OBJECT_CONSTRUCT('name', w.product),
    'product_type', OBJECT_CONSTRUCT('name', 'Workstation'),
    'state', OBJECT_CONSTRUCT('name', w.asset_state),
    'vendor', OBJECT_CONSTRUCT('name', SPLIT_PART(w.product, ' ', 1)),
    'acquisition_date', SDP_DT(w.acquisition_date::TIMESTAMP_NTZ),
    'warranty_expiry', SDP_DT(DATEADD(year, 3, w.acquisition_date)::TIMESTAMP_NTZ),
    'last_scan_time', SDP_DT(DATEADD(hour, -IFF(w.stale_scan, 24 * (35 + FLOOR(R(w.ws_idx,'scan') * 120)), FLOOR(R(w.ws_idx,'scan') * 96)), $demo_end::TIMESTAMP_NTZ)),
    'user', IFF(w.missing_owner OR w.asset_state IN ('In Store','Disposed'), NULL, OBJECT_CONSTRUCT('email_id', w.user_email)),
    'department', IFF(w.missing_owner, NULL, OBJECT_CONSTRUCT('name', p.department)),
    'site', OBJECT_CONSTRUCT('name', p.site),
    'operating_system', OBJECT_CONSTRUCT('os', w.os),
    'udf_fields', OBJECT_CONSTRUCT('udf_environment', 'Production', 'udf_tier', 'End User',
                                   'udf_support_group', 'Service Desk')
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM SEED_WORKSTATIONS w
JOIN SEED_PEOPLE p ON p.email = w.user_email;

CREATE OR REPLACE TABLE RAW_SDP_CI_RELATIONSHIPS (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_SDP_CI_RELATIONSHIPS
SELECT OBJECT_CONSTRUCT('ci', OBJECT_CONSTRUCT('name', hostname, 'ci_type', 'Server'),
                        'relationship_type', OBJECT_CONSTRUCT('name', 'Runs'),
                        'related_ci', OBJECT_CONSTRUCT('name', application, 'ci_type', 'Business Service')),
       'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM SEED_SERVERS WHERE NOT missing_relationship
UNION ALL
SELECT OBJECT_CONSTRUCT('ci', OBJECT_CONSTRUCT('name', column1, 'ci_type', 'Server'),
                        'relationship_type', OBJECT_CONSTRUCT('name', 'Depends on'),
                        'related_ci', OBJECT_CONSTRUCT('name', column2, 'ci_type', 'Server')),
       'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM VALUES ('JDE-APP01','JDE-SQL01'),('JDE-APP02','JDE-SQL01'),('JDE-APP03','JDE-SQL01'),
            ('JDE-BATCH01','JDE-SQL01'),('JDE-WEB01','JDE-APP01'),('JDE-WEB02','JDE-APP02'),
            ('FABRIC-GW01','JDE-SQL01'),('FABRIC-GW02','ONESTREAM-SQL01'),
            ('ONESTREAM-APP01','ONESTREAM-SQL01'),('ONESTREAM-APP02','ONESTREAM-SQL01');

CREATE OR REPLACE TABLE RAW_SDP_SOFTWARE_LICENSES (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_SDP_SOFTWARE_LICENSES
SELECT OBJECT_CONSTRUCT(
    'software', OBJECT_CONSTRUCT('name', column1), 'manufacturer', OBJECT_CONSTRUCT('name', column2),
    'license_type', OBJECT_CONSTRUCT('name', column3),
    'purchased_licenses', column4, 'allocated_licenses', column5, 'installations', column6,
    'cost', column7, 'expiry_date', SDP_DT(DATEADD(day, column8, $demo_end)::TIMESTAMP_NTZ)),
  'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM VALUES
  ('Adobe Acrobat Pro','Adobe','Named User',180,121,118,43200,120),
  ('AutoCAD LT','Autodesk','Named User',25,9,8,12500,45),
  ('Smartsheet Business','Smartsheet','Named User',60,58,58,14400,200),
  ('Zoom Workplace','Zoom','Named User',120,64,51,17280,30),
  ('Snagit','TechSmith','Perpetual',50,22,19,3000,NULL),
  ('JD Edwards EnterpriseOne','Oracle','Named User',220,214,214,264000,365),
  ('OneStream Platform','OneStream','Named User',80,77,77,96000,300),
  ('Tableau Creator','Salesforce','Named User',15,4,3,10800,60),
  ('LogicMonitor Collector','LogicMonitor','Device',200,166,166,36000,240),
  ('ManageEngine ServiceDesk Plus','Zoho','Technician',45,40,40,13500,150);

-- ============================================================================
-- LOGICMONITOR DEVICES (servers minus unmonitored + 4 network devices not in SDP)
-- ============================================================================
CREATE OR REPLACE TABLE RAW_LM_DEVICES (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_LM_DEVICES
WITH d AS (
  SELECT server_idx AS dev_idx, hostname, os, tier, environment, application FROM SEED_SERVERS WHERE NOT not_in_logicmonitor
  UNION ALL
  SELECT 900 + ROW_NUMBER() OVER (ORDER BY column1), column1, column2, 'Tier 1', 'Production', 'Network Infrastructure'
  FROM VALUES ('CORE-SW01','Cisco NX-OS'),('CORE-SW02','Cisco NX-OS'),('FW-EDGE01','Palo Alto PAN-OS'),('WLC01','Cisco IOS-XE')
)
SELECT OBJECT_CONSTRUCT(
    'id', 1000 + dev_idx,
    'name', hostname,
    'displayName', hostname,
    'deviceType', 0,
    'hostStatus', 'normal',
    'hostGroupIds', CASE WHEN application = 'JD Edwards EnterpriseOne' THEN '12,31'
                         WHEN application = 'Network Infrastructure' THEN '12,40' ELSE '12' END,
    'systemProperties', ARRAY_CONSTRUCT(
        OBJECT_CONSTRUCT('name','system.sysinfo','value', os),
        OBJECT_CONSTRUCT('name','system.categories','value',
            IFF(application = 'Network Infrastructure', 'Network', IFF(os LIKE 'Windows%', 'Windows', 'Linux')))),
    'customProperties', ARRAY_CONSTRUCT(
        OBJECT_CONSTRUCT('name','tac.environment','value', environment),
        OBJECT_CONSTRUCT('name','tac.tier','value', tier),
        OBJECT_CONSTRUCT('name','tac.application','value', application))
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM d;

-- Daily datapoint roll-up per device
CREATE OR REPLACE TABLE RAW_LM_DEVICE_DAILY (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_LM_DEVICE_DAILY
WITH dev AS (
  SELECT PAYLOAD:id::NUMBER AS device_id, PAYLOAD:name::STRING AS hostname FROM RAW_LM_DEVICES
),
days AS (SELECT DATEADD(day, SEQ4(), $demo_start) AS d FROM TABLE(GENERATOR(ROWCOUNT => 180))),
x AS (
  SELECT dev.device_id, dev.hostname, days.d,
    HASH(dev.hostname, days.d) AS h,
    -- ~8 "hot" devices run near capacity
    IFF(R(HASH(dev.hostname),'hot') < 0.055, 72, 12 + R(HASH(dev.hostname),'cpu') * 38) AS cpu_base,
    30 + R(HASH(dev.hostname),'mem') * 45 AS mem_base,
    35 + R(HASH(dev.hostname),'disk') * 45 AS disk_base
  FROM dev CROSS JOIN days
)
SELECT OBJECT_CONSTRUCT(
    'deviceId', device_id,
    'deviceDisplayName', hostname,
    'date', TO_VARCHAR(d, 'YYYY-MM-DD'),
    'datapoints', OBJECT_CONSTRUCT(
      'CPUBusyPercent', OBJECT_CONSTRUCT('avg', ROUND(LEAST(99, cpu_base + R(h,'c') * 8), 1),
                                         'p95', ROUND(LEAST(100, cpu_base + 10 + R(h,'c2') * 18), 1)),
      'MemoryUtilizationPercent', OBJECT_CONSTRUCT('avg', ROUND(LEAST(99, mem_base + R(h,'m') * 6), 1),
                                                   'p95', ROUND(LEAST(100, mem_base + 8 + R(h,'m2') * 12), 1)),
      'DiskUsedPercent', OBJECT_CONSTRUCT('max', ROUND(LEAST(99, disk_base + DATEDIFF(day, $demo_start, d) * 0.03 + R(h,'dk') * 2), 1)),
      'HostStatus', OBJECT_CONSTRUCT('downMinutes', IFF(R(h,'down') < 0.006, 5 + FLOOR(R(h,'dm') * 55), 0)))
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM x;

-- ============================================================================
-- LOGICMONITOR ALERTS (~9,000 baseline). ~55% are short, un-acked flaps (noise).
-- ============================================================================
CREATE OR REPLACE TABLE RAW_LM_ALERTS (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_LM_ALERTS
WITH dev AS (
  SELECT ROW_NUMBER() OVER (ORDER BY PAYLOAD:id::NUMBER) - 1 AS rn, PAYLOAD:id::NUMBER AS device_id,
         PAYLOAD:name::STRING AS hostname, COUNT(*) OVER () AS n
  FROM RAW_LM_DEVICES
),
a AS (
  SELECT i,
    DATEADD(second, FLOOR(R(i,'t') * 180 * 86400), $demo_start::TIMESTAMP_NTZ) AS started_at,
    (R(i,'noise') < 0.55) AS is_flap,
    (R(i,'sdt') < 0.05) AS is_sdt,
    ARRAY_CONSTRUCT('WinCPU','WinMemory','WinVolumeUsage','Ping','WinService','Microsoft_SQLServer_Performance','HostStatus')[(FLOOR(R(i,'ds') * 7))::INT]::STRING AS datasource,
    CASE WHEN R(i,'sev') < 0.60 THEN 2 WHEN R(i,'sev') < 0.90 THEN 3 ELSE 4 END AS severity,
    FLOOR(R(i,'dev') * 1000) AS dev_pick
  FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 9000)))
)
SELECT OBJECT_CONSTRUCT(
    'id', 'LMA' || (500000 + a.i),
    'internalId', 'LMD' || (500000 + a.i),
    'type', 'dataSourceAlert',
    'severity', a.severity,
    'startEpoch', DATE_PART(epoch_second, a.started_at),
    'endEpoch', DATE_PART(epoch_second, DATEADD(minute, IFF(a.is_flap, 1 + FLOOR(R(a.i,'dur') * 13), 20 + FLOOR(R(a.i,'dur') * 580)), a.started_at)),
    'cleared', TRUE,
    'acked', IFF(a.is_flap, FALSE, R(a.i,'ack') < 0.85),
    'sdted', a.is_sdt,
    'monitorObjectName', dev.hostname,
    'monitorObjectId', dev.device_id,
    'resourceTemplateName', a.datasource,
    'instanceName', a.datasource,
    'dataPointName', CASE a.datasource WHEN 'WinCPU' THEN 'CPUBusyPercent' WHEN 'WinMemory' THEN 'MemoryUtilizationPercent'
                        WHEN 'WinVolumeUsage' THEN 'PercentUsed' WHEN 'Ping' THEN 'PingLossPercent'
                        WHEN 'WinService' THEN 'State' WHEN 'HostStatus' THEN 'idleInterval' ELSE 'BatchRequestsPerSec' END,
    'alertValue', TO_VARCHAR(ROUND(80 + R(a.i,'v') * 20, 1)),
    'threshold', '> 80 90 95',
    'rule', 'Default'
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM a JOIN dev ON dev.rn = MOD(a.dev_pick, dev.n);

-- ============================================================================
-- SMARTSHEET: IT PMO Portfolio (one sheet payload with columns + rows/cells)
-- Jordan Patel is assigned 6 projects; 4 run late (storyline 3).
-- ============================================================================
CREATE OR REPLACE TABLE RAW_SMARTSHEET_SHEET (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_SMARTSHEET_SHEET
WITH cols AS (
  SELECT ARRAY_CONSTRUCT(
    OBJECT_CONSTRUCT('id',101,'title','Project Name','type','TEXT_NUMBER','primary',TRUE),
    OBJECT_CONSTRUCT('id',102,'title','Project Manager','type','CONTACT_LIST'),
    OBJECT_CONSTRUCT('id',103,'title','Assigned To','type','CONTACT_LIST'),
    OBJECT_CONSTRUCT('id',104,'title','Start Date','type','DATE'),
    OBJECT_CONSTRUCT('id',105,'title','Due Date','type','DATE'),
    OBJECT_CONSTRUCT('id',106,'title','Actual End Date','type','DATE'),
    OBJECT_CONSTRUCT('id',107,'title','% Complete','type','TEXT_NUMBER'),
    OBJECT_CONSTRUCT('id',108,'title','Status','type','PICKLIST'),
    OBJECT_CONSTRUCT('id',109,'title','Health','type','PICKLIST'),
    OBJECT_CONSTRUCT('id',110,'title','Estimated Hours','type','TEXT_NUMBER'),
    OBJECT_CONSTRUCT('id',111,'title','Actual Hours','type','TEXT_NUMBER')) AS columns
),
p AS (
  SELECT i,
    ARRAY_CONSTRUCT('JDE Security Role Redesign','OneStream Upgrade','Fabric CDW Phase 2','Windows 2012 Decommission',
                    'Endpoint Refresh','SD-WAN Rollout','MFA for Service Accounts','Power BI App Migration',
                    'AI Gateway Pilot','Backup Modernization','ServiceDesk Plus CMDB Cleanup','Teams Phone Rollout',
                    'LogicMonitor Coverage Expansion','Sentinel Use-Case Tuning','Azure Landing Zone')[(MOD(i, 15))::INT]::STRING
      || IFF(i >= 15, ' - Wave ' || (FLOOR(i / 15) + 1), '') AS project_name,
    -- Jordan's four late projects (i < 4) were due 2-8 weeks ago
    IFF(i < 4, DATEADD(day, -(90 + 15 + i * 12), $demo_end),
        DATEADD(day, -FLOOR(30 + R(i,'st') * 360), $demo_end)) AS start_date,
    IFF(i < 4, 90, FLOOR(45 + R(i,'dur') * 150)) AS duration_days,
    IFF(i < 6, 0, 1 + FLOOR(R(i,'asg') * 33)) AS assignee_idx,
    ARRAY_CONSTRUCT(5, 11, 17)[(FLOOR(R(i,'pm') * 3))::INT]::NUMBER AS pm_idx,
    IFF(i < 6, i < 4, R(i,'late') < 0.33) AS is_late,
    FLOOR(80 + R(i,'est') * 520) AS est_hours
  FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 60)))
),
p2 AS (
  SELECT p.*, DATEADD(day, duration_days, start_date) AS due_date,
    DATEADD(day, duration_days, start_date) < $demo_end AS past_due
  FROM p
),
p3 AS (
  SELECT p2.*,
    CASE WHEN past_due AND NOT is_late THEN DATEADD(day, -FLOOR(R(i,'early') * 10), due_date)
         WHEN past_due AND is_late AND R(i,'done') < 0.6 THEN DATEADD(day, 5 + FLOOR(R(i,'lt') * 55), due_date)
         ELSE NULL END AS actual_end
  FROM p2
),
p4 AS (
  SELECT p3.*,
    IFF(actual_end > $demo_end, NULL, actual_end) AS actual_end_date,
    CASE WHEN actual_end IS NOT NULL AND actual_end <= $demo_end THEN 'Complete'
         WHEN start_date > $demo_end THEN 'Not Started'
         WHEN R(i,'hold') < 0.05 THEN 'On Hold' ELSE 'In Progress' END AS status
  FROM p3
)
SELECT OBJECT_CONSTRUCT(
    'id', 7788990011,
    'name', 'IT PMO Portfolio',
    'columns', (SELECT columns FROM cols),
    'rows', ARRAY_AGG(OBJECT_CONSTRUCT(
      'id', 9000000 + p4.i,
      'rowNumber', p4.i + 1,
      'cells', ARRAY_CONSTRUCT(
        OBJECT_CONSTRUCT('columnId',101,'value',p4.project_name),
        OBJECT_CONSTRUCT('columnId',102,'value',pm.email,'displayValue',pm.full_name),
        OBJECT_CONSTRUCT('columnId',103,'value',a.email,'displayValue',a.full_name),
        OBJECT_CONSTRUCT('columnId',104,'value',TO_VARCHAR(p4.start_date,'YYYY-MM-DD')),
        OBJECT_CONSTRUCT('columnId',105,'value',TO_VARCHAR(p4.due_date,'YYYY-MM-DD')),
        OBJECT_CONSTRUCT('columnId',106,'value',TO_VARCHAR(p4.actual_end_date,'YYYY-MM-DD')),
        OBJECT_CONSTRUCT('columnId',107,'value',
            IFF(p4.status = 'Complete', 1,
                ROUND(LEAST(0.95, GREATEST(0, DATEDIFF(day, p4.start_date, $demo_end) / p4.duration_days * IFF(p4.is_late, 0.7, 1.0))), 2))),
        OBJECT_CONSTRUCT('columnId',108,'value',p4.status),
        OBJECT_CONSTRUCT('columnId',109,'value',
            CASE WHEN p4.status = 'Complete' THEN 'Green'
                 WHEN p4.is_late AND p4.past_due THEN 'Red'
                 WHEN p4.is_late THEN 'Yellow' ELSE 'Green' END),
        OBJECT_CONSTRUCT('columnId',110,'value',p4.est_hours),
        OBJECT_CONSTRUCT('columnId',111,'value',
            ROUND(p4.est_hours * IFF(p4.is_late, 1.2 + R(p4.i,'ah') * 0.5, 0.7 + R(p4.i,'ah') * 0.35)
                  * IFF(p4.status = 'Complete', 1, 0.6)))
      )))
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM p4
JOIN SEED_PEOPLE a ON a.person_idx = p4.assignee_idx
JOIN SEED_PEOPLE pm ON pm.person_idx = p4.pm_idx;

SELECT 'raw_itsm_monitoring' AS step,
  (SELECT COUNT(*) FROM RAW_SDP_REQUESTS) AS sdp_requests,
  (SELECT COUNT(*) FROM RAW_SDP_WORKLOGS) AS sdp_worklogs,
  (SELECT COUNT(*) FROM RAW_SDP_CHANGES) AS sdp_changes,
  (SELECT COUNT(*) FROM RAW_SDP_ASSETS) AS sdp_assets,
  (SELECT COUNT(*) FROM RAW_LM_DEVICES) AS lm_devices,
  (SELECT COUNT(*) FROM RAW_LM_ALERTS) AS lm_alerts,
  (SELECT COUNT(*) FROM RAW_LM_DEVICE_DAILY) AS lm_device_days;
