# Security Investigation Scenarios - Demo Guide

This document provides realistic security investigation scenarios that demonstrate the capabilities of the **Security Monitoring Agent** (`SECURITY_MONITORING_AGENT`). Each scenario includes context, investigation questions, and expected insights.

---

## Scenario 1: Suspicious npm Package Installation Alert

**Context:** Your CI/CD pipeline monitoring detected a suspicious `postinstall` script execution from a recently published npm package. You need to investigate the scope and impact.

**Investigation Questions:**

1. **Initial Triage:**
   - "Show me all npm package events with critical or high severity indicators in the last 24 hours"
   - "Which npm packages triggered outbound network connections to external hosts?"
   - "What CWE vulnerabilities are associated with the suspicious npm events?"

2. **Deep Dive:**
   - "Show me all npm events for package 'ansi-styles' or 'chalk' - what indicators were detected?"
   - "Which repositories and environments were affected by npm packages with CWE-94 (Code Injection) indicators?"
   - "What postinstall scripts executed network connections to 'evil.example' or 'pastebin.com'?"

3. **Cross-Source Correlation:**
   - "Did any Kubernetes pods access secrets around the same time as npm package installations with credential theft indicators?"
   - "Were there any Cloudflare WAF blocks or security actions triggered for requests from our CI/CD infrastructure IPs?"
   - "Show me CrowdStrike events from the same hostnames that had suspicious npm package installations"

**Expected Insights:**
- Identify compromised packages (typosquatting, malicious postinstall scripts)
- Map to CWE Top 25 vulnerabilities (CWE-94, CWE-829, CWE-522)
- Correlate with infrastructure events (K8s secrets access, network anomalies)
- Determine blast radius (which repos, environments, pipelines affected)

---

## Scenario 2: Kubernetes Unauthorized Secrets Access

**Context:** Your Kubernetes audit logs show multiple 403 Forbidden responses for secrets access attempts. You suspect a compromised service account or misconfigured RBAC.

**Investigation Questions:**

1. **Initial Triage:**
   - "Show me all Kubernetes audit events with 403 Forbidden responses in the last 7 days"
   - "Which users or service accounts attempted to access secrets but were denied?"
   - "What Kubernetes namespaces had the most authorization failures?"

2. **Deep Dive:**
   - "Show me Kubernetes delete operations on secrets or configmaps - who performed them and from which source IPs?"
   - "Which Kubernetes audit events involved the 'secrets' resource type - show me the verbs, usernames, and response codes"
   - "Were there any Kubernetes events with 'forbid' authorization decisions from unusual source IPs?"

3. **Cross-Source Correlation:**
   - "Did any Snowflake login failures occur from IPs that also had Kubernetes 403 errors?"
   - "Show me CloudTrail events around the same time as Kubernetes secrets access attempts - were there any AWS API calls?"
   - "Were there any npm package installations on the same hostnames that had Kubernetes authorization failures?"

**Expected Insights:**
- Identify unauthorized access patterns (service accounts, users, IPs)
- Detect privilege escalation attempts (delete operations, cross-namespace access)
- Correlate with authentication failures in other systems
- Map to CWE-284 (Improper Access Control) and CWE-639 (Authorization Bypass)

---

## Scenario 3: Supply Chain Attack - Typosquatting Detection

**Context:** Your security team received an alert about a package named 'react-domm' (typo of 'react-dom') being installed. You need to assess if this is a typosquatting attack.

**Investigation Questions:**

1. **Initial Triage:**
   - "Show me all npm package events with 'typosquat' indicator type - which packages and versions were involved?"
   - "Which environments (dev/ci/prod) had typosquatting package installations?"
   - "What is the severity breakdown of npm typosquatting events?"

2. **Deep Dive:**
   - "Show me all npm events for packages that look like typosquats - 'react-domm', 'lodashs', or similar suspicious names"
   - "Which repositories and pipelines installed typosquatting packages - show me the actors and timestamps"
   - "What CWE vulnerabilities are associated with typosquatting events - show me CWE-829 (Untrusted Control Sphere) details"

3. **Cross-Source Correlation:**
   - "Did any Kubernetes pods get created or modified around the time typosquatting packages were installed?"
   - "Were there any Cloudflare security actions (blocks/challenges) for requests from hosts that installed typosquatting packages?"
   - "Show me CrowdStrike suspicious activity events from the same hostnames that had typosquatting npm installations"

**Expected Insights:**
- Identify typosquatting packages and their installation scope
- Map to CWE-829 (Inclusion of Functionality from Untrusted Control Sphere)
- Determine if malicious packages executed (postinstall scripts, network connections)
- Assess impact across environments and repositories

---

## Scenario 4: Multi-Vector Attack Investigation

**Context:** You're investigating a potential multi-stage attack. Initial indicators suggest credential theft, followed by lateral movement, and potential data exfiltration.

**Investigation Questions:**

1. **Credential Theft Phase:**
   - "Show me npm package events with 'credential_theft' indicator type - which packages and what CWE vulnerabilities?"
   - "Were there any npm events that executed scripts accessing environment variables or credential stores?"
   - "Which hostnames had npm credential theft indicators and what other security events occurred on those hosts?"

2. **Lateral Movement Phase:**
   - "Show me CrowdStrike events with suspicious activity from IPs that also had npm credential theft indicators"
   - "Were there any Kubernetes pods created or modified from source IPs associated with credential theft?"
   - "Show me CloudTrail events for AWS API calls from IPs that had npm credential theft events"

