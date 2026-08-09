# Remediation Runbook — Identity Lifecycle Audit Findings

**Environment:** Link3IT hybrid identity (on-prem Active Directory → Microsoft Entra ID)
**Source audit:** `docs/JML-Identity-Lifecycle-Audit.pdf`
**Framework:** NIST SP 800-53 Rev. 5 — Access Control (AC) family

---

## Purpose

This runbook documents how each finding from the identity lifecycle audit was remediated. It is written to be repeatable: another administrator should be able to follow it, understand why each step exists, and execute it safely.

**Operating principle used throughout:** *report before you remediate.* Every script defaults to read-only and requires an explicit switch to make changes. Broad account changes are validated with `-WhatIf` before execution.

---

## Remediation order and rationale

Findings were not remediated in numerical order. They were sequenced by dependency and risk:

| Order | Finding | Why this order |
|-------|---------|----------------|
| 1 | F-01 Reconciliation | Everything else depends on knowing which accounts are governed. You cannot safely disable accounts before you know what they are. |
| 2 | F-05 Service account inventory | Service accounts must be identified and protected *before* running inactivity logic, or automation breaks. |
| 3 | F-02 Inactive accounts | Once accounts are classified, stale human accounts can be disabled safely. |
| 4 | F-04 Test accounts | Subset of the classified population; low risk once identified. |
| 5 | F-03 Shared accounts | Requires process change and stakeholder involvement, not just a script. |
| 6 | F-06 Continuous detection | Preventive control; closes the loop so the gap does not reopen. |

> **Lesson recorded:** the original instinct was to start with F-02 (disable stale accounts) because it was the largest number. That would have disabled functioning service accounts, because service accounts authenticate non-interactively and never populate `LastLogonDate`. Classification had to come first.

---

## F-01 — Accounts not traceable to an authoritative source

**Control:** AC-2 Account Management
**Risk:** HIGH
**Script:** `scripts/Invoke-IdentityReconciliation.ps1`

### What the finding meant
The authoritative HR source contained 5 personnel records. The directory contained approximately 39 enabled accounts. Any account without a matching HR record is unmanaged: no owner, no lifecycle event will ever disable it, and it will never appear in a personnel-driven offboarding process.

### Remediation steps

1. **Run reconciliation in read-only mode.**
   ```powershell
   .\Invoke-IdentityReconciliation.ps1 `
       -HRSourcePath "C:\IAM\worknyte_authoritative.csv" `
       -ExportPath "C:\IAM\reports"
   ```
   The script classifies every enabled account as `MATCHED`, `UNMATCHED`, or `MISSING` (an HR record with no corresponding account — a provisioning gap in the other direction).

2. **Review the `UNMATCHED` export.** Each account gets a disposition:
   - **Adopt** — legitimate account; add an authoritative record and assign an owner
   - **Reclassify** — service or shared account; move to the service-account inventory (F-05)
   - **Remove** — no business justification; disable, then delete after a retention window

3. **Do not delete immediately.** Disable first, retain for a defined period, then remove. Deletion destroys the audit trail and SID history, and a wrongly-removed account is far more disruptive than a disabled one.

### Verification
Re-run the reconciliation. The `UNMATCHED` count should decrease to only accounts with a documented disposition in progress.

---

## F-05 — Service accounts lack documented ownership

**Control:** AC-2, AC-6 Least Privilege
**Risk:** MEDIUM

### Why this was remediated before F-02
Service accounts do not log on interactively, so they show as "never logged in" and would be caught by any naive inactivity rule. Identifying and protecting them first prevented an outage.

### Remediation steps

1. **Extract service accounts** using naming convention and directory location:
   ```powershell
   Get-ADUser -Filter { Enabled -eq $true } -Properties Description, whenCreated, PasswordLastSet |
       Where-Object { $_.SamAccountName -match '^(svc-|msol_|psm)' } |
       Select-Object SamAccountName, Name, Description, whenCreated, PasswordLastSet |
       Export-Csv "C:\IAM\reports\service-accounts.csv" -NoTypeInformation
   ```

2. **Record for each account:** owner (a named person, not a team), business purpose, systems it authenticates to, permission scope, credential rotation method, and review date.

3. **Vault credentials** for privileged service accounts in the privileged access platform so rotation is automated and check-out is attributed.

4. **Exclude from human lifecycle logic.** Service accounts must never be processed by joiner-mover-leaver rules built for people.

### Verification
Every service account in the directory appears in the inventory with a named owner. No service account is in scope for the inactivity script.

---

## F-02 — Inactive accounts remain enabled

**Control:** AC-2(3) Disable Accounts
**Risk:** HIGH
**Script:** `scripts/Disable-StaleAccounts.ps1`

### Remediation steps

1. **Report first — always.**
   ```powershell
   .\Disable-StaleAccounts.ps1 -InactiveDays 90 -ExportPath "C:\IAM\reports"
   ```
   Produces the candidate list. Makes no changes.

