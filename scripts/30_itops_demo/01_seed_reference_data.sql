-- ============================================================================
-- 30_itops_demo/01_seed_reference_data.sql
-- IT Operations + Security demo (TAC): reference + seed entities
--
-- Creates in COWORK.IT_OPS:
--   REF_DEMO_CONFIG        anchor date for the 180-day synthetic window
--   R(seed, salt)          deterministic pseudo-random [0,1) helper (reproducible demo)
--   SEED_PEOPLE            640 people (40 IT technicians in 6 support groups)
--   SEED_SERVERS           150 servers (JDE, OneStream, Fabric gateway, infra, generic)
--   SEED_WORKSTATIONS      700 end-user devices
--   REF_PRODUCT_LIFECYCLE  OS / hardware end-of-support dates (SDP has no native EOL field)
--   REF_LICENSE_PRICES     M365 list prices (USD / user / month)
--   REF_SLA_TARGETS        SDP SLA targets by priority
--
-- Re-runnable: everything is CREATE OR REPLACE. Re-run 02..08 afterwards.
-- ============================================================================

USE ROLE cortex_role;
USE WAREHOUSE cortex_wh;
CREATE SCHEMA IF NOT EXISTS COWORK.IT_OPS;
USE SCHEMA COWORK.IT_OPS;

-- Anchor: the synthetic window is the 180 days ending on the day 01 was run.
-- Every later script reads the anchor from here so re-runs stay consistent.
CREATE OR REPLACE TABLE REF_DEMO_CONFIG AS
SELECT CURRENT_DATE() AS demo_end_date,
       DATEADD(day, -180, CURRENT_DATE()) AS demo_start_date,
       'tacdemo.com' AS email_domain;

-- Deterministic uniform [0,1): same inputs always give the same value.
CREATE OR REPLACE FUNCTION R(seed NUMBER, salt VARCHAR)
RETURNS FLOAT
AS 'MOD(ABS(HASH(seed, salt)), 1000000)::FLOAT / 1000000.0';

-- ----------------------------------------------------------------------------
-- People: index 0..39 are IT technicians. Person 0 is Jordan Patel
-- (Business Applications), the overloaded-engineer storyline.
-- Technicians 34..39 rarely log tickets (the client says only part of the
-- team uses the ticketing system).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE SEED_PEOPLE AS
WITH names AS (
  SELECT ARRAY_CONSTRUCT('Jordan','Alex','Taylor','Morgan','Casey','Riley','Jamie','Avery','Quinn','Drew',
                         'Cameron','Reese','Parker','Rowan','Skyler','Dakota','Emerson','Finley','Harper','Kendall',
                         'Logan','Micah','Noah','Olivia','Priya','Sam','Tess','Uma','Victor','Wes',
                         'Xavier','Yara','Zoe','Liam','Maya','Nina','Omar','Paula','Raj','Sofia') AS fn,
         ARRAY_CONSTRUCT('Patel','Nguyen','Smith','Garcia','Kim','Brown','Chen','Martin','Lopez','Wilson',
                         'Singh','Tremblay','Roy','Gagnon','Walker','Young','Hall','Allen','Wright','King') AS ln
),
g AS (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 640)))
SELECT
  g.i                                                     AS person_idx,
  n.fn[g.i % 40]::STRING                                  AS first_name,
  n.ln[((g.i + FLOOR(g.i / 40)) % 20)::INT]::STRING                      AS last_name,
  first_name || ' ' || last_name                          AS full_name,
  LOWER(first_name || '.' || last_name || '@tacdemo.com') AS email,
  (g.i < 40)                                              AS is_technician,
  IFF(g.i < 40,
      ARRAY_CONSTRUCT('Business Applications','Service Desk','Infrastructure','Network',
                      'Security','Cloud Platform')[(g.i % 6)::INT]::STRING,
      NULL)                                               AS support_group,
  (g.i BETWEEN 34 AND 39)                                 AS low_ticket_usage,
  IFF(g.i < 40, 'Information Technology',
      ARRAY_CONSTRUCT('Finance','Operations','Sales & Marketing','Human Resources','Executive')
        [(IFF(R(g.i,'dept') < 0.06, 4, FLOOR(R(g.i,'dept2') * 4)))::INT]::STRING) AS department,
  ARRAY_CONSTRUCT('Denver HQ','Los Angeles','Ottawa','London','Remote')[(FLOOR(R(g.i,'site') * 5))::INT]::STRING AS site,
  IFF(g.i < 40,
      ARRAY_CONSTRUCT('Business Systems Analyst','Service Desk Analyst','Systems Engineer','Network Engineer',
                      'Security Analyst','Cloud Engineer')[(g.i % 6)::INT]::STRING,
      'Staff')                                            AS job_title
