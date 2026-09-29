-- ============================================================================
-- 30_itops_demo/09_itops_security_svw.sql
-- Semantic view COWORK.IT_OPS.IT_OPS_SECURITY_SVW
-- One governed definition for every KPI on the five TAC dashboards (see
-- docs/KPI_CATALOG.md) plus security, Fabric CDW / Power BI and cross-source
-- tracing. Used by IT_OPS_SECURITY_AGENT (Cortex Analyst tool) and can also be
-- queried directly with SELECT ... FROM SEMANTIC_VIEW(...).
-- Requires 06, 07. Re-runnable (CREATE OR REPLACE via YAML).
-- ============================================================================

USE ROLE cortex_role;
USE WAREHOUSE cortex_wh;
USE SCHEMA COWORK.IT_OPS;

CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML('COWORK.IT_OPS', $$
name: IT_OPS_SECURITY_SVW
description: >-
  TAC IT operations and security model. Joins ManageEngine ServiceDesk Plus (tickets, changes, worklogs, CMDB/assets,
  software licenses), LogicMonitor (alerts, device health), Smartsheet (IT projects), Microsoft Entra ID sign-ins,
  Microsoft Sentinel, Defender XDR, Azure activity, Microsoft 365 licensing, the AI gateway, and the Microsoft Fabric
  corporate data warehouse (CDW) with Power BI. Conformed keys are user email and hostname.

tables:
  # --------------------------------------------------------------------------
  - name: users
    description: Conformed people and service accounts (employees, IT technicians, svc_* service accounts).
    base_table: {database: COWORK, schema: IT_OPS, table: DIM_USER}
    primary_key: {columns: [user_email]}
    dimensions:
      - {name: user_email, expr: user_email, data_type: VARCHAR, description: Lower-case email / UPN; the join key across all systems., synonyms: [upn, email, account]}
      - {name: full_name, expr: full_name, data_type: VARCHAR, description: Person or account display name., synonyms: [user name, technician name, employee name]}
      - {name: department, expr: department, data_type: VARCHAR, description: Department of the person., sample_values: [Finance, Operations, Sales & Marketing, Human Resources, Executive, Information Technology]}
      - {name: site, expr: site, data_type: VARCHAR, description: Office location.}
      - {name: account_type, expr: account_type, data_type: VARCHAR, description: Employee / IT Staff / Service Account., sample_values: [Employee, IT Staff, Service Account]}
      - {name: user_support_group, expr: support_group, data_type: VARCHAR, description: IT support group of a technician., synonyms: [team, IT team]}
      - {name: is_technician, expr: is_technician, data_type: BOOLEAN, description: True for IT technicians.}
      - {name: low_ticket_usage, expr: low_ticket_usage, data_type: BOOLEAN, description: Technician known to rarely log tickets in ServiceDesk Plus.}

  # --------------------------------------------------------------------------
  - name: cis
    description: Conformed configuration items / hosts across the ServiceDesk Plus CMDB, LogicMonitor and Defender (servers, workstations, network devices).
    base_table: {database: COWORK, schema: IT_OPS, table: DIM_CI}
    primary_key: {columns: [hostname]}
    dimensions:
      - {name: hostname, expr: hostname, data_type: VARCHAR, description: Upper-case host name (CI name)., synonyms: [server, host, device, CI, configuration item], sample_values: [JDE-SQL01, JDE-APP02, FABRIC-GW01, ONESTREAM-SQL01]}
      - {name: ci_type, expr: ci_type, data_type: VARCHAR, sample_values: [Server, Workstation, Network Device]}
      - {name: application, expr: application, data_type: VARCHAR, description: Business application or service the host runs., synonyms: [system, business service, app], sample_values: [JD Edwards EnterpriseOne, OneStream, Microsoft Fabric Data Gateway, Active Directory]}
      - {name: tier, expr: tier, data_type: VARCHAR, description: Criticality tier., sample_values: [Tier 1, Tier 2, Tier 3, End User]}
      - {name: environment, expr: environment, data_type: VARCHAR, sample_values: [Production, Test, Development]}
      - {name: operating_system, expr: os, data_type: VARCHAR, synonyms: [os]}
      - {name: ci_support_group, expr: support_group, data_type: VARCHAR, description: Support group owning the CI.}
      - {name: ci_is_end_of_support, expr: is_end_of_support, data_type: BOOLEAN, description: True when the OS, database or hardware is past vendor end of support.}
      - {name: ci_in_logicmonitor, expr: in_logicmonitor, data_type: BOOLEAN}
      - {name: ci_in_servicedesk_plus, expr: in_servicedesk_plus, data_type: BOOLEAN}

  # --------------------------------------------------------------------------
  - name: requests
    description: ManageEngine ServiceDesk Plus requests (tickets). request_type Incident vs Service Request. Use for MTTR, SLA compliance, ticket volume, FCR, backlog aging and workload.
    base_table: {database: COWORK, schema: IT_OPS, table: SDP_REQUESTS}
    primary_key: {columns: [request_id]}
    dimensions:
      - {name: request_id, expr: request_id, data_type: VARCHAR}
      - {name: request_number, expr: request_number, data_type: VARCHAR, description: SDP display id quoted by staff., synonyms: [ticket number, request id, ticket id]}
      - {name: subject, expr: subject, data_type: VARCHAR}
      - {name: request_type, expr: request_type, data_type: VARCHAR, sample_values: [Incident, Service Request]}
      - {name: priority, expr: priority, data_type: VARCHAR, sample_values: [Urgent, High, Medium, Low]}
      - {name: priority_code, expr: priority_code, data_type: VARCHAR, description: P1=Urgent P2=High P3=Medium P4=Low., sample_values: [P1, P2, P3, P4]}
      - {name: category, expr: category, data_type: VARCHAR, sample_values: [JD Edwards, OneStream, Microsoft Fabric / Power BI, Security, Hardware, Network]}
      - {name: mode, expr: mode, data_type: VARCHAR, description: Channel the ticket came in on., sample_values: [E-Mail, Web Form, Phone Call, Chat]}
      - {name: status, expr: status, data_type: VARCHAR, sample_values: [Open, In Progress, On Hold, Resolved, Closed]}
      - {name: support_group, expr: support_group, data_type: VARCHAR, description: Support group assigned., synonyms: [assignment group, resolver group, team], sample_values: [Service Desk, Business Applications, Infrastructure, Network, Security, Cloud Platform]}
      - {name: technician_email, expr: technician_email, data_type: VARCHAR}
      - {name: technician_name, expr: technician_name, data_type: VARCHAR, synonyms: [assignee, engineer, analyst]}
      - {name: requester_email, expr: requester_email, data_type: VARCHAR}
      - {name: requester_department, expr: department, data_type: VARCHAR}
      - {name: ticket_ci_name, expr: ci_name, data_type: VARCHAR, description: First configuration item linked to the ticket.}
      - {name: backlog_age_bucket, expr: backlog_age_bucket, data_type: VARCHAR, description: Age bucket for open tickets only., sample_values: [0-2d, 3-7d, 8-30d, 30d+]}
      - {name: is_open, expr: is_open, data_type: BOOLEAN}
      - {name: is_sla_breached, expr: is_sla_breached, data_type: BOOLEAN}
      - {name: is_fcr, expr: is_fcr, data_type: BOOLEAN, description: First contact resolution (FCR flag, no reassignment, not reopened).}
      - {name: is_vip_requester, expr: is_vip_requester, data_type: BOOLEAN}
    time_dimensions:
      - {name: created_at, expr: created_at, data_type: TIMESTAMP_NTZ, description: When the ticket was opened.}
      - {name: created_date, expr: created_date, data_type: DATE}
      - {name: created_month, expr: created_month, data_type: DATE}
      - {name: resolved_at, expr: resolved_at, data_type: TIMESTAMP_NTZ}
    facts:
      - {name: resolution_hours, expr: resolution_hours, data_type: NUMBER, description: Hours from created to resolved.}
      - {name: first_response_hours, expr: first_response_hours, data_type: NUMBER}
      - {name: reassignment_count, expr: reassignment_count, data_type: NUMBER}
      - {name: open_age_days, expr: open_age_days, data_type: NUMBER}
    metrics:
      - {name: ticket_count, expr: COUNT(request_id), description: Number of tickets., synonyms: [ticket volume, number of tickets, request count]}
      - {name: incident_count, expr: "SUM(IFF(request_type = 'Incident', 1, 0))"}
      - name: mttr_hours
        expr: "AVG(IFF(request_type = 'Incident' AND resolved_at IS NOT NULL, resolution_hours, NULL))"
        description: Mean time to resolve incidents in hours.
        synonyms: [MTTR, mean time to resolve, mean time to repair, average resolution time]
      - name: sla_compliance_pct
        expr: "100 * (1 - SUM(IFF(resolved_at IS NOT NULL AND is_sla_breached, 1, 0)) / NULLIF(SUM(IFF(resolved_at IS NOT NULL, 1, 0)), 0))"
        description: Percent of resolved tickets resolved within the SLA due-by time.
        synonyms: [SLA compliance, SLA attainment, within SLA percent]
      - {name: sla_breach_count, expr: "SUM(IFF(resolved_at IS NOT NULL AND is_sla_breached, 1, 0))"}
      - name: fcr_pct
        expr: "100 * SUM(IFF(resolved_at IS NOT NULL AND is_fcr, 1, 0)) / NULLIF(SUM(IFF(resolved_at IS NOT NULL, 1, 0)), 0)"
        description: First contact resolution rate for resolved tickets.
        synonyms: [FCR, first call resolution, first contact resolution]
      - {name: open_backlog_count, expr: "SUM(IFF(is_open, 1, 0))", description: Open tickets (Open / In Progress / On Hold)., synonyms: [backlog, open tickets]}
      - {name: reassignment_rate_pct, expr: "100 * SUM(IFF(reassignment_count > 0, 1, 0)) / NULLIF(COUNT(request_id), 0)"}
      - {name: avg_first_response_hours, expr: AVG(first_response_hours)}

  # --------------------------------------------------------------------------
  - name: worklogs
    description: Time technicians logged against tickets in ServiceDesk Plus.
    base_table: {database: COWORK, schema: IT_OPS, table: SDP_WORKLOGS}
    primary_key: {columns: [worklog_id]}
    dimensions:
      - {name: worklog_id, expr: worklog_id, data_type: VARCHAR}
      - {name: worklog_technician_email, expr: technician_email, data_type: VARCHAR}
      - {name: worklog_type, expr: worklog_type, data_type: VARCHAR}
    time_dimensions:
      - {name: worklog_date, expr: worklog_date, data_type: DATE}
    facts:
      - {name: hours_spent, expr: hours_spent, data_type: NUMBER}
    metrics:
      - {name: worklog_hours, expr: SUM(hours_spent), description: Hours logged on tickets., synonyms: [ticket hours, time spent, logged hours]}

  # --------------------------------------------------------------------------
  - name: workload
    description: One row per IT technician summarising tickets, SLA breaches, FCR, ticket hours and Smartsheet projects. Use for "where is staff time going" and resourcing questions.
    base_table: {database: COWORK, schema: IT_OPS, table: TECHNICIAN_WORKLOAD}
    primary_key: {columns: [workload_technician_email]}
    dimensions:
      - {name: workload_technician_email, expr: technician_email, data_type: VARCHAR}
      - {name: workload_technician_name, expr: technician_name, data_type: VARCHAR, synonyms: [engineer, technician]}
      - {name: workload_support_group, expr: support_group, data_type: VARCHAR}
      - {name: workload_low_ticket_usage, expr: low_ticket_usage, data_type: BOOLEAN}
    facts:
      - {name: tickets_assigned, expr: tickets_assigned, data_type: NUMBER}
      - {name: open_tickets, expr: open_tickets, data_type: NUMBER}
      - {name: p1_p2_tickets, expr: p1_p2_tickets, data_type: NUMBER}
      - {name: tech_sla_breach_pct, expr: sla_breach_pct, data_type: NUMBER}
      - {name: tech_fcr_pct, expr: fcr_pct, data_type: NUMBER}
      - {name: ticket_hours, expr: ticket_hours, data_type: NUMBER}
      - {name: active_projects, expr: active_projects, data_type: NUMBER}
      - {name: late_projects, expr: late_projects, data_type: NUMBER}
      - {name: project_hours, expr: project_hours, data_type: NUMBER}
      - {name: total_tracked_hours, expr: total_tracked_hours, data_type: NUMBER}
    metrics:
      - {name: total_tickets_assigned, expr: SUM(tickets_assigned)}
      - {name: total_tracked_hours_sum, expr: SUM(total_tracked_hours), synonyms: [total hours, tracked hours]}
      - {name: total_late_projects, expr: SUM(late_projects)}

  # --------------------------------------------------------------------------
  - name: changes
    description: ServiceDesk Plus change requests (RFCs) with LogicMonitor alerts and incidents on the changed CI and its dependent CIs 48h before vs after.
    base_table: {database: COWORK, schema: IT_OPS, table: CHANGE_ALERT_CORRELATION}
    primary_key: {columns: [change_id]}
    dimensions:
      - {name: change_id, expr: change_id, data_type: VARCHAR}
      - {name: change_number, expr: change_number, data_type: VARCHAR, synonyms: [RFC number, CHG number, change id]}
      - {name: change_title, expr: title, data_type: VARCHAR}
      - {name: change_type, expr: change_type, data_type: VARCHAR, sample_values: [Standard, Minor, Major, Emergency]}
      - {name: change_risk, expr: risk, data_type: VARCHAR}
      - {name: closure_code, expr: closure_code, data_type: VARCHAR, sample_values: [Success, Failed, Rolled Back]}
      - {name: is_failed_change, expr: is_failed_change, data_type: BOOLEAN}
      - {name: change_ci_name, expr: ci_name, data_type: VARCHAR}
      - {name: change_owner_name, expr: owner_name, data_type: VARCHAR}
      - {name: change_support_group, expr: support_group, data_type: VARCHAR}
      - {name: cab_approval, expr: cab_approval, data_type: VARCHAR}
      - {name: backout_plan_tested, expr: backout_plan_tested, data_type: VARCHAR}
    time_dimensions:
      - {name: change_scheduled_start_at, expr: scheduled_start_at, data_type: TIMESTAMP_NTZ}
      - {name: change_date, expr: change_date, data_type: DATE}
    facts:
      - {name: alerts_48h_before, expr: alerts_48h_before, data_type: NUMBER}
      - {name: alerts_48h_after, expr: alerts_48h_after, data_type: NUMBER}
      - {name: critical_alerts_48h_after, expr: critical_alerts_48h_after, data_type: NUMBER}
      - {name: incidents_48h_after, expr: incidents_48h_after, data_type: NUMBER}
    metrics:
      - {name: change_count, expr: COUNT(change_id), synonyms: [number of changes, RFC count]}
      - {name: failed_change_count, expr: "SUM(IFF(is_failed_change, 1, 0))"}
      - name: change_failure_rate_pct
        expr: "100 * SUM(IFF(is_failed_change, 1, 0)) / NULLIF(SUM(IFF(closure_code IS NOT NULL, 1, 0)), 0)"
        synonyms: [change failure rate, failed change percent]
      - {name: alerts_after_change, expr: SUM(alerts_48h_after), description: LogicMonitor alerts on the change CI and dependent CIs within 48h after change start.}
      - {name: incidents_after_change, expr: SUM(incidents_48h_after)}

  # --------------------------------------------------------------------------
  - name: alerts
    description: LogicMonitor alerts. Noise = cleared in under 15 minutes without acknowledgement, or during scheduled downtime.
    base_table: {database: COWORK, schema: IT_OPS, table: LM_ALERTS}
    primary_key: {columns: [alert_id]}
    dimensions:
      - {name: alert_id, expr: alert_id, data_type: VARCHAR}
      - {name: alert_hostname, expr: hostname, data_type: VARCHAR}
      - {name: alert_severity, expr: severity, data_type: VARCHAR, sample_values: [Warning, Error, Critical]}
      - {name: datasource, expr: datasource, data_type: VARCHAR, description: LogicMonitor DataSource (monitor)., sample_values: [WinCPU, WinMemory, Ping, Microsoft_SQLServer_Performance, WinService]}
      - {name: datapoint, expr: datapoint, data_type: VARCHAR}
      - {name: is_noise, expr: is_noise, data_type: BOOLEAN}
      - {name: is_acked, expr: is_acked, data_type: BOOLEAN}
    time_dimensions:
      - {name: alert_started_at, expr: started_at, data_type: TIMESTAMP_NTZ}
      - {name: alert_date, expr: alert_date, data_type: DATE}
    facts:
      - {name: alert_duration_minutes, expr: duration_minutes, data_type: NUMBER}
    metrics:
      - {name: alert_count, expr: COUNT(alert_id), synonyms: [alert volume, number of alerts]}
      - {name: critical_alert_count, expr: "SUM(IFF(alert_severity = 'Critical', 1, 0))"}
      - {name: noise_alert_count, expr: "SUM(IFF(is_noise, 1, 0))"}
      - {name: noise_ratio_pct, expr: "100 * SUM(IFF(is_noise, 1, 0)) / NULLIF(COUNT(alert_id), 0)", synonyms: [alert noise, noise ratio, non-actionable alerts percent]}
      - {name: avg_alert_duration_minutes, expr: AVG(alert_duration_minutes)}

  # --------------------------------------------------------------------------
  - name: device_health
    description: Daily LogicMonitor device health per host (CPU, memory, disk, downtime, uptime).
    base_table: {database: COWORK, schema: IT_OPS, table: LM_DEVICE_DAILY}
    primary_key: {columns: [health_hostname, metric_date]}
    dimensions:
      - {name: health_hostname, expr: hostname, data_type: VARCHAR}
      - {name: health_tier, expr: tier, data_type: VARCHAR}
      - {name: health_application, expr: application, data_type: VARCHAR}
      - {name: is_hot, expr: is_hot, data_type: BOOLEAN, description: Device whose 30-day average p95 CPU is at least 85% or p95 memory at least 90%.}
    time_dimensions:
      - {name: metric_date, expr: metric_date, data_type: DATE}
    facts:
      - {name: downtime_minutes, expr: downtime_minutes, data_type: NUMBER}
      - {name: cpu_avg_pct, expr: cpu_avg_pct, data_type: NUMBER}
      - {name: cpu_p95_pct, expr: cpu_p95_pct, data_type: NUMBER}
      - {name: memory_avg_pct, expr: memory_avg_pct, data_type: NUMBER}
      - {name: disk_used_max_pct, expr: disk_used_max_pct, data_type: NUMBER}
    metrics:
      - name: uptime_pct
        expr: "100 * (1 - SUM(downtime_minutes) / NULLIF(COUNT(*) * 1440, 0))"
        description: Availability percent across device-days.
        synonyms: [uptime, availability, system uptime]
      - {name: total_downtime_minutes, expr: SUM(downtime_minutes), synonyms: [downtime, outage minutes]}
      - {name: avg_cpu_pct, expr: AVG(cpu_avg_pct), synonyms: [CPU utilization]}
      - {name: avg_p95_cpu_pct, expr: AVG(cpu_p95_pct)}
      - {name: avg_memory_pct, expr: AVG(memory_avg_pct), synonyms: [memory utilization]}
      - {name: max_disk_used_pct, expr: MAX(disk_used_max_pct), synonyms: [disk utilization]}
      - {name: hot_device_count, expr: "COUNT(DISTINCT IFF(is_hot, health_hostname, NULL))", description: Devices running near capacity.}

  # --------------------------------------------------------------------------
  - name: assets
    description: ServiceDesk Plus assets and CMDB records with lifecycle state, EOL/EOS, warranty, completeness and LogicMonitor coverage.
    base_table: {database: COWORK, schema: IT_OPS, table: SDP_ASSETS}
    primary_key: {columns: [asset_id]}
    dimensions:
      - {name: asset_id, expr: asset_id, data_type: VARCHAR}
      - {name: asset_hostname, expr: hostname, data_type: VARCHAR}
      - {name: asset_type, expr: asset_type, data_type: VARCHAR, sample_values: [Server, Workstation]}
      - {name: product, expr: product, data_type: VARCHAR, description: Hardware model or VM size.}
      - {name: asset_state, expr: asset_state, data_type: VARCHAR, description: SDP lifecycle state., synonyms: [lifecycle state, asset status], sample_values: [In Use, In Store, In Repair, Expired, Disposed]}
      - {name: age_band, expr: age_band, data_type: VARCHAR, sample_values: [0-1y, 1-3y, 3-5y, 5y+]}
      - {name: asset_os, expr: os, data_type: VARCHAR}
      - {name: db_engine, expr: db_engine, data_type: VARCHAR}
      - {name: asset_application, expr: application, data_type: VARCHAR}
      - {name: asset_department, expr: department, data_type: VARCHAR}
      - {name: missing_fields, expr: missing_fields, data_type: VARCHAR, description: CMDB attributes that are missing.}
      - {name: end_of_support_components, expr: end_of_support_components, data_type: VARCHAR, description: Which OS / DB / hardware is past end of support.}
      - {name: is_cmdb_complete, expr: is_cmdb_complete, data_type: BOOLEAN}
      - {name: is_stale_scan, expr: is_stale_scan, data_type: BOOLEAN}
      - {name: is_end_of_support, expr: is_end_of_support, data_type: BOOLEAN, synonyms: [EOS, EOL, out of support, end of life]}
      - {name: is_eos_within_12m, expr: is_eos_within_12m, data_type: BOOLEAN}
      - {name: is_warranty_expired, expr: is_warranty_expired, data_type: BOOLEAN}
      - {name: is_monitored_in_logicmonitor, expr: is_monitored_in_logicmonitor, data_type: BOOLEAN}
    time_dimensions:
      - {name: earliest_end_of_support_date, expr: earliest_end_of_support_date, data_type: DATE}
      - {name: acquired_date, expr: acquired_date, data_type: DATE}
    metrics:
      - {name: asset_count, expr: COUNT(asset_id)}
      - {name: cmdb_completeness_pct, expr: "100 * SUM(IFF(is_cmdb_complete, 1, 0)) / NULLIF(COUNT(asset_id), 0)", synonyms: [CMDB completeness, CMDB health]}
      - {name: stale_asset_count, expr: "SUM(IFF(is_stale_scan, 1, 0))"}
      - {name: eos_asset_count, expr: "SUM(IFF(is_end_of_support, 1, 0))", synonyms: [end of support count, EOL assets]}
      - {name: eos_within_12m_count, expr: "SUM(IFF(is_eos_within_12m, 1, 0))"}
      - {name: warranty_expired_count, expr: "SUM(IFF(is_warranty_expired, 1, 0))"}
      - {name: unmonitored_server_count, expr: "SUM(IFF(asset_type = 'Server' AND NOT is_monitored_in_logicmonitor, 1, 0))"}

  # --------------------------------------------------------------------------
  - name: cmdb_recon
    description: Reconciliation of servers/network devices between ServiceDesk Plus CMDB and LogicMonitor.
    base_table: {database: COWORK, schema: IT_OPS, table: CMDB_RECONCILIATION}
    primary_key: {columns: [recon_hostname]}
    dimensions:
      - {name: recon_hostname, expr: hostname, data_type: VARCHAR}
      - {name: reconciliation_status, expr: reconciliation_status, data_type: VARCHAR}
      - {name: recon_in_servicedesk_plus, expr: in_servicedesk_plus, data_type: BOOLEAN}
      - {name: recon_in_logicmonitor, expr: in_logicmonitor, data_type: BOOLEAN}
    metrics:
      - {name: missing_in_logicmonitor_count, expr: "SUM(IFF(recon_in_servicedesk_plus AND NOT recon_in_logicmonitor, 1, 0))"}
      - {name: missing_in_cmdb_count, expr: "SUM(IFF(recon_in_logicmonitor AND NOT recon_in_servicedesk_plus, 1, 0))"}

  # --------------------------------------------------------------------------
  - name: projects
    description: Smartsheet IT PMO Portfolio projects.
    base_table: {database: COWORK, schema: IT_OPS, table: PROJECTS}
    primary_key: {columns: [project_row_id]}
    dimensions:
      - {name: project_row_id, expr: row_id, data_type: NUMBER}
      - {name: project_name, expr: project_name, data_type: VARCHAR}
      - {name: project_assigned_to_email, expr: assigned_to_email, data_type: VARCHAR}
      - {name: project_status, expr: status, data_type: VARCHAR, sample_values: [Not Started, In Progress, On Hold, Complete]}
      - {name: project_health, expr: health, data_type: VARCHAR, sample_values: [Green, Yellow, Red]}
      - {name: is_late, expr: is_late, data_type: BOOLEAN}
      - {name: is_complete, expr: is_complete, data_type: BOOLEAN}
      - {name: is_on_time_complete, expr: is_on_time_complete, data_type: BOOLEAN}
    time_dimensions:
      - {name: project_due_date, expr: due_date, data_type: DATE}
      - {name: project_start_date, expr: start_date, data_type: DATE}
    facts:
      - {name: days_late, expr: days_late, data_type: NUMBER}
      - {name: estimated_hours, expr: estimated_hours, data_type: NUMBER}
      - {name: actual_hours, expr: actual_hours, data_type: NUMBER}
    metrics:
      - {name: project_count, expr: COUNT(project_row_id)}
      - {name: late_project_count, expr: "SUM(IFF(is_late, 1, 0))"}
      - {name: active_project_count, expr: "SUM(IFF(NOT is_complete, 1, 0))"}
      - {name: project_on_time_pct, expr: "100 * SUM(IFF(is_on_time_complete, 1, 0)) / NULLIF(SUM(IFF(is_complete, 1, 0)), 0)", synonyms: [on-time delivery, projects on time]}

  # --------------------------------------------------------------------------
  - name: signins
    description: Microsoft Entra ID sign-in logs.
    base_table: {database: COWORK, schema: IT_OPS, table: ENTRA_SIGNINS}
    primary_key: {columns: [signin_id]}
    dimensions:
      - {name: signin_id, expr: signin_id, data_type: VARCHAR}
      - {name: signin_user_email, expr: user_email, data_type: VARCHAR}
      - {name: app_name, expr: app_name, data_type: VARCHAR}
      - {name: ip_address, expr: ip_address, data_type: VARCHAR, synonyms: [source ip, client ip]}
      - {name: country, expr: country, data_type: VARCHAR}
      - {name: city, expr: city, data_type: VARCHAR}
      - {name: authentication_requirement, expr: authentication_requirement, data_type: VARCHAR}
      - {name: conditional_access_status, expr: conditional_access_status, data_type: VARCHAR}
      - {name: risk_level, expr: risk_level, data_type: VARCHAR, sample_values: [none, low, medium, high]}
      - {name: error_code, expr: error_code, data_type: NUMBER, description: 0 success, 50126 invalid credentials, 50053 locked, 50074 MFA required.}
      - {name: failure_reason, expr: failure_reason, data_type: VARCHAR}
      - {name: is_success, expr: is_success, data_type: BOOLEAN}
      - {name: is_mfa, expr: is_mfa, data_type: BOOLEAN}
      - {name: is_interactive, expr: is_interactive, data_type: BOOLEAN}
    time_dimensions:
      - {name: signin_at, expr: signin_at, data_type: TIMESTAMP_NTZ}
      - {name: signin_date, expr: signin_date, data_type: DATE}
    metrics:
      - {name: signin_count, expr: COUNT(signin_id)}
      - {name: failed_signin_count, expr: "SUM(IFF(NOT is_success, 1, 0))"}
      - {name: failed_signin_pct, expr: "100 * SUM(IFF(NOT is_success, 1, 0)) / NULLIF(COUNT(signin_id), 0)"}
      - {name: mfa_pct, expr: "100 * SUM(IFF(is_success AND is_mfa, 1, 0)) / NULLIF(SUM(IFF(is_success, 1, 0)), 0)", synonyms: [MFA coverage, MFA rate]}
      - {name: risky_signin_count, expr: "SUM(IFF(risk_level IN ('medium','high'), 1, 0))"}
      - {name: distinct_signin_users, expr: COUNT(DISTINCT signin_user_email)}

  # --------------------------------------------------------------------------
  - name: sentinel_incidents
    description: Microsoft Sentinel incidents triaged by the MSSP SOC.
    base_table: {database: COWORK, schema: IT_OPS, table: SENTINEL_INCIDENTS}
    primary_key: {columns: [incident_number]}
    dimensions:
      - {name: incident_number, expr: incident_number, data_type: NUMBER}
      - {name: incident_title, expr: title, data_type: VARCHAR}
      - {name: incident_severity, expr: severity, data_type: VARCHAR, sample_values: [Informational, Low, Medium, High]}
      - {name: incident_status, expr: status, data_type: VARCHAR}
      - {name: classification, expr: classification, data_type: VARCHAR, sample_values: [TruePositive, BenignPositive, FalsePositive, Undetermined]}
      - {name: classification_comment, expr: classification_comment, data_type: VARCHAR}
      - {name: incident_owner, expr: owner, data_type: VARCHAR}
      - {name: tactics, expr: tactics, data_type: VARCHAR, description: MITRE ATT&CK tactics.}
    time_dimensions:
      - {name: incident_created_at, expr: created_at, data_type: TIMESTAMP_NTZ}
      - {name: incident_created_date, expr: created_date, data_type: DATE}
    facts:
      - {name: hours_to_close, expr: hours_to_close, data_type: NUMBER}
    metrics:
      - {name: security_incident_count, expr: COUNT(incident_number)}
      - {name: open_security_incident_count, expr: "SUM(IFF(incident_status <> 'Closed', 1, 0))"}
      - {name: true_positive_count, expr: "SUM(IFF(classification = 'TruePositive', 1, 0))"}
      - {name: security_incident_mttr_hours, expr: AVG(hours_to_close), synonyms: [security MTTR, time to close incident]}

  # --------------------------------------------------------------------------
  - name: defender_alerts
    description: Microsoft Defender XDR endpoint alerts with device, account, IP and process evidence.
    base_table: {database: COWORK, schema: IT_OPS, table: DEFENDER_ALERTS}
    primary_key: {columns: [defender_alert_id]}
    dimensions:
      - {name: defender_alert_id, expr: alert_id, data_type: VARCHAR}
      - {name: defender_title, expr: title, data_type: VARCHAR}
      - {name: defender_category, expr: category, data_type: VARCHAR}
      - {name: defender_severity, expr: severity, data_type: VARCHAR}
      - {name: defender_device_name, expr: device_name, data_type: VARCHAR}
      - {name: defender_account_upn, expr: account_upn, data_type: VARCHAR}
      - {name: defender_remote_ip, expr: remote_ip, data_type: VARCHAR}
      - {name: attack_techniques, expr: attack_techniques, data_type: VARCHAR}
      - {name: process_command_line, expr: process_command_line, data_type: VARCHAR}
    time_dimensions:
      - {name: defender_alert_at, expr: alert_at, data_type: TIMESTAMP_NTZ}
    metrics:
      - {name: defender_alert_count, expr: COUNT(defender_alert_id)}
      - {name: high_defender_alert_count, expr: "SUM(IFF(defender_severity = 'High', 1, 0))"}

  # --------------------------------------------------------------------------
  - name: event_timeline
    description: >-
      Unified cross-source event timeline (changes, P1/P2 and security tickets, actionable LogicMonitor alerts, Fabric job
      failures and manual reruns, risky or foreign Entra sign-ins, sensitive directory audits, sensitive Azure operations,
      Defender alerts, Sentinel incidents, bulk Fabric warehouse reads, Power BI exports). Use to reconstruct what happened
      in order, by host, actor, IP or time window.
    base_table: {database: COWORK, schema: IT_OPS, table: EVENT_TIMELINE}
    dimensions:
      - {name: source_system, expr: source_system, data_type: VARCHAR, sample_values: [ManageEngine SDP, LogicMonitor, Microsoft Fabric, Microsoft Entra ID, Azure Activity, Microsoft Defender XDR, Microsoft Sentinel, Power BI]}
      - {name: event_domain, expr: domain, data_type: VARCHAR, sample_values: [IT Operations, Data Platform, Security]}
      - {name: event_type, expr: event_type, data_type: VARCHAR}
      - {name: event_summary, expr: event_summary, data_type: VARCHAR}
      - {name: event_severity, expr: severity, data_type: VARCHAR}
      - {name: event_actor, expr: actor, data_type: VARCHAR, description: User or account involved.}
      - {name: event_host, expr: host, data_type: VARCHAR}
      - {name: event_ip_address, expr: ip_address, data_type: VARCHAR}
      - {name: event_detail, expr: detail, data_type: VARCHAR}
    time_dimensions:
      - {name: event_at, expr: event_at, data_type: TIMESTAMP_NTZ}
    metrics:
      - {name: event_count, expr: COUNT(*)}

  # --------------------------------------------------------------------------
  - name: azure_activity
    description: Azure control-plane operations (AzureActivity).
    base_table: {database: COWORK, schema: IT_OPS, table: AZURE_ACTIVITY}
    dimensions:
      - {name: azure_operation, expr: operation, data_type: VARCHAR}
      - {name: azure_caller_email, expr: caller_email, data_type: VARCHAR}
      - {name: azure_caller_ip, expr: caller_ip, data_type: VARCHAR}
      - {name: resource_group, expr: resource_group, data_type: VARCHAR}
      - {name: azure_resource_name, expr: resource_name, data_type: VARCHAR}
      - {name: is_sensitive_operation, expr: is_sensitive_operation, data_type: BOOLEAN}
    time_dimensions:
      - {name: azure_activity_at, expr: activity_at, data_type: TIMESTAMP_NTZ}
    metrics:
      - {name: azure_operation_count, expr: COUNT(*)}
      - {name: sensitive_operation_count, expr: "SUM(IFF(is_sensitive_operation, 1, 0))"}

  # --------------------------------------------------------------------------
  - name: m365_licenses
    description: Microsoft 365 license utilization per SKU (active = activity in last 30 days).
    base_table: {database: COWORK, schema: IT_OPS, table: LICENSE_UTILIZATION}
    primary_key: {columns: [sku_part_number]}
    dimensions:
      - {name: sku_part_number, expr: sku_part_number, data_type: VARCHAR, sample_values: [SPE_E5, SPE_E3, Microsoft_365_Copilot, POWER_BI_PRO]}
      - {name: sku_display_name, expr: sku_display_name, data_type: VARCHAR, synonyms: [license, SKU, product]}
    facts:
      - {name: prepaid_units, expr: prepaid_units, data_type: NUMBER}
      - {name: active_users, expr: active_users, data_type: NUMBER}
      - {name: unused_seats, expr: unused_seats, data_type: NUMBER}
      - {name: annual_waste_usd, expr: annual_waste_usd, data_type: NUMBER}
    metrics:
      - {name: prepaid_seats, expr: SUM(prepaid_units)}
      - {name: active_license_users, expr: SUM(active_users)}
      - {name: m365_utilization_pct, expr: "100 * SUM(active_users) / NULLIF(SUM(prepaid_units), 0)", synonyms: [license utilization, seat utilization]}
      - {name: unused_license_seats, expr: SUM(unused_seats), synonyms: [unused licenses, wasted licenses, reclaimable licenses]}
      - {name: license_annual_waste_usd, expr: SUM(annual_waste_usd), synonyms: [license waste, potential savings]}

  # --------------------------------------------------------------------------
  - name: software_licenses
    description: ServiceDesk Plus software license entitlements vs allocations.
    base_table: {database: COWORK, schema: IT_OPS, table: SDP_SOFTWARE_LICENSES}
    primary_key: {columns: [software_name]}
    dimensions:
      - {name: software_name, expr: software_name, data_type: VARCHAR}
      - {name: software_manufacturer, expr: manufacturer, data_type: VARCHAR}
    facts:
      - {name: purchased_licenses, expr: purchased_licenses, data_type: NUMBER}
      - {name: allocated_licenses, expr: allocated_licenses, data_type: NUMBER}
      - {name: software_cost_usd, expr: annual_cost_usd, data_type: NUMBER}
    time_dimensions:
      - {name: license_expiry_date, expr: expiry_date, data_type: DATE}
    metrics:
      - {name: purchased_licenses_total, expr: SUM(purchased_licenses)}
      - {name: allocated_licenses_total, expr: SUM(allocated_licenses)}
      - {name: software_allocation_pct, expr: "100 * SUM(allocated_licenses) / NULLIF(SUM(purchased_licenses), 0)"}
      - {name: software_annual_cost_usd, expr: SUM(software_cost_usd)}

  # --------------------------------------------------------------------------
  - name: ai_requests
    description: AI gateway requests (prompt router) with model, routing reason, complexity, tokens and cost.
    base_table: {database: COWORK, schema: IT_OPS, table: AI_GATEWAY_REQUESTS}
    primary_key: {columns: [ai_request_id]}
    dimensions:
      - {name: ai_request_id, expr: request_id, data_type: VARCHAR}
      - {name: ai_user_email, expr: user_email, data_type: VARCHAR}
      - {name: ai_department, expr: department, data_type: VARCHAR}
      - {name: model, expr: model, data_type: VARCHAR, sample_values: [gpt-4o-mini, claude-haiku-4-5, claude-sonnet-4-5, gpt-5, claude-opus-4-1]}
      - {name: route_reason, expr: route_reason, data_type: VARCHAR, sample_values: [auto_simple, auto_complex, user_override, fallback]}
      - {name: complexity, expr: complexity, data_type: VARCHAR, sample_values: [simple, moderate, complex]}
      - {name: is_premium_model, expr: is_premium_model, data_type: BOOLEAN}
      - {name: client_app, expr: client_app, data_type: VARCHAR}
    time_dimensions:
      - {name: ai_request_date, expr: request_date, data_type: DATE}
      - {name: ai_request_month, expr: request_month, data_type: DATE}
    facts:
      - {name: ai_cost, expr: cost_usd, data_type: NUMBER}
      - {name: ai_tokens, expr: total_tokens, data_type: NUMBER}
    metrics:
      - {name: ai_request_count, expr: COUNT(ai_request_id)}
      - {name: ai_cost_usd, expr: SUM(ai_cost), synonyms: [AI spend, AI cost, token cost]}
      - {name: ai_total_tokens, expr: SUM(ai_tokens), synonyms: [tokens, token usage]}
      - {name: ai_active_users, expr: COUNT(DISTINCT ai_user_email)}
      - {name: premium_simple_pct, expr: "100 * SUM(IFF(is_premium_model AND complexity = 'simple', 1, 0)) / NULLIF(COUNT(ai_request_id), 0)", description: Share of requests that sent simple prompts to the premium model (waste).}

  # --------------------------------------------------------------------------
  - name: ai_adoption
    description: Monthly AI adoption by department (Microsoft 365 Copilot or AI gateway usage vs employees).
    base_table: {database: COWORK, schema: IT_OPS, table: AI_ADOPTION_MONTHLY}
    primary_key: {columns: [usage_month, adoption_department]}
    dimensions:
      - {name: adoption_department, expr: department, data_type: VARCHAR}
    time_dimensions:
      - {name: usage_month, expr: usage_month, data_type: DATE}
    facts:
      - {name: employees, expr: employees, data_type: NUMBER}
      - {name: ai_active_user_count, expr: ai_active_users, data_type: NUMBER}
      - {name: copilot_active_user_count, expr: copilot_active_users, data_type: NUMBER}
      - {name: gateway_active_user_count, expr: gateway_active_users, data_type: NUMBER}
    metrics:
      - {name: ai_adoption_pct, expr: "100 * SUM(ai_active_user_count) / NULLIF(SUM(employees), 0)", synonyms: [AI adoption, adoption rate]}
      - {name: copilot_active_users_total, expr: SUM(copilot_active_user_count)}
      - {name: gateway_active_users_total, expr: SUM(gateway_active_user_count)}

  # --------------------------------------------------------------------------
  - name: cost_per_user
    description: Monthly technology cost per active user by department (Microsoft 365 license cost + AI gateway spend).
    base_table: {database: COWORK, schema: IT_OPS, table: COST_PER_USER_MONTHLY}
    primary_key: {columns: [cost_month, cost_department]}
    dimensions:
      - {name: cost_department, expr: department, data_type: VARCHAR}
    time_dimensions:
      - {name: cost_month, expr: cost_month, data_type: DATE}
    facts:
      - {name: license_cost_usd, expr: license_cost_usd, data_type: NUMBER}
      - {name: dept_ai_cost_usd, expr: ai_cost_usd, data_type: NUMBER}
      - {name: dept_active_users, expr: active_users, data_type: NUMBER}
    metrics:
      - {name: cost_per_active_user_usd, expr: "SUM(license_cost_usd + dept_ai_cost_usd) / NULLIF(SUM(dept_active_users), 0)", synonyms: [cost per user, per-seat cost]}
      - {name: total_technology_cost_usd, expr: SUM(license_cost_usd + dept_ai_cost_usd)}

  # --------------------------------------------------------------------------
  - name: fabric_jobs
    description: Microsoft Fabric CDW job runs (pipelines, notebooks) and Power BI semantic model refreshes.
    base_table: {database: COWORK, schema: IT_OPS, table: FABRIC_JOB_RUNS}
    primary_key: {columns: [job_id]}
    dimensions:
      - {name: job_id, expr: job_id, data_type: VARCHAR}
      - {name: fabric_item_name, expr: item_name, data_type: VARCHAR, sample_values: [PL_JDE_Ingest_Nightly, NB_Silver_Transform_GL, PL_Silver_To_Gold, SM_Finance_GL, SM_AP_AR]}
      - {name: fabric_item_type, expr: item_type, data_type: VARCHAR, sample_values: [DataPipeline, Notebook, SemanticModel]}
      - {name: fabric_workspace, expr: workspace_name, data_type: VARCHAR}
      - {name: job_type, expr: job_type, data_type: VARCHAR}
      - {name: invoke_type, expr: invoke_type, data_type: VARCHAR, sample_values: [Scheduled, Manual]}
      - {name: job_status, expr: status, data_type: VARCHAR, sample_values: [Completed, Failed, Cancelled]}
      - {name: job_error_code, expr: error_code, data_type: VARCHAR}
      - {name: job_error_message, expr: error_message, data_type: VARCHAR}
      - {name: is_job_success, expr: is_success, data_type: BOOLEAN}
    time_dimensions:
      - {name: job_started_at, expr: started_at, data_type: TIMESTAMP_NTZ}
      - {name: run_date, expr: run_date, data_type: DATE}
    facts:
      - {name: job_duration_minutes, expr: duration_minutes, data_type: NUMBER}
    metrics:
      - {name: job_run_count, expr: COUNT(job_id)}
      - {name: failed_job_count, expr: "SUM(IFF(job_status = 'Failed', 1, 0))"}
      - {name: job_success_rate_pct, expr: "100 * SUM(IFF(is_job_success, 1, 0)) / NULLIF(COUNT(job_id), 0)", synonyms: [pipeline success rate, refresh success rate]}
      - {name: avg_job_duration_minutes, expr: AVG(job_duration_minutes)}

  # --------------------------------------------------------------------------
  - name: fabric_capacity
    description: Fabric Capacity Metrics daily CU seconds per item. Production capacity tac-fabric-f64 (64 CU), dev tac-fabric-f8-dev.
    base_table: {database: COWORK, schema: IT_OPS, table: FABRIC_CAPACITY_DAILY}
    primary_key: {columns: [capacity_item_name, capacity_metric_date]}
    dimensions:
      - {name: capacity_item_name, expr: item_name, data_type: VARCHAR}
      - {name: capacity_name, expr: capacity_name, data_type: VARCHAR, sample_values: [tac-fabric-f64, tac-fabric-f8-dev]}
      - {name: capacity_workspace, expr: workspace_name, data_type: VARCHAR}
      - {name: billing_type, expr: billing_type, data_type: VARCHAR, sample_values: [Interactive, Background]}
      - {name: operation_name, expr: operation_name, data_type: VARCHAR}
    time_dimensions:
      - {name: capacity_metric_date, expr: metric_date, data_type: DATE}
    facts:
      - {name: cu_seconds, expr: cu_seconds, data_type: NUMBER}
      - {name: throttling_minutes, expr: throttling_minutes, data_type: NUMBER}
      - {name: capacity_cu_seconds_per_day, expr: capacity_cu_seconds_per_day, data_type: NUMBER}
    metrics:
      - {name: total_cu_seconds, expr: SUM(cu_seconds)}
      - name: capacity_utilization_pct
        expr: "100 * SUM(cu_seconds) / NULLIF(COUNT(DISTINCT capacity_name || TO_VARCHAR(capacity_metric_date)) * MAX(capacity_cu_seconds_per_day), 0)"
        description: Average daily capacity utilization; filter to a single capacity (usually tac-fabric-f64).
        synonyms: [Fabric capacity usage, CU utilization]
      - {name: throttled_day_count, expr: "COUNT(DISTINCT IFF(throttling_minutes > 0, capacity_metric_date, NULL))"}
      - {name: max_throttling_minutes, expr: MAX(throttling_minutes)}

  # --------------------------------------------------------------------------
  - name: cdw_freshness
    description: Daily freshness of the Fabric CDW gold layer at 08:00 UTC (hours since last successful PL_Silver_To_Gold). Stale when over 24 hours.
    base_table: {database: COWORK, schema: IT_OPS, table: FABRIC_DATA_FRESHNESS}
    primary_key: {columns: [freshness_date]}
    dimensions:
      - {name: is_stale, expr: is_stale, data_type: BOOLEAN}
    time_dimensions:
      - {name: freshness_date, expr: calendar_date, data_type: DATE}
    facts:
      - {name: gold_staleness_hours, expr: gold_staleness_hours, data_type: NUMBER}
    metrics:
      - {name: stale_day_count, expr: "SUM(IFF(is_stale, 1, 0))", synonyms: [days with stale data]}
      - {name: max_gold_staleness_hours, expr: MAX(gold_staleness_hours), synonyms: [data freshness, data latency]}

  # --------------------------------------------------------------------------
  - name: warehouse_queries
    description: Fabric warehouse WH_CDW_Gold query insights (who read how many rows).
    base_table: {database: COWORK, schema: IT_OPS, table: FABRIC_WAREHOUSE_QUERIES}
    primary_key: {columns: [statement_id]}
    dimensions:
      - {name: statement_id, expr: statement_id, data_type: VARCHAR}
      - {name: wh_login_name, expr: login_name, data_type: VARCHAR}
      - {name: wh_program_name, expr: program_name, data_type: VARCHAR}
      - {name: wh_status, expr: status, data_type: VARCHAR}
      - {name: wh_command_text, expr: command_text, data_type: VARCHAR}
    time_dimensions:
      - {name: wh_query_started_at, expr: started_at, data_type: TIMESTAMP_NTZ}
      - {name: wh_query_date, expr: query_date, data_type: DATE}
    facts:
      - {name: wh_row_count, expr: row_count, data_type: NUMBER}
      - {name: wh_data_scanned_mb, expr: data_scanned_mb, data_type: NUMBER}
    metrics:
      - {name: wh_query_count, expr: COUNT(statement_id)}
      - {name: wh_rows_read, expr: SUM(wh_row_count), synonyms: [rows returned, rows read]}
      - {name: wh_data_scanned_mb_total, expr: SUM(wh_data_scanned_mb)}

  # --------------------------------------------------------------------------
  - name: powerbi_activity
    description: Power BI activity events (report views, exports, refreshes, shares).
    base_table: {database: COWORK, schema: IT_OPS, table: POWERBI_ACTIVITY}
    primary_key: {columns: [pbi_event_id]}
    dimensions:
      - {name: pbi_event_id, expr: event_id, data_type: VARCHAR}
      - {name: pbi_operation, expr: operation, data_type: VARCHAR, sample_values: [ViewReport, ViewDashboard, ExportReport, RefreshDataset, ShareReport, AnalyzeInExcel]}
      - {name: pbi_user_email, expr: user_email, data_type: VARCHAR}
      - {name: pbi_client_ip, expr: client_ip, data_type: VARCHAR}
      - {name: report_name, expr: report_name, data_type: VARCHAR, sample_values: [Finance - GL Summary, Finance - AP Aging, Executive KPI Dashboard, IT Operations Overview]}
      - {name: dataset_name, expr: dataset_name, data_type: VARCHAR}
      - {name: pbi_workspace, expr: workspace_name, data_type: VARCHAR}
      - {name: consumption_method, expr: consumption_method, data_type: VARCHAR}
      - {name: export_type, expr: export_type, data_type: VARCHAR}
      - {name: is_export, expr: is_export, data_type: BOOLEAN}
    time_dimensions:
      - {name: pbi_event_at, expr: event_at, data_type: TIMESTAMP_NTZ}
      - {name: pbi_event_date, expr: event_date, data_type: DATE}
    facts:
      - {name: exported_rows, expr: exported_rows, data_type: NUMBER}
    metrics:
      - {name: report_view_count, expr: "SUM(IFF(pbi_operation IN ('ViewReport','ViewDashboard'), 1, 0))", synonyms: [report views, report usage]}
      - {name: export_count, expr: "SUM(IFF(is_export, 1, 0))", synonyms: [report exports]}
      - {name: exported_rows_total, expr: SUM(exported_rows)}
      - {name: pbi_active_users, expr: COUNT(DISTINCT pbi_user_email)}

relationships:
  - {name: requests_to_technician, left_table: requests, right_table: users, relationship_columns: [{left_column: technician_email, right_column: user_email}], join_type: left_outer, relationship_type: many_to_one}
  - {name: requests_to_ci, left_table: requests, right_table: cis, relationship_columns: [{left_column: ticket_ci_name, right_column: hostname}], join_type: left_outer, relationship_type: many_to_one}
  - {name: worklogs_to_technician, left_table: worklogs, right_table: users, relationship_columns: [{left_column: worklog_technician_email, right_column: user_email}], join_type: left_outer, relationship_type: many_to_one}
  - {name: workload_to_user, left_table: workload, right_table: users, relationship_columns: [{left_column: workload_technician_email, right_column: user_email}], join_type: left_outer, relationship_type: many_to_one}
  - {name: changes_to_ci, left_table: changes, right_table: cis, relationship_columns: [{left_column: change_ci_name, right_column: hostname}], join_type: left_outer, relationship_type: many_to_one}
  - {name: alerts_to_ci, left_table: alerts, right_table: cis, relationship_columns: [{left_column: alert_hostname, right_column: hostname}], join_type: left_outer, relationship_type: many_to_one}
  - {name: health_to_ci, left_table: device_health, right_table: cis, relationship_columns: [{left_column: health_hostname, right_column: hostname}], join_type: left_outer, relationship_type: many_to_one}
  - {name: assets_to_ci, left_table: assets, right_table: cis, relationship_columns: [{left_column: asset_hostname, right_column: hostname}], join_type: left_outer, relationship_type: many_to_one}
  - {name: defender_to_ci, left_table: defender_alerts, right_table: cis, relationship_columns: [{left_column: defender_device_name, right_column: hostname}], join_type: left_outer, relationship_type: many_to_one}
  - {name: projects_to_user, left_table: projects, right_table: users, relationship_columns: [{left_column: project_assigned_to_email, right_column: user_email}], join_type: left_outer, relationship_type: many_to_one}
  - {name: signins_to_user, left_table: signins, right_table: users, relationship_columns: [{left_column: signin_user_email, right_column: user_email}], join_type: left_outer, relationship_type: many_to_one}
  - {name: ai_requests_to_user, left_table: ai_requests, right_table: users, relationship_columns: [{left_column: ai_user_email, right_column: user_email}], join_type: left_outer, relationship_type: many_to_one}
  - {name: pbi_to_user, left_table: powerbi_activity, right_table: users, relationship_columns: [{left_column: pbi_user_email, right_column: user_email}], join_type: left_outer, relationship_type: many_to_one}

module_custom_instructions:
  sql_generation: |
    Data is synthetic demo data for TAC; the latest date in the data is the demo end date (today).
    Round percentages and hours to 1 decimal place and currency to 2 decimal places.
    MTTR always means mttr_hours (incidents only). Tickets are requests in ManageEngine ServiceDesk Plus.
    For uptime of critical systems filter cis.tier = 'Tier 1' or health_tier = 'Tier 1'.
    For Fabric capacity utilization always filter capacity_name = 'tac-fabric-f64' unless the user asks about dev.
    When asked to trace, reconstruct or build a timeline of an incident, query event_timeline ordered by event_at ascending
    and filter by event_actor, event_host or event_ip_address, and a time window.
    Service accounts start with svc_. The JD Edwards database server is JDE-SQL01; the Fabric on-prem data gateway is FABRIC-GW01.
  question_categorization: |
    This model answers IT operations, service desk, infrastructure health, asset/CMDB, license, AI adoption and cost,
    Microsoft Fabric CDW / Power BI operations, and security investigation questions for TAC.

verified_queries:
  - name: cio_overview_monthly
    question: Show the monthly IT operations overview with ticket volume, MTTR and SLA compliance
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS requests.created_month
        METRICS requests.ticket_count, requests.mttr_hours, requests.sla_compliance_pct)
      ORDER BY created_month
    use_as_onboarding_question: true
    verified_by: TAC demo
    verified_at: 1790000000
  - name: tier1_uptime_by_application
    question: What is uptime for Tier 1 systems by application?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS cis.application
        METRICS device_health.uptime_pct, device_health.total_downtime_minutes
        WHERE cis.tier = 'Tier 1')
      ORDER BY uptime_pct
    verified_by: TAC demo
    verified_at: 1790000000
  - name: mttr_by_priority
    question: What is MTTR by priority?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS requests.priority_code
        METRICS requests.mttr_hours, requests.incident_count)
      ORDER BY priority_code
    verified_by: TAC demo
    verified_at: 1790000000
  - name: fcr_by_support_group
    question: What is first contact resolution by support group?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS requests.support_group
        METRICS requests.fcr_pct, requests.reassignment_rate_pct, requests.ticket_count)
      ORDER BY fcr_pct
    use_as_onboarding_question: true
    verified_by: TAC demo
    verified_at: 1790000000
  - name: backlog_aging
    question: How old is the open ticket backlog?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS requests.backlog_age_bucket
        METRICS requests.open_backlog_count
        WHERE requests.is_open)
      ORDER BY backlog_age_bucket
    verified_by: TAC demo
    verified_at: 1790000000
  - name: technician_workload
    question: Where is each technician spending their time across tickets and projects?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS workload.workload_technician_name, workload.workload_support_group, workload.workload_low_ticket_usage
        FACTS workload.tickets_assigned, workload.p1_p2_tickets, workload.tech_sla_breach_pct, workload.tech_fcr_pct,
              workload.ticket_hours, workload.active_projects, workload.late_projects, workload.project_hours, workload.total_tracked_hours)
      ORDER BY total_tracked_hours DESC
    use_as_onboarding_question: true
    verified_by: TAC demo
    verified_at: 1790000000
  - name: alert_noise_by_datasource
    question: What is the LogicMonitor alert noise ratio by datasource?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS alerts.datasource
        METRICS alerts.alert_count, alerts.noise_ratio_pct)
      ORDER BY alert_count DESC
    verified_by: TAC demo
    verified_at: 1790000000
  - name: changes_followed_by_alerts
    question: Which changes were followed by the most alerts and incidents?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS changes.change_number, changes.change_title, changes.change_type, changes.closure_code,
                   changes.change_scheduled_start_at, changes.change_owner_name, changes.backout_plan_tested
        FACTS changes.alerts_48h_before, changes.alerts_48h_after, changes.incidents_48h_after)
      ORDER BY alerts_48h_after DESC
      LIMIT 10
    use_as_onboarding_question: true
    verified_by: TAC demo
    verified_at: 1790000000
  - name: hot_devices
    question: Which servers are running hot on CPU or memory?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS device_health.health_hostname, device_health.health_application
        METRICS device_health.avg_p95_cpu_pct, device_health.avg_memory_pct
        WHERE device_health.metric_date >= DATEADD(day, -30, CURRENT_DATE()))
      ORDER BY avg_p95_cpu_pct DESC
      LIMIT 10
    verified_by: TAC demo
    verified_at: 1790000000
  - name: cmdb_completeness_by_type
    question: What is CMDB completeness by asset type?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS assets.asset_type
        METRICS assets.asset_count, assets.cmdb_completeness_pct, assets.stale_asset_count, assets.unmonitored_server_count)
    verified_by: TAC demo
    verified_at: 1790000000
  - name: lifecycle_distribution
    question: Show asset lifecycle distribution by state and age band
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS assets.asset_type, assets.asset_state, assets.age_band
        METRICS assets.asset_count)
      ORDER BY asset_type, asset_state, age_band
    verified_by: TAC demo
    verified_at: 1790000000
  - name: eos_servers
    question: Which servers are past end of support and what applications run on them?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS assets.asset_hostname, assets.asset_application, assets.end_of_support_components, assets.asset_state
        METRICS assets.asset_count
        WHERE assets.is_end_of_support AND assets.asset_type = 'Server')
      ORDER BY asset_application
    use_as_onboarding_question: true
    verified_by: TAC demo
    verified_at: 1790000000
  - name: m365_license_waste
    question: How many Microsoft 365 licenses are unused and what is the annual waste?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS m365_licenses.sku_display_name
        METRICS m365_licenses.prepaid_seats, m365_licenses.active_license_users, m365_licenses.m365_utilization_pct,
                m365_licenses.unused_license_seats, m365_licenses.license_annual_waste_usd)
      ORDER BY license_annual_waste_usd DESC
    use_as_onboarding_question: true
    verified_by: TAC demo
    verified_at: 1790000000
  - name: ai_adoption_trend
    question: What is the AI adoption trend by month?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS ai_adoption.usage_month
        METRICS ai_adoption.ai_adoption_pct, ai_adoption.copilot_active_users_total, ai_adoption.gateway_active_users_total)
      ORDER BY usage_month
    verified_by: TAC demo
    verified_at: 1790000000
  - name: ai_cost_by_department_last_30_days
    question: Which department drives AI gateway cost in the last 30 days and why?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS ai_requests.ai_department, ai_requests.model, ai_requests.route_reason
        METRICS ai_requests.ai_cost_usd, ai_requests.ai_request_count, ai_requests.premium_simple_pct
        WHERE ai_requests.ai_request_date >= DATEADD(day, -30, CURRENT_DATE()))
      ORDER BY ai_cost_usd DESC
      LIMIT 15
    verified_by: TAC demo
    verified_at: 1790000000
  - name: cost_per_user_by_department
    question: What is the monthly technology cost per active user by department?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS cost_per_user.cost_month, cost_per_user.cost_department
        METRICS cost_per_user.cost_per_active_user_usd)
      ORDER BY cost_month, cost_department
    verified_by: TAC demo
    verified_at: 1790000000
  - name: fabric_pipeline_failures
    question: Which Fabric CDW pipelines and refreshes failed recently and why?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS fabric_jobs.job_started_at, fabric_jobs.fabric_item_name, fabric_jobs.invoke_type,
                   fabric_jobs.job_status, fabric_jobs.job_error_code, fabric_jobs.job_error_message
        METRICS fabric_jobs.job_run_count
        WHERE fabric_jobs.job_status <> 'Completed' AND fabric_jobs.run_date >= DATEADD(day, -60, CURRENT_DATE()))
      ORDER BY job_started_at
    verified_by: TAC demo
    verified_at: 1790000000
  - name: fabric_capacity_daily
    question: What was the daily Fabric F64 capacity utilization and throttling over the last 60 days?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS fabric_capacity.capacity_metric_date
        METRICS fabric_capacity.capacity_utilization_pct, fabric_capacity.max_throttling_minutes
        WHERE fabric_capacity.capacity_name = 'tac-fabric-f64' AND fabric_capacity.capacity_metric_date >= DATEADD(day, -60, CURRENT_DATE()))
      ORDER BY capacity_metric_date
    verified_by: TAC demo
    verified_at: 1790000000
  - name: service_account_timeline
    question: Map out the security incident involving svc_jde_integration from start to finish
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS event_timeline.event_at, event_timeline.source_system, event_timeline.event_type,
                   event_timeline.event_summary, event_timeline.event_severity, event_timeline.event_host,
                   event_timeline.event_ip_address, event_timeline.event_detail
        WHERE event_timeline.event_domain = 'Security'
          AND event_timeline.event_type <> 'Sign-in Failure'
          AND (event_timeline.event_actor ILIKE 'svc_jde_integration%' OR event_timeline.event_ip_address LIKE '185.220.101.%'
               OR event_timeline.event_host = 'JDE-APP02' OR event_timeline.event_summary ILIKE '%svc_jde_integration%'
               OR event_timeline.event_summary ILIKE '%password spray%' OR event_timeline.event_summary ILIKE '%JDE-APP02%'))
      ORDER BY event_at
    use_as_onboarding_question: true
    verified_by: TAC demo
    verified_at: 1790000000
  - name: jde_outage_timeline
    question: Why did alerts spike on JDE-SQL01 and what was the downstream impact?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS event_timeline.event_at, event_timeline.source_system, event_timeline.event_type,
                   event_timeline.event_summary, event_timeline.event_host, event_timeline.event_detail
        WHERE event_timeline.event_domain IN ('IT Operations', 'Data Platform')
          AND event_timeline.event_at BETWEEN DATEADD(day, -36, CURRENT_DATE()) AND DATEADD(day, -32, CURRENT_DATE())
          AND (event_timeline.event_host LIKE 'JDE-%' OR event_timeline.event_host = 'FABRIC-GW01' OR event_timeline.source_system = 'Microsoft Fabric'))
      ORDER BY event_at
    verified_by: TAC demo
    verified_at: 1790000000
  - name: signins_from_attacker_range
    question: Show successful and failed sign-ins from 185.220.101.x by user
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS signins.signin_user_email, signins.is_success, signins.authentication_requirement, signins.conditional_access_status
        METRICS signins.signin_count
        WHERE signins.ip_address LIKE '185.220.101.%')
      ORDER BY is_success DESC, signin_count DESC
    verified_by: TAC demo
    verified_at: 1790000000
  - name: sentinel_incidents_by_classification
    question: How did the MSSP classify Sentinel incidents by severity?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS sentinel_incidents.incident_severity, sentinel_incidents.classification
        METRICS sentinel_incidents.security_incident_count, sentinel_incidents.security_incident_mttr_hours)
      ORDER BY incident_severity, classification
    verified_by: TAC demo
    verified_at: 1790000000
  - name: bulk_cdw_reads_and_exports
    question: Who read large volumes from the Fabric CDW or exported Power BI reports from outside the corporate network?
    sql: |
      SELECT * FROM SEMANTIC_VIEW(COWORK.IT_OPS.IT_OPS_SECURITY_SVW
        DIMENSIONS event_timeline.event_at, event_timeline.source_system, event_timeline.event_actor,
                   event_timeline.event_ip_address, event_timeline.event_summary, event_timeline.event_detail
        WHERE event_timeline.event_type IN ('Warehouse Query', 'Power BI Export'))
      ORDER BY event_at
    verified_by: TAC demo
    verified_at: 1790000000
$$, FALSE);

GRANT SELECT ON SEMANTIC VIEW COWORK.IT_OPS.IT_OPS_SECURITY_SVW TO ROLE PUBLIC;
GRANT SELECT ON ALL VIEWS IN SCHEMA COWORK.IT_OPS TO ROLE PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA COWORK.IT_OPS TO ROLE PUBLIC;
