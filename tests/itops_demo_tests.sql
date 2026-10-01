-- ============================================================================
-- tests/itops_demo_tests.sql
-- Assertions for the IT Ops + Security demo (scripts/30_itops_demo):
--   * every KPI in docs/KPI_CATALOG.md lands in its expected demo range
--   * every storyline in docs/ITOPS_DEMO_SCENARIOS.md is detectable
--   * the semantic view, search service and agent exist
-- Prints a PASS/FAIL table, then fails the script if any assertion failed.
--   snow sql -c <connection> --enable-templating NONE -f tests/itops_demo_tests.sql
-- ============================================================================

USE ROLE cortex_role;
USE WAREHOUSE cortex_wh;
USE SCHEMA COWORK.IT_OPS;

CREATE OR REPLACE TEMPORARY TABLE TEST_RESULTS (test_name VARCHAR, actual VARCHAR, expected VARCHAR, passed BOOLEAN);

-- ---------------------------------------------------------------------------
-- KPI ranges (queried through the semantic view so the governed definitions are tested)
-- ---------------------------------------------------------------------------
INSERT INTO TEST_RESULTS
SELECT 'kpi: SLA compliance %', ROUND(sla_compliance_pct, 1)::VARCHAR, '84-93', sla_compliance_pct BETWEEN 84 AND 93
FROM SEMANTIC_VIEW(IT_OPS_SECURITY_SVW METRICS requests.sla_compliance_pct);

INSERT INTO TEST_RESULTS
SELECT 'kpi: FCR %', ROUND(fcr_pct, 1)::VARCHAR, '55-72', fcr_pct BETWEEN 55 AND 72
FROM SEMANTIC_VIEW(IT_OPS_SECURITY_SVW METRICS requests.fcr_pct);

INSERT INTO TEST_RESULTS
SELECT 'kpi: P1 MTTR hours < P4 MTTR hours', LISTAGG(priority_code || '=' || ROUND(mttr_hours, 1), ', ') WITHIN GROUP (ORDER BY priority_code), 'P1 < P4',
       MAX(IFF(priority_code = 'P1', mttr_hours, NULL)) < MAX(IFF(priority_code = 'P4', mttr_hours, NULL))
FROM SEMANTIC_VIEW(IT_OPS_SECURITY_SVW DIMENSIONS requests.priority_code METRICS requests.mttr_hours);

INSERT INTO TEST_RESULTS
SELECT 'kpi: open backlog has 30d+ tail', SUM(IFF(backlog_age_bucket = '30d+', open_backlog_count, 0))::VARCHAR, '> 0',
       SUM(IFF(backlog_age_bucket = '30d+', open_backlog_count, 0)) > 0
FROM SEMANTIC_VIEW(IT_OPS_SECURITY_SVW DIMENSIONS requests.backlog_age_bucket METRICS requests.open_backlog_count WHERE requests.is_open);

INSERT INTO TEST_RESULTS
SELECT 'kpi: alert noise ratio %', ROUND(noise_ratio_pct, 1)::VARCHAR, '50-75', noise_ratio_pct BETWEEN 50 AND 75
FROM SEMANTIC_VIEW(IT_OPS_SECURITY_SVW METRICS alerts.noise_ratio_pct);

INSERT INTO TEST_RESULTS
SELECT 'kpi: Tier 1 uptime %', ROUND(uptime_pct, 3)::VARCHAR, '99.5-99.99', uptime_pct BETWEEN 99.5 AND 99.99
FROM SEMANTIC_VIEW(IT_OPS_SECURITY_SVW METRICS device_health.uptime_pct WHERE cis.tier = 'Tier 1');

INSERT INTO TEST_RESULTS
SELECT 'kpi: hot devices', hot_device_count::VARCHAR, '3-20', hot_device_count BETWEEN 3 AND 20
FROM SEMANTIC_VIEW(IT_OPS_SECURITY_SVW METRICS device_health.hot_device_count);

