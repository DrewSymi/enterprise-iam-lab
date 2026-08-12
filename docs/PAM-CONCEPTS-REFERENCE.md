# PAM Concepts Reference — how privileged access management actually works

A working reference for the core mechanics of Privileged Access Management, using CyberArk's architecture as the model. Written to be useful both as a refresher and as a starting point for anyone learning how PAM fits together.

The point of PAM in one line: **standing privileged access is the biggest attack surface in an enterprise, so PAM removes standing access — credentials are vaulted, rotated, brokered, and recorded, so no human holds a permanent admin password.**

---

## The four core components

A CyberArk PAM deployment is four cooperating components. Knowing what each does — and how they talk to each other — is the foundation of everything else.

### Vault (Digital Vault)
The secure store. It holds the privileged credentials, session recordings, and audit data, encrypted. It is **Tier 0 infrastructure** — the most protected asset in the deployment — and by design it runs on its own dedicated, hardened server, never co-located with the other components. Everything else connects *to* the Vault; the Vault initiates nothing outbound.

### PVWA (Password Vault Web Access)
The web interface. This is where users and administrators live day to day — requesting access, launching sessions, onboarding accounts, running reports. It's a web front end that talks to the Vault on the user's behalf. If the Vault is the safe, PVWA is the teller window.

### CPM (Central Policy Manager)
The engine that manages passwords. CPM reaches *out* to target systems and rotates, verifies, and reconciles credentials on a schedule and on demand. It runs as a Windows service ("CyberArk Password Manager") and is governed by **platforms** (the per-target-type rulebooks). When rotation stops fleet-wide, the first thing to check is whether the CPM service is running.

### PSM (Privileged Session Manager)
The session broker and recorder. PSM lets a user connect to a target **without ever seeing the actual credential** — it injects the credential, isolates the session, and records it. The user's machine never touches the privileged password. PSM handles RDP/Windows; PSM for SSH (PSMP) handles Unix/Linux.

> **How they interact:** a user logs into **PVWA**, requests a target, and PSM launches an isolated, recorded session using a credential the **Vault** holds and **CPM** keeps rotated. Four components, one flow.

---

## The three CPM operations: Change, Verify, Reconcile

This is the single most-asked PAM topic, because it's the heart of credential management. The clean distinction:

| Operation | What it does | Needs the current password? |
|-----------|--------------|-----------------------------|
| **Verify** | Checks that the password stored in the Vault still matches the target | Yes — it logs in to confirm |
| **Change** | Rotates the password to a new value, using the current one to authenticate | Yes — it logs in, then changes |
| **Reconcile** | Forcibly resets the password when the current one is unknown or out of sync, using a separate higher-privileged **reconcile account** | No — that's the whole point |

The plain-language version:

- **Verify** = "does the Vault's copy still work?"
- **Change** = "rotate it, logging in with the password we have"
- **Reconcile** = "we've lost sync — reset it with the master override account, no old password needed"

**Reconcile is the forgot-password flow.** Just like clicking "forgot password" on a website resets your login without you knowing the old one, the reconcile account is a linked, higher-privileged account that resets a managed password without needing the current value. It's what recovers an account after someone changed a password out-of-band or a target fell out of sync.

### The gotcha that separates juniors from operators

A rotation can report **success** and still break an application. Why? **Dependent accounts (Usages).** If a service account's password is used by a scheduled task, an IIS app pool, or a Windows service, CPM only updates those dependents if they were **onboarded as Usages**. Rotate the account without onboarding its dependents, and the password changes in the Vault and on the target — but the app still tries the old one and breaks. That's the 2 a.m. page. Knowing to onboard dependents is the mark of someone who's actually operated CPM.

---

## Why PSM isolates the session (instead of showing the password)

A natural question: why not just show the admin the password and let them connect?

Because the moment a privileged password touches a user's machine — their clipboard, their RDP client, their memory — it can be captured, logged, reused, or exfiltrated. PSM's model removes that risk entirely:

