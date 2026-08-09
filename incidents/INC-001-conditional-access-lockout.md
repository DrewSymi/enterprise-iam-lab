# INC-001 — Administrator lockout during Conditional Access rollout

| | |
|---|---|
| **Severity** | High (administrative access impaired) |
| **Status** | Resolved |
| **Systems** | Microsoft Entra ID — Conditional Access |
| **Control** | NIST SP 800-53 IA-2 (Identification and Authentication), CP-2 (Contingency Planning) |
| **Detection** | Self-detected during post-change validation |

---

## Summary

A tenant-wide Conditional Access policy requiring multifactor authentication was deployed with an exclusion for a designated break-glass administrative account. The exclusion did not save. Both the primary administrative account and the break-glass account were caught in an MFA challenge loop, impairing administrative access to the tenant.

Access was recovered, the policy was rebuilt with verified exclusions, and additional validation controls were adopted.

**No production impact.** This occurred in a laboratory environment during controlled rollout.

---

## Timeline

| Time | Event |
|------|-------|
| T+0 | Break-glass account created and assigned Global Administrator, per design. Intended to be excluded from all access policies. |
| T+10m | Conditional Access policy created: include *All users*, exclude *Break Glass Admin*, grant control *Require multifactor authentication*. Policy saved. |
| T+15m | Post-change validation: primary administrative account entered an MFA challenge loop — challenge satisfied, then re-presented. |
| T+18m | Attempted recovery via the break-glass account. **Break-glass account was also challenged**, indicating the exclusion was not in effect. |
| T+22m | Determined the MFA challenge was satisfiable (a registration method could be added). Completed MFA registration and regained portal access. |
| T+30m | Policy inspected. Exclusion list was empty despite having been configured. |
| T+35m | Exclusion rebuilt and **verified by confirming the exclusion count displayed on the policy before saving**. |
| T+40m | Policy returned to report-only mode pending validation against sign-in logs. |

---

## Root cause

In the Entra Conditional Access policy editor, adding a principal to the **Exclude** list requires two actions: selecting the principal in the picker, and confirming the selection with the **Select** control at the bottom of the blade.

Closing the blade without confirming saves the policy with an **empty exclusion list**. No warning is presented, and the policy summary does not clearly indicate that the exclusion is absent.

The policy appeared correctly configured. It was not.

**Contributing factor:** the policy was validated by attempting a sign-in rather than by inspecting the saved configuration first. The exclusion was assumed to have persisted.

---

## Recovery

1. Confirmed the MFA challenge was satisfiable rather than a hard block — a registration method could still be added, so administrative access was recoverable without vendor support.
2. Completed MFA registration on the administrative account and regained access to the tenant.
3. Inspected the saved policy and identified the empty exclusion list.
4. Rebuilt the exclusion, this time confirming the displayed exclusion count before saving.
5. Added the directory synchronization service account to the exclusion list — it authenticates non-interactively and would have been broken by the policy.
6. Returned the policy to report-only mode for validation before enforcement.

---

## What went wrong, honestly

Three things, in order of significance:

**The exclusion was never verified.** The break-glass account existed and was correctly conceived, but an untested exclusion is not an exclusion. The entire value of a break-glass account is that it works when everything else does not — which means it has to be proven, not assumed.

**The policy was enforced before validation.** Report-only mode exists precisely to observe policy impact without blocking anyone. It was available and was not used first.

**The service account was overlooked.** Automation accounts cannot complete an interactive MFA challenge. Had the policy remained enforced, directory synchronization would have failed silently — a second incident hiding behind the first.

---

## Corrective actions

| Action | Type | Status |
|--------|------|--------|
| Verify exclusion count is displayed on the policy before saving | Detective | Adopted |
| Deploy all broad access policies in report-only mode first; validate against sign-in logs before enforcing | Preventive | Adopted |
| Include non-interactive service accounts in access policy exclusions | Preventive | Adopted |
| Test break-glass access **after** any policy change affecting authentication | Detective | Adopted |
| Manage exclusions via a dedicated security group rather than individually named users | Preventive | Planned |

### On group-based exclusions

Excluding a group rather than individual accounts is the stronger pattern:

- Adding a second break-glass account becomes a group membership change, not a live policy edit
- Policy edits are change-control events; group membership changes are routine
- Auditors review one group instead of tracing exclusions across every policy
- The same pattern applies in Okta, Ping, and other platforms — exclude a group from the sign-on policy

---

## Lessons that generalize

Beyond this platform:

- **A control you have not tested is not a control.** This applies to break-glass accounts, backup restores, and failover paths equally.
- **Configuration that appears saved may not be.** Verify the resulting state, not the action you performed.
- **Broad authentication policies deserve staged rollout.** Report-only, monitor, then enforce — the same discipline as any production change.
- **Non-human identities need explicit consideration in every access policy.** They fail differently and more quietly than people do.
- **Design the recovery path before you need it, then prove it works.** In a production tenant, a locked-out administrator without a functioning break-glass account means vendor support and hours of downtime.

---

*Documented as part of the Link3IT identity laboratory. Incident occurred in a controlled environment during deliberate control implementation.*
