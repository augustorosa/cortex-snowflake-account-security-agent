# Snowflake Cortex Agents Lab: Account Monitoring, Security, and IT Operations

Cortex Agents + Semantic Views that let people ask operational questions in plain English. The lab has three modules:

| Module | Folder | What it answers |
|---|---|---|
| Account monitoring | `scripts/10_account_monitoring` | Snowflake cost, performance, governance and login posture from `SNOWFLAKE.ACCOUNT_USAGE` |
| Security telemetry | `scripts/20_security` | Cross-source security investigations over synthetic Cloudflare, CrowdStrike, Kubernetes audit, npm supply-chain and CloudTrail data |
| IT Operations + Security demo | `scripts/30_itops_demo` | IT service desk, infrastructure health, asset/CMDB, license and AI adoption KPIs, plus outage troubleshooting and security incident reconstruction across ManageEngine ServiceDesk Plus, LogicMonitor, Smartsheet, Microsoft Sentinel / Defender XDR / Entra ID / Azure Activity, Microsoft 365, an AI gateway, and the Microsoft Fabric CDW with Power BI |

All data in the security and IT Ops modules is synthetic. The IT Ops demo uses a fictional live-events company, **Summit Live Group (SLG)**, with the email domain `summitlive.example`. It mirrors each vendor's native API/export shape so the same flatten and model pattern applies to real feeds (Snowflake or Microsoft Fabric).

## Repository layout

```
deploy.sh                          snow sql runner (module-aware)
scripts/
  00_foundation/                   role, database, schemas, warehouse, email tool
  10_account_monitoring/           ACCOUNT_USAGE semantic views + agents
  20_security/                     synthetic security sources, flatten views, security SVW + agent
  30_itops_demo/                   IT Ops + Security demo:
    01_seed_reference_data.sql       people, servers, workstations, lifecycle / price / SLA reference
    02_raw_itsm_monitoring.sql       ServiceDesk Plus, LogicMonitor, Smartsheet (native JSON)
    03_raw_security_m365_ai.sql      Entra, Azure Activity, Defender, Sentinel, M365, AI gateway
    04_raw_fabric_powerbi.sql        Fabric items, job runs, capacity, warehouse queries, Power BI activity
    05_inject_scenarios.sql          storylines S1 (outage) S2 (breach) S4 (AI spike)
    06_flatten_views.sql             silver: typed views over RAW
    07_dimensions_kpi_views.sql      gold: DIM_USER, DIM_CI, KPI helpers, EVENT_TIMELINE
    08_knowledge_base_search.sql     runbooks/policies + Cortex Search service
    09_itops_security_svw.sql        semantic view IT_OPS_SECURITY_SVW (+ 23 verified queries)
    10_itops_security_agent.sql      Cortex Agent IT_OPS_SECURITY_AGENT
  utilities/                       column checks, BI queries against semantic views
  _archive/                        superseded scripts kept for reference
tests/
  account_monitoring_tests.sql     checks for modules 10/20
  itops_demo_tests.sql             KPI range + storyline detection checks for module 30
  agent_eval/                      end-to-end agent answers for all 23 verified questions
docs/
  KPI_CATALOG.md                   IT Ops KPI definitions (five dashboards)
  CLIENT_SOURCE_MAPPING.md         vendor API fields -> flattened columns
  ITOPS_DEMO_SCENARIOS.md          injected storylines and answer keys
  ...                              architecture, security scenarios, semantic view guide
```

## Prerequisites

- A role that can run `00_foundation/01_lab_foundations.sql` (ACCOUNTADMIN). It creates `cortex_role`, `cortex_wh`, and the `COWORK` database with schemas `AGENTS`, `TOOLS` and `IT_OPS`.
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index) with a configured connection (`snow connection list`).
- Cortex Agents (with semantic views) and Cortex Search available in the region, or cross-region inference enabled (the foundation script sets `CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION'`).

## Deploy

```bash
# everything
./deploy.sh -c <connection>

# only the IT Ops + Security demo (after foundation has been run once)
./deploy.sh -c <connection> foundation itops tests

# a single script (disable CLI templating; the YAML contains special characters)
snow sql -c <connection> --enable-templating NONE -f scripts/30_itops_demo/09_itops_security_svw.sql
```

Every script is re-runnable: it uses `CREATE OR REPLACE` for derived objects and `IF NOT EXISTS` for account-level objects. `01_seed_reference_data.sql` pins the 180-day window to the day it runs. Re-run 01-10 to roll the window forward.

The optional CloudTrail view (`10_account_monitoring/02_flattened_cloudtrail_logs_views.sql`) needs an existing CloudTrail table. See the commented grants in the foundation script.

## Using the agents

Agents live in `COWORK.AGENTS`:

| Agent | Scope |
|---|---|
| `IT_OPS_SECURITY_AGENT` | IT Ops KPIs, troubleshooting, security incident timelines, resourcing, license/AI cost |
| `SNOWFLAKE_MAINTENANCE_AGENT` | Snowflake account operations (cost/perf/governance) |
| `COST_PERFORMANCE_AGENT` | Snowflake cost and query performance |
| `SECURITY_MONITORING_AGENT` | Snowflake auth posture + synthetic security telemetry |

You can reach them in three ways:
- **Snowflake CoWork:** Snowsight > AI & ML > Snowflake CoWork, then pick the agent.
- **REST:** `POST /api/v2/databases/COWORK/schemas/AGENTS/agents/<AGENT>:run` ([docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-run)).
- **Semantic view only:** query with `SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW METRICS ... DIMENSIONS ...)`.

Try these questions with `IT_OPS_SECURITY_AGENT`:
- "Give me the CIO overview for the last quarter: MTTR trend, SLA compliance, ticket volume and uptime."
- "What is first contact resolution by support group, and how old is the open backlog?"
- "Why did alerts spike on JDE-SQL01 last month and what was the downstream impact on Finance reporting?"
- "Map out the security incident involving svc_jde_integration from start to finish."
- "Where is each technician spending time across tickets and projects?"
- "How many E5 licenses are unused and what would we save?"
- "Which servers are past end of support and what apps run on them?"
- "How is Fabric F64 capacity trending and when did we throttle?"

To check the agent end to end (about 10 minutes): `python3 tests/agent_eval/run_agent_eval.py -c <connection>`.

The answer keys are in `docs/ITOPS_DEMO_SCENARIOS.md`. KPI definitions are in `docs/KPI_CATALOG.md`.

## Status

This is a demo lab. Nothing here is intended for production as-is: public-role grants and synthetic data are demo conveniences.
