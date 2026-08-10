# Scripts

PowerShell automation for identity lifecycle operations and audit remediation.

## Safety model
Every script here is **read-only by default**. Changing state requires an explicit switch. Service accounts are protected from logic built for human accounts. Changes are annotated in the directory with the reason and control reference.

## Invoke-IdentityReconciliation.ps1
Compares enabled Active Directory accounts against an authoritative HR source. Classifies each as MATCHED, UNMATCHED (no authoritative record), or MISSING (record with no account). Read-only.

```powershell
.\Invoke-IdentityReconciliation.ps1 -HRSourcePath "C:\path\hr.csv" -ExportPath "C:\reports"
```

## Disable-StaleAccounts.ps1
Identifies and optionally disables accounts inactive past a threshold. Report-only unless `-Remediate`. Supports `-WhatIf`. Excludes service accounts (they authenticate non-interactively and never populate LastLogonDate).

```powershell
.\Disable-StaleAccounts.ps1 -InactiveDays 90                          # report only
.\Disable-StaleAccounts.ps1 -InactiveDays 90 -Remediate -WhatIf       # preview
.\Disable-StaleAccounts.ps1 -InactiveDays 90 -Remediate              # execute
```

Requires PowerShell 5.1+ and the ActiveDirectory module (RSAT).

### Get-IdentitySnapshot.ps1
One-command triage snapshot for a user — the "check everything first" pattern before diving into connector logs or provisioning workflows. Answers the four questions that start most investigations (enabled? last logon? locked/expired? groups?) in a single read-only call. Accepts a sAMAccountName **or** an email address (falls back to `-Filter` on `mail` automatically).

```powershell
.\Get-IdentitySnapshot.ps1 -User dokafor
.\Get-IdentitySnapshot.ps1 -User "dana.okafor@link3it.com" -ShowGroups
```

Read-only. See [`docs/IAM-TRIAGE-PLAYBOOK.md`](../docs/IAM-TRIAGE-PLAYBOOK.md) for the full triage approach.
