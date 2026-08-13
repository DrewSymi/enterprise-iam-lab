<div align="center">

# 🔐 Operation Link3IT

### The case file of an identity operator holding a financial firm's access perimeter

*Investigate the directory · trace the break · remediate without collateral damage · prove every change*

<br>

![Active Directory](https://img.shields.io/badge/Active_Directory-Windows_Server_2022-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![Entra ID](https://img.shields.io/badge/Microsoft_Entra_ID-Hybrid_Sync-0067B8?style=for-the-badge&logo=microsoftazure&logoColor=white)
![Okta](https://img.shields.io/badge/Okta-SSO_Federation-007DC1?style=for-the-badge&logo=okta&logoColor=white)
![CyberArk](https://img.shields.io/badge/CyberArk-EPM_%2B_PASM-FF0000?style=for-the-badge&logo=cyberark&logoColor=white)

![PowerShell](https://img.shields.io/badge/PowerShell-Automation-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![Python](https://img.shields.io/badge/Python-Provisioning-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Splunk](https://img.shields.io/badge/Splunk-SIEM-000000?style=for-the-badge&logo=splunk&logoColor=white)
![NIST](https://img.shields.io/badge/NIST_800--53-Audit-2E5090?style=for-the-badge)

<br>

**Built and operated by Andrew Symister**
`Identity & Access Management` · `Financial Services` · New York, NY

[![LinkedIn](https://img.shields.io/badge/LinkedIn-andrewsymister-0A66C2?style=flat-square&logo=linkedin&logoColor=white)](https://linkedin.com/in/andrewsymister)

</div>

---

> [!NOTE]
> **This is a laboratory environment.** It runs real software on real infrastructure — a live Active Directory forest, a Microsoft Entra ID tenant with hybrid sync, and a SIEM ingesting genuine directory events. Findings and evidence come from real queries against those systems. It is not a production enterprise, and nothing here claims to be.

---

## 📖 Quick navigation

| I want to see... | Go to |
|---|---|
| 🎫 Real troubleshooting, worked end to end | [**Worked tickets**](tickets/) — 7 scenarios across 7 domains |
| 📋 A formal access audit with findings | [**JML Audit**](docs/JML-Identity-Lifecycle-Audit.pdf) — NIST 800-53 |
| ⚙️ Automation I wrote | [**Scripts**](scripts/) — reconciliation, remediation, triage |
| 🔥 How I handle failure | [**Incident writeup**](incidents/INC-001-conditional-access-lockout.md) |
| 🔐 How I think about PAM | [**PAM concepts reference**](docs/PAM-CONCEPTS-REFERENCE.md) |
| 🔎 How I diagnose | [**Triage playbook**](docs/IAM-TRIAGE-PLAYBOOK.md) · [**Identity chain**](docs/TRACING-THE-IDENTITY-CHAIN.md) |

---

## 🗺️ The premise

> *Identity is the new perimeter. This is what it looks like to stand on it.*

**Link3IT** is a mid-size financial firm. Roughly 45 identities, a hybrid directory, a cloud tenant, privileged accounts — and every one of them a door into systems, data, and revenue.

I'm the operator responsible for those doors.

This repository is my **case file** — the operational record of running that perimeter. Not a list of projects. A trail of evidence. Every folder is part of the same investigation: *who has access, should they, is it provable, and where does the chain break?*

Most identity work is invisible until it fails — the account that should have been disabled six months ago, the role change that added access without removing the old, the service account nobody owns. This file is what it looks like to find those before they find you.

**Follow the evidence:**

```
  THE CASE           →  can I account for every identity on the perimeter?
  THE INVESTIGATION  →  audit the directory against the authoritative source
  THE FINDINGS       →  34+ accounts no one owns · 39 stale · 1 created off-book
  THE RESPONSE       →  remediate with automation that can't cause collateral damage
  THE CALLS          →  7 tickets — the daily work of holding the line
  THE NIGHT IT BROKE →  an incident, documented honestly
  THE FIELD NOTES    →  lessons written down so the next operator doesn't bleed
```

---

## 🏗️ The environment (the scene)

```
   Authoritative HR source (CSV feed)
                │
                ▼
   ┌────────────────────────────┐
   │  Identity governance layer │
   │  • Entra ID Governance     │  ← primary: lifecycle workflows, access reviews
   │  • MidPoint (open source)  │  ← secondary: IGA engine patterns
   └──────────┬─────────────────┘
              │
              ▼
   Active Directory (DC01, Windows Server 2022)
   LDAPS via AD CS · OU-based access model
              │
              ▼  Entra Cloud Sync (outbound agent)
              │
   Microsoft Entra ID  ──►  SaaS applications via SSO (SAML/OIDC)
   Conditional Access · MFA · Access reviews · Lifecycle workflows
              │
   ┌──────────┴──────────┐
   ▼                     ▼
  CyberArk (PAM)      Splunk (SIEM)
  privileged &        4720 / 4725 / 4740
  service accounts    correlation & detection
```

**Platform:** Ubuntu 24.04 host · KVM/QEMU virtualization · Docker · Cockpit & Portainer for management · Jira operations board.

---

## 📂 What's in this repository

| Path | Contents |
|------|----------|
| [`docs/`](docs/) | Audit report, remediation runbook, **IAM triage playbook**, **identity-chain walkthrough**, **deprovisioning checklist**, **PAM concepts reference**, architecture notes |
| [`scripts/`](scripts/) | PowerShell automation for reconciliation and lifecycle remediation |
| [`tickets/`](tickets/) | Seven worked IAM tickets across file access, MFA, SSO/SAML, offboarding, CyberArk EPM & PASM, and Conditional Access &mdash; each documented end to end |
| [`incidents/`](incidents/) | Incident writeups — what broke, root cause, recovery |
| [`evidence/`](evidence/) | Screenshots and exported artifacts |

---

## 🔦 The case file

> Follow the evidence. Every item is real, documented, and clickable — the record of an identity operator at work.

### 🥇 The three exhibits that tell the story fastest

<table>
<tr>
<td width="33%" valign="top">

**🔍 The Investigation**

I audited the directory against the authoritative source. **34+ accounts** answered to no one. A 4-page case mapped to NIST 800-53 — 6 findings, ranked by risk, with what's working noted too.

[**→ Open the audit**](docs/JML-Identity-Lifecycle-Audit.pdf)

</td>
<td width="33%" valign="top">

**📞 The Calls**

Seven tickets — the daily work of holding the line. File access, MFA lockouts, a broken SSO claim, an offboarding that only *looked* done. Each traced to root cause.

[**→ Read the tickets**](tickets/)

</td>
<td width="33%" valign="top">

**🌙 The Night It Broke**

An MFA policy locked out the admins when a break-glass exclusion silently failed to save. No spin — root cause, recovery, and the controls that came after.

[**→ Read INC-001**](incidents/INC-001-conditional-access-lockout.md)

</td>
</tr>
</table>

### 📂 Everything in the file

| # | Exhibit | What it proves |
|---|---------|----------------|
| 🔍 | [**The Investigation** — JML Audit](docs/JML-Identity-Lifecycle-Audit.pdf) | Formal access audit mapped to NIST 800-53 with risk-rated findings and a remediation plan |
| 📞 | [**The Calls** — 7 Worked Tickets](tickets/) | End-to-end troubleshooting: file access, MFA, SSO/SAML, offboarding, CyberArk EPM & PASM, Conditional Access |
| ⚙️ | [**The Response** — Remediation Scripts](scripts/) | Read-only-by-default PowerShell: reconciliation, stale-account disablement, identity triage |
| 📖 | [**The Method** — Remediation Runbook](docs/REMEDIATION-RUNBOOK.md) | How & why each finding was fixed — including sequencing decisions that avoid outages |
| 🌙 | [**The Night It Broke** — INC-001](incidents/INC-001-conditional-access-lockout.md) | How I handle failure: root cause, recovery, prevention |
| 🔎 | [**First Five Minutes** — Triage Playbook](docs/IAM-TRIAGE-PLAYBOOK.md) | Validate the object before diving into logs — the operator's opening move |
| 🔗 | [**Follow the Chain** — Identity Path](docs/TRACING-THE-IDENTITY-CHAIN.md) | Tracing user → directory → IdP → app to find where access breaks |
| 🔐 | [**The Vault** — PAM Concepts](docs/PAM-CONCEPTS-REFERENCE.md) | How CyberArk PAM works: Vault/PVWA/CPM/PSM, change-verify-reconcile, session isolation |
| 🧰 | [**Close the Doors** — Deprovisioning](docs/DEPROVISIONING-CHECKLIST.md) | Why "disabled ≠ removed" — verifying access is gone across every connected system |
| ✅ | [**Prove It** — Audit & Edge Cases](docs/PROVING-IT-AUDIT-AND-EDGE-CASES.md) | Verifying changes land as audit events, and the JML edge cases that break the tidy HR trigger |

<details>
<summary><b>📝 The operator's notes on the key exhibits</b> (click to expand)</summary>

<br>

**📞 The Calls** each follow one structure — reported issue → investigation → root cause → resolution → evidence → prevention — across file access, MFA, SSO/SAML, offboarding, CyberArk EPM & PASM, and Conditional Access. This is the job itself: reproduce, diagnose to root cause, fix safely, document so it doesn't recur.

**🔎 First Five Minutes** covers the `Get-ADUser -Properties *` sanity check and the four questions it answers, the `-Identity` vs `-Filter` gotcha, checking **both** AD and Entra in hybrid environments, forcing a delta sync, and finding the touched account during incident response. A companion script turns the pattern into one read-only command.

**🔐 The Vault** explains the four CyberArk components and how they interact; change / verify / reconcile and the dependent-account gotcha that breaks apps after a "successful" rotation; why PSM isolates sessions instead of showing the password; and how PAM and EPM enforce least privilege together.

**🔍 The Investigation** is mapped to NIST SP 800-53 Rev. 5 (AC-2, AC-2(3), AC-5, AC-6, IA-2). Six findings with risk ratings and a prioritized remediation plan, including a *Controls Operating Effectively* section — an audit that only lists problems is a complaint; one that also documents what works is an assessment.

**⚙️ The Response** defaults to report-only. `Invoke-IdentityReconciliation.ps1` classifies every account as `MATCHED` / `UNMATCHED` / `MISSING`; `Disable-StaleAccounts.ps1` supports `-WhatIf`, protects service accounts, and annotates every change. An identity script that changes state on first run is a liability.

**📖 The Method** documents the sequencing decision that matters most:

> Remediation was ordered by dependency, not by finding number. The instinct was to start with the largest finding — 39 stale accounts — but that would have disabled functioning service accounts, because service accounts authenticate non-interactively and never populate `LastLogonDate`. Classification had to come first.

</details>

---

## 🎯 Capabilities demonstrated

| Domain | What I've built and operated |
|--------|------------------------------|
| **Identity lifecycle** | HR-driven provisioning & deprovisioning, joiner-mover-leaver automation, correlation on a unique identifier, orphan-account detection, RBAC models where a role change swaps one group with zero residual access |
| **Access governance** | Access certification campaigns with automatic remediation, entitlement models, least privilege, audit-evidence production |
| **Authentication & access control** | Conditional Access design with break-glass & service-account exclusions, MFA enforcement, device compliance, SSO federation (SAML/OIDC) with Entra ID as IdP |
| **Privileged access** | CyberArk EPM (JIT elevation) & PASM (vaulted credential retrieval), service-account governance, credential-rotation concepts, separation of privileged & standard access |
| **Detection & audit** | SIEM correlation of directory events against an authoritative source to surface ungoverned account creation, NIST 800-53 control mapping, audit-ready documentation |
| **Operations** | ITIL-aligned ticket handling, change documentation, runbook authoring, incident writeups |

---

## ⚙️ Operating principles used throughout

These are the habits the environment enforced, learned mostly by breaking things first:

- **Report before you remediate.** Every automation defaults to read-only.
- **`-WhatIf` before every bulk change.** Reviewing a change set costs minutes; a bad bulk disable costs an outage.
- **Disable, retain, then delete.** Deletion destroys the audit trail.
- **Classify before you act.** Service accounts and human accounts cannot share the same lifecycle logic.
- **Build the break-glass path before you enforce the policy** — and then test that the exclusion actually works.
- **Verify in report-only mode.** Any broad access policy gets validated against real sign-in logs before enforcement.
- **Annotate automated changes** with the reason and control reference, so the directory carries its own audit trail.
- **Verify the change landed as an event.** A change and its audit event are two different things — confirm the event was written, because in a regulated environment an unprovable change is treated as one that never happened. ([details](docs/PROVING-IT-AUDIT-AND-EDGE-CASES.md))

---

## 🔄 Vendor translation

The environment runs Microsoft Entra ID and MidPoint, but the concepts are portable. Where relevant, documentation notes the equivalent in other platforms:

| Concept | Entra ID | Okta | SailPoint |
|---------|----------|------|-----------|
| Access policy | Conditional Access | Sign-On / Authentication Policy | Access Policy |
| Certification | Access Reviews | Access Certifications | Certifications |
| Lifecycle automation | Lifecycle Workflows | Lifecycle Management | Lifecycle Manager |
| Directory sync | Cloud Sync / Connect Sync | Directory Integration (AD Agent) | Source aggregation |

---

## 📊 Repository status

This is an active environment. Work in progress is tracked openly rather than hidden:

- ✅ Hybrid identity sync, Conditional Access, access reviews, SSO federation, audit and remediation
- 🔄 Lifecycle workflow testing, additional worked tickets, video walkthrough
- ⏸️ **Known open issue:** MidPoint's LDAP connector times out completing the LDAPS session against the domain controller. Routing, certificate trust, domain signing policy, credentials, and connector selection have each been eliminated with evidence; the remaining suspect is the ConnId/MINA TLS negotiation from within the container. Documented as a scoped investigation rather than quietly dropped.

---

## 📬 Contact

**Andrew Symister**
[LinkedIn](https://linkedin.com/in/andrewsymister)

Open to remote and hybrid Identity and Access Management roles.
