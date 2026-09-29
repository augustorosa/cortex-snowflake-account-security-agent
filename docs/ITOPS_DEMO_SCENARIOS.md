# IT Ops + Security Demo Scenarios (answer keys)

The demo injects these storylines on top of about 6 months of synthetic baseline data. Scenario rows are tagged `SOURCE = 'scenario:<name>'` in the RAW tables. `D-n` means n days before the demo end date (the day `01_seed_reference_data.sql` was last run). Times are UTC.

`tests/itops_demo_tests.sql` asserts that every storyline is detectable.

## S1: Change-induced JD Edwards outage with Fabric CDW / Power BI impact

**Ask:** "Why did alerts spike on JDE-SQL01 last month and what was the downstream impact on Finance reporting?"

| When | System | Event |
|---|---|---|
| D-35 22:00 | ServiceDesk Plus | **CHG 1450**: Emergency "Apply SQL Server 2022 CU14 and TempDB reconfiguration - JDE-SQL01". Owner Jordan Patel, CAB bypass (verbal), back-out plan **not tested**, closure **Failed** |
| D-35 22:15 to D-34 04:00 | LogicMonitor | About 160 Critical/Error alerts on JDE-SQL01 (PageLifeExpectancy, CPU, connections), JDE-APP01..03 services, JDE-WEB01/02 HTTPS, JDE-BATCH01, FABRIC-GW01 ping. Downtime on JDE-SQL01: 95 min, then 180 min |
| D-34 02:00 | Fabric | `PL_JDE_Ingest_Nightly` **Failed**: "Copy activity failed via on-premises data gateway FABRIC-GW01: Cannot connect to JDE-SQL01:1433 (SQL error 10060)". Silver and gold steps **Cancelled** |
| D-34 04:15 | Power BI | `SM_Finance_GL`, `SM_AP_AR` and `SM_Executive_KPI` refresh **successfully on stale gold data**, so reports look normal but show yesterday's numbers |
| D-34 06:00 to 12:00 | ServiceDesk Plus | 14 P1 and 20 P2 JD Edwards incidents (JDE unavailable, cannot post journals, AP payment run failed), mostly assigned to Jordan Patel |
| D-34 09:30 | ServiceDesk Plus | P2 **14600** from an Executive: "Finance - GL Summary report still shows yesterday's numbers (month-end close)" |
| D-34 | Fabric capacity | Manual reloads push F64 over capacity, causing 35 then 48 minutes of interactive throttling |
| D-34 13:00 | Fabric | Manual rerun of ingest fails again (lock timeout on F0911) |
| D-33 00:00 | ServiceDesk Plus | **CHG 1451** rollback, **Success** |
| D-33 01:00 to 05:00 | Fabric | Manual ingest, then silver, gold and model refreshes all complete; CDW fresh again |

**Key facts:** CDW gold staleness was about 28 hours at 08:00 on D-34. Runbook RB-101 says never change TempDB in the same change as a CU. Policy POL-003 requires a tested back-out plan for emergency changes.

## S2: Service account compromise (svc_jde_integration)

**Ask:** "Map out the security incident involving svc_jde_integration from start to finish."

