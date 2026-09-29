-- ============================================================================
-- 30_itops_demo/03_raw_security_m365_ai.sql
-- RAW landing tables (native JSON shape) for:
--   Microsoft Entra ID (signIns, directoryAudits)
--   Azure Monitor AzureActivity
--   Microsoft Defender XDR (AlertInfo + AlertEvidence)
--   Microsoft Sentinel (SecurityIncident, SecurityAlert)
--   Microsoft 365 (subscribedSkus, app user detail, Copilot usage)
--   AI gateway request log
-- Baseline only; attack / cost-spike storylines are added by 05_inject_scenarios.sql.
-- Requires 01. Re-runnable.
-- ============================================================================

USE ROLE cortex_role;
USE WAREHOUSE cortex_wh;
USE SCHEMA COWORK.IT_OPS;

SET demo_start = (SELECT demo_start_date FROM REF_DEMO_CONFIG);
SET demo_end   = (SELECT demo_end_date FROM REF_DEMO_CONFIG);

CREATE OR REPLACE FUNCTION ISO_TS(ts TIMESTAMP_NTZ)
RETURNS VARCHAR
AS $$ TO_VARCHAR(ts, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') $$;

-- ============================================================================
-- ENTRA ID SIGN-INS (~36k user sign-ins + daily service-account sign-ins)
-- ============================================================================
CREATE OR REPLACE TABLE RAW_ENTRA_SIGNINS (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_ENTRA_SIGNINS
WITH s AS (
  SELECT i,
    FLOOR(R(i,'u') * 640) AS person_idx,
    DATEADD(minute, 360 + FLOOR(R(i,'m') * 780), DATEADD(day, FLOOR(R(i,'d') * 180), $demo_start)::TIMESTAMP_NTZ) AS ts,
    ARRAY_CONSTRUCT('Microsoft Teams','Office 365 Exchange Online','SharePoint Online','Microsoft Teams',
                    'JD Edwards EnterpriseOne (SSO)','OneStream','Power BI Service','Microsoft Fabric',
                    'ManageEngine ServiceDesk Plus','Smartsheet','Azure Portal','Office 365 Exchange Online')[(FLOOR(R(i,'app') * 12))::INT]::STRING AS app,
    R(i,'fail') AS rf,
    R(i,'mfa') AS rm,
    R(i,'risk') AS rr,
    R(i,'net') AS rn
  FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 36000)))
)
SELECT OBJECT_CONSTRUCT(
    'id', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'signin-' || s.i),
    'createdDateTime', ISO_TS(s.ts),
    'userPrincipalName', p.email,
    'userDisplayName', p.full_name,
    'appDisplayName', s.app,
    'ipAddress', IFF(s.rn < 0.55, '203.0.113.' || (10 + MOD(p.person_idx, 40)), '198.51.100.' || MOD(p.person_idx * 7, 250)),
    'clientAppUsed', IFF(s.app LIKE '%Teams%', 'Mobile Apps and Desktop clients', 'Browser'),
    'isInteractive', TRUE,
    'conditionalAccessStatus', IFF(s.rm < 0.90, 'success', 'notApplied'),
    'authenticationRequirement', IFF(s.rm < 0.93, 'multiFactorAuthentication', 'singleFactorAuthentication'),
    'riskLevelDuringSignIn', CASE WHEN s.rr < 0.985 THEN 'none' WHEN s.rr < 0.997 THEN 'low' ELSE 'medium' END,
    'status', CASE WHEN s.rf < 0.018 THEN OBJECT_CONSTRUCT('errorCode', 50126, 'failureReason', 'Invalid username or password or Invalid on-premise username or password.')
                   WHEN s.rf < 0.026 THEN OBJECT_CONSTRUCT('errorCode', 50074, 'failureReason', 'Strong Authentication is required.')
                   WHEN s.rf < 0.030 THEN OBJECT_CONSTRUCT('errorCode', 50053, 'failureReason', 'Account is locked because user tried to sign in too many times with an incorrect user ID or password.')
                   ELSE OBJECT_CONSTRUCT('errorCode', 0) END,
    'location', OBJECT_CONSTRUCT(
        'city', CASE p.site WHEN 'Denver HQ' THEN 'Denver' WHEN 'Los Angeles' THEN 'Los Angeles' WHEN 'Ottawa' THEN 'Ottawa'
                            WHEN 'London' THEN 'London' ELSE 'Denver' END,
        'countryOrRegion', CASE p.site WHEN 'Ottawa' THEN 'CA' WHEN 'London' THEN 'GB' ELSE 'US' END),
    'deviceDetail', OBJECT_CONSTRUCT('operatingSystem', 'Windows', 'browser', 'Edge', 'isCompliant', s.rn < 0.9)
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM s JOIN SEED_PEOPLE p ON p.person_idx = s.person_idx
UNION ALL
-- Service accounts: non-interactive, single factor, excluded from Conditional Access (the gap)
SELECT OBJECT_CONSTRUCT(
    'id', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'svc-' || sa.upn || d.n),
    'createdDateTime', ISO_TS(DATEADD(minute, sa.minute_of_day, DATEADD(day, d.n, $demo_start)::TIMESTAMP_NTZ)),
    'userPrincipalName', sa.upn,
    'userDisplayName', sa.display_name,
    'appDisplayName', sa.app,
    'ipAddress', sa.ip,
    'clientAppUsed', 'Other clients',
    'isInteractive', FALSE,
    'conditionalAccessStatus', 'notApplied',
    'authenticationRequirement', 'singleFactorAuthentication',
    'riskLevelDuringSignIn', 'none',
    'status', OBJECT_CONSTRUCT('errorCode', 0),
    'location', OBJECT_CONSTRUCT('city', 'Toronto', 'countryOrRegion', 'CA'),
    'deviceDetail', OBJECT_CONSTRUCT('operatingSystem', 'Windows Server', 'isCompliant', FALSE)
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM (SELECT SEQ4() AS n FROM TABLE(GENERATOR(ROWCOUNT => 180))) d
CROSS JOIN (SELECT column1 AS upn, column2 AS display_name, column3 AS app, column4 AS ip, column5 AS minute_of_day FROM VALUES
  ('svc_jde_integration@tacdemo.com','svc JDE Integration','JD Edwards EnterpriseOne (SSO)','20.48.200.14',120),
  ('svc_fabric_etl@tacdemo.com','svc Fabric ETL','Microsoft Fabric','20.48.200.21',115),
  ('svc_backup@tacdemo.com','svc Backup','Azure Portal','20.48.200.33',60)) sa;

