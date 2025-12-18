-- ============================================================================
-- KUBERNETES AUDIT LOGS - CREATE + SEED SAMPLE DATA
-- ============================================================================
-- Sample shape based on IBM DSM Kubernetes Auditing sample event message:
-- https://www.ibm.com/docs/en/dsm?topic=auditing-kubernetes-sample-event-message
--
-- DATA TIMELINE: Last 30 days (recent data for realistic demos)
--
-- INJECTED SECURITY INCIDENTS:
--   1) CRYPTO MINING: Pod 'crypto-linter-worker' spawned by compromised npm package
--   2) SECRETS EXFIL: Unauthorized secrets access attempts (403 Forbidden)

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.TOOLS;

CREATE OR REPLACE TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SOURCE (
  EVENT_TIME TIMESTAMP_NTZ(9),
  HOSTNAME VARCHAR,
  PROGRAM VARCHAR,
  SEVERITY NUMBER(38,0),
  RAW_SYSLOG VARCHAR,
  RAW_EVENT_JSON VARCHAR,
  AUDIT_ID VARCHAR,
  STAGE VARCHAR,
  LEVEL VARCHAR,
  VERB VARCHAR,
  REQUEST_URI VARCHAR,
  USERNAME VARCHAR,
  USER_UID VARCHAR,
  SOURCE_IP VARCHAR,
  USER_AGENT VARCHAR,
  OBJECT_RESOURCE VARCHAR,
  OBJECT_NAMESPACE VARCHAR,
  RESPONSE_CODE NUMBER(38,0),
  AUTHZ_DECISION VARCHAR
);

-- ============================================================================
-- BASELINE: ~350 normal Kubernetes audit events
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SOURCE
SELECT
  DATEADD('minute', -seq4() * 120, CURRENT_TIMESTAMP()) AS event_time,
  IFF(seq4() % 3 = 0, 'k8s-master-01.cluster.local', IFF(seq4() % 3 = 1, 'k8s-master-02.cluster.local', 'k8s-master-03.cluster.local')) AS hostname,
  'k8s-audit' AS program,
  133::NUMBER(38,0) AS severity,
  'normal audit event' AS raw_syslog,
  TO_JSON(OBJECT_CONSTRUCT('kind', 'Event', 'apiVersion', 'audit.k8s.io/v1', 'level', 'Metadata')) AS raw_event_json,
  UUID_STRING() AS audit_id,
  IFF(seq4() % 3 = 0, 'ResponseComplete', IFF(seq4() % 3 = 1, 'ResponseStarted', 'RequestReceived')) AS stage,
  IFF(seq4() % 5 = 0, 'Metadata', IFF(seq4() % 5 = 1, 'Request', IFF(seq4() % 5 = 2, 'RequestResponse', 'Response'))) AS level,
  IFF(seq4() % 6 = 0, 'get', IFF(seq4() % 6 = 1, 'list', IFF(seq4() % 6 = 2, 'watch', IFF(seq4() % 6 = 3, 'create', IFF(seq4() % 6 = 4, 'update', 'patch'))))) AS verb,
  IFF(seq4() % 6 = 0, '/api/v1/namespaces/default/pods',
      IFF(seq4() % 6 = 1, '/api/v1/namespaces/kube-system/configmaps',
      IFF(seq4() % 6 = 2, '/api/v1/namespaces/prod/services',
      IFF(seq4() % 6 = 3, '/apis/apps/v1/namespaces/prod/deployments',
      IFF(seq4() % 6 = 4, '/api/v1/nodes', '/api/v1/namespaces/dev/pods'))))) AS request_uri,
  IFF(seq4() % 6 = 0, 'system:apiserver', IFF(seq4() % 6 = 1, 'system:serviceaccount:kube-system:coredns', IFF(seq4() % 6 = 2, 'admin', IFF(seq4() % 6 = 3, 'developer', IFF(seq4() % 6 = 4, 'system:kube-controller-manager', 'system:kube-scheduler'))))) AS username,
  UUID_STRING() AS user_uid,
  CONCAT('10.42.0.', ((seq4() % 250)+1)::STRING) AS source_ip,
  IFF(seq4() % 4 = 0, 'kube-apiserver/v1.28.0 (linux/amd64)', IFF(seq4() % 4 = 1, 'kubectl/v1.28.0 (linux/amd64)', IFF(seq4() % 4 = 2, 'kube-controller-manager/v1.28.0', 'argocd/v2.8.0'))) AS user_agent,
  IFF(seq4() % 6 = 0, 'pods', IFF(seq4() % 6 = 1, 'configmaps', IFF(seq4() % 6 = 2, 'services', IFF(seq4() % 6 = 3, 'deployments', IFF(seq4() % 6 = 4, 'nodes', 'pods'))))) AS object_resource,
  IFF(seq4() % 5 = 0, 'default', IFF(seq4() % 5 = 1, 'kube-system', IFF(seq4() % 5 = 2, 'prod', IFF(seq4() % 5 = 3, 'dev', 'monitoring')))) AS object_namespace,
  200::NUMBER(38,0) AS response_code,
  'allow' AS authz_decision
