# Proving It — audit-log verification and the edge cases that break JML

Two things separate someone who *does* IAM from someone who does IAM they can **prove**. In a regulated environment, proving it is most of the job.

---

## 1. Audit-log verification — the step most labs skip

Making a change is half the work. Confirming the change **actually landed as an audit event** is the other half — and it's the half that turns "I disabled the account" into "here is the logged, timestamped, attributable proof that the account was disabled, by whom, and when."

**The principle:** every security-relevant change should produce a verifiable event in the log. If you can't find the event, you can't prove the change — and in an audit, an unprovable change is treated as a change that didn't happen.

### What this looks like in practice

When I disable a stale account, I don't stop at "the account shows disabled." I confirm the **event** was written:

```
# Account disable → Windows Security Event 4725 (user account disabled)
index=windows_ad EventCode=4725 earliest=-1h
| table _time, Account_Name, Security_ID, Message
```

Other changes, other events — the point is the same each time: **the change and the event are two different things, and I verify both.**

| Change | The event that proves it |
|--------|--------------------------|
| Account created | 4720 |
| Account enabled | 4722 |
| Account disabled | 4725 |
| Account deleted | 4726 |
| Password reset by admin | 4724 |
| Group membership added | 4728 / 4732 / 4756 |
| Group membership removed | 4729 / 4733 / 4757 |
| Account locked out | 4740 |

### Why it matters more than it sounds

- **Audit readiness:** when an auditor asks "prove that terminated users were deprovisioned," the answer is a query returning the disable events, not a screenshot of a checkbox.
- **Detection:** verifying that *your* change logged correctly is the same skill as spotting a change that logged **without** an authorized ticket — the ungoverned account creation the [JML audit](JML-Identity-Lifecycle-Audit.pdf) surfaces.
- **Attribution:** the event carries *who* made the change. Without it, you have an outcome with no accountability.

This is the difference between doing IAM and doing IAM you can prove. In a SOX/regulated environment, the proof *is* the deliverable.

---

## 2. The edge cases that break the tidy HR trigger

Most lifecycle automation assumes a clean HR signal: HR marks a hire, a role change, or a termination, and the pipeline reacts. Real environments are messier, and the messy cases are exactly where access risk hides. Two that come up constantly:

### Edge case A — the mover who changes role *while on leave*

**The scenario:** an employee on leave (parental, medical, sabbatical) is promoted or transferred. HR records the role change against an account that is currently in a leave state.

**Why it breaks the tidy assumption:**
- A naive mover workflow swaps the old role's groups for the new role's groups — **granting the new access immediately**, even though the person isn't working and won't be for weeks or months. Now there's standing access to systems the person isn't using, which is exactly the dormant-but-privileged risk an audit flags.
- If the leave state itself removed some access, the role-change workflow may **re-grant** it, silently undoing the leave handling.
- When they return, a return-from-leave workflow may fire against a role that no longer matches what HR now says — the two events collide.

**How I'd handle it:**
- Treat leave state as a **gate** on the mover workflow: record the role change, but **stage** the entitlement grant so it activates on return rather than immediately.
- Reconcile on return: compare the account's actual access against the *current* authoritative role, not the role it had when leave started.
- Log both the staged change and the activation as separate events, so the sequence is provable.

### Edge case B — the leaver whose manager has already left

**The scenario:** an employee is terminated, and the offboarding workflow routes an access-review or attestation task to their **manager** — but that manager already left the company. The approval task lands on a disabled account. Nothing happens. The leaver's access sits, un-reviewed, indefinitely.

**Why it breaks the tidy assumption:**
- Lifecycle and certification workflows lean on the manager relationship for approvals and attestations. When the manager record is stale or disabled, the workflow **stalls silently** — no error loud enough to notice, just a task no one will ever action.
- This is a top source of orphaned access: not a failure to *start* offboarding, but a failure to *complete* it because the approval chain pointed at a ghost.

**How I'd handle it:**
- **Validate the approver** before routing: if the manager account is disabled or missing, escalate to the manager's manager or a role-based owner group, not a single named person.
- Prefer **group-based ownership** for approvals over individual named approvers, so a departure never orphans a workflow (the same reason group-based Conditional Access exclusions beat named-user exclusions — see [`incidents/INC-001`](../incidents/INC-001-conditional-access-lockout.md)).
- Add a **stalled-task monitor**: any lifecycle or certification task open past an SLA gets surfaced, because a silent stall is the failure mode that hides orphaned access.

---

## Why these belong in a portfolio

Anyone can automate the happy path: hire, provision; terminate, deprovision. The signal of someone who has actually operated identity is that they think about **the account on leave, the manager who left, and whether the event actually logged.** Those are the cases that generate audit findings and security incidents — and planning for them is the difference between a lab that demos and an environment that holds up.

**Related in this repo:**
- [`docs/DEPROVISIONING-CHECKLIST.md`](DEPROVISIONING-CHECKLIST.md) — verifying access is gone across every system, not just AD
- [`tickets/TICKET-1004-incomplete-offboarding.md`](../tickets/TICKET-1004-incomplete-offboarding.md) — an offboarding that looked complete but wasn't
- [`docs/JML-Identity-Lifecycle-Audit.pdf`](JML-Identity-Lifecycle-Audit.pdf) — the audit that finds accounts no lifecycle event fully handled