-- ============================================================================
-- ENTRA DIRECTORY AUDITS (~600 admin operations by IT staff)
-- ============================================================================
CREATE OR REPLACE TABLE RAW_ENTRA_AUDITS (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_ENTRA_AUDITS
SELECT OBJECT_CONSTRUCT(
    'id', 'Directory_' || UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'audit-' || i),
    'activityDateTime', ISO_TS(DATEADD(minute, 480 + FLOOR(R(i,'m') * 540), DATEADD(day, FLOOR(R(i,'d') * 180), $demo_start)::TIMESTAMP_NTZ)),
    'activityDisplayName', ARRAY_CONSTRUCT('Add member to group','Reset user password','Update user','Add user',
                                           'Disable account','Add app role assignment to user','Update conditional access policy',
                                           'Add member to group','Reset user password')[(FLOOR(R(i,'a') * 9))::INT]::STRING,
    'category', 'UserManagement',
    'result', IFF(R(i,'r') < 0.98, 'success', 'failure'),
    'initiatedBy', OBJECT_CONSTRUCT('user', OBJECT_CONSTRUCT('userPrincipalName', p.email)),
    'targetResources', ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('displayName', t.full_name, 'userPrincipalName', t.email, 'type', 'User'))
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 600))) g
JOIN SEED_PEOPLE p ON p.person_idx = ARRAY_CONSTRUCT(1,7,13,4,10,16)[(FLOOR(R(g.i,'who') * 6))::INT]::NUMBER
JOIN SEED_PEOPLE t ON t.person_idx = 40 + FLOOR(R(g.i,'tgt') * 600);

