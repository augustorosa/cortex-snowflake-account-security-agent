-- ============================================================================
-- 30_itops_demo/04_raw_fabric_powerbi.sql
-- RAW landing tables (native JSON shape) for the TAC Microsoft Fabric CDW
-- (Corporate Data Warehouse) and Power BI:
--   RAW_FABRIC_ITEMS              Fabric REST  GET /v1/workspaces/{id}/items
--   RAW_FABRIC_JOB_RUNS           Fabric REST  GET /v1/workspaces/{id}/items/{id}/jobs/instances
--                                  (+ Power BI semantic model refresh history)
--   RAW_FABRIC_CAPACITY_METRICS   Fabric Capacity Metrics app (daily per item, CU seconds)
--   RAW_FABRIC_WAREHOUSE_QUERIES  Warehouse queryinsights.exec_requests_history
--   RAW_POWERBI_ACTIVITY          Power BI / Fabric activity events (Get-PowerBIActivityEvent)
-- Data flow modelled: JDE-SQL01 -> FABRIC-GW01 (on-prem data gateway)
--   -> PL_JDE_Ingest_Nightly -> LH_Bronze_JDE -> NB_Silver_Transform_GL -> LH_Silver
--   -> PL_Silver_To_Gold -> WH_CDW_Gold -> SM_Finance_GL / SM_AP_AR -> Finance reports
-- Baseline only; outage / exfiltration events are added by 05_inject_scenarios.sql.
-- Requires 01 and 03 (ISO_TS). Re-runnable.
-- ============================================================================

USE ROLE cortex_role;
USE WAREHOUSE cortex_wh;
USE SCHEMA COWORK.IT_OPS;

SET demo_start = (SELECT demo_start_date FROM REF_DEMO_CONFIG);
SET demo_end   = (SELECT demo_end_date FROM REF_DEMO_CONFIG);

-- ----------------------------------------------------------------------------
-- Items catalog
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE SEED_FABRIC_ITEMS AS
SELECT column1 AS workspace_name, column2 AS item_name, column3 AS item_type,
       column4 AS schedule_minute_utc, column5 AS base_duration_min, column6 AS daily_cu_seconds,
       column7 AS upstream_item, column8 AS description
FROM VALUES
  ('TAC-CDW-Prod','LH_Bronze_JDE','Lakehouse',NULL,NULL,90000,NULL,'Raw JDE F0911/F0411/F03B11 extracts'),
  ('TAC-CDW-Prod','LH_Bronze_OneStream','Lakehouse',NULL,NULL,40000,NULL,'Raw OneStream cube exports'),
  ('TAC-CDW-Prod','LH_Silver','Lakehouse',NULL,NULL,120000,NULL,'Cleansed conformed finance data'),
  ('TAC-CDW-Prod','WH_CDW_Gold','Warehouse',NULL,NULL,520000,NULL,'Gold star schema: fact_gl_journal, fact_ap_invoice, fact_ar_invoice, dim_account, dim_vendor'),
  ('TAC-CDW-Prod','PL_JDE_Ingest_Nightly','DataPipeline',120,30,260000,NULL,'Copy JDE tables via on-prem gateway FABRIC-GW01 from JDE-SQL01'),
  ('TAC-CDW-Prod','PL_OneStream_Ingest','DataPipeline',130,18,110000,NULL,'OneStream export via FABRIC-GW02'),
  ('TAC-CDW-Prod','NB_Silver_Transform_GL','Notebook',170,26,380000,'PL_JDE_Ingest_Nightly','PySpark bronze to silver GL transform'),
  ('TAC-CDW-Prod','PL_Silver_To_Gold','DataPipeline',210,24,300000,'NB_Silver_Transform_GL','Load gold warehouse facts and dimensions'),
  ('TAC-Finance-Reporting','SM_Finance_GL','SemanticModel',255,11,240000,'PL_Silver_To_Gold','GL semantic model (Import) on WH_CDW_Gold'),
  ('TAC-Finance-Reporting','SM_AP_AR','SemanticModel',260,9,160000,'PL_Silver_To_Gold','AP/AR semantic model (Import) on WH_CDW_Gold'),
  ('TAC-Finance-Reporting','SM_Executive_KPI','SemanticModel',270,6,90000,'PL_Silver_To_Gold','Executive KPI model'),
  ('TAC-Finance-Reporting','Finance - GL Summary','Report',NULL,NULL,70000,'SM_Finance_GL','Monthly GL summary and variance'),
  ('TAC-Finance-Reporting','Finance - AP Aging','Report',NULL,NULL,45000,'SM_AP_AR','AP aging by vendor'),
  ('TAC-Finance-Reporting','Executive KPI Dashboard','Report',NULL,NULL,40000,'SM_Executive_KPI','CFO / CEO KPI dashboard'),
  ('TAC-IT-Ops','SM_IT_Ops','SemanticModel',300,5,30000,NULL,'IT operations semantic model'),
  ('TAC-IT-Ops','IT Operations Overview','Report',NULL,NULL,15000,'SM_IT_Ops','CIO overview report'),
  ('TAC-CDW-Dev','LH_Dev','Lakehouse',NULL,NULL,25000,NULL,'Development lakehouse'),
  ('TAC-CDW-Dev','NB_Dev_Experiments','Notebook',NULL,NULL,60000,NULL,'Ad-hoc development notebooks');

