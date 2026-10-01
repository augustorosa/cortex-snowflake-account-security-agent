# Client Source Mapping (Summit Live Group IT Operations + Security demo)

This file maps each client system to its native API shape, the RAW table that mimics it in `COWORK.IT_OPS`, and the flattened view the semantic view uses.

All demo data is synthetic. RAW tables store one native API object per row in `PAYLOAD VARIANT`, plus these columns:
- `SOURCE`: `baseline` or `scenario:<name>`
- `INGESTED_AT`

The same pattern (land native JSON, flatten, conform, model) applies in Snowflake or Microsoft Fabric (bronze, silver, gold).

| Domain | Client system | Ingestion pattern (real) | RAW table(s) | Flattened view(s) |
|---|---|---|---|---|
| ITSM, CMDB, assets | ManageEngine ServiceDesk Plus (SDP) | REST API v3, scheduled pull (`GET /api/v3/requests`, `/changes`, `/assets`, `/requests/{id}/worklogs`, `/requests/{id}/history`) | `RAW_SDP_REQUESTS`, `RAW_SDP_REQUEST_HISTORY`, `RAW_SDP_WORKLOGS`, `RAW_SDP_CHANGES`, `RAW_SDP_ASSETS`, `RAW_SDP_CI_RELATIONSHIPS`, `RAW_SDP_SOFTWARE_LICENSES` | `SDP_REQUESTS`, `SDP_REASSIGNMENTS`, `SDP_WORKLOGS`, `SDP_CHANGES`, `SDP_ASSETS`, `SDP_CI_RELATIONSHIPS`, `SDP_SOFTWARE_LICENSES` |
| Infrastructure monitoring (MSP-managed) | LogicMonitor | REST API v3 (`/device/devices`, `/alert/alerts`, datapoint data), or MSP export if API access is refused | `RAW_LM_DEVICES`, `RAW_LM_ALERTS`, `RAW_LM_DEVICE_DAILY` | `LM_DEVICES`, `LM_ALERTS`, `LM_DEVICE_DAILY` |
| Projects and resourcing | Smartsheet | API 2.0 `GET /sheets/{id}` (columns + rows/cells) | `RAW_SMARTSHEET_SHEET` | `PROJECTS` |
| Identity | Microsoft Entra ID | Graph `auditLogs/signIns`, `auditLogs/directoryAudits`, or Log Analytics `SigninLogs` / `AuditLogs` | `RAW_ENTRA_SIGNINS`, `RAW_ENTRA_AUDITS` | `ENTRA_SIGNINS`, `ENTRA_AUDITS` |
| Azure control plane | Azure Monitor | Log Analytics `AzureActivity` | `RAW_AZURE_ACTIVITY` | `AZURE_ACTIVITY` |
| Endpoint | Microsoft Defender XDR | Advanced hunting `AlertInfo` joined with `AlertEvidence` (streaming API / Event Hub) | `RAW_DEFENDER_ALERTS` | `DEFENDER_ALERTS` |
| SIEM (MSSP-managed) | Microsoft Sentinel | Log Analytics `SecurityIncident`, `SecurityAlert` | `RAW_SENTINEL_INCIDENTS`, `RAW_SENTINEL_ALERTS` | `SENTINEL_INCIDENTS`, `SENTINEL_ALERTS` |
| Licensing | Microsoft 365 | Graph `subscribedSkus`, `reports/getM365AppUserDetail`, `copilot/reports/getMicrosoft365CopilotUsageUserDetail` | `RAW_M365_SUBSCRIBED_SKUS`, `RAW_M365_USER_ACTIVITY`, `RAW_M365_COPILOT_USAGE` | `M365_SKUS`, `M365_USER_ACTIVITY`, `M365_COPILOT_USAGE` |
| AI usage and cost | In-house AI gateway (prompt router) | Gateway request log, pushed as events (schema assumed, to confirm with Summit Live Group) | `RAW_AI_GATEWAY_REQUESTS` | `AI_GATEWAY_REQUESTS` |
| Data platform (CDW) | Microsoft Fabric | Fabric REST `GET /v1/workspaces/{id}/items` and `.../items/{id}/jobs/instances`; Capacity Metrics app; warehouse `queryinsights.exec_requests_history` | `RAW_FABRIC_ITEMS`, `RAW_FABRIC_JOB_RUNS`, `RAW_FABRIC_CAPACITY_METRICS`, `RAW_FABRIC_WAREHOUSE_QUERIES` | `FABRIC_ITEMS`, `FABRIC_JOB_RUNS`, `FABRIC_CAPACITY_DAILY`, `FABRIC_WAREHOUSE_QUERIES`, `FABRIC_DATA_FRESHNESS` |
| Reporting | Power BI | Admin API activity events (`GET /admin/activityevents`, Get-PowerBIActivityEvent) | `RAW_POWERBI_ACTIVITY` | `POWERBI_ACTIVITY` |
| Reference | Demo-maintained | Manual / CSV | `REF_PRODUCT_LIFECYCLE`, `REF_LICENSE_PRICES`, `REF_SLA_TARGETS` | used directly |