-- ============================================================================
-- AZURE ACTIVITY (~3,000 control-plane operations)
-- ============================================================================
CREATE OR REPLACE TABLE RAW_AZURE_ACTIVITY (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_AZURE_ACTIVITY
WITH a AS (
  SELECT i,
    DATEADD(minute, FLOOR(R(i,'t') * 180 * 1440), $demo_start::TIMESTAMP_NTZ) AS ts,
    ARRAY_CONSTRUCT('rg-jde-prod','rg-onestream-prod','rg-fabric-cdw','rg-shared-infra','rg-ai-gateway')[(FLOOR(R(i,'rg') * 5))::INT]::STRING AS rg,
    ARRAY_CONSTRUCT('Microsoft.Compute/virtualMachines/start/action','Microsoft.Compute/virtualMachines/deallocate/action',
                    'Microsoft.Compute/virtualMachines/write','Microsoft.Network/networkSecurityGroups/securityRules/write',
                    'Microsoft.Storage/storageAccounts/write','Microsoft.KeyVault/vaults/secrets/write',
                    'Microsoft.Compute/snapshots/write','Microsoft.Resources/deployments/write')[(FLOOR(R(i,'op') * 8))::INT]::STRING AS op,
    ARRAY_CONSTRUCT(5, 11, 17, 23, 29)[(FLOOR(R(i,'who') * 5))::INT]::NUMBER AS caller_idx,
    (R(i,'svc') < 0.25) AS by_svc
  FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 3000)))
)
SELECT OBJECT_CONSTRUCT(
    'TimeGenerated', ISO_TS(a.ts),
    'OperationNameValue', a.op,
    'ActivityStatusValue', IFF(R(a.i,'st') < 0.97, 'Success', 'Failure'),
    'CategoryValue', 'Administrative',
    'Caller', IFF(a.by_svc, 'svc_fabric_etl@tacdemo.com', p.email),
    'CallerIpAddress', IFF(a.by_svc, '20.48.200.21', '203.0.113.' || (10 + MOD(p.person_idx, 40))),
    'ResourceGroup', a.rg,
    '_ResourceId', '/subscriptions/0000-tac/resourceGroups/' || a.rg || '/providers/' || SPLIT_PART(a.op, '/', 1) || '/' || SPLIT_PART(a.op, '/', 2) || '/res' || MOD(a.i, 20)
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM a JOIN SEED_PEOPLE p ON p.person_idx = a.caller_idx;

-- ============================================================================
-- DEFENDER XDR ALERTS (~250 low-grade workstation alerts)
-- ============================================================================
CREATE OR REPLACE TABLE RAW_DEFENDER_ALERTS (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_DEFENDER_ALERTS
WITH d AS (
  SELECT i, FLOOR(R(i,'ws') * 700) AS ws_idx,
    DATEADD(minute, FLOOR(R(i,'t') * 180 * 1440), $demo_start::TIMESTAMP_NTZ) AS ts,
    FLOOR(R(i,'k') * 5) AS k
  FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 250)))
)
SELECT OBJECT_CONSTRUCT(
    'Timestamp', ISO_TS(d.ts),
    'AlertId', 'da' || LPAD(TO_VARCHAR(600000 + d.i), 12, '0'),
    'Title', ARRAY_CONSTRUCT('Potentially unwanted application detected','Suspicious URL clicked',
                             'Malware was prevented','Suspicious PowerShell activity blocked',
                             'Unsanctioned cloud app access')[(d.k)::INT]::STRING,
    'Category', ARRAY_CONSTRUCT('Malware','InitialAccess','Malware','Execution','Exfiltration')[(d.k)::INT]::STRING,
    'Severity', ARRAY_CONSTRUCT('Low','Medium','Informational','Medium','Low')[(d.k)::INT]::STRING,
    'ServiceSource', 'Microsoft Defender for Endpoint',
    'DetectionSource', 'Antivirus',
    'AttackTechniques', ARRAY_CONSTRUCT('[]','["Phishing (T1566)"]','[]','["PowerShell (T1059.001)"]','[]')[(d.k)::INT]::STRING,
    'Evidence', ARRAY_CONSTRUCT(
        OBJECT_CONSTRUCT('EntityType','Machine','EvidenceRole','Impacted','DeviceName', w.hostname),
        OBJECT_CONSTRUCT('EntityType','User','EvidenceRole','Impacted','AccountUpn', w.user_email))
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM d JOIN SEED_WORKSTATIONS w ON w.ws_idx = d.ws_idx;

-- ============================================================================
-- SENTINEL: ~160 incidents (mostly benign / false positive), 1-3 alerts each
-- ============================================================================
CREATE OR REPLACE TEMPORARY TABLE TMP_SENT AS
SELECT i,
  DATEADD(minute, FLOOR(R(i,'t') * 180 * 1440), $demo_start::TIMESTAMP_NTZ) AS created_at,
  FLOOR(R(i,'k') * 6) AS k,
  1 + FLOOR(R(i,'na') * 3) AS n_alerts,
  CASE WHEN R(i,'sev') < 0.50 THEN 'Low' WHEN R(i,'sev') < 0.85 THEN 'Medium' WHEN R(i,'sev') < 0.97 THEN 'Informational' ELSE 'High' END AS severity,
  FLOOR(2 + R(i,'close') * 70) AS hours_to_close
FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 160)));

