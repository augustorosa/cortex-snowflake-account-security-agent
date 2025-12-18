-- ============================================================================
-- SECURITY MONITORING AGENT (EXPANDED) - SECURITY TOOLS + EXTERNAL SOURCES
-- ============================================================================
-- Goal: keep the Snowflake Maintenance agent "Snowflake-only" and provide a
-- dedicated SECURITY agent with expanded scope across:
-- - Snowflake authentication/security posture (LOGIN_HISTORY, SESSIONS, USERS, policies)
-- - Flattened security telemetry (CloudTrail flattened helper columns)
-- - Optional external security datasets (Cloudflare / CrowdStrike synthetic demos)
-- - Helper/flatten views for JSON (so Intelligence can query scalar fields)
-- ============================================================================

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.AGENTS;

CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.SECURITY_MONITORING_AGENT
WITH PROFILE='{ "display_name": "Security Monitoring Analyst (Expanded)" }'
    COMMENT=$$ 🔐 EXPANDED SECURITY MONITORING AGENT

I provide security monitoring and investigations across Snowflake-native security data plus optional external security telemetry.

SNOWFLAKE SECURITY (authoritative):
• LOGIN_HISTORY: failed logins, brute-force patterns, client fingerprints, MFA usage
• SESSIONS: active sessions, authentication methods, anomalous session behavior
• USERS + POLICIES: MFA enablement, password/session/network policy posture

SECURITY TELEMETRY (flattened for AI querying):
• CloudTrail flattened fields (path/key/value style) via helper views (no raw JSON)
• Cloudflare / CrowdStrike synthetic demo datasets (optional)

IMPORTANT:
• Snowflake Intelligence cannot reliably “look inside” VARIANT JSON.
• Always use flattened helper views (path/key/value) when you need JSON content.

ARCHITECTURE NOTE:
• SNOWFLAKE_MAINTENANCE_SVW is Snowflake-only (generalist ops).
• SECURITY_MONITORING_SVW is the expanded security semantic view (Snowflake security + flattened telemetry + optional external demo sources).
$$
FROM SPECIFICATION $$
{
  "models": { "orchestration": "auto" },
  "instructions": {
    "response": "You are a Snowflake security monitoring expert. Always provide:\n\n- Clear risk assessment (HIGH/MEDIUM/LOW)\n- Specific evidence (user, ip, counts, time range)\n- Concrete remediation steps and Snowflake commands\n- FULL SQL queries users can run directly\n\nIf the question involves JSON telemetry, use flattened helper views / flattened semantic-view columns (do not assume the model can query raw VARIANT).",
    "orchestration": "EXPANDED SECURITY MONITORING\n\nPrimary semantic views:\n1) SECURITY_MONITORING_SVW (expanded security: Snowflake login/session/user/policies + flattened telemetry + optional external demo sources)\n2) SNOWFLAKE_MAINTENANCE_SVW (Snowflake-only generalist ops)\n\nWhen possible:\n- Use SECURITY_MONITORING_SVW for security investigations and posture questions.\n- Use SNOWFLAKE_MAINTENANCE_SVW for Snowflake ops questions (cost/perf/storage/governance).\n\nIf a user asks for deep object-level access auditing:\n- Recommend querying the flattened ACCESS_HISTORY helper views directly (ACCESS_*_VW) in SNOWFLAKE_INTELLIGENCE.TOOLS.",
    "sample_questions": [
      { "question": "Show me failed login attempts in the last 7 days, grouped by user and client IP" },
      { "question": "Are there any brute force attacks (many failed logins from the same IP)?" },
      { "question": "What is our MFA adoption rate (logins using MFA and users with MFA enabled)?" },
      { "question": "Which users do not have MFA enabled?" },
      { "question": "How many active sessions do we have right now, and which users own them?" },
      { "question": "Show active sessions older than 24 hours" },
      { "question": "Do we have network policies configured? How many have allowed IP lists or blocked IP lists?" },
      { "question": "How strong are our password policies (min length and complexity)?" },
      { "question": "Show CloudTrail flattened events where the JSON path or key contains 'AssumeRole'" },
      { "question": "Show CloudTrail flattened activity by region, status, and severity" },
      { "question": "Show Cloudflare blocked vs 2xx vs 5xx responses by host and request URI (demo data)" },
      { "question": "Show CrowdStrike events targeting ports 22 or 3389 and the top usernames involved (demo data)" },
      { "question": "Kubernetes audit: show all forbidden (403) requests to secrets in the last 7 days" },
      { "question": "Kubernetes audit: which users are deleting resources, and in which namespaces?" },
      { "question": "Kubernetes audit: show suspicious userAgent values for write verbs (create/update/delete)" },
      { "question": "NPM supply chain: show critical/high indicators by repository and pipeline_id" },
      { "question": "NPM supply chain: list suspected typosquatting packages and how often they appeared" },
      { "question": "NPM supply chain: show postinstall scripts making outbound connections (possible code execution) and map to CWE-94 / CWE-829" }
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "name": "security_monitoring_semantic_view",
        "type": "cortex_analyst_text_to_sql",
        "description": "Focused Snowflake security semantic view: logins, sessions, users, and security policies (Phase 7). Use for MFA adoption, failed logins, active sessions, and policy posture."
      }
    },
    {
      "tool_spec": {
        "name": "snowflake_maintenance_semantic_view",
        "type": "cortex_analyst_text_to_sql",
        "description": "Snowflake-only generalist semantic view (ops/cost/perf/storage/governance). Use this for operational questions; use SECURITY_MONITORING_SVW for expanded security/telemetry."
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "security_alert_email",
        "description": "Send security alert emails for critical findings (HIGH risk brute force, unusual auth patterns). Include specific user/IP/count evidence.",
        "input_schema": {
          "type": "object",
          "properties": {
            "recipient_email": { "type": "string", "description": "Email recipient" },
            "subject": { "type": "string", "description": "Subject with alert type and severity" },
            "body": { "type": "string", "description": "HTML body with findings and remediation steps" }
          },
          "required": ["recipient_email", "subject", "body"]
        }
      }
    }
  ],
  "tool_resources": {
    "security_monitoring_semantic_view": {
      "semantic_view": "SNOWFLAKE_INTELLIGENCE.TOOLS.SECURITY_MONITORING_SVW",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "CORTEX_WH",
        "query_timeout": 120
      }
    },
    "snowflake_maintenance_semantic_view": {
      "semantic_view": "SNOWFLAKE_INTELLIGENCE.TOOLS.SNOWFLAKE_MAINTENANCE_SVW",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "CORTEX_WH",
        "query_timeout": 180
      }
    },
    "security_alert_email": {
      "identifier": "SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_EMAIL",
      "name": "SEND_EMAIL(VARCHAR, VARCHAR, VARCHAR)",
      "type": "procedure",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "CORTEX_WH",
        "query_timeout": 60
      }
    }
  }
}
$$;

GRANT USAGE ON AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.SECURITY_MONITORING_AGENT TO ROLE PUBLIC;