3. **Data Exfiltration Phase:**
   - "Which npm packages triggered outbound network connections to external hosts (C2 indicators)?"
   - "Show me Cloudflare events with high response bytes or unusual traffic patterns from hosts with security incidents"
   - "Were there any Kubernetes secrets accessed or deleted around the time of outbound network connections?"

4. **Timeline Reconstruction:**
   - "Create a timeline of security events: npm credential theft → CrowdStrike suspicious activity → Kubernetes secrets access → Cloudflare data transfer"
   - "Show me all security events from hostname 'prod-app-01' in chronological order - what was the attack chain?"

**Expected Insights:**
- Reconstruct attack timeline across multiple data sources
- Identify attack vectors (supply chain → credential theft → lateral movement → exfiltration)
- Map to multiple CWE Top 25 vulnerabilities (CWE-522, CWE-284, CWE-200)
- Determine blast radius and affected systems

---

## Scenario 5: CWE Top 25 Compliance Audit

**Context:** Your organization needs to demonstrate compliance with CWE Top 25 security controls. You're auditing your security telemetry to identify gaps.

**Investigation Questions:**

1. **CWE-94 (Code Injection) Detection:**
   - "Show me all security events mapped to CWE-94 - which data sources detected code injection attempts?"
   - "What npm packages had CWE-94 indicators and what were the associated script commands?"
   - "Were there any Kubernetes audit events that could indicate code injection attempts?"

2. **CWE-829 (Untrusted Control Sphere) Detection:**
   - "Show me npm package events with CWE-829 - which packages came from untrusted sources?"
   - "What typosquatting or suspicious package installations were detected?"
   - "Which environments had the most CWE-829 violations?"

3. **CWE-284 (Improper Access Control) Detection:**
   - "Show me Kubernetes 403 Forbidden events - what authorization failures occurred?"
   - "Were there any Snowflake login failures that could indicate access control issues?"
   - "What CloudTrail events showed unauthorized API access attempts?"

4. **CWE-522 (Insufficiently Protected Credentials) Detection:**
   - "Show me npm events with credential theft indicators mapped to CWE-522"
   - "Which packages attempted to access environment variables or credential stores?"
   - "Were there any Kubernetes secrets accessed inappropriately?"

5. **Compliance Summary:**
   - "Give me a summary of CWE Top 25 violations detected across all security sources"
   - "Which CWE vulnerabilities had the highest severity indicators?"
   - "What is the distribution of CWE violations by environment (dev/ci/prod)?"

**Expected Insights:**
- Comprehensive CWE Top 25 coverage across all data sources
- Identify security control gaps and violations
- Prioritize remediation based on severity and frequency
- Demonstrate compliance posture to auditors

---

## Scenario 6: Zero-Day Supply Chain Attack Response

**Context:** A zero-day supply chain attack was disclosed affecting a popular npm package. You need to quickly assess if your organization is impacted.

**Investigation Questions:**

1. **Rapid Assessment:**
   - "Show me all npm package events for package 'event-stream' or 'ua-parser-js' - were they installed?"
   - "Which versions of 'chalk' or 'ansi-styles' were installed in our environments?"
   - "What indicators were detected for these specific packages - show me severity and CWE mappings"

2. **Impact Analysis:**
   - "Which repositories and pipelines installed the compromised packages?"
   - "What environments (dev/ci/prod) had installations of the affected packages?"
   - "Show me all events for packages with critical severity indicators in the last 30 days"

3. **Containment Verification:**
   - "Were there any outbound network connections from hosts that installed the compromised packages?"
   - "Did any Kubernetes pods access secrets after installing the compromised packages?"
   - "Show me Cloudflare security actions for requests from hosts with the compromised packages"

4. **Remediation Tracking:**
   - "Which packages have been blocked or detected but not yet remediated?"
   - "What is the status breakdown (detected/blocked/allowed) for npm security events?"
   - "Show me recent npm events to verify no new installations of compromised packages"

**Expected Insights:**
- Rapid identification of affected systems and packages
- Determine scope of compromise (repos, environments, hosts)
- Verify containment effectiveness
- Track remediation progress

---

## Tips for Demo Execution

1. **Start Broad, Then Narrow:** Begin with high-level questions, then drill down into specific indicators
2. **Cross-Source Correlation:** Always ask follow-up questions that correlate across data sources
3. **Timeline Focus:** Use time-based questions to reconstruct attack sequences
4. **CWE Mapping:** Emphasize how events map to CWE Top 25 for compliance/audit scenarios
5. **Realistic Context:** Frame questions as if investigating a real incident (urgency, impact, remediation)

---

## Sample Agent Interaction Flow

```
You: "I'm investigating a potential supply chain attack. Show me all npm package events with critical severity indicators."

Agent: [Returns results showing outbound_c2, credential_theft events]

You: "Which packages triggered outbound network connections?"

Agent: [Lists packages with network_dest_host populated]

You: "Did any Kubernetes pods access secrets around the same time as these npm installations?"

Agent: [Correlates timestamps and shows Kubernetes secrets access events]

You: "What CWE vulnerabilities are associated with these events?"

Agent: [Maps to CWE-94, CWE-522, CWE-829]
```

---

## Additional Investigation Patterns

- **Anomaly Detection:** "Show me unusual patterns in [source] - what stands out?"
- **Blast Radius:** "Which systems/environments were affected by [indicator]?"
- **Attribution:** "Who/what triggered [event] - show me actors, IPs, service accounts"
- **Compliance:** "What CWE Top 25 violations were detected in [timeframe]?"
- **Remediation:** "What is the status of [indicator] - detected, blocked, or allowed?"

