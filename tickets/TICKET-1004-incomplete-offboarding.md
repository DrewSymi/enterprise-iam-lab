# TICKET-1004 — Terminated employee still had active access after departure

| | |
|---|---|
| **Type** | Incident (Leaver / Deprovisioning) · Security |
| **Priority** | P2 — High (security exposure) |
| **Status** | Resolved |
| **Domain** | JML (Leaver) · Deprovisioning · Hybrid identity |
| **Systems** | Active Directory, Microsoft Entra ID (Cloud Sync) |

---

## Reported issue

During a routine access review, a terminated employee (left the company three weeks earlier) was found still able to reach cloud email and at least one SaaS application. Their on-premises AD account had been disabled on their last day, so at first glance offboarding looked complete.

---

## Investigation

**Step 1 — Confirm the on-prem state.** The AD account was correctly **disabled** — the last-day task had run.
```powershell
Get-ADUser mlindberg -Properties Enabled, whenChanged | Select Name, Enabled, whenChanged
```
`Enabled : False`. So why was cloud access still working?

**Step 2 — Check the cloud state.** In Entra, the corresponding user was still **enabled**. In a hybrid environment, disabling an on-prem account does **not** instantly disable the cloud account — the change has to synchronize, and only if the account is in sync scope and the sync is healthy.

**Step 3 — Check sync scope and health.** The account's OU was reviewed against the Cloud Sync scoping. The account had been moved to a `Disabled Users` OU on termination — an OU that was **outside** the sync scope. Because the disable happened *and* the move happened, the disabled state never synced: once the object left sync scope, Cloud Sync stopped managing it, freezing the cloud account in its last-known **enabled** state.

**Step 4 — Confirm the exposure.** Because the cloud account stayed enabled, cloud-only access (email, SSO apps that trust Entra) continued to work even though the on-prem account was dead. Active sessions and refresh tokens extended the window further.

---

## Root cause

An **ordering problem** in the leaver process. The account was disabled and then immediately moved to an out-of-scope OU. Moving it out of sync scope before the disabled state synchronized meant the cloud account was never updated. On-prem looked done; the cloud half was orphaned in an enabled state.

---

## Resolution

1. Disabled the account directly in Entra to stop cloud access immediately.
2. **Revoked the user's sessions / refresh tokens** so existing tokens could not continue to be used:
   ```powershell
   Revoke-MgUserSignInSession -UserId "mlindberg@link3it.com"
   ```
3. Confirmed the SaaS applications, which trust Entra, no longer granted access once the account was disabled and tokens revoked.
4. Documented the account for scheduled deletion after the retention window (disable and retain, then delete — never delete immediately).

---

## Evidence

- `evidence/TICKET-1004-aduser-disabled.png` — on-prem account disabled
- `evidence/TICKET-1004-entra-still-enabled.png` — cloud account still enabled (the gap)
- `evidence/TICKET-1004-sync-scope.png` — Disabled OU outside Cloud Sync scope
- `evidence/TICKET-1004-tokens-revoked.png` — sessions revoked, cloud access stopped

---

## Prevention

Fixed the leaver ordering so the disabled state reliably reaches the cloud:

- **Disable first, let it sync, then move.** Do not move the account out of sync scope until the disabled state has synchronized to Entra.
- Keep the `Disabled Users` OU **in** sync scope, or use a lifecycle workflow that disables the cloud account explicitly rather than relying on OU-based scoping.
- Add **token/session revocation** to every leaver — disabling an account does not kill live sessions on its own.
- This is exactly the class of finding the identity audit surfaced (accounts that no lifecycle event fully deprovisions); see `docs/JML-Identity-Lifecycle-Audit.pdf`.

**Lesson:** In hybrid identity, "disabled on-prem" is not "disabled everywhere." The most dangerous offboarding gaps are the ones that *look* complete on the side you checked.
