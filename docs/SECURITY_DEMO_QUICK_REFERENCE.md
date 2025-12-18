# Security Demo Quick Reference Card

## 🚨 INJECTED SECURITY INCIDENTS (Use These for Demos!)

The seed data contains **three complete attack chains** you can investigate:

### **INCIDENT C: Service Account Compromise** 🔑 (LIVE INJECTION)
**Run before demo:** `snowsql -f "scripts/6.9 DEMO_INJECT_SERVICE_ACCOUNT_COMPROMISE.sql"`

| Timeline | Source | Evidence |
|----------|--------|----------|
| **-2 hours** | Cloudflare | 50 credential stuffing attempts against `svc_deploy` |
| **-1 hour** | Cloudflare | Successful authentication from attacker IP 45.227.255.206 |
| **-1 hour** | CrowdStrike | Suspicious activity: svc_deploy accessing unusual resources |
| **-45 min** | Kubernetes | svc_deploy accessing secrets, configmaps from external IP |
| **-30 min** | npm | Data exfiltration attempt via package publish |
| **-15 min** | CrowdStrike | CRITICAL alert: compromised service account detected |

**Demo Questions:**
```
1. "Show me all events for user 'svc_deploy' in the last 2 hours"
2. "Which IPs did svc_deploy authenticate from?"
3. "Show me Cloudflare events from IP 45.227.255.206"
4. "Were there failed login attempts before the successful compromise?"
5. "What Kubernetes resources did svc_deploy access after the compromise?"
6. "Were there any data exfiltration attempts?"
7. "Create a timeline of the svc_deploy compromise"
```

---

### **INCIDENT A: Crypto Mining Attack Chain** ⛏️
**Timeline:** 5 days ago | **Attacker Package:** `crypto-linter`

| Source | Evidence |
|--------|----------|
| **npm** | Package `crypto-linter` v9.9.9 installed with postinstall downloading xmrig |
| **Kubernetes** | Pod `crypto-linter-worker` created, secrets accessed (aws-credentials, database-secrets) |
| **CrowdStrike** | xmrig process detected, connections to pool.minexmr.com:3333 |
| **Cloudflare** | Outbound traffic to mining pools (some blocked) |

**Demo Questions:**
```
1. "Show me all npm events for package 'crypto-linter'"
2. "Which Kubernetes pods were created with 'crypto' in the name?"
3. "Show me CrowdStrike events with xmrig or mining pool connections"
4. "Were there any Cloudflare blocks to mining pool domains?"
5. "Create a timeline of the crypto mining attack chain"
```

---

### **INCIDENT B: Brute Force Login Attack** 🔐
**Timeline:** 3 days ago | **Attacker IPs:** 185.220.101.x (Tor exit nodes)

| Source | Evidence |
|--------|----------|
| **Cloudflare** | 150+ POST /login attempts from 185.220.101.x, 401/403/429 responses, WAF blocks |
| **CrowdStrike** | Suspicious login activity detected from same IP range |
| **Kubernetes** | 403 Forbidden on secrets access from 185.220.101.42 (recon phase, 7 days ago) |

**Demo Questions:**
```
1. "Show me Cloudflare events from IPs starting with 185.220.101"
2. "How many failed login attempts (401/403) came from attacker IPs?"
3. "Show me CrowdStrike suspicious activity from the brute force IPs"
4. "Were there any Kubernetes 403 events from the same attacker IPs?"
5. "What countries did the brute force traffic originate from?"
```

---

## 🎯 Top 5 Demo Scenarios (5-10 min each)

### 1. **Crypto Mining Attack Investigation** ⛏️
**Hook:** "We detected crypto mining traffic on our network"

**Questions:**
```
1. "Show me all npm events for package 'crypto-linter' - what indicators were detected?"
2. "Which Kubernetes pods with 'crypto' in the name were created in the last week?"
3. "Show me CrowdStrike events with connections to mining pools"
4. "What secrets did the compromised pods access?"
5. "Create a timeline: npm install → Kubernetes pod → mining pool connection"
```

**Key Demo Points:**
- Full attack chain reconstruction (npm → K8s → CrowdStrike → Cloudflare)
- CWE-94 (Code Injection) mapping
- Blast radius: which hosts, environments, secrets affected

---

### 2. **Brute Force Attack Investigation** 🔐
**Hook:** "We're seeing credential stuffing attacks on our login page"

**Questions:**
```
1. "Show me all Cloudflare events with 401 or 403 responses to /login"
2. "Which IPs had the most failed login attempts?"
3. "What security actions (block/challenge) were triggered by WAF?"
4. "Did CrowdStrike detect any suspicious activity from the same IPs?"
5. "Were there any Kubernetes access attempts from the brute force IPs?"
```

**Key Demo Points:**
- Attack pattern identification (Tor exit nodes, credential stuffing)
- WAF effectiveness (blocks vs allows)
- Cross-source IP correlation

---

### 3. **Typosquatting Detection** 🎭
**Hook:** "Alert about 'react-domm' package (typo of 'react-dom')"