## ManageEngine ServiceDesk Plus (API v3)

SDP returns datetimes as objects: `{"value": "<epoch ms>", "display_value": "Sep 1, 2026 10:15 AM"}`. Lookups are nested objects (`{"name": ..., "id": ...}`).

**Request** (`requests[]`)

| Native field | Flattened column | Notes |
|---|---|---|
| `id`, `display_id` | `request_id`, `request_number` | `display_id` is what staff quote ("request 10452") |
| `subject` | `subject` | |
| `request_type.name` | `request_type` | Incident / Service Request |
| `priority.name` | `priority`, `priority_code` | Urgent=P1, High=P2, Medium=P3, Low=P4 |
| `category.name`, `subcategory.name` | `category`, `subcategory` | |
| `mode.name` | `mode` | E-Mail, Web Form, Phone Call, Chat |
| `status.name` | `status`, `is_open` | Open, In Progress, On Hold, Resolved, Closed |
| `group.name` | `support_group` | |
| `technician.email_id` / `.name` | `technician_email`, `technician_name` | |
| `requester.email_id`, `department.name`, `site.name` | `requester_email`, `department`, `site` | |
| `created_time.value` | `created_at` | |
| `first_response_due_by_time.value`, `responded_time.value` | `first_response_due_at`, `responded_at` | |
| `due_by_time.value` | `due_by_at` | resolution SLA target |
| `resolved_time.value`, `completed_time.value` | `resolved_at`, `closed_at` | |
| `is_overdue`, `is_first_response_overdue` | `is_sla_breached`, `is_first_response_breached` | |
| `is_fcr` | `is_fcr` | first call resolution flag set by the technician |
| `is_reopened` | `is_reopened` | |
| `configuration_items[].name` | `ci_name` | first linked CI (server hostname) |

**Request history** (`/requests/{id}/history`, `operation = "ASSIGN"`) is used to derive `reassignment_count` per request. **Worklog** (`worklogs[]`) supplies `owner.email_id`, `start_time`, `end_time`, `time_spent.hours`/`.minutes`, and `worklog_type.name`.

**Change** (`changes[]`) supplies:
- `id`, `display_id`, `title`
- `change_type.name` (Minor / Major / Standard / Emergency), `risk.name`, `stage.name`, `status.name`
- `closure_code.name` (Success / Failed / Rolled Back)
- `scheduled_start_time`, `scheduled_end_time`, `completed_time`
- `change_owner.email_id`, `group.name`, `configuration_items[].name`

**Asset** (`assets[]`) supplies:
- `name`, `product.name`, `product_type.name` (Server / Workstation)
- `state.name` (In Use, In Store, In Repair, Expired, Disposed)
- `vendor.name`, `acquisition_date`, `warranty_expiry`, `last_scan_time`
- `user.email_id`, `department.name`, `site.name`
- `operating_system.os` / `.version`, and custom fields `udf_fields.udf_environment`, `udf_tier`, `udf_owner`, `udf_support_group`