CREATE OR REPLACE TABLE RAW_SENTINEL_ALERTS (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_SENTINEL_ALERTS
SELECT OBJECT_CONSTRUCT(
    'TimeGenerated', ISO_TS(DATEADD(minute, -5 * n.n, s.created_at)),
    'SystemAlertId', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'salert-' || s.i || '-' || n.n),
    'AlertName', ARRAY_CONSTRUCT('Unfamiliar sign-in properties','Atypical travel','Anomalous token',
                                 'Mass download by a single user','Suspicious inbox manipulation rule',
                                 'Multiple failed sign-in attempts')[(s.k)::INT]::STRING,
    'AlertSeverity', s.severity,
    'ProviderName', ARRAY_CONSTRUCT('IPC','IPC','IPC','MCAS','OATP','ASI Scheduled Alerts')[(s.k)::INT]::STRING,
    'ProductName', ARRAY_CONSTRUCT('Azure Active Directory Identity Protection','Azure Active Directory Identity Protection',
                                   'Azure Active Directory Identity Protection','Microsoft Cloud App Security',
                                   'Office 365 Advanced Threat Protection','Azure Sentinel')[(s.k)::INT]::STRING,
    'Tactics', ARRAY_CONSTRUCT('InitialAccess','InitialAccess','CredentialAccess','Exfiltration','Persistence','CredentialAccess')[(s.k)::INT]::STRING,
    'Techniques', '[]',
    'CompromisedEntity', p.email
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM TMP_SENT s
JOIN (SELECT SEQ4() AS n FROM TABLE(GENERATOR(ROWCOUNT => 3))) n ON n.n < s.n_alerts
JOIN SEED_PEOPLE p ON p.person_idx = 40 + MOD(s.i * 37, 600);

CREATE OR REPLACE TABLE RAW_SENTINEL_INCIDENTS (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_SENTINEL_INCIDENTS
SELECT OBJECT_CONSTRUCT(
    'TimeGenerated', ISO_TS(s.created_at),
    'IncidentNumber', 3900 + s.i,
    'Title', ARRAY_CONSTRUCT('Unfamiliar sign-in properties','Atypical travel','Anomalous token',
                             'Mass download by a single user','Suspicious inbox manipulation rule',
                             'Multiple failed sign-in attempts')[(s.k)::INT]::STRING || ' involving one user',
    'Severity', s.severity,
    'Status', IFF(s.created_at > DATEADD(day, -4, $demo_end), 'Active', 'Closed'),
    'Classification', IFF(s.created_at > DATEADD(day, -4, $demo_end), NULL,
                          ARRAY_CONSTRUCT('FalsePositive','BenignPositive','BenignPositive','TruePositive','Undetermined')[(FLOOR(R(s.i,'cls') * 5))::INT]::STRING),
    'Owner', OBJECT_CONSTRUCT('assignedTo', 'MSSP SOC Tier 1'),
    'CreatedTime', ISO_TS(s.created_at),
    'FirstActivityTime', ISO_TS(DATEADD(minute, -5 * (s.n_alerts - 1) - 10, s.created_at)),
    'LastActivityTime', ISO_TS(s.created_at),
    'ClosedTime', IFF(s.created_at > DATEADD(day, -4, $demo_end), NULL, ISO_TS(DATEADD(hour, s.hours_to_close, s.created_at))),
    'AlertIds', ARRAY_SLICE(ARRAY_CONSTRUCT(
        UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'salert-' || s.i || '-0'),
        UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'salert-' || s.i || '-1'),
        UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'salert-' || s.i || '-2')), 0, s.n_alerts),
    'AdditionalData', OBJECT_CONSTRUCT('alertsCount', s.n_alerts,
                        'tactics', ARRAY_CONSTRUCT(ARRAY_CONSTRUCT('InitialAccess','InitialAccess','CredentialAccess','Exfiltration','Persistence','CredentialAccess')[s.k]))
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM TMP_SENT s;