**Questions:**
```
1. "Show me all npm events with typosquat indicator type"
2. "Which packages look like typosquats - 'react-domm', 'lodashs', 'axois'?"
3. "What CWE-829 violations were detected?"
4. "Which environments installed these typosquatting packages?"
5. "Were the typosquatting packages blocked or allowed?"
```

**Key Demo Points:**
- Supply chain attack detection
- CWE-829 (Untrusted Control Sphere)
- Environment impact analysis

---

### 4. **Kubernetes Unauthorized Access** 🔒
**Hook:** "Multiple 403 Forbidden responses for secrets access"

**Questions:**
```
1. "Show me all Kubernetes audit events with 403 Forbidden responses"
2. "Which users or IPs attempted to access secrets but were denied?"
3. "Were there any delete operations attempted on critical resources?"
4. "What namespaces were targeted by unauthorized access attempts?"
5. "Did the same IPs appear in other security incidents?"
```

**Key Demo Points:**
- Authorization failure detection
- Privilege escalation attempts (delete operations)
- Attack reconnaissance phase identification

---

### 5. **CWE Top 25 Compliance Audit** 📋
**Hook:** "Need to demonstrate CWE Top 25 compliance"

**Questions:**
```
1. "Show me all events mapped to CWE-94 (Code Injection) - which packages?"
2. "What CWE-522 (Credential Protection) violations were detected?"
3. "What CWE-829 (Untrusted Control Sphere) issues exist?"
4. "Which CWE vulnerabilities had critical severity?"
5. "Give me a summary of CWE violations by environment (ci/dev/prod)"
```

**Key Demo Points:**
- Compliance reporting
- CWE mapping across all sources
- Risk prioritization by severity

---

## 🚀 Quick Start Questions (30 seconds each)

**Service Account Compromise (Incident C) ⭐:**
- "Show me all events for user svc_deploy"
- "Which IPs did svc_deploy authenticate from?"
- "Show me Cloudflare events from IP 45.227.255.206"
- "What Kubernetes secrets did svc_deploy access?"
- "Were there data exfiltration attempts by svc_deploy?"

**Crypto Mining Attack (Incident A):**
- "Show me all npm events for package crypto-linter"
- "Which Kubernetes pods have 'crypto' in the name?"
- "Show me CrowdStrike events with xmrig or mining"
- "Were there connections to pool.minexmr.com?"

**Brute Force Attack (Incident B):**
- "Show me Cloudflare events from IP 185.220.101"
- "How many 401 or 403 responses on /login?"
- "Which IPs had the most failed login attempts?"
- "Show me WAF blocks in the last week"

**npm Supply Chain:**
- "Which npm packages have critical severity indicators?"
- "Show me typosquatting packages like react-domm or lodashs"
- "What credential theft events were detected?"

**Kubernetes Security:**
- "Show me Kubernetes 403 Forbidden events"
- "Which users got denied access to secrets?"
- "Were there any delete attempts on critical resources?"

**Cross-Source Correlation:**
- "Show me all events from IP 10.42.1.50 across all sources"
- "Did the same IPs appear in both Cloudflare and Kubernetes events?"
- "Correlate crypto-linter npm install with Kubernetes pod creation"

**CWE Compliance:**
- "What CWE-94 (Code Injection) violations exist?"
- "Show me CWE-522 (Credential Protection) events"
- "Which CWE vulnerabilities have critical severity?"

---

## 💡 Demo Tips

1. **Start with Impact:** "Show me critical/high severity events" → builds urgency
2. **Drill Down:** "Which packages?" → "Which environments?" → "What CWE?"
3. **Correlate:** Always ask "Did X happen around the same time as Y?"
4. **Timeline:** "Create a timeline of events" → shows attack progression
5. **Compliance:** "What CWE violations?" → shows business value

---

## 🎬 Sample Demo Flow: Crypto Mining Investigation (5 min)

```
[0:00] Hook: "We detected crypto mining traffic - let's investigate"
[0:30] Q1: "Show me all npm events for package 'crypto-linter'"
       → Shows 30 events with critical severity, CWE-94, postinstall downloading xmrig
[1:00] Q2: "Which Kubernetes pods were created with 'crypto' in the name?"
       → Shows crypto-linter-worker pods in default namespace
[1:30] Q3: "What secrets did these pods access?"
       → Shows access to aws-credentials, database-secrets, tls-certs
[2:00] Q4: "Show me CrowdStrike events with xmrig process activity"
       → Shows 60+ events with xmrig, connections to pool.minexmr.com:3333
[2:30] Q5: "Were there any Cloudflare blocks to mining pool domains?"
       → Shows some blocked, some allowed outbound to mining pools
[3:00] Q6: "What IPs were compromised? Show me the common hosts across all sources"
       → Shows 10.42.1.50-54 appearing in npm, K8s, CrowdStrike, Cloudflare
[3:30] Summary: "Attack chain: npm postinstall → xmrig download → K8s pod spawn → mining pool connections. 5 hosts compromised, 3 secrets accessed, CWE-94 violation."
[4:00] Q&A
```

## 🎬 Sample Demo Flow: Brute Force Investigation (5 min)