SDP has no native end-of-life / end-of-support date. The demo uses `REF_PRODUCT_LIFECYCLE`, keyed on product or OS name.

**CI relationships** (CMDB) record `ci.name`, `relationship_type.name` ("Runs", "Depends on") and `related_ci.name` (application CI).

**Software license** (Asset > Software) records:
- `software.name`, `manufacturer.name`, `license_type.name`
- `purchased_licenses`, `allocated_licenses`, `installations`, `cost`, `expiry_date`

## LogicMonitor (REST API v3)

**Device** (`items[]` from `/device/devices`):

| Native field | Flattened column |
|---|---|
| `id`, `name` | `lm_device_id`, `hostname` |
| `displayName` | `display_name` |
| `hostStatus` | `host_status` (normal / dead) |
| `deviceType`, `hostGroupIds` | `device_type`, `host_group_ids` |
| `systemProperties[name='system.categories']` | `categories` |
| `customProperties[name='slg.environment' / 'slg.tier']` | `environment`, `tier` |

**Alert** (`items[]` from `/alert/alerts`):

| Native field | Flattened column | Notes |
|---|---|---|
| `id`, `internalId` | `alert_id` | e.g. `LMD123456` |
| `severity` | `severity` | 2 Warning, 3 Error, 4 Critical |
| `startEpoch`, `endEpoch` | `started_at`, `ended_at` | epoch seconds, `endEpoch = 0` when still active |
| `cleared`, `acked`, `sdted` | `is_cleared`, `is_acked`, `is_in_sdt` | SDT = scheduled downtime |
| `monitorObjectName` | `hostname` | |
| `resourceTemplateName`, `instanceName`, `dataPointName` | `datasource`, `instance`, `datapoint` | |
| `alertValue`, `threshold` | `alert_value`, `threshold` | |

**Device daily** is a demo roll-up of LogicMonitor datapoint data (`/device/devices/{id}/devicedatasources/{dsId}/instances/{iId}/data`). It holds CPU, memory and disk daily avg/p95, and `downtime_minutes` derived from HostStatus / Ping.

## Smartsheet (API 2.0)

One sheet ("IT PMO Portfolio"). The payload has `columns[]` (`id`, `title`, `type`) and `rows[]` with `cells[]` (`columnId`, `value`). The flatten step pivots cells by column title:
- Project Name, Project Manager, Assigned To
- Start Date, Due Date, Actual End Date
- % Complete, Status, Health (Green / Yellow / Red)
- Estimated Hours, Actual Hours

## Microsoft Entra ID

**signIn**:
- `id`, `createdDateTime`, `userPrincipalName`, `appDisplayName`, `ipAddress`, `clientAppUsed`, `isInteractive`
- `status.errorCode` (0 = success, 50126 = invalid credentials, 50053 = locked, 50074 = MFA required), `status.failureReason`
- `conditionalAccessStatus` (success / failure / notApplied)
- `authenticationRequirement` (singleFactorAuthentication / multiFactorAuthentication)
- `riskLevelDuringSignIn`, `location.countryOrRegion`, `location.city`, `deviceDetail.operatingSystem`, `deviceDetail.isCompliant`

**directoryAudit**:
- `activityDateTime`, `activityDisplayName`, `category`, `result`
- `initiatedBy.user.userPrincipalName`, `targetResources[0].displayName`

## Azure Activity (Log Analytics `AzureActivity`)

`TimeGenerated`, `OperationNameValue`, `ActivityStatusValue`, `Caller`, `CallerIpAddress`, `ResourceGroup`, `_ResourceId`, `CategoryValue`.

## Microsoft Defender XDR (AlertInfo + AlertEvidence)

- `Timestamp`, `AlertId`, `Title`, `Category`, `Severity`, `ServiceSource`, `DetectionSource`, `AttackTechniques`
- Evidence: `EntityType`, `EvidenceRole`, `DeviceName`, `AccountUpn`, `RemoteIP`, `FileName`, `ProcessCommandLine`

## Microsoft Sentinel