INSERT INTO TEST_RESULTS
SELECT 'kpi: CMDB completeness %', ROUND(cmdb_completeness_pct, 1)::VARCHAR, '70-88', cmdb_completeness_pct BETWEEN 70 AND 88
FROM SEMANTIC_VIEW(IT_OPS_SECURITY_SVW METRICS assets.cmdb_completeness_pct);

INSERT INTO TEST_RESULTS
SELECT 'kpi: M365 E5 utilization %', ROUND(m365_utilization_pct, 1)::VARCHAR, '70-80', m365_utilization_pct BETWEEN 70 AND 80
FROM SEMANTIC_VIEW(IT_OPS_SECURITY_SVW DIMENSIONS m365_licenses.sku_part_number METRICS m365_licenses.m365_utilization_pct
                   WHERE m365_licenses.sku_part_number = 'SPE_E5');

INSERT INTO TEST_RESULTS
SELECT 'kpi: AI adoption rises over time', LISTAGG(TO_VARCHAR(usage_month, 'YYYY-MM') || '=' || ROUND(ai_adoption_pct, 1), ', ') WITHIN GROUP (ORDER BY usage_month),
       'last month > first month',
       MAX_BY(ai_adoption_pct, usage_month) > MIN_BY(ai_adoption_pct, usage_month)
FROM SEMANTIC_VIEW(IT_OPS_SECURITY_SVW DIMENSIONS ai_adoption.usage_month METRICS ai_adoption.ai_adoption_pct);

INSERT INTO TEST_RESULTS
SELECT 'kpi: F64 capacity utilization %', ROUND(capacity_utilization_pct, 1)::VARCHAR, '30-60', capacity_utilization_pct BETWEEN 30 AND 60
FROM SEMANTIC_VIEW(IT_OPS_SECURITY_SVW METRICS fabric_capacity.capacity_utilization_pct WHERE fabric_capacity.capacity_name = 'slg-fabric-f64');

INSERT INTO TEST_RESULTS
SELECT 'kpi: change failure rate %', ROUND(change_failure_rate_pct, 1)::VARCHAR, '3-15', change_failure_rate_pct BETWEEN 3 AND 15
FROM SEMANTIC_VIEW(IT_OPS_SECURITY_SVW METRICS changes.change_failure_rate_pct);

-- ---------------------------------------------------------------------------
-- Storylines
-- ---------------------------------------------------------------------------
-- S1: failed emergency change on JDE-SQL01 is the #1 change by alerts afterwards, with incidents and a stale CDW
INSERT INTO TEST_RESULTS
SELECT 'S1: CHG 1450 has most alerts after change', MAX_BY(change_number, alerts_48h_after), '1450', MAX_BY(change_number, alerts_48h_after) = '1450'
FROM SEMANTIC_VIEW(IT_OPS_SECURITY_SVW DIMENSIONS changes.change_number FACTS changes.alerts_48h_after);

INSERT INTO TEST_RESULTS
SELECT 'S1: incidents within 48h of CHG 1450', incidents_48h_after::VARCHAR, '>= 30', incidents_48h_after >= 30
FROM CHANGE_ALERT_CORRELATION WHERE change_number = '1450';

INSERT INTO TEST_RESULTS
SELECT 'S1: JDE ingest failed via FABRIC-GW01', COUNT(*)::VARCHAR, '>= 2', COUNT(*) >= 2
FROM FABRIC_JOB_RUNS
WHERE item_name = 'PL_JDE_Ingest_Nightly' AND status = 'Failed' AND error_message ILIKE '%FABRIC-GW01%' AND record_source = 'scenario:s1_outage';

INSERT INTO TEST_RESULTS
SELECT 'S1: CDW gold stale the morning after', MAX(gold_staleness_hours)::VARCHAR, '> 24h on D-34', MAX(gold_staleness_hours) > 24
FROM FABRIC_DATA_FRESHNESS WHERE calendar_date = (SELECT demo_end_date - 34 FROM REF_DEMO_CONFIG);