CREATE OR REPLACE TABLE RAW_FABRIC_ITEMS (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_FABRIC_ITEMS
SELECT OBJECT_CONSTRUCT(
    'id', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'item-' || item_name),
    'type', item_type,
    'displayName', item_name,
    'description', description,
    'workspaceId', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'ws-' || workspace_name),
    'workspaceName', workspace_name,
    'capacityName', IFF(workspace_name = 'TAC-CDW-Dev', 'tac-fabric-f8-dev', 'tac-fabric-f64'),
    'upstreamItem', upstream_item
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM SEED_FABRIC_ITEMS;

-- ----------------------------------------------------------------------------
-- Job runs: nightly scheduled pipelines, notebook and semantic model refreshes
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE RAW_FABRIC_JOB_RUNS (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_FABRIC_JOB_RUNS
WITH days AS (SELECT DATEADD(day, SEQ4(), $demo_start) AS d FROM TABLE(GENERATOR(ROWCOUNT => 180))),
runs AS (
  SELECT i.*, days.d,
    HASH(i.item_name, days.d) AS h,
    DATEADD(minute, i.schedule_minute_utc + FLOOR(R(HASH(i.item_name, days.d),'jit') * 4), days.d::TIMESTAMP_NTZ) AS start_ts
  FROM SEED_FABRIC_ITEMS i CROSS JOIN days
  WHERE i.schedule_minute_utc IS NOT NULL
)
SELECT OBJECT_CONSTRUCT(
    'id', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'job-' || item_name || d),
    'itemId', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'item-' || item_name),
    'itemName', item_name,
    'itemType', item_type,
    'workspaceName', workspace_name,
    'jobType', CASE item_type WHEN 'DataPipeline' THEN 'Pipeline' WHEN 'Notebook' THEN 'RunNotebook' ELSE 'Refresh' END,
    'invokeType', 'Scheduled',
    'status', IFF(R(h,'fail') < 0.02, 'Failed', 'Completed'),
    'rootActivityId', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'root-' || item_name || d),
    'startTimeUtc', ISO_TS(start_ts),
    'endTimeUtc', ISO_TS(DATEADD(second, FLOOR(base_duration_min * 60 * (0.8 + R(h,'dur') * 0.5)), start_ts)),
    'failureReason', IFF(R(h,'fail') < 0.02,
        OBJECT_CONSTRUCT('errorCode', ARRAY_CONSTRUCT('UserError','SqlFailedToConnect','Timeout')[(FLOOR(R(h,'err') * 3))::INT]::STRING,
                         'message', 'Transient failure; succeeded on next scheduled run'),
        NULL)
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM runs;

