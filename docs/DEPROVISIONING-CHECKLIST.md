# Deprovisioning Verification Checklist — "disabled" is not "removed"

Disabling a user in on-premises Active Directory is **not** the same as fully removing their access. Offboarding is not complete until access is removed **and verified** across every connected system.

If offboarding only disables the AD account, a former employee's identity can still be an open door: an active cloud session, a still-valid refresh token, a SaaS account that authenticates locally, an API token, a shared-mailbox permission, or a privileged group membership that no one revisited.

This checklist is the verification standard behind the incomplete-offboarding failure documented in [`tickets/TICKET-1004-incomplete-offboarding.md`](../tickets/TICKET-1004-incomplete-offboarding.md).

---

## The core principle

> Deprovisioning is a **multi-system** action, not a single-system one. Every place an identity can authenticate or hold standing access is a place that must be closed and confirmed closed.

"I disabled the AD account" answers one system. A leaver has an identity footprint across many.

---

## Verification checklist

### On-premises Active Directory
- [ ] Account **disabled** (not just password reset)
- [ ] Removed from **privileged and access groups** (or membership captured for audit before removal)
- [ ] Moved to a Disabled OU **that is still in sync scope** (see hybrid note below)
- [ ] Description stamped with offboarding date and reason for audit trail

### Microsoft Entra ID (cloud)
- [ ] Cloud account shows **disabled** (confirm — disabling on-prem does not guarantee this synced)
- [ ] **Sessions and refresh tokens revoked** — a disabled account can keep working until tokens expire
  ```powershell
  Revoke-MgUserSignInSession -UserId "user@domain.com"
  ```
- [ ] Registered **authentication methods** reviewed (MFA devices no longer a re-entry path)
- [ ] Removed from **Entra security groups** and app-assignment groups

### Federated / SaaS applications
- [ ] Access removed in each **SSO-integrated app** (SSO removes the login path, but check for local/break-glass accounts inside the app)
- [ ] **Local application accounts** (apps with their own credential store, not just SSO) disabled
- [ ] **API tokens / personal access tokens** the user created revoked
- [ ] **Service accounts they owned** reassigned to a new owner (not orphaned)

### Access and connectivity
- [ ] **VPN / remote access** revoked
- [ ] **Shared mailbox / delegate / Send-As** permissions removed
- [ ] **Distribution list and shared resource** memberships reviewed
- [ ] **Privileged access** (PAM safes, vault permissions, admin roles) removed

### Verification (the step most offboarding skips)
- [ ] Confirmed the account **cannot authenticate** to cloud email/apps after the change
- [ ] Confirmed **sync propagated** the disabled state to the cloud
- [ ] Documented what was removed, so the offboarding is auditable

---

## The hybrid trap (why verification matters)

The most dangerous offboarding gaps are the ones that *look* complete on the side you checked. A real failure mode:

1. AD account disabled on the last day — looks done.
2. Account immediately moved to a Disabled OU **outside** sync scope.
3. Because it left sync scope before the disabled state synced, the **cloud account stayed enabled**.
4. Cloud email and SSO apps kept working for weeks — because no one checked the cloud side.

Disabling on-prem is not disabling everywhere. **Verify both planes**, and revoke tokens so existing sessions can't outlive the disable.

---

## Why this is an IAM skill, not a checkbox

Anyone can disable an account. The IAM discipline is knowing the **full footprint** of an identity and confirming every door is closed — because the cost of a missed one is a former employee with live access to systems, data, and revenue. Deprovisioning done right is quiet, complete, and provable.

Related in this repo:
- [`tickets/TICKET-1004-incomplete-offboarding.md`](../tickets/TICKET-1004-incomplete-offboarding.md) — the exact failure this checklist prevents
- [`docs/JML-Identity-Lifecycle-Audit.pdf`](JML-Identity-Lifecycle-Audit.pdf) — the audit finding for accounts no lifecycle event fully deprovisions
- [`scripts/Invoke-IdentityReconciliation.ps1`](../scripts/Invoke-IdentityReconciliation.ps1) — detects accounts that fell out of governance