| When | System | Stage | Event |
|---|---|---|---|
| D-62 03:00 | Entra ID | Credential access | Password spray: 420 failures (50126 / 50053) from 185.220.101.0/24 (DE/NL/RO) across 120 users plus the service account |
| D-62 06:00 | Sentinel | | **#4061** Password spray, Medium, closed **BenignPositive** by MSSP ("no successful sign-ins") |
| D-61 04:12 | Entra ID | Initial access | **Successful** sign-in by svc_jde_integration from **185.220.101.47**: single factor, Conditional Access notApplied |
| D-61 04:17 | Sentinel | | **#4063** Unfamiliar sign-in properties, closed **FalsePositive** ("expected automation traffic") |
| (about 2 weeks dormant) | | | |
| D-47 02:31 to 02:47 | Entra ID + Azure | Privilege escalation / persistence | Azure Portal sign-in; `roleAssignments/write` (Contributor on rg-jde-prod); new app secret and service principal credentials on JDE-Integration-App |
| (about 2 weeks dormant) | | | |
| D-33 01:12 to 01:40 | Azure + Defender | Execution / credential access | `runCommand` on **JDE-APP02** (Windows Server 2012 R2, end of support); Defender: encoded PowerShell (T1059.001), LSASS dump via comsvcs.dll (T1003.001); `listKeys` on stcdwstaging |
| D-32 01:25 to 01:58 | Fabric + Power BI | Collection | NSG rule allow-out-443-any; Fabric sign-in; `SELECT *` from gold.fact_ap_invoice (1.92M rows) and gold.fact_gl_journal (4.81M rows); 4 Power BI CSV exports (AP Aging x2, GL Summary, Executive KPI) from 185.220.101.47 |
| D-32 02:10 | Defender | Exfiltration | rclone copy to cloud storage (T1567.002) |
| D-32 02:15 | Sentinel | | **#4127** multi-stage incident, High, **TruePositive** |
| D-32 02:35 | ServiceDesk Plus | Response | P1 **14700** Security incident; emergency **CHG 1460**: disable account, rotate secrets, isolate JDE-APP02 |

**Key facts:**
- The MSSP dismissed the two early incidents. Runbook RB-201 says not to close a spray as benign until successful sign-ins from the spray IPs have been reviewed.
- Open risk RSK-17 (POL-202) covers the service account being excluded from MFA and Conditional Access.
- The compromised host is end of support (KB-401).

## S3: Overloaded engineer

**Ask:** "Where is each technician spending their time? Who is overloaded?"

- Jordan Patel (Business Applications):
  - about 306 tickets, which is the highest by far;
  - about 30% SLA breach rate against about 9% for peers;
  - owner of the failed CHG 1450;
  - 6 Smartsheet projects, 4 of them late (Red or Yellow).
- Technicians flagged `low_ticket_usage` log about 14 tickets each against about 87 for the rest. Their workload is invisible in ServiceDesk Plus, which matches the client comment that only half the team uses the ticketing system.

## S4: AI gateway cost spike

**Ask:** "Which department is driving AI cost in the last 30 days and is it following the routing policy?"

- Sales & Marketing sent about 9,000 **simple** prompts with `route_reason = user_override` to **claude-opus-4-1**, from the client app "Marketing Copy Assistant (browser extension)", in the last 30 days.
- That is about 5x the next department's spend and exceeds the $250/month budget in POL-501.

## S5: Unused Microsoft 365 licenses

**Ask:** "How many licenses are unused and what would we save?"

- Microsoft 365 E5: 450 prepaid, 441 assigned, 336 active in the last 30 days, which is **74.7% utilization**.
- That leaves **114 unused seats**, about **$78k per year** at $57 per user per month.
- Copilot: 150 seats at 80% utilization. Teams Premium and several SDP software titles (AutoCAD LT, Tableau Creator, Zoom) are also under-allocated.

## S6: End-of-support servers hosting business applications

**Ask:** "Which servers are past end of support and what runs on them?"

- JDE-APP02, JDE-APP03 and JDE-BATCH01 run Windows Server 2012 R2 (end of support 2023-10-10).
- ONESTREAM-SQL01 runs SQL Server 2014 (end of support 2024-07-09).
- PRINT01 and several generic SRV hosts are also affected.
- About 18% of workstations still run Windows 10 22H2, and HP EliteBook 840 G5 / Dell Latitude 5400 hardware is out of vendor support.
- JDE-APP02 links to S2: the attacker executed code on it.

## Baseline characteristics (for KPI dashboards)

| KPI | Demo value |
|---|---|
| SLA compliance | about 88% |
| First contact resolution | about 62% |
| MTTR by priority | P1 about 8h, P4 about 90h |
| Alert noise ratio | about 57% |
| Tier 1 uptime | about 99.96% |
| CMDB completeness | about 82%, with 3 servers not in LogicMonitor and 4 network devices not in the CMDB |
| Change failure rate | about 10% |
| F64 capacity utilization | about 43% |
