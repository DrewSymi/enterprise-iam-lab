# REQ0045015 — Stale account remediation

| | |
|---|---|
| **Type** | Service Request (Standard Change) |
| **Priority** | Medium |
| **Status** | Closed — Successful |
| **Source finding** | F-02, Identity Lifecycle Audit |
| **Control** | NIST SP 800-53 AC-2(3) — Disable Accounts |
| **Systems** | Active Directory (DC01) → Microsoft Entra ID (via Cloud Sync) |

---

## Request

Following the identity lifecycle audit, remediate finding **F-02**: enabled Active Directory accounts with no interactive logon activity within the preceding 90 days.

Enabled accounts with no usage represent unmonitored attack surface. Credentials may be weak or unrotated, and a compromise is unlikely to be detected because there is no baseline of legitimate activity to deviate from.

---

## Pre-change assessment

**Population identified:** 39 enabled accounts exceeding the 90-day inactivity threshold, the majority with no recorded logon at all.

**Critical scoping decision:** the initial population included service accounts supporting privileged access infrastructure, ITSM integration, HR integration, and monitoring.

> Service accounts authenticate non-interactively and therefore never populate `LastLogonDate`. Disabling them on an inactivity basis would have broken functioning automation — including the directory synchronization service account, which would have silently halted hybrid sync.
>
> Service accounts were excluded from this change and routed to a separate service-account inventory workstream.

**Risk assessment:** Medium. Bulk account disablement carries the risk of disabling accounts still required. Mitigated by report-only review and dry-run validation prior to execution.

**Rollback plan:** accounts are disabled, not deleted, and annotated with the change reference. Re-enablement is a single command per account if a disablement proves incorrect.

---

## Execution

### 1. Report-only review

```powershell
.\Disable-StaleAccounts.ps1 -InactiveDays 90 -ExportPath "C:\IAM\reports"
```

Produced the candidate list. No changes made. Output reviewed to confirm the population and the service-account exclusions behaved as expected.

### 2. Dry-run validation

```powershell
.\Disable-StaleAccounts.ps1 -InactiveDays 90 -Remediate -WhatIf
```

`-WhatIf` printed the exact change set without executing it. Reviewed line by line before proceeding.

### 3. Execution

```powershell
.\Disable-StaleAccounts.ps1 -InactiveDays 90 -Remediate `
    -DisabledOU "OU=Disabled,DC=Link3IT,DC=com"
```

Each account was disabled, annotated in the description field with the control reference and date, and moved to the Disabled OU.

---

## Verification

**Directory state:**

```powershell
Get-ADUser -Filter { Enabled -eq $true } -Properties LastLogonDate |
    Where-Object {
        $_.LastLogonDate -lt (Get-Date).AddDays(-90) -and
        $_.SamAccountName -notmatch '^(svc-|msol_|psm)'
    } | Measure-Object
```

Confirmed no remaining enabled human accounts exceeding the inactivity threshold.

**Hybrid propagation:** verified that the disabled account state propagated to Microsoft Entra ID via Cloud Sync, confirming the change took effect in both the on-premises directory and the cloud identity plane.

> This verification step matters. In a hybrid environment, disabling an account on-premises does not immediately disable cloud access. If synchronization is broken or delayed, an account can remain active in the cloud after being disabled on-premises — a gap that offboarding processes frequently miss.

**Service account integrity:** confirmed directory synchronization continued to function, verifying that service accounts were correctly excluded.

---

## Closure notes

Remediation of audit finding F-02 completed successfully. Stale accounts were disabled, annotated, and relocated to the Disabled OU. Cloud propagation verified. No service impact.

Service accounts were deliberately excluded from this change and are being addressed under a separate workstream establishing documented ownership, business justification, and a review cadence (audit finding F-05).

Accounts remain disabled rather than deleted, preserving the audit trail. Deletion will follow the defined retention period.

**Recommended follow-up:** implement the inactivity check on a recurring schedule so the condition is detected continuously rather than at the next audit.

---

## Reflection

The most consequential part of this change was the part that involved no execution at all: recognizing that the largest finding could not be remediated as a single population.

Running the obvious command against all 39 accounts would have satisfied the audit finding and broken directory synchronization at the same time. Classification before action is what separated a successful change from an outage.
