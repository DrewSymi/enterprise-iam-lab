# TICKET-1005 — Admin cannot retrieve local-admin password from the vault during a lockout

| | |
|---|---|
| **Type** | Incident (Privileged Access) |
| **Priority** | P2 — High (recovery blocked) |
| **Status** | Resolved |
| **Domain** | PAM · CyberArk PASM/Vault · Local admin recovery |
| **Systems** | CyberArk (PASM / vault), Active Directory, endpoint |

---

## Reported issue

A workstation had fallen off the domain (its secure channel with AD was broken — a "stale machine" scenario). To fix it locally, an administrator needed the machine's **local administrator password**, which is vaulted and rotated in CyberArk. When they tried to retrieve it, the account showed as unavailable / failed to show the password.

---

## Investigation

**Step 1 — Understand the workflow.** The local-admin credential for endpoints is stored in the vault and rotated automatically. Retrieval is a check-out: the admin requests the account, the platform shows (or brokers) the current password, and the action is logged and attributed. A retrieval failure is usually either an account state problem (the object is in an error state) or a reconciliation problem (the platform's stored password no longer matches the target).

**Step 2 — Check the account state in the vault.** The account for that machine's local admin was flagged with a **reconciliation/verification error** — the platform's Central Policy Manager (CPM) had failed to verify or rotate the password against the target, because the target machine was unreachable (that is the whole reason for the ticket: the machine is off the domain and network-degraded). The stored password may therefore be out of sync with the actual machine.

**Step 3 — Decide the safe recovery path.** Two facts matter: (a) the machine is unreachable, so normal rotation can't confirm the password, and (b) the admin still needs a working credential *now* to recover the machine. The vault holds the **last known good** password from before the machine went stale, which is very likely still valid on the (now offline) machine because rotation could not have succeeded while it was unreachable.

---

## Root cause

The target machine going stale (broken domain trust, degraded connectivity) caused CPM verification/rotation to fail, which put the vaulted account into an error state. The error state is what blocked the clean "show password" path — the platform was protecting against handing out a credential it could no longer verify.

---

## Resolution

1. Retrieved the **last-known-good** password from the vault via the appropriate break-glass/retrieval path, with the action logged and attributed to the requesting admin (no shared, unattributed credential).
2. Used it to log in locally to the stale machine and repair the domain trust:
   ```powershell
   Test-ComputerSecureChannel -Repair -Credential (Get-Credential)
   ```
   (Alternatively `Reset-ComputerMachinePassword` with local-admin context.)
3. Once the machine was back on the domain and reachable, triggered CPM to **reconcile** the account so the vault and the machine agreed on the current password again, clearing the error state.
4. Confirmed the account returned to a healthy, rotating state.

---

## Evidence

- `evidence/TICKET-1005-account-error-state.png` — vaulted account in reconciliation error
- `evidence/TICKET-1005-secure-channel-repair.png` — domain trust repaired on the endpoint
- `evidence/TICKET-1005-account-reconciled.png` — account healthy and rotating again

---

## Prevention

- **Reconciliation exists for exactly this.** When a target is unreachable, expect verification/rotation to fail and the account to error; the fix is to restore reachability, then reconcile, not to force-rotate blindly.
- Attribute every privileged retrieval to a named person — the value of vaulting a shared local-admin credential is that check-out is logged, so lockout recovery does not become an unaudited use of a shared password.
- Monitor for machines that repeatedly go stale; recurring secure-channel breaks often point to an imaging, time-sync, or computer-account-cleanup problem worth fixing upstream.

**Lesson:** A privileged-access tool blocking retrieval is often the control working as intended, not a bug. The right move is to understand *why* it errored (here: the target was unreachable) and choose the recovery path that keeps the action attributed and the vault consistent afterward.
