# Enterprise IAM Lab — Operation Link3IT

A self-built hybrid identity environment used to practice real identity and access management operations: joiner-mover-leaver lifecycle, access governance, privileged access, and the audit and remediation work that follows.

**Built and operated by [Andrew Symister](https://iamandrewsymister.com)** · New York, NY

> **This is a laboratory environment.** It runs real software on real infrastructure — a live Active Directory forest, a Microsoft Entra ID tenant with hybrid sync, and a SIEM ingesting genuine directory events. Findings and evidence in this repository come from real queries against those systems. It is not a production enterprise, and nothing here claims to be.

---

## Why this exists

Most identity work is invisible until it fails. An account that should have been disabled six months ago. A role change that added access without removing the old. A service account nobody owns.

I built this environment to practice the operational side of identity governance — not just configuring tools, but running the lifecycle, auditing it, finding what broke, and fixing it with repeatable automation.

---

## Architecture

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

**Platform:** Ubuntu 24.04 host, KVM/QEMU virtualization, Docker for containerized services. Cockpit and Portainer for host and container management. Jira for the operations board.

---

## What's in this repository

| Path | Contents |
|------|----------|
| [`docs/`](docs/) | Audit report, remediation runbook, **IAM triage playbook**, architecture notes |
| [`scripts/`](scripts/) | PowerShell automation for reconciliation and lifecycle remediation |
| [`tickets/`](tickets/) | Seven worked IAM tickets across file access, MFA, SSO/SAML, offboarding, CyberArk EPM & PASM, and Conditional Access &mdash; each documented end to end |
| [`incidents/`](incidents/) | Incident writeups — what broke, root cause, recovery |
| [`evidence/`](evidence/) | Screenshots and exported artifacts |

---

## Featured work

### 🎫 Worked IAM tickets — seven scenarios, seven domains
**[`tickets/`](tickets/)**

Real identity troubleshooting worked end to end, each following the same structure: reported issue → investigation → root cause → resolution → evidence → prevention. Together they span the breadth of day-to-day IAM work:

- **File access** — NTFS vs share permissions and group-membership diagnosis ([1001](tickets/TICKET-1001-shared-drive-access.md))
- **MFA** — lockout recovery with Temporary Access Pass, identity verified before reset ([1002](tickets/TICKET-1002-mfa-lockout-recovery.md))
- **SSO / SAML** — reading an assertion to fix a NameID/attribute mismatch ([1003](tickets/TICKET-1003-sso-saml-attribute-mismatch.md))
- **Offboarding** — a hybrid deprovisioning gap where "disabled on-prem" wasn't "disabled everywhere" ([1004](tickets/TICKET-1004-incomplete-offboarding.md))
- **CyberArk PASM** — vaulted local-admin recovery during a stale-machine lockout ([1005](tickets/TICKET-1005-cyberark-vault-lockout-recovery.md))
- **CyberArk EPM** — just-in-time elevation that elevates the action, not the user ([1006](tickets/TICKET-1006-epm-jit-elevation.md))
- **Conditional Access** — sign-in log analysis and a time-bound exception for approved travel ([1007](tickets/TICKET-1007-conditional-access-travel-block.md))

These are the job itself: reproduce, diagnose to root cause, fix safely, document so it doesn't recur.

### 🔎 IAM Triage Playbook
**[`docs/IAM-TRIAGE-PLAYBOOK.md`](docs/IAM-TRIAGE-PLAYBOOK.md)** · **[`scripts/Get-IdentitySnapshot.ps1`](scripts/Get-IdentitySnapshot.ps1)**

The first five minutes of most identity investigations: validate the object before diving into connector logs or provisioning workflows. Covers the `Get-ADUser -Properties *` sanity check and the four questions it answers, the `-Identity` vs `-Filter` gotcha, checking **both** AD and Entra in hybrid environments, forcing a delta sync, and finding the touched account during incident response. The companion script turns the pattern into one read-only command that accepts a username or an email.

### 📋 Identity Lifecycle (JML) Audit
**[`docs/JML-Identity-Lifecycle-Audit.pdf`](docs/JML-Identity-Lifecycle-Audit.pdf)**

A four-page access risk assessment mapped to **NIST SP 800-53 Rev. 5** (AC-2, AC-2(3), AC-5, AC-6, IA-2).

Six findings with risk ratings, evidence, and a prioritized remediation plan. Headline finding: **34+ enabled accounts with no corresponding record in the authoritative source** — accounts that no lifecycle event would ever disable.

The report includes a *Controls Operating Effectively* section. An audit that only lists problems is a complaint; an audit that also documents what works is an assessment.

### ⚙️ Remediation automation
**[`scripts/`](scripts/)**

- **`Invoke-IdentityReconciliation.ps1`** — compares every enabled directory account against the authoritative source and classifies it as `MATCHED`, `UNMATCHED`, or `MISSING` (an HR record with no account — a provisioning gap in the other direction). Read-only.
- **`Disable-StaleAccounts.ps1`** — inactivity-based account disablement with `-WhatIf` support, service-account protection, and self-documenting change annotations.

Both default to report-only. An identity script that changes state on first run is a liability.

### 📖 Remediation runbook
**[`docs/REMEDIATION-RUNBOOK.md`](docs/REMEDIATION-RUNBOOK.md)**

Documents *how* and *why* each finding was remediated, including the sequencing decision that matters most:

> Remediation was ordered by dependency, not by finding number. The instinct was to start with the largest finding — 39 stale accounts — but that would have disabled functioning service accounts, because service accounts authenticate non-interactively and never populate `LastLogonDate`. Classification had to come first.

### 🔥 Incident: Conditional Access lockout
**[`incidents/`](incidents/)**

A broad "Require MFA" policy was deployed with a break-glass exclusion. The exclusion silently failed to save, and administrators were caught in an MFA loop. Documented root cause, recovery, and the controls added to prevent recurrence.

Real failures are more instructive than clean successes.

---

## Capabilities demonstrated

**Identity lifecycle** — HR-driven provisioning and deprovisioning, joiner-mover-leaver automation, correlation on a unique identifier, orphan account detection, RBAC group models where a role change swaps a single group with zero residual access.

**Access governance** — access certification campaigns with automatic remediation, entitlement models, least privilege, audit evidence production.

**Authentication and access control** — Conditional Access policy design with break-glass and service-account exclusions, MFA enforcement, device compliance, SSO federation (SAML/OIDC) with Entra ID as identity provider.

**Privileged access** — service account governance, credential rotation concepts, privileged session response, separation of privileged and standard access.

**Detection and audit** — SIEM correlation of directory events against an authoritative source to surface ungoverned account creation, NIST 800-53 control mapping, audit-ready documentation.

**Operations** — ITIL-aligned ticket handling, change documentation, runbook authoring, incident writeups.

---

## Operating principles used throughout

These are the habits the environment enforced, learned mostly by breaking things first:

- **Report before you remediate.** Every automation defaults to read-only.
- **`-WhatIf` before every bulk change.** Reviewing a change set costs minutes; a bad bulk disable costs an outage.
- **Disable, retain, then delete.** Deletion destroys the audit trail.
- **Classify before you act.** Service accounts and human accounts cannot share the same lifecycle logic.
- **Build the break-glass path before you enforce the policy** — and then test that the exclusion actually works.
- **Verify in report-only mode.** Any broad access policy gets validated against real sign-in logs before enforcement.
- **Annotate automated changes** with the reason and control reference, so the directory carries its own audit trail.

---

## Vendor translation

The environment runs Microsoft Entra ID and MidPoint, but the concepts are portable. Where relevant, documentation notes the equivalent in other platforms:

| Concept | Entra ID | Okta | SailPoint |
|---------|----------|------|-----------|
| Access policy | Conditional Access | Sign-On / Authentication Policy | Access Policy |
| Certification | Access Reviews | Access Certifications | Certifications |
| Lifecycle automation | Lifecycle Workflows | Lifecycle Management | Lifecycle Manager |
| Directory sync | Cloud Sync / Connect Sync | Directory Integration (AD Agent) | Source aggregation |

---

## Repository status

This is an active environment. Work in progress is tracked openly rather than hidden:

- ✅ Hybrid identity sync, Conditional Access, access reviews, SSO federation, audit and remediation
- 🔄 Lifecycle workflow testing, additional worked tickets, video walkthrough
- ⏸️ **Known open issue:** MidPoint's LDAP connector times out completing the LDAPS session against the domain controller. Routing, certificate trust, domain signing policy, credentials, and connector selection have each been eliminated with evidence; the remaining suspect is the ConnId/MINA TLS negotiation from within the container. Documented as a scoped investigation rather than quietly dropped.

---

## Contact

**Andrew Symister**
[iamandrewsymister.com](https://iamandrewsymister.com) · [LinkedIn](https://linkedin.com/in/andrew-symister)

Open to remote and hybrid Identity and Access Management roles.