FROM g CROSS JOIN names n;

-- ----------------------------------------------------------------------------
-- Servers: 30 named business / infrastructure servers + 120 generic.
-- JDE-APP02, JDE-APP03 and JDE-BATCH01 run Windows Server 2012 R2 (EOS) and
-- ONESTREAM-SQL01 runs SQL Server 2014 (EOS). This is the EOL storyline.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE SEED_SERVERS AS
WITH named AS (
  SELECT column1 AS hostname, column2 AS application, column3 AS os, column4 AS db_engine,
         column5 AS tier, column6 AS environment, column7 AS support_group, column8 AS product
  FROM VALUES
    ('JDE-SQL01','JD Edwards EnterpriseOne','Windows Server 2022','SQL Server 2022','Tier 1','Production','Business Applications','Azure VM E16ds v5'),
    ('JDE-SQL02','JD Edwards EnterpriseOne','Windows Server 2022','SQL Server 2022','Tier 1','Production','Business Applications','Azure VM E16ds v5'),
    ('JDE-APP01','JD Edwards EnterpriseOne','Windows Server 2022',NULL,'Tier 1','Production','Business Applications','Azure VM D8s v5'),
    ('JDE-APP02','JD Edwards EnterpriseOne','Windows Server 2012 R2',NULL,'Tier 1','Production','Business Applications','Azure VM D8s v3'),
    ('JDE-APP03','JD Edwards EnterpriseOne','Windows Server 2012 R2',NULL,'Tier 1','Production','Business Applications','Azure VM D8s v3'),
    ('JDE-BATCH01','JD Edwards EnterpriseOne','Windows Server 2012 R2',NULL,'Tier 1','Production','Business Applications','Azure VM D4s v3'),
    ('JDE-WEB01','JD Edwards EnterpriseOne','Windows Server 2022',NULL,'Tier 1','Production','Business Applications','Azure VM D4s v5'),
    ('JDE-WEB02','JD Edwards EnterpriseOne','Windows Server 2022',NULL,'Tier 1','Production','Business Applications','Azure VM D4s v5'),
    ('JDE-DEV01','JD Edwards EnterpriseOne','Windows Server 2022','SQL Server 2022','Tier 3','Development','Business Applications','Azure VM D4s v5'),
    ('ONESTREAM-APP01','OneStream','Windows Server 2019',NULL,'Tier 1','Production','Business Applications','Azure VM D8s v4'),
    ('ONESTREAM-APP02','OneStream','Windows Server 2019',NULL,'Tier 1','Production','Business Applications','Azure VM D8s v4'),
    ('ONESTREAM-SQL01','OneStream','Windows Server 2016','SQL Server 2014','Tier 1','Production','Business Applications','Azure VM E8s v3'),
    ('FABRIC-GW01','Microsoft Fabric Data Gateway','Windows Server 2022',NULL,'Tier 2','Production','Cloud Platform','Azure VM D4s v5'),
    ('FABRIC-GW02','Microsoft Fabric Data Gateway','Windows Server 2022',NULL,'Tier 2','Production','Cloud Platform','Azure VM D4s v5'),
    ('DC01','Active Directory','Windows Server 2019',NULL,'Tier 1','Production','Infrastructure','Dell PowerEdge R650'),
    ('DC02','Active Directory','Windows Server 2019',NULL,'Tier 1','Production','Infrastructure','Dell PowerEdge R650'),
    ('AADC01','Entra Connect Sync','Windows Server 2019',NULL,'Tier 1','Production','Security','Azure VM D2s v5'),
    ('FS01','File Services','Windows Server 2016',NULL,'Tier 2','Production','Infrastructure','Dell PowerEdge R740'),
    ('FS02','File Services','Windows Server 2016',NULL,'Tier 2','Production','Infrastructure','Dell PowerEdge R740'),
    ('PRINT01','Print Services','Windows Server 2012 R2',NULL,'Tier 3','Production','Infrastructure','Dell PowerEdge R630'),
    ('EXCH-HYB01','Exchange Hybrid','Windows Server 2019',NULL,'Tier 2','Production','Infrastructure','Azure VM D4s v4'),
    ('VPN-GW01','Remote Access VPN','Ubuntu 22.04 LTS',NULL,'Tier 1','Production','Network','Azure VM D2s v5'),
    ('SMARTSHEET-SYNC01','Smartsheet Connector','Windows Server 2022',NULL,'Tier 3','Production','Business Applications','Azure VM B2ms'),
    ('SDP-APP01','ManageEngine ServiceDesk Plus','Windows Server 2022','PostgreSQL 15','Tier 2','Production','Service Desk','Azure VM D4s v5'),
    ('LM-COLLECTOR01','LogicMonitor Collector','Windows Server 2022',NULL,'Tier 2','Production','Infrastructure','Azure VM D2s v5'),
    ('LM-COLLECTOR02','LogicMonitor Collector','Windows Server 2022',NULL,'Tier 2','Production','Infrastructure','Dell PowerEdge R640'),
    ('AI-GW01','AI Gateway','Ubuntu 22.04 LTS',NULL,'Tier 2','Production','Cloud Platform','Azure Container Apps'),
    ('AI-GW02','AI Gateway','Ubuntu 22.04 LTS',NULL,'Tier 2','Production','Cloud Platform','Azure Container Apps'),
    ('BACKUP01','Backup Services','Windows Server 2019',NULL,'Tier 2','Production','Infrastructure','Dell PowerEdge R750'),
    ('SQL-SHARED01','Shared SQL Services','Windows Server 2019','SQL Server 2019','Tier 2','Production','Infrastructure','Azure VM E8s v4')
),
generic AS (
  SELECT
    'SRV-' || ARRAY_CONSTRUCT('WEB','APP','DB','UTIL','FILE')[(i % 5)::INT]::STRING || '-' || LPAD(i + 1, 3, '0') AS hostname,
    'General Business Services' AS application,
    CASE WHEN R(i,'os') < 0.45 THEN 'Windows Server 2022'
         WHEN R(i,'os') < 0.73 THEN 'Windows Server 2019'
         WHEN R(i,'os') < 0.86 THEN 'Windows Server 2016'
         WHEN R(i,'os') < 0.91 THEN 'Windows Server 2012 R2'
         ELSE 'Ubuntu 22.04 LTS' END AS os,
    IFF(i % 5 = 2, IFF(R(i,'db') < 0.8, 'SQL Server 2019', 'SQL Server 2016'), NULL) AS db_engine,
    IFF(R(i,'tier') < 0.35, 'Tier 2', 'Tier 3') AS tier,
    CASE WHEN R(i,'env') < 0.78 THEN 'Production' WHEN R(i,'env') < 0.9 THEN 'Test' ELSE 'Development' END AS environment,
    ARRAY_CONSTRUCT('Infrastructure','Cloud Platform','Business Applications','Network')[(FLOOR(R(i,'grp') * 4))::INT]::STRING AS support_group,
    IFF(R(i,'hw') < 0.6, 'Azure VM D4s v5', 'Dell PowerEdge R640') AS product
  FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 120)))
),
all_srv AS (SELECT * FROM named UNION ALL SELECT * FROM generic)
SELECT
  ROW_NUMBER() OVER (ORDER BY hostname) - 1 AS server_idx,
  s.*,
  -- Owner: a technician from the support group (deterministic)
  o.owner_email,
  -- ~20% of CMDB records are incomplete in at least one field (generic servers only)
  (s.hostname LIKE 'SRV-%' AND R(HASH(s.hostname),'miss_owner') < 0.10) AS missing_owner,
  (s.hostname LIKE 'SRV-%' AND R(HASH(s.hostname),'miss_grp')   < 0.07) AS missing_support_group,
  (s.hostname LIKE 'SRV-%' AND R(HASH(s.hostname),'miss_env')   < 0.05) AS missing_environment,
  (s.hostname LIKE 'SRV-%' AND R(HASH(s.hostname),'miss_rel')   < 0.12) AS missing_relationship,
  -- ~5% of generic servers are not monitored by LogicMonitor
  (s.hostname LIKE 'SRV-%' AND R(HASH(s.hostname),'no_lm')      < 0.06) AS not_in_logicmonitor,
  (s.hostname LIKE 'SRV-%' AND R(HASH(s.hostname),'stale')      < 0.08) AS stale_scan,
  DATEADD(day, -FLOOR(200 + R(HASH(s.hostname),'acq') * 1800), CURRENT_DATE()) AS acquisition_date,
  CASE WHEN R(HASH(s.hostname),'state') < 0.94 THEN 'In Use'
       WHEN R(HASH(s.hostname),'state') < 0.97 THEN 'In Repair'
       ELSE 'In Store' END AS asset_state,
  ARRAY_CONSTRUCT('Denver HQ','Azure Canada Central','Azure West US 2')[(FLOOR(R(HASH(s.hostname),'site') * 3))::INT]::STRING AS site