INSERT INTO TEST_RESULTS
SELECT 'S1: F64 throttling after full reloads', MAX(throttling_minutes)::VARCHAR, '> 0', MAX(throttling_minutes) > 0
FROM FABRIC_CAPACITY_DAILY WHERE record_source = 'scenario:s1_outage';

-- S2: compromise chain across Entra, Azure, Defender, Fabric, Power BI and Sentinel
INSERT INTO TEST_RESULTS
SELECT 'S2: attacker sign-ins as svc_jde_integration', COUNT(*)::VARCHAR, '5', COUNT(*) = 5
FROM ENTRA_SIGNINS WHERE user_email = 'svc_jde_integration@summitlive.example' AND ip_address = '185.220.101.47' AND is_success;

INSERT INTO TEST_RESULTS
SELECT 'S2: security timeline spans systems', COUNT(DISTINCT source_system)::VARCHAR, '>= 6', COUNT(DISTINCT source_system) >= 6
FROM EVENT_TIMELINE
WHERE domain = 'Security' AND (actor ILIKE 'svc_jde_integration%' OR ip_address = '185.220.101.47' OR host = 'JDE-APP02');

INSERT INTO TEST_RESULTS
SELECT 'S2: bulk CDW read > 4M rows', MAX(row_count)::VARCHAR, '> 4,000,000', MAX(row_count) > 4000000
FROM FABRIC_WAREHOUSE_QUERIES WHERE login_name = 'svc_jde_integration@summitlive.example';

INSERT INTO TEST_RESULTS
SELECT 'S2: Power BI exports from attacker IP', COUNT(*)::VARCHAR, '4', COUNT(*) = 4
FROM POWERBI_ACTIVITY WHERE is_export AND client_ip = '185.220.101.47';

INSERT INTO TEST_RESULTS
SELECT 'S2: MSSP closed early incidents as benign/FP', LISTAGG(incident_number || '=' || classification, ', '), '4061, 4063 not TruePositive; 4127 TruePositive',
       COUNT_IF(incident_number IN (4061, 4063) AND classification <> 'TruePositive') = 2 AND COUNT_IF(incident_number = 4127 AND classification = 'TruePositive') = 1
FROM SENTINEL_INCIDENTS WHERE incident_number IN (4061, 4063, 4127);

INSERT INTO TEST_RESULTS
SELECT 'S2: compromised host is end of support', end_of_support_components, 'Windows Server 2012 R2', is_end_of_support
FROM SDP_ASSETS WHERE hostname = 'JDE-APP02';

-- S3: overloaded engineer
INSERT INTO TEST_RESULTS
SELECT 'S3: Jordan Patel has most tracked hours', MAX_BY(technician_name, total_tracked_hours), 'Jordan Patel', MAX_BY(technician_name, total_tracked_hours) = 'Jordan Patel'
FROM TECHNICIAN_WORKLOAD;

INSERT INTO TEST_RESULTS
SELECT 'S3: Jordan Patel late projects', late_projects::VARCHAR, '4', late_projects = 4
FROM TECHNICIAN_WORKLOAD WHERE technician_name = 'Jordan Patel';

INSERT INTO TEST_RESULTS
SELECT 'S3: low-ticket-usage technicians log few tickets', ROUND(AVG(IFF(low_ticket_usage, tickets_assigned, NULL)))::VARCHAR || ' vs ' || ROUND(AVG(IFF(NOT low_ticket_usage, tickets_assigned, NULL)))::VARCHAR,
       'low < half of others',
       AVG(IFF(low_ticket_usage, tickets_assigned, NULL)) < 0.5 * AVG(IFF(NOT low_ticket_usage, tickets_assigned, NULL))
FROM TECHNICIAN_WORKLOAD;