FROM TABLE(GENERATOR(ROWCOUNT => 350));

-- ============================================================================
-- INCIDENT 1: CRYPTO MINING - Malicious pod 'crypto-linter-worker' created
-- Timeline: 5 days ago (matches npm incident + CrowdStrike)
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SOURCE
SELECT
  DATEADD('minute', seq4(), DATEADD('day', -5, CURRENT_TIMESTAMP())) AS event_time,
  'k8s-master-01.cluster.local' AS hostname,
  'k8s-audit' AS program,
  133::NUMBER(38,0) AS severity,
  CONCAT('<133> k8s-audit: crypto-linter-worker pod created in default namespace') AS raw_syslog,
  TO_JSON(OBJECT_CONSTRUCT(
    'kind', 'Event',
    'apiVersion', 'audit.k8s.io/v1',
    'level', 'RequestResponse',
    'verb', IFF(seq4() % 4 = 0, 'create', IFF(seq4() % 4 = 1, 'get', IFF(seq4() % 4 = 2, 'list', 'watch'))),
    'objectRef', OBJECT_CONSTRUCT(
      'resource', 'pods',
      'namespace', 'default',
      'name', CONCAT('crypto-linter-worker-', (seq4() % 3)::STRING)
    ),
    'user', OBJECT_CONSTRUCT('username', 'system:serviceaccount:default:default'),
    'responseStatus', OBJECT_CONSTRUCT('code', 200),
    'annotations', OBJECT_CONSTRUCT('suspicious', 'true', 'reason', 'unusual pod name pattern')
  )) AS raw_event_json,
  UUID_STRING() AS audit_id,
  'ResponseComplete' AS stage,
  'RequestResponse' AS level,
  IFF(seq4() % 4 = 0, 'create', IFF(seq4() % 4 = 1, 'get', IFF(seq4() % 4 = 2, 'list', 'watch'))) AS verb,
  '/api/v1/namespaces/default/pods' AS request_uri,
  'system:serviceaccount:default:default' AS username,
  UUID_STRING() AS user_uid,
  CONCAT('10.42.1.', ((seq4() % 5) + 50)::STRING) AS source_ip,  -- Same IPs as CrowdStrike mining hosts
  'kubectl/v1.28.0 (linux/amd64)' AS user_agent,
  'pods' AS object_resource,
  'default' AS object_namespace,
  200::NUMBER(38,0) AS response_code,
  'allow' AS authz_decision
FROM TABLE(GENERATOR(ROWCOUNT => 25));

-- ============================================================================
-- INCIDENT 1b: CRYPTO MINING - Pod accessing secrets (for crypto wallet keys)
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SOURCE
SELECT
  DATEADD('minute', 30 + seq4() * 5, DATEADD('day', -5, CURRENT_TIMESTAMP())) AS event_time,
  'k8s-master-01.cluster.local' AS hostname,
  'k8s-audit' AS program,
  133::NUMBER(38,0) AS severity,
  '<133> k8s-audit: secrets access by crypto-linter pod' AS raw_syslog,
  TO_JSON(OBJECT_CONSTRUCT(
    'kind', 'Event',
    'apiVersion', 'audit.k8s.io/v1',
    'level', 'RequestResponse',
    'verb', IFF(seq4() % 3 = 0, 'get', 'list'),
    'objectRef', OBJECT_CONSTRUCT(
      'resource', 'secrets',
      'namespace', 'default',
      'name', IFF(seq4() % 3 = 0, 'aws-credentials', IFF(seq4() % 3 = 1, 'database-secrets', 'tls-certs'))
    ),
    'user', OBJECT_CONSTRUCT('username', 'system:serviceaccount:default:default'),
    'responseStatus', OBJECT_CONSTRUCT('code', 200),
    'annotations', OBJECT_CONSTRUCT('suspicious', 'true', 'reason', 'service account accessing secrets')
  )) AS raw_event_json,
  UUID_STRING() AS audit_id,
  'ResponseComplete' AS stage,
  'RequestResponse' AS level,
  IFF(seq4() % 3 = 0, 'get', 'list') AS verb,
  '/api/v1/namespaces/default/secrets' AS request_uri,
  'system:serviceaccount:default:default' AS username,
  UUID_STRING() AS user_uid,
  CONCAT('10.42.1.', ((seq4() % 5) + 50)::STRING) AS source_ip,
  'kubectl/v1.28.0 (linux/amd64)' AS user_agent,
  'secrets' AS object_resource,
  'default' AS object_namespace,
  200::NUMBER(38,0) AS response_code,
  'allow' AS authz_decision
FROM TABLE(GENERATOR(ROWCOUNT => 15));

