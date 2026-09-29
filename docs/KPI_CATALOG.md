# IT Operations KPI Catalog

These KPIs back the five TAC dashboards and the `IT_OPS_SECURITY_AGENT`. Each one is defined once, as a metric in `COWORK.IT_OPS.IT_OPS_SECURITY_SVW`, so Power BI, the agent and ad-hoc SQL all return the same number.

Conventions:
- Time windows use the event date (created, started or activity date).
- MTTR is measured on requests with `request_type = 'Incident'` and a `resolved_at`.

## 1. IT Operations Overview (CIO, IT Directors)

| KPI | SVW metric | Definition |
|---|---|---|
| MTTR trend | `requests.mttr_hours` by `requests.created_month` | `AVG(DATEDIFF(minute, created_at, resolved_at)) / 60` for resolved incidents |
| SLA compliance % | `requests.sla_compliance_pct` | `1 - SUM(is_sla_breached) / COUNT(resolved requests)` |
| Ticket volume | `requests.ticket_count` | `COUNT(request_id)`, split by month, category or mode |
| System uptime % | `device_health.uptime_pct` | `1 - SUM(downtime_minutes) / SUM(1440)` across monitored device-days, filterable by tier and application |

## 2. Service Desk Performance (Service Desk Managers)

| KPI | SVW metric | Definition |
|---|---|---|
| MTTR by priority | `requests.mttr_hours` by `priority_code` | as above, P1 to P4 |
| First contact resolution % | `requests.fcr_pct` | resolved requests with `is_fcr = TRUE AND reassignment_count = 0 AND is_reopened = FALSE` / resolved requests |
| Backlog aging | `requests.open_backlog_count` by `backlog_age_bucket` | open requests (`status IN ('Open','In Progress','On Hold')`) bucketed `0-2d`, `3-7d`, `8-30d`, `30d+` |
| Workload | `requests.ticket_count`, `worklogs.worklog_hours`, `projects.project_count` by technician | tickets handled, hours logged in SDP, and Smartsheet projects assigned per technician / support group |
| Reassignment rate | `requests.reassignment_rate_pct` | requests with `reassignment_count > 0` / requests |

## 3. Infrastructure Health (IT Operations / SRE)

| KPI | SVW metric | Definition |
|---|---|---|
| Uptime % | `device_health.uptime_pct` | per device, group, tier or application |
| Alert volume | `alerts.alert_count` | LogicMonitor alerts by severity / datasource / day |
| Noise ratio % | `alerts.noise_ratio_pct` | alerts that cleared in under 15 minutes without acknowledgement, or fired during scheduled downtime (SDT), / all alerts |
| Utilization | `device_health.avg_cpu_pct`, `avg_p95_cpu_pct`, `avg_memory_pct`, `max_disk_used_pct`, `hot_device_count` | daily datapoint roll-ups. A hot device has a 30-day average p95 CPU of 85% or more, or p95 memory of 90% or more |
| Change-related alerts | `changes.alerts_after_change` | alerts on the change's CI (and CIs that depend on it) within 48 hours after `scheduled_start_time` |
| Change failure rate % | `changes.change_failure_rate_pct` | changes with `closure_code IN ('Failed','Rolled Back')` / completed changes |

## 4. Technology and AI Adoption (CTO, IT Finance)

| KPI | SVW metric | Definition |
|---|---|---|
| License utilization % (M365) | `m365_licenses.m365_utilization_pct` | active assigned users (activity in last 30 days) / prepaid units, per SKU |
| Unused licenses and waste | `m365_licenses.unused_license_seats`, `m365_licenses.license_annual_waste_usd` | `(prepaid - active)` and `× monthly list price × 12` |
| License utilization % (SDP software) | `software_licenses.software_allocation_pct` | `allocated_licenses / purchased_licenses` |
| AI adoption % | `ai_adoption.ai_adoption_pct` | users with Copilot or AI gateway activity in the month / employees |
| AI cost | `ai_requests.ai_cost_usd`, `ai_requests.ai_total_tokens` | AI gateway spend and tokens by department, model and route reason |
| Premium model misuse % | `ai_requests.premium_simple_pct` | premium-model requests classified `simple` / all requests |
| Cost per user | `cost_per_user.cost_per_active_user_usd` | monthly (M365 license cost + AI gateway cost) / active users, by department |