**SecurityIncident**:
- `TimeGenerated`, `IncidentNumber`, `Title`, `Severity`, `Status`, `Classification`
- `Owner.assignedTo`, `CreatedTime`, `FirstActivityTime`, `LastActivityTime`, `ClosedTime`
- `AlertIds`, `AdditionalData.tactics`, `AdditionalData.alertsCount`

**SecurityAlert**:
- `TimeGenerated`, `SystemAlertId`, `AlertName`, `AlertSeverity`, `ProviderName`, `ProductName`
- `Tactics`, `Techniques`, `CompromisedEntity`

## Microsoft 365

- **subscribedSkus:** `skuId`, `skuPartNumber`, `prepaidUnits.enabled`, `consumedUnits`.
- **M365 app user detail:** `userPrincipalName`, `reportRefreshDate`, `lastActivityDate`, `assignedProducts[]`, and per-app last activity.
- **Copilot usage user detail:** `userPrincipalName`, `reportRefreshDate`, `lastActivityDate`, `copilotChatLastActivityDate`, `microsoftTeamsCopilotLastActivityDate`, `wordCopilotLastActivityDate`, `excelCopilotLastActivityDate`, `outlookCopilotLastActivityDate`. One snapshot per month.

## AI gateway (assumed schema, to confirm with Summit Live Group)

`request_id`, `timestamp`, `user_email`, `department`, `model`, `provider`, `route_reason` (auto_simple / auto_complex / user_override / fallback), `complexity` (router classification: simple / moderate / complex), `prompt_tokens`, `completion_tokens`, `cost_usd`, `latency_ms`, `status`.

## Microsoft Fabric CDW and Power BI

The modelled data flow is:

```
JDE-SQL01 -> FABRIC-GW01 (on-prem data gateway) -> PL_JDE_Ingest_Nightly -> LH_Bronze_JDE
  -> NB_Silver_Transform_GL -> LH_Silver -> PL_Silver_To_Gold -> WH_CDW_Gold
  -> SM_Finance_GL / SM_AP_AR / SM_Executive_KPI -> Finance - GL Summary, Finance - AP Aging, Executive KPI Dashboard
```

| Source | Native fields used |
|---|---|
| Items | `id`, `type` (Lakehouse, Warehouse, DataPipeline, Notebook, SemanticModel, Report), `displayName`, `workspaceId`; demo extras: `workspaceName`, `capacityName`, `upstreamItem` |
| Job instances | `id`, `itemId`, `jobType` (Pipeline, RunNotebook, Refresh), `invokeType` (Scheduled / Manual), `status` (Completed, Failed, Cancelled), `startTimeUtc`, `endTimeUtc`, `rootActivityId`, `failureReason.errorCode` / `.message` |
| Capacity Metrics (daily per item) | `capacityName`, `capacitySku`, `date`, `workspaceName`, `itemName`, `itemKind`, `billingType` (Interactive / Background), `operationName`, `cuSeconds`, `throttlingMinutes` |
| Warehouse query insights | `distributed_statement_id`, `session_id`, `login_name`, `program_name`, `start_time`, `end_time`, `total_elapsed_time_ms`, `status`, `row_count`, `data_scanned_remote_storage_mb`, `command` |
| Power BI activity events | `Id`, `CreationTime`, `Operation` (ViewReport, ViewDashboard, ExportReport, RefreshDataset, ShareReport, AnalyzeInExcel), `UserId`, `ClientIP`, `UserAgent`, `WorkSpaceName`, `ReportName`, `DatasetName`, `ConsumptionMethod`, `DistributionMethod`, `ExportedArtifactInfo.ExportType`; demo extra: `RowCount` |

## Conformed keys

| Key | Joins |
|---|---|
| `user_email` (lower-case) | SDP technician / requester, worklog owner, Entra UPN, Smartsheet contact, M365 UPN, AI gateway user, Fabric warehouse `login_name`, Power BI `UserId` |
| `hostname` (upper-case) | SDP asset / CI name, LogicMonitor `name` / `monitorObjectName`, Defender `DeviceName`, gateway host in Fabric error messages |
| `department` | SDP department, AI gateway department |
| `date` | every event timestamp truncated to day |