-- ============================================================================
-- MICROSOFT 365: SKUs, per-user activity snapshot, monthly Copilot usage
-- E5 is assigned to 441 people; 105 of them have been inactive 30+ days
-- (with 9 unassigned seats, about 114 wasted E5 licenses: storyline 5).
-- ============================================================================
CREATE OR REPLACE TABLE RAW_M365_SUBSCRIBED_SKUS (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_M365_SUBSCRIBED_SKUS
SELECT OBJECT_CONSTRUCT('skuId', UUID_STRING('6ba7b810-9dad-11d1-80b4-00c04fd430c8', column1),
                        'skuPartNumber', column1, 'capabilityStatus', 'Enabled',
                        'prepaidUnits', OBJECT_CONSTRUCT('enabled', column2, 'suspended', 0, 'warning', 0),
                        'consumedUnits', column3),
       'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM VALUES ('SPE_E5',450,441),('SPE_E3',230,199),('Microsoft_365_Copilot',150,148),('POWER_BI_PRO',120,97),
            ('VISIOCLIENT',40,31),('PROJECTPROFESSIONAL',30,28),('Microsoft_Teams_Premium',25,9),('SPE_F3',60,44);

CREATE OR REPLACE TEMPORARY TABLE TMP_LIC AS
WITH ranked AS (
  SELECT p.*,
    ROW_NUMBER() OVER (ORDER BY IFF(department IN ('Information Technology','Executive','Finance'), 0, 1), R(person_idx,'e5')) AS e5_rank,
    ROW_NUMBER() OVER (ORDER BY IFF(department IN ('Information Technology','Executive','Finance'), 0, 1), R(person_idx,'cop')) AS cop_rank
  FROM SEED_PEOPLE p
)
SELECT r.*,
  IFF(e5_rank <= 441, 'SPE_E5', 'SPE_E3') AS base_sku,
  (cop_rank <= 148) AS has_copilot,
  (department = 'Finance' OR department = 'Executive' OR R(person_idx,'pbi') < 0.08) AS has_powerbi_pro,
  -- Inactive: 105 non-IT E5 users, ~5% of E3
  CASE WHEN e5_rank <= 441 AND department <> 'Information Technology'
            AND ROW_NUMBER() OVER (PARTITION BY (e5_rank <= 441 AND department <> 'Information Technology') ORDER BY R(person_idx,'inact')) <= 105 THEN TRUE
       WHEN e5_rank > 441 AND R(person_idx,'inact3') < 0.05 THEN TRUE
       ELSE FALSE END AS is_inactive
FROM ranked r;

CREATE OR REPLACE TABLE RAW_M365_USER_ACTIVITY (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_M365_USER_ACTIVITY
SELECT OBJECT_CONSTRUCT(
    'reportRefreshDate', TO_VARCHAR(DATEADD(day, -2, $demo_end), 'YYYY-MM-DD'),
    'userPrincipalName', email,
    'displayName', full_name,
    'isDeleted', FALSE,
    'lastActivityDate', TO_VARCHAR(IFF(is_inactive, DATEADD(day, -(35 + FLOOR(R(person_idx,'la') * 120)), $demo_end),
                                                    DATEADD(day, -FLOOR(R(person_idx,'la') * 6), $demo_end)), 'YYYY-MM-DD'),
    'assignedProducts', ARRAY_CAT(
        ARRAY_CONSTRUCT(IFF(base_sku = 'SPE_E5', 'MICROSOFT 365 E5', 'MICROSOFT 365 E3')),
        ARRAY_CAT(IFF(has_copilot, ARRAY_CONSTRUCT('MICROSOFT 365 COPILOT'), ARRAY_CONSTRUCT()),
                  IFF(has_powerbi_pro AND base_sku <> 'SPE_E5', ARRAY_CONSTRUCT('POWER BI PRO'), ARRAY_CONSTRUCT()))),
    'skuPartNumbers', ARRAY_CAT(ARRAY_CONSTRUCT(base_sku),
        ARRAY_CAT(IFF(has_copilot, ARRAY_CONSTRUCT('Microsoft_365_Copilot'), ARRAY_CONSTRUCT()),
                  IFF(has_powerbi_pro AND base_sku <> 'SPE_E5', ARRAY_CONSTRUCT('POWER_BI_PRO'), ARRAY_CONSTRUCT()))),
    'department', department
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM TMP_LIC;

-- Copilot usage: one snapshot per month; active share rises from ~35% to ~75%
CREATE OR REPLACE TABLE RAW_M365_COPILOT_USAGE (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_M365_COPILOT_USAGE
WITH months AS (SELECT SEQ4() AS m FROM TABLE(GENERATOR(ROWCOUNT => 6))),
x AS (
  SELECT l.*, months.m,
    LAST_DAY(DATEADD(month, months.m - 5, $demo_end)) AS month_end,
    (R(l.person_idx * 10 + months.m, 'cop_act') < 0.35 + months.m * 0.08 AND NOT l.is_inactive) AS active
  FROM TMP_LIC l CROSS JOIN months WHERE l.has_copilot
)
SELECT OBJECT_CONSTRUCT(
    'reportRefreshDate', TO_VARCHAR(LEAST(month_end, $demo_end), 'YYYY-MM-DD'),
    'reportPeriod', 30,
    'userPrincipalName', email,
    'displayName', full_name,
    'lastActivityDate', IFF(active, TO_VARCHAR(DATEADD(day, -FLOOR(R(person_idx * 10 + m,'d') * 25), LEAST(month_end, $demo_end)), 'YYYY-MM-DD'), NULL),
    'copilotChatLastActivityDate', IFF(active, TO_VARCHAR(DATEADD(day, -FLOOR(R(person_idx * 10 + m,'c') * 25), LEAST(month_end, $demo_end)), 'YYYY-MM-DD'), NULL),
    'microsoftTeamsCopilotLastActivityDate', IFF(active AND R(person_idx * 10 + m,'t') < 0.7, TO_VARCHAR(LEAST(month_end, $demo_end), 'YYYY-MM-DD'), NULL),
    'wordCopilotLastActivityDate', IFF(active AND R(person_idx * 10 + m,'w') < 0.5, TO_VARCHAR(LEAST(month_end, $demo_end), 'YYYY-MM-DD'), NULL),
    'excelCopilotLastActivityDate', IFF(active AND R(person_idx * 10 + m,'x') < 0.4, TO_VARCHAR(LEAST(month_end, $demo_end), 'YYYY-MM-DD'), NULL),
    'outlookCopilotLastActivityDate', IFF(active AND R(person_idx * 10 + m,'o') < 0.6, TO_VARCHAR(LEAST(month_end, $demo_end), 'YYYY-MM-DD'), NULL)
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM x;

-- ============================================================================
-- AI GATEWAY REQUESTS (~40k over the last 120 days, growing adoption)
-- Price per 1M tokens (input/output): gpt-4o-mini 0.15/0.60, claude-haiku-4-5 1/5,
-- claude-sonnet-4-5 3/15, gpt-5 1.25/10, claude-opus-4-1 15/75
-- ============================================================================
CREATE OR REPLACE TABLE RAW_AI_GATEWAY_REQUESTS (PAYLOAD VARIANT, SOURCE VARCHAR, INGESTED_AT TIMESTAMP_NTZ);
INSERT INTO RAW_AI_GATEWAY_REQUESTS
WITH users AS (
  SELECT ROW_NUMBER() OVER (ORDER BY person_idx) - 1 AS rn, person_idx, email, department, COUNT(*) OVER () AS n
  FROM SEED_PEOPLE WHERE R(person_idx,'ai_user') < 0.42 OR department = 'Information Technology'
),
g AS (
  SELECT i,
    -- sqrt skews timestamps toward recent days (adoption growth)
    DATEADD(second, -FLOOR((1 - SQRT(R(i,'t'))) * 120 * 86400), $demo_end::TIMESTAMP_NTZ) AS ts,
    CASE WHEN R(i,'cx') < 0.55 THEN 'simple' WHEN R(i,'cx') < 0.85 THEN 'moderate' ELSE 'complex' END AS complexity,
    (R(i,'ovr') < 0.03) AS is_override,
    FLOOR(R(i,'u') * 100000) AS u_pick
  FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 40000)))
),
m AS (
  SELECT g.*, u.email, u.department,
    CASE WHEN g.is_override THEN 'claude-opus-4-1'
         WHEN g.complexity = 'simple' THEN IFF(R(g.i,'m') < 0.7, 'gpt-4o-mini', 'claude-haiku-4-5')
         WHEN g.complexity = 'moderate' THEN IFF(R(g.i,'m') < 0.6, 'claude-sonnet-4-5', 'gpt-5')
         ELSE IFF(R(g.i,'m') < 0.6, 'claude-opus-4-1', 'gpt-5') END AS model,
    CASE WHEN g.is_override THEN 'user_override'
         WHEN R(g.i,'fb') < 0.02 THEN 'fallback'
         WHEN g.complexity = 'simple' THEN 'auto_simple' ELSE 'auto_complex' END AS route_reason,
    FLOOR(CASE g.complexity WHEN 'simple' THEN 200 + R(g.i,'pt') * 700 WHEN 'moderate' THEN 900 + R(g.i,'pt') * 2500 ELSE 2000 + R(g.i,'pt') * 6000 END) AS prompt_tokens,
    FLOOR(CASE g.complexity WHEN 'simple' THEN 100 + R(g.i,'ct') * 300 WHEN 'moderate' THEN 300 + R(g.i,'ct') * 900 ELSE 800 + R(g.i,'ct') * 1700 END) AS completion_tokens
  FROM g JOIN users u ON u.rn = MOD(g.u_pick, u.n)
)
SELECT OBJECT_CONSTRUCT(
    'request_id', 'aigw-' || LPAD(TO_VARCHAR(i), 7, '0'),
    'timestamp', ISO_TS(ts),
    'user_email', email,
    'department', department,
    'model', model,
    'provider', IFF(model LIKE 'claude%', 'Anthropic', 'OpenAI'),
    'route_reason', route_reason,
    'complexity', complexity,
    'prompt_tokens', prompt_tokens,
    'completion_tokens', completion_tokens,
    'cost_usd', ROUND(CASE model
        WHEN 'gpt-4o-mini' THEN prompt_tokens * 0.15 + completion_tokens * 0.60
        WHEN 'claude-haiku-4-5' THEN prompt_tokens * 1 + completion_tokens * 5
        WHEN 'claude-sonnet-4-5' THEN prompt_tokens * 3 + completion_tokens * 15
        WHEN 'gpt-5' THEN prompt_tokens * 1.25 + completion_tokens * 10
        ELSE prompt_tokens * 15 + completion_tokens * 75 END / 1000000, 6),
    'latency_ms', FLOOR(400 + R(i,'lat') * IFF(model = 'claude-opus-4-1', 9000, 3000)),
    'status', IFF(R(i,'err') < 0.01, 'error', 'success')
  ), 'baseline', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
FROM m;

SELECT 'raw_security_m365_ai' AS step,
  (SELECT COUNT(*) FROM RAW_ENTRA_SIGNINS) AS signins,
  (SELECT COUNT(*) FROM RAW_AZURE_ACTIVITY) AS azure_activity,
  (SELECT COUNT(*) FROM RAW_DEFENDER_ALERTS) AS defender,
  (SELECT COUNT(*) FROM RAW_SENTINEL_INCIDENTS) AS sentinel_incidents,
  (SELECT COUNT(*) FROM RAW_M365_USER_ACTIVITY) AS m365_users,
  (SELECT COUNT(*) FROM RAW_AI_GATEWAY_REQUESTS) AS ai_requests;