-- ============================================================================
-- INCIDENT 2: UNAUTHORIZED SECRETS ACCESS - 403 Forbidden responses
-- Timeline: 7 days ago (reconnaissance phase before main attack)
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SOURCE
SELECT
  DATEADD('minute', seq4() * 3, DATEADD('day', -7, CURRENT_TIMESTAMP())) AS event_time,
  'k8s-master-02.cluster.local' AS hostname,
  'k8s-audit' AS program,
  133::NUMBER(38,0) AS severity,
  '<133> k8s-audit: FORBIDDEN - secrets access denied' AS raw_syslog,
  TO_JSON(OBJECT_CONSTRUCT(
    'kind', 'Event',
    'apiVersion', 'audit.k8s.io/v1',
    'level', 'RequestResponse',
    'verb', IFF(seq4() % 3 = 0, 'get', IFF(seq4() % 3 = 1, 'list', 'delete')),
    'objectRef', OBJECT_CONSTRUCT(
      'resource', 'secrets',
      'namespace', IFF(seq4() % 3 = 0, 'kube-system', IFF(seq4() % 3 = 1, 'prod', 'default')),
      'name', IFF(seq4() % 4 = 0, 'admin-token', IFF(seq4() % 4 = 1, 'database-credentials', IFF(seq4() % 4 = 2, 'api-keys', 'tls-certs')))
    ),
    'user', OBJECT_CONSTRUCT('username', 'attacker-recon'),
    'responseStatus', OBJECT_CONSTRUCT('code', 403, 'reason', 'Forbidden'),
    'annotations', OBJECT_CONSTRUCT('authorization.k8s.io/decision', 'forbid', 'authorization.k8s.io/reason', 'RBAC: access denied')
  )) AS raw_event_json,
  UUID_STRING() AS audit_id,
  'ResponseComplete' AS stage,
  'RequestResponse' AS level,
  IFF(seq4() % 3 = 0, 'get', IFF(seq4() % 3 = 1, 'list', 'delete')) AS verb,
  CONCAT('/api/v1/namespaces/', IFF(seq4() % 3 = 0, 'kube-system', IFF(seq4() % 3 = 1, 'prod', 'default')), '/secrets') AS request_uri,
  'attacker-recon' AS username,
  UUID_STRING() AS user_uid,
  '185.220.101.42' AS source_ip,  -- Same attacker IP range as brute force
  'curl/7.68.0' AS user_agent,
  'secrets' AS object_resource,
  IFF(seq4() % 3 = 0, 'kube-system', IFF(seq4() % 3 = 1, 'prod', 'default')) AS object_namespace,
  403::NUMBER(38,0) AS response_code,
  'forbid' AS authz_decision
FROM TABLE(GENERATOR(ROWCOUNT => 40));

-- ============================================================================
-- INCIDENT 2b: DELETE ATTEMPTS on critical resources (privilege escalation)
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SOURCE
SELECT
  DATEADD('minute', seq4() * 10, DATEADD('day', -6, CURRENT_TIMESTAMP())) AS event_time,
  'k8s-master-01.cluster.local' AS hostname,
  'k8s-audit' AS program,
  133::NUMBER(38,0) AS severity,
  '<133> k8s-audit: DELETE attempt on critical resource' AS raw_syslog,
  TO_JSON(OBJECT_CONSTRUCT(
    'kind', 'Event',
    'apiVersion', 'audit.k8s.io/v1',
    'level', 'RequestResponse',
    'verb', 'delete',
    'objectRef', OBJECT_CONSTRUCT(
      'resource', IFF(seq4() % 3 = 0, 'deployments', IFF(seq4() % 3 = 1, 'configmaps', 'secrets')),
      'namespace', 'prod',
      'name', IFF(seq4() % 4 = 0, 'critical-app', IFF(seq4() % 4 = 1, 'database-config', 'api-gateway'))
    ),
    'user', OBJECT_CONSTRUCT('username', 'attacker-escalation'),
    'responseStatus', OBJECT_CONSTRUCT('code', 403, 'reason', 'Forbidden'),
    'annotations', OBJECT_CONSTRUCT('authorization.k8s.io/decision', 'forbid')
  )) AS raw_event_json,
  UUID_STRING() AS audit_id,
  'ResponseComplete' AS stage,
  'RequestResponse' AS level,
  'delete' AS verb,
  CONCAT('/apis/apps/v1/namespaces/prod/', IFF(seq4() % 3 = 0, 'deployments', IFF(seq4() % 3 = 1, 'configmaps', 'secrets'))) AS request_uri,
  'attacker-escalation' AS username,
  UUID_STRING() AS user_uid,
  '185.220.101.55' AS source_ip,
  'curl/7.68.0' AS user_agent,
  IFF(seq4() % 3 = 0, 'deployments', IFF(seq4() % 3 = 1, 'configmaps', 'secrets')) AS object_resource,
  'prod' AS object_namespace,
  403::NUMBER(38,0) AS response_code,
  'forbid' AS authz_decision
FROM TABLE(GENERATOR(ROWCOUNT => 20));

COMMENT ON TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SOURCE IS
'Seeded Kubernetes audit logs (last 30 days) with injected incidents: crypto mining pod + unauthorized secrets access + delete attempts.';

GRANT SELECT ON TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.KUBERNETES_AUDIT_LOGS_SOURCE TO ROLE PUBLIC;