FROM all_srv s
LEFT JOIN (SELECT support_group, MIN(email) AS owner_email FROM SEED_PEOPLE
           WHERE support_group IS NOT NULL GROUP BY support_group) o
  ON o.support_group = s.support_group;

-- Named Tier 1 servers are always "In Use"
UPDATE SEED_SERVERS SET asset_state = 'In Use' WHERE hostname NOT LIKE 'SRV-%';

-- ----------------------------------------------------------------------------
-- Workstations: 700 laptops/desktops assigned to people.
-- Windows 10 22H2 (EOS 2025-10-14) is still on ~18% of devices.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE SEED_WORKSTATIONS AS
SELECT
  i AS ws_idx,
  'WS-' || LPAD(i + 1, 4, '0') AS hostname,
  CASE WHEN R(i,'prod') < 0.30 THEN 'Dell Latitude 5440'
       WHEN R(i,'prod') < 0.52 THEN 'Lenovo ThinkPad T14 Gen 4'
       WHEN R(i,'prod') < 0.70 THEN 'Dell Latitude 7420'
       WHEN R(i,'prod') < 0.84 THEN 'HP EliteBook 840 G8'
       WHEN R(i,'prod') < 0.94 THEN 'Dell Latitude 5400'
       ELSE 'HP EliteBook 840 G5' END AS product,
  IFF(R(i,'os') < 0.82, 'Windows 11 23H2', 'Windows 10 22H2') AS os,
  CASE WHEN R(i,'st') < 0.82 THEN 'In Use'
       WHEN R(i,'st') < 0.90 THEN 'In Store'
       WHEN R(i,'st') < 0.93 THEN 'In Repair'
       WHEN R(i,'st') < 0.97 THEN 'Expired'
       ELSE 'Disposed' END AS asset_state,
  p.email AS user_email,
  DATEADD(day, -FLOOR(30 + R(i,'acq') * 2100), CURRENT_DATE()) AS acquisition_date,
  (R(i,'stale') < 0.07) AS stale_scan,
  (R(i,'miss_user') < 0.09) AS missing_owner