-- ----------------------------------------------------------------------------
-- Capacity metrics: daily CU seconds per item (F64 = 64 CU * 86,400 s = 5,529,600 CU-s/day)
-- Baseline runs at ~45% of capacity on weekdays, lower on weekends.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE RAW_FABRIC_CAPACITY_METRICS (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_FABRIC_CAPACITY_METRICS
WITH days AS (SELECT DATEADD(day, SEQ4(), $demo_start) AS d FROM TABLE(GENERATOR(ROWCOUNT => 180)))
SELECT OBJECT_CONSTRUCT(
    'capacityName', IFF(i.workspace_name = 'TAC-CDW-Dev', 'tac-fabric-f8-dev', 'tac-fabric-f64'),
    'capacitySku', IFF(i.workspace_name = 'TAC-CDW-Dev', 'F8', 'F64'),
    'capacityCUs', IFF(i.workspace_name = 'TAC-CDW-Dev', 8, 64),
    'date', TO_VARCHAR(days.d, 'YYYY-MM-DD'),
    'workspaceName', i.workspace_name,
    'itemName', i.item_name,
    'itemKind', i.item_type,
    'billingType', IFF(i.item_type IN ('Report','Warehouse'), 'Interactive', 'Background'),
    'operationName', CASE i.item_type WHEN 'DataPipeline' THEN 'Pipeline Run' WHEN 'Notebook' THEN 'Notebook Run'
                        WHEN 'SemanticModel' THEN 'Dataset Scheduled Refresh' WHEN 'Report' THEN 'Query'
                        WHEN 'Warehouse' THEN 'Warehouse Query' ELSE 'OneLake Read via Proxy' END,
    'cuSeconds', ROUND(i.daily_cu_seconds * (0.8 + R(HASH(i.item_name, days.d),'cu') * 0.4)
                      * IFF(DAYOFWEEKISO(days.d) >= 6 AND i.item_type IN ('Report','Warehouse'), 0.25, 1.0), 0),
    'throttlingMinutes', 0,
    'operations', FLOOR(10 + R(HASH(i.item_name, days.d),'ops') * 400)
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM SEED_FABRIC_ITEMS i CROSS JOIN days;

-- ----------------------------------------------------------------------------
-- Warehouse query insights (WH_CDW_Gold): ~12k queries
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE RAW_FABRIC_WAREHOUSE_QUERIES (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_FABRIC_WAREHOUSE_QUERIES
WITH analysts AS (
  SELECT ROW_NUMBER() OVER (ORDER BY person_idx) - 1 AS rn, email, COUNT(*) OVER () AS n
  FROM SEED_PEOPLE WHERE department = 'Finance' AND R(person_idx,'wh') < 0.25
),
q AS (
  SELECT i,
    DATEADD(minute, 420 + FLOOR(R(i,'m') * 660), DATEADD(day, FLOOR(R(i,'d') * 180), $demo_start)::TIMESTAMP_NTZ) AS ts,
    FLOOR(R(i,'kind') * 10) AS kind,
    FLOOR(R(i,'who') * 1000) AS who
  FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 12000)))
)
SELECT OBJECT_CONSTRUCT(
    'distributed_statement_id', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'whq-' || q.i),
    'session_id', 50 + MOD(q.i, 400),
    'login_name', CASE WHEN q.kind < 2 THEN 'svc_fabric_etl@tacdemo.com'
                       WHEN q.kind < 6 THEN 'Power BI Service'
                       ELSE a.email END,
    'program_name', CASE WHEN q.kind < 2 THEN 'Fabric Data Pipeline'
                         WHEN q.kind < 6 THEN 'Mashup Engine (Power BI)'
                         WHEN q.kind < 9 THEN 'Azure Data Studio' ELSE 'Microsoft SQL Server Management Studio' END,
    'start_time', ISO_TS(q.ts),
    'end_time', ISO_TS(DATEADD(millisecond, FLOOR(300 + R(q.i,'el') * 20000), q.ts)),
    'total_elapsed_time_ms', FLOOR(300 + R(q.i,'el') * 20000),
    'status', IFF(R(q.i,'st') < 0.985, 'Succeeded', 'Failed'),
    'row_count', FLOOR(IFF(q.kind < 2, 50000 + R(q.i,'rc') * 400000, 20 + R(q.i,'rc') * 40000)),
    'data_scanned_remote_storage_mb', ROUND(IFF(q.kind < 2, 200 + R(q.i,'mb') * 1500, 1 + R(q.i,'mb') * 180), 2),
    'command', CASE WHEN q.kind < 2 THEN 'INSERT INTO gold.fact_gl_journal SELECT * FROM silver.gl_journal WHERE load_date = @load_date'
                    WHEN q.kind < 6 THEN 'SELECT account_key, fiscal_period, SUM(amount) FROM gold.fact_gl_journal GROUP BY account_key, fiscal_period'
                    ELSE ARRAY_CONSTRUCT('SELECT TOP 100 * FROM gold.fact_ap_invoice WHERE vendor_key = 1042',
                                         'SELECT * FROM gold.dim_account WHERE account_type = ''Expense''',
                                         'SELECT fiscal_period, SUM(open_amount) FROM gold.fact_ar_invoice GROUP BY fiscal_period')[(FLOOR(R(q.i,'cmd') * 3))::INT]::STRING END
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM q JOIN analysts a ON a.rn = MOD(q.who, a.n);