## 5. Asset and Configuration Management (IT Asset Manager)

| KPI | SVW metric | Definition |
|---|---|---|
| CMDB completeness % | `assets.cmdb_completeness_pct` | assets with owner, support group, environment, site, product, OS and one or more CI relationships (servers only) / assets |
| CMDB health | `assets.stale_asset_count`, `cmdb_recon.missing_in_logicmonitor_count`, `cmdb_recon.missing_in_cmdb_count` | stale means `last_scan_time` older than 30 days. Reconciliation compares SDP servers with LogicMonitor devices |
| Lifecycle distribution | `assets.asset_count` by `asset_state`, `age_band` | In Use / In Store / In Repair / Expired / Disposed, and age bands 0-1y, 1-3y, 3-5y, 5y+ |
| EOL / EOS exposure | `assets.eos_asset_count`, `assets.eos_within_12m_count` | OS or product past (or within 12 months of) end of support, from `REF_PRODUCT_LIFECYCLE` |
| Warranty expired | `assets.warranty_expired_count` | `warranty_expiry < CURRENT_DATE` for In Use assets |

## 6. Security (troubleshooting agent)

| KPI | SVW metric | Definition |
|---|---|---|
| Failed sign-in rate % | `signins.failed_signin_pct` | `status.errorCode <> 0` / sign-ins |
| MFA coverage % | `signins.mfa_pct` | successful sign-ins with `authenticationRequirement = multiFactorAuthentication` / successful sign-ins |
| Risky sign-ins | `signins.risky_signin_count` | `riskLevelDuringSignIn IN ('medium','high')` |
| Open security incidents | `sentinel_incidents.open_security_incident_count` by severity | `Status <> 'Closed'` |
| Security MTTR (hours) | `sentinel_incidents.security_incident_mttr_hours` | `ClosedTime - CreatedTime` |
| Endpoint alerts | `defender_alerts.defender_alert_count` | by severity, category, device |

## 7. Microsoft Fabric CDW and Power BI (Data Platform)

| KPI | SVW metric | Definition |
|---|---|---|
| Pipeline / refresh success % | `fabric_jobs.job_success_rate_pct` | completed job runs / all runs (pipelines, notebooks, semantic model refreshes) |
| CDW data freshness | `cdw_freshness.max_gold_staleness_hours`, `stale_day_count` | hours since last successful `PL_Silver_To_Gold` at 08:00 UTC; stale when over 24h |
| Capacity utilization % | `fabric_capacity.capacity_utilization_pct` | daily CU seconds / (64 CU × 86,400) for `tac-fabric-f64` |
| Throttling | `fabric_capacity.max_throttling_minutes`, `throttled_day_count` | interactive throttling minutes from the Capacity Metrics app |
| Report usage | `powerbi_activity.report_view_count`, `pbi_active_users` | Power BI view events |
| Report exports (security) | `powerbi_activity.export_count`, `exported_rows_total` | export events by user and IP |
| Warehouse reads | `warehouse_queries.wh_rows_read`, `wh_query_count` | `queryinsights.exec_requests_history` for `WH_CDW_Gold` |

## 8. Cross-source tracing

`event_timeline` holds the key events from every source in one timeline, with common actor, host, IP, severity and detail columns. Order it by `event_at` to reconstruct an outage or a security incident. Filter by host (for example `JDE-SQL01`), account (`svc_jde_integration@tacdemo.com`) or IP (`185.220.101.47`).

## Expected demo ranges (asserted in `tests/itops_demo_tests.sql`)

| KPI | Expected |
|---|---|
| SLA compliance | 84-93% |
| FCR | 55-72% |
| Alert noise ratio | 50-75% |
| CMDB completeness | 70-88% |
| M365 E5 utilization | 70-80% |
| Uptime (Tier 1) | 99.5-99.99% |
| Hot devices | 3-20 |
| Change failure rate | 3-15% |
| F64 capacity utilization | 30-60% |