FROM (SELECT SEQ4() AS i FROM TABLE(GENERATOR(ROWCOUNT => 700))) g
JOIN SEED_PEOPLE p ON p.person_idx = MOD(g.i, 640);

-- Older hardware models run Windows 10 more often
UPDATE SEED_WORKSTATIONS SET os = 'Windows 10 22H2'
WHERE product IN ('Dell Latitude 5400','HP EliteBook 840 G5');

-- ----------------------------------------------------------------------------
-- Reference data
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE REF_PRODUCT_LIFECYCLE (
  product_name VARCHAR, product_kind VARCHAR, vendor VARCHAR,
  end_of_life_date DATE, end_of_support_date DATE, notes VARCHAR
);
INSERT INTO REF_PRODUCT_LIFECYCLE VALUES
  ('Windows Server 2012 R2','Operating System','Microsoft','2018-10-09','2023-10-10','Extended support ended; ESU only'),
  ('Windows Server 2016','Operating System','Microsoft','2022-01-11','2027-01-12','Extended support ends Jan 2027'),
  ('Windows Server 2019','Operating System','Microsoft','2024-01-09','2029-01-09',NULL),
  ('Windows Server 2022','Operating System','Microsoft','2026-10-13','2031-10-14',NULL),
  ('Windows 10 22H2','Operating System','Microsoft','2025-10-14','2025-10-14','End of support; ESU required'),
  ('Windows 11 23H2','Operating System','Microsoft','2025-11-11','2026-11-10','Enterprise edition servicing'),
  ('Ubuntu 22.04 LTS','Operating System','Canonical','2027-04-01','2032-04-01',NULL),
  ('SQL Server 2014','Database','Microsoft','2019-07-09','2024-07-09','Extended support ended'),
  ('SQL Server 2016','Database','Microsoft','2021-07-13','2026-07-14','Extended support ended Jul 2026'),
  ('SQL Server 2019','Database','Microsoft','2025-02-28','2030-01-08',NULL),
  ('SQL Server 2022','Database','Microsoft','2028-01-11','2033-01-11',NULL),
  ('HP EliteBook 840 G5','Hardware','HP','2021-06-30','2024-06-30','Vendor support ended'),
  ('Dell Latitude 5400','Hardware','Dell','2022-05-31','2025-05-31','Vendor support ended'),
  ('Dell Latitude 7420','Hardware','Dell','2024-03-31','2027-03-31',NULL),
  ('Dell PowerEdge R630','Hardware','Dell','2019-05-31','2024-05-31','Vendor support ended'),
  ('Dell PowerEdge R740','Hardware','Dell','2023-08-31','2027-08-31',NULL);