-- S4: AI cost spike
INSERT INTO TEST_RESULTS
SELECT 'S4: Sales & Marketing top AI spend (30d)', MAX_BY(ai_department, ai_cost_usd), 'Sales & Marketing', MAX_BY(ai_department, ai_cost_usd) = 'Sales & Marketing'
FROM SEMANTIC_VIEW(IT_OPS_SECURITY_SVW DIMENSIONS ai_requests.ai_department METRICS ai_requests.ai_cost_usd
                   WHERE ai_requests.ai_request_date >= DATEADD(day, -30, CURRENT_DATE()));

-- S5: license waste
INSERT INTO TEST_RESULTS
SELECT 'S5: unused E5 seats', unused_seats::VARCHAR, '100-130', unused_seats BETWEEN 100 AND 130
FROM LICENSE_UTILIZATION WHERE sku_part_number = 'SPE_E5';

-- S6: EOL servers hosting business apps
INSERT INTO TEST_RESULTS
SELECT 'S6: EOS servers running JDE / OneStream', LISTAGG(hostname, ', ') WITHIN GROUP (ORDER BY hostname), 'JDE-APP02, JDE-APP03, JDE-BATCH01, ONESTREAM-SQL01',
       LISTAGG(hostname, ', ') WITHIN GROUP (ORDER BY hostname) = 'JDE-APP02, JDE-APP03, JDE-BATCH01, ONESTREAM-SQL01'
FROM SDP_ASSETS WHERE is_end_of_support AND application IN ('JD Edwards EnterpriseOne', 'OneStream');

INSERT INTO TEST_RESULTS
SELECT 'CMDB: hosts missing on each side', LISTAGG(reconciliation_status || '=' || n, '; '), 'both gaps > 0',
       COUNT_IF(reconciliation_status <> 'Matched' AND n > 0) = 2
FROM (SELECT reconciliation_status, COUNT(*) AS n FROM CMDB_RECONCILIATION GROUP BY 1);

-- ---------------------------------------------------------------------------
-- Objects
-- ---------------------------------------------------------------------------
SHOW CORTEX SEARCH SERVICES LIKE 'IT_OPS_KNOWLEDGE_SEARCH' IN SCHEMA COWORK.IT_OPS;
INSERT INTO TEST_RESULTS SELECT 'object: Cortex Search service', COUNT(*)::VARCHAR, '1', COUNT(*) = 1 FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SHOW AGENTS LIKE 'IT_OPS_SECURITY_AGENT' IN SCHEMA COWORK.AGENTS;
INSERT INTO TEST_RESULTS SELECT 'object: IT_OPS_SECURITY_AGENT', COUNT(*)::VARCHAR, '1', COUNT(*) = 1 FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

INSERT INTO TEST_RESULTS
SELECT 'search: runbook retrieval', PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW('COWORK.IT_OPS.IT_OPS_KNOWLEDGE_SEARCH',
         '{"query": "JDE SQL cumulative update rollback TempDB", "columns": ["doc_id"], "limit": 1}')):results[0]:doc_id::VARCHAR,
       'RB-101',
       PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW('COWORK.IT_OPS.IT_OPS_KNOWLEDGE_SEARCH',
         '{"query": "JDE SQL cumulative update rollback TempDB", "columns": ["doc_id"], "limit": 1}')):results[0]:doc_id::VARCHAR = 'RB-101';

-- ---------------------------------------------------------------------------
-- Report and fail on any error
-- ---------------------------------------------------------------------------
SELECT IFF(passed, 'PASS', 'FAIL') AS result, test_name, actual, expected FROM TEST_RESULTS ORDER BY passed, test_name;

EXECUTE IMMEDIATE $$
DECLARE
  failures INTEGER DEFAULT 0;
  total INTEGER DEFAULT 0;
  test_failed EXCEPTION (-20001, 'IT Ops demo tests failed - see the PASS/FAIL table above');
BEGIN
  SELECT COUNT_IF(NOT passed OR passed IS NULL), COUNT(*) INTO :failures, :total FROM TEST_RESULTS;
  IF (failures > 0) THEN
    RAISE test_failed;
  END IF;
  RETURN 'ALL ' || total || ' TESTS PASSED';
END;
$$;