- The user authenticates to PSM, not to the target
- PSM retrieves the credential from the Vault and injects it into the session
- The user drives the session but **never sees or holds the credential**
- The whole session is recorded for audit

This is the difference between "give the user the key" and "let the user into the room while the key stays locked away." It also produces a complete, attributable audit trail — you know exactly who did what in a privileged session, on video.

---

## Safes, Platforms, and Accounts — the organizing model

Three terms people mix up:

- **Account** — a single managed credential (one server's local admin, one service account).
- **Safe** — a container that groups accounts and controls *who* can access them. Access is granted at the safe level via membership, much like an AGDLP group model but for privileged credentials. A safe is the unit of access control.
- **Platform** — the *rulebook* for a type of account: how to change it, how often, what the password policy is, which connection component PSM uses. A Windows local-admin platform behaves differently from an Oracle-database platform. Apply the wrong platform to an account and rotation fails before it even starts.

The relationship: **accounts live in safes; platforms govern how accounts behave.**

---

## The privileged access lifecycle

PAM applies joiner-mover-leaver thinking to *privileged* access:

1. **Discovery** — find privileged accounts that exist but aren't managed (the unmanaged local admin on every workstation is the classic risk).
2. **Onboarding** — bring an account under management: into a safe, under a platform, with (if needed) a reconcile account and dependent Usages.
3. **Rotation** — CPM changes and verifies on a schedule; reconcile handles drift.
4. **Access** — users request and receive brokered, recorded sessions via PVWA/PSM, often with request/approve or dual-control workflows.
5. **Review** — periodic access reviews confirm safe membership is still justified; session recordings and logs surface unusual activity.
6. **Offboarding** — remove privileged access cleanly when it's no longer needed, and reassign owned service accounts rather than orphaning them.

---

## Least privilege: PAM + endpoint privilege

PAM (vaulting/session brokering) pairs with **Endpoint Privilege Management (EPM)** to enforce least privilege from two directions:

- **PAM** removes standing access to *servers and infrastructure* — credentials are vaulted and sessions brokered.
- **EPM** removes standing *local admin* on endpoints — instead of making a user an admin, a specific approved action is elevated **just-in-time**, logged, and the user stays a standard user.

The unifying principle: **elevate actions, not people; grant access just-in-time, not permanently; and record everything.** A former standing admin becomes a request that is approved, scoped, time-bound, and audited.

---

## How to reason about a PAM problem

When something breaks, the components tell you where to look:

| Symptom | Likely component | First check |
|---------|------------------|-------------|
| Rotation failing fleet-wide | CPM | Is the CyberArk Password Manager service running? |
| One account won't rotate | Platform / target | Right platform? target reachable? reconcile account linked? |
| App broke after a "successful" rotation | Dependents | Were the Usages onboarded? |
| Can't launch a session | PSM | Connection component, PSM service, target reachability |
| Password out of sync with target | Reconcile | Is a reconcile account linked and is reconcile enabled? |
| Can't retrieve a credential | Vault / safe | Safe membership and permissions |

Diagnosis in PAM, like the rest of identity, is about knowing the path a credential travels and finding where it breaks.

---

## Where this connects in the repo

- [`tickets/TICKET-1005-cyberark-vault-lockout-recovery.md`](../tickets/TICKET-1005-cyberark-vault-lockout-recovery.md) — recovering a vaulted credential during a stale-machine lockout (reconcile in practice)
- [`tickets/TICKET-1006-epm-jit-elevation.md`](../tickets/TICKET-1006-epm-jit-elevation.md) — endpoint just-in-time elevation (elevate the action, not the user)
- [`docs/DEPROVISIONING-CHECKLIST.md`](DEPROVISIONING-CHECKLIST.md) — removing privileged group memberships and PAM safe access at offboarding

---

*Reference written to explain the operating model of privileged access management. Uses CyberArk's architecture as the reference implementation; the concepts — vaulting, rotation, session isolation, least privilege — apply across PAM platforms.*