-- ----------------------------------------------------------------------------
-- Power BI activity events: ~15k (views, exports, shares, analyze-in-Excel)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE RAW_POWERBI_ACTIVITY (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_POWERBI_ACTIVITY
WITH viewers AS (
  SELECT ROW_NUMBER() OVER (ORDER BY person_idx) - 1 AS rn, email, person_idx, COUNT(*) OVER () AS n
  FROM SEED_PEOPLE WHERE department IN ('Finance','Executive') OR R(person_idx,'pbi') < 0.08
),
reports AS (
  SELECT column1 AS rk, column2 AS report_name, column3 AS dataset_name, column4 AS workspace_name FROM VALUES
    (0,'Finance - GL Summary','SM_Finance_GL','TAC-Finance-Reporting'),
    (1,'Finance - GL Summary','SM_Finance_GL','TAC-Finance-Reporting'),
    (2,'Finance - AP Aging','SM_AP_AR','TAC-Finance-Reporting'),
    (3,'Executive KPI Dashboard','SM_Executive_KPI','TAC-Finance-Reporting'),
    (4,'IT Operations Overview','SM_IT_Ops','TAC-IT-Ops')
),
e AS (
  SELECT i,
    DATEADD(minute, 420 + FLOOR(R(i,'m') * 660), DATEADD(day, FLOOR(R(i,'d') * 180), $demo_start)::TIMESTAMP_NTZ) AS ts,
    CASE WHEN R(i,'op') < 0.80 THEN 'ViewReport' WHEN R(i,'op') < 0.88 THEN 'ViewDashboard'
         WHEN R(i,'op') < 0.92 THEN 'AnalyzeInExcel' WHEN R(i,'op') < 0.95 THEN 'ExportReport'
         WHEN R(i,'op') < 0.975 THEN 'RefreshDataset' WHEN R(i,'op') < 0.99 THEN 'ShareReport' ELSE 'CreateReport' END AS operation,
    FLOOR(R(i,'rpt') * 5) AS rk,
    FLOOR(R(i,'who') * 1000) AS who
  FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 15000)))
)
SELECT OBJECT_CONSTRUCT(
    'Id', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'pbi-' || e.i),
    'RecordType', 20,
    'CreationTime', ISO_TS(e.ts),
    'Operation', e.operation,
    'Activity', e.operation,
    'Workload', 'PowerBI',
    'UserType', 0,
    'UserId', v.email,
    'UserKey', TO_VARCHAR(100320000 + v.person_idx),
    'ClientIP', '203.0.113.' || (10 + MOD(v.person_idx, 40)),
    'UserAgent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Edge/126.0',
    'WorkSpaceName', r.workspace_name,
    'WorkspaceId', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'ws-' || r.workspace_name),
    'ReportName', r.report_name,
    'ReportId', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'item-' || r.report_name),
    'DatasetName', r.dataset_name,
    'DatasetId', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'item-' || r.dataset_name),
    'ItemName', r.report_name,
    'ConsumptionMethod', IFF(R(e.i,'cm') < 0.8, 'Power BI Web', 'Power BI Mobile'),
    'DistributionMethod', IFF(R(e.i,'dm') < 0.7, 'App', 'Workspace'),
    'ExportedArtifactInfo', IFF(e.operation = 'ExportReport',
        OBJECT_CONSTRUCT('ExportType', IFF(R(e.i,'ex') < 0.6, 'PDF', 'CSV'), 'ArtifactType', 'Report', 'ArtifactId', 1), NULL),
    'RowCount', IFF(e.operation = 'ExportReport', FLOOR(50 + R(e.i,'rows') * 5000), NULL)
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM e
JOIN viewers v ON v.rn = MOD(e.who, v.n)
JOIN reports r ON r.rk = e.rk;

SELECT 'raw_fabric_powerbi' AS step,
  (SELECT COUNT(*) FROM RAW_FABRIC_ITEMS) AS items,
  (SELECT COUNT(*) FROM RAW_FABRIC_JOB_RUNS) AS job_runs,
  (SELECT COUNT(*) FROM RAW_FABRIC_CAPACITY_METRICS) AS capacity_rows,
  (SELECT COUNT(*) FROM RAW_FABRIC_WAREHOUSE_QUERIES) AS wh_queries,
  (SELECT COUNT(*) FROM RAW_POWERBI_ACTIVITY) AS pbi_events;