CREATE OR REPLACE TABLE REF_LICENSE_PRICES (
  sku_part_number VARCHAR, sku_display_name VARCHAR, monthly_price_usd NUMBER(10,2)
);
INSERT INTO REF_LICENSE_PRICES VALUES
  ('SPE_E5','Microsoft 365 E5',57.00),
  ('SPE_E3','Microsoft 365 E3',36.00),
  ('Microsoft_365_Copilot','Microsoft 365 Copilot',30.00),
  ('POWER_BI_PRO','Power BI Pro',14.00),
  ('VISIOCLIENT','Visio Plan 2',15.00),
  ('PROJECTPROFESSIONAL','Project Plan 3',30.00),
  ('Microsoft_Teams_Premium','Teams Premium',10.00),
  ('SPE_F3','Microsoft 365 F3',8.00);

CREATE OR REPLACE TABLE REF_SLA_TARGETS (
  priority VARCHAR, priority_code VARCHAR, first_response_hours NUMBER, resolution_hours NUMBER
);
INSERT INTO REF_SLA_TARGETS VALUES
  ('Urgent','P1',0.5,6),
  ('High','P2',1,24),
  ('Medium','P3',4,72),
  ('Low','P4',8,120);

SELECT 'seed' AS step,
  (SELECT COUNT(*) FROM SEED_PEOPLE) AS people,
  (SELECT COUNT(*) FROM SEED_SERVERS) AS servers,
  (SELECT COUNT(*) FROM SEED_WORKSTATIONS) AS workstations;