```
[0:00] Hook: "We're seeing credential stuffing attacks - let's investigate"
[0:30] Q1: "Show me Cloudflare events from IPs starting with 185.220.101"
       → Shows 150+ events, 401/403/429 responses, WAF blocks
[1:00] Q2: "How many unique attacker IPs and what countries?"
       → Shows 20 IPs from ru, cn, ir (Tor exit nodes pattern)
[1:30] Q3: "What security actions were triggered?"
       → Shows mix of block, challenge, some allowed
[2:00] Q4: "Did CrowdStrike see these IPs?"
       → Shows 100 suspicious activity events, credential_stuffing threat type
[2:30] Q5: "Were there any Kubernetes events from these IPs?"
       → Shows 403 Forbidden on secrets from 185.220.101.42 (recon phase)
[3:00] Q6: "Show me the attack timeline"
       → Day -7: K8s recon (secrets access denied) → Day -3: Brute force attack
[3:30] Summary: "Attacker reconnaissance on Day -7, main brute force attack on Day -3. 150+ attempts, WAF blocked most, attacker IPs correlate across all sources."
[4:00] Q&A
```

## 🎬 Sample Demo Flow: Service Account Compromise (5 min) ⭐ RECOMMENDED

**Pre-demo:** Run `snowsql -f "scripts/6.9 DEMO_INJECT_SERVICE_ACCOUNT_COMPROMISE.sql"`

```
[0:00] Hook: "We just got an alert that service account 'svc_deploy' may be compromised"
[0:30] Q1: "Show me all events for user 'svc_deploy' in the last 2 hours"
       → Shows events across Cloudflare, CrowdStrike, Kubernetes, npm
[1:00] Q2: "Which IPs did svc_deploy authenticate from?"
       → Shows 45.227.255.206 (external IP - unusual for service account!)
[1:30] Q3: "Were there failed login attempts before the successful one?"
       → Shows 50 credential stuffing attempts, then successful auth
[2:00] Q4: "What Kubernetes resources did svc_deploy access after the compromise?"
       → Shows secrets, configmaps, deployments accessed from external IP
[2:30] Q5: "Were there any data exfiltration attempts?"
       → Shows npm publish attempts with credential theft indicators
[3:00] Q6: "Show me the CrowdStrike alerts for this incident"
       → Shows CRITICAL alerts: compromised_credentials, account_takeover
[3:30] Summary: "Timeline: 2h ago credential stuffing → 1h ago successful auth → 45min K8s access → 30min exfil attempt. Attacker IP 45.227.255.206. Recommendation: Rotate svc_deploy credentials immediately."
[4:00] Q&A
```

---

## 📊 Expected Results Summary

**npm Events (~405 total):**
- ~300 baseline normal installs (lodash, react, express, etc.)
- ~30 crypto-linter events (CRITICAL - mining attack)
- ~25 typosquatting events (react-domm, lodashs, axois)
- ~20 credential theft events (event-stream, ua-parser-js)
- ~30 suspicious postinstall events

**Kubernetes Events (~450 total):**
- ~350 baseline normal audit events
- ~40 crypto-linter-worker pod events (5 days ago)
- ~60 403 Forbidden on secrets (attacker-recon, 7 days ago)
- ~20 delete attempts on critical resources

**Cloudflare Events (~600 total):**
- ~400 baseline normal traffic
- ~150 brute force attack events (185.220.101.x → /login)
- ~50 crypto mining C2 traffic (pool.minexmr.com)

**CrowdStrike Events (~470 total):**
- ~300 baseline endpoint events
- ~100 brute force suspicious activity
- ~70 crypto mining (xmrig process, stratum connections)

**Key Correlations:**
- IPs 10.42.1.50-54: Compromised hosts (appear in npm, K8s, CrowdStrike, Cloudflare)
- IPs 185.220.101.x: Attacker IPs (appear in Cloudflare, CrowdStrike, Kubernetes)
- IP 45.227.255.206: Service account attacker (appears in all sources after injection)
- Timeline: npm install (Day -5) → K8s pods (Day -5) → Mining traffic (Day -5)
- Timeline: K8s recon (Day -7) → Brute force (Day -3)
- Timeline: Credential stuffing (-2h) → Auth success (-1h) → K8s access (-45m) → Exfil (-30m)

**After running 6.9 (Service Account Compromise):**
- 50 credential stuffing events (Cloudflare)
- 30 lateral movement events (Cloudflare)
- 25 CrowdStrike suspicious activity events
- 20 Kubernetes secrets/resource access events
- 10 npm data exfiltration events
- 5 CrowdStrike CRITICAL alerts

---

## 🔍 Advanced Investigation Patterns

**Anomaly Detection:**
- "Show me unusual patterns in [source]"
- "What stands out in [timeframe]?"

**Blast Radius:**
- "Which systems were affected by [indicator]?"
- "What's the scope of [event]?"

**Attribution:**
- "Who triggered [event]?"
- "Which IPs/service accounts were involved?"

**Remediation:**
- "What's the status of [indicator]?"
- "Which events are detected vs blocked?"

