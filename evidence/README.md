# Evidence — Screenshot Capture Guide

This folder holds the visual proof behind each ticket, incident, and audit finding. Below is the exact list of screenshots to capture, named to match the references in each document so they render inline on GitHub.

## Redaction checklist (do this on EVERY screenshot before committing)

- [ ] No tenant IDs, subscription IDs, or object GUIDs
- [ ] No real email addresses or usernames outside the fictional `Link3IT.com` lab
- [ ] No passwords, tokens, secrets, or certificate content visible
- [ ] No real internal IPs/hostnames you want kept private
- [ ] No unrelated browser tabs, bookmarks, or notification popups
- [ ] Crop tightly to the relevant panel; blur anything sensitive that remains

---

## Screenshots to capture, by document

### TICKET-1001 — Shared drive access
- `TICKET-1001-group-membership-before.png` — Get-ADPrincipalGroupMembership output, user NOT in the access group
- `TICKET-1001-group-membership-after.png` — same command after re-adding, user now in the group
- `TICKET-1001-share-access-restored.png` — the share opening successfully in File Explorer

### TICKET-1002 — MFA lockout recovery
- `TICKET-1002-auth-methods-before.png` — Entra > user > Authentication methods, only the stale Authenticator
- `TICKET-1002-tap-issued.png` — Temporary Access Pass creation confirmation
- `TICKET-1002-auth-methods-after.png` — new Authenticator + a backup method registered

### TICKET-1003 — SSO / SAML attribute mismatch
- `TICKET-1003-saml-trace-before.png` — SAML trace showing NameID as objectID
- `TICKET-1003-claim-config.png` — Entra enterprise app > SSO > NameID claim set to user.mail
- `TICKET-1003-sso-success.png` — the app loading successfully after the fix

### TICKET-1004 — Incomplete offboarding
- `TICKET-1004-aduser-disabled.png` — Get-ADUser output showing Enabled: False on-prem
- `TICKET-1004-entra-still-enabled.png` — Entra showing the same user still enabled (the gap)
- `TICKET-1004-sync-scope.png` — Cloud Sync config showing the Disabled OU out of scope
- `TICKET-1004-tokens-revoked.png` — session revocation confirmation

### TICKET-1005 — CyberArk vault lockout recovery
- `TICKET-1005-account-error-state.png` — vaulted account showing reconciliation/verification error
- `TICKET-1005-secure-channel-repair.png` — Test-ComputerSecureChannel -Repair succeeding
- `TICKET-1005-account-reconciled.png` — account back to healthy/rotating after reconcile

### TICKET-1006 — EPM just-in-time elevation
- `TICKET-1006-install-blocked.png` — standard user hitting the "need administrator" block
- `TICKET-1006-jit-elevation.png` — EPM elevation prompt/approval for the specific action
- `TICKET-1006-install-success.png` — install completed, user still standard (no standing admin)

### TICKET-1007 — Conditional Access travel block
- `TICKET-1007-signin-log-ca-failure.png` — sign-in log, Conditional Access tab showing the policy as Failure
- `TICKET-1007-whatif-result.png` — Conditional Access What If tool showing the policy would block
- `TICKET-1007-timebound-exception.png` — the scoped exclusion / time-bound exception applied

### INC-001 — Conditional Access lockout
- `INC-001-ca-policy-exclusions.png` — the CA policy showing break-glass and sync-account exclusions
- `INC-001-report-only.png` — the policy in report-only mode before enforcement
- `INC-001-signin-log-loop.png` — sign-in log showing the MFA loop during the incident

### Audit — JML Identity Lifecycle Audit
- `audit-stale-accounts-query.png` — the Get-ADUser inactivity query and its result count
- `audit-4720-splunk.png` — Splunk search of Windows event 4720 (account creation) results
- `audit-reconciliation-output.png` — Invoke-IdentityReconciliation.ps1 output with MATCHED/UNMATCHED counts
- `audit-whatif-disable.png` — Disable-StaleAccounts.ps1 -WhatIf preview output

---

## Capture tips

- PowerShell: make the window wide enough that output is not truncated; a dark theme reads well on GitHub.
- Entra/portal: capture just the relevant blade, not the whole browser. Collapse the left nav if it shows tenant name.
- Consistency: same tool, same zoom, same crop style across shots makes the repo look intentional and professional.
- File format: PNG, reasonable resolution, keep each under ~500KB so the repo stays light.

Once captured and redacted, drop them in this folder with the exact filenames above and they render inline in each document on GitHub.