2. **Dry-run the change set.**
   ```powershell
   .\Disable-StaleAccounts.ps1 -InactiveDays 90 -Remediate -WhatIf
   ```
   `-WhatIf` prints exactly which accounts would be disabled without doing it. Review this list with the account owners before proceeding.

3. **Execute remediation.**
   ```powershell
   .\Disable-StaleAccounts.ps1 -InactiveDays 90 -Remediate `
       -DisabledOU "OU=Disabled,DC=Link3IT,DC=com"
   ```
   Disables the account, stamps the description with the reason and date, and moves it to the Disabled OU.

### Safety controls built into the script
- Report-only by default; requires explicit `-Remediate`
- Service accounts excluded by default
- `SupportsShouldProcess` enables `-WhatIf` and `-Confirm`
- Each disabled account is annotated with the control reference and date, so the change is self-documenting for audit

### Verification
```powershell
Get-ADUser -Filter { Enabled -eq $true } -Properties LastLogonDate |
    Where-Object { $_.LastLogonDate -lt (Get-Date).AddDays(-90) -and $_.SamAccountName -notmatch '^(svc-|msol_|psm)' } |
    Measure-Object
```
Count should be zero (or only accounts with a documented exception).

---

## F-04 — Test and placeholder accounts remain enabled

**Control:** AC-2
**Risk:** MEDIUM

### Remediation steps

1. **Identify** accounts matching test/placeholder patterns (`cpm-test`, `splunktest`, accounts with placeholder surnames such as "Unknown").
2. **Confirm no active dependency** before disabling — test accounts are sometimes wired into automation.
3. **Disable and annotate**, then remove after a retention window.
4. **Prevent recurrence:** adopt a naming standard (`tst-` prefix) and require an expiry date in the description at creation time, so test accounts can be found and aged out automatically.

---

## F-03 — Shared and functional accounts

**Control:** AC-2, IA-2
**Risk:** MEDIUM

This finding cannot be fixed with a script alone; it requires a process change.

### Remediation approach

1. **Inventory** shared accounts and identify who currently uses each one.
2. **Replace with individual accounts plus role-based groups** wherever the application supports it. The access stays the same; the accountability improves.
3. **Where a shared account is genuinely required** (some legacy applications cannot do otherwise), vault the credential so check-out is attributed to a named person and the session is recorded.
4. **Document any exception** with a business justification and a review date.

> **Why this matters:** shared credentials break attribution. The log records the account, not the person. During an incident you can prove *what* happened but not *who* did it.

---

## F-06 — Accounts created outside the governed process

**Control:** AC-2
**Risk:** MEDIUM

### Remediation approach — preventive control

1. **Detect at creation.** Alert on Windows Security event 4720 (user account created) where the new account has no matching authoritative record.

   Reference detection logic (SIEM):
   ```
   index=windows_ad EventCode=4720
   | eval sam=lower(mvindex(Account_Name, -1))
   | lookup hr_authoritative sam_account AS sam OUTPUT employee_id
   | where isnull(employee_id)
   | eval finding="UNGOVERNED ACCOUNT CREATION"
   | table _time, sam, finding
   ```

   > **Implementation note:** in event 4720 the `Account_Name` field is multivalue — the first value is the administrator who performed the action, the second is the account that was created. `mvindex(Account_Name, -1)` selects the created account. Keying on the wrong value produces false positives against your own administrators.

2. **Restrict direct creation.** Provisioning should flow through the automated engine. Direct creation is reserved for break-glass and requires documented justification.

3. **Schedule recurring reconciliation** (see F-01) so drift is caught continuously rather than at the next audit.

---

## Summary of controls implemented

| Control | Implementation | Evidence |
|---------|----------------|----------|
| AC-2 | Automated reconciliation against authoritative source | `Invoke-IdentityReconciliation.ps1` + CSV reports |
| AC-2(3) | Inactivity-based account disablement with service-account protection | `Disable-StaleAccounts.ps1` + change log |
| AC-2 | Service account inventory with named ownership | `service-accounts.csv` |
| AC-6 | Least privilege via role-based groups replacing shared accounts | Group design documentation |
| AU-6 | SIEM detection of ungoverned account creation | Saved SIEM alert |

---

## Operating notes

- **Scripts are read-only by default.** This is deliberate. An identity script that changes state on first run is a liability.
- **`-WhatIf` before every bulk change.** The cost of reviewing a change set is minutes; the cost of a bad bulk disable is an outage.
- **Disable, retain, then delete.** Never delete first.
- **Annotate every automated change** with the reason and control reference, so the directory itself carries the audit trail.

---

*Runbook maintained as part of the Link3IT identity lab. Scripts are written against Active Directory and PowerShell 5.1+ with the ActiveDirectory module.*
