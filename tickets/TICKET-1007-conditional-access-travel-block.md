# TICKET-1007 — Legitimate user blocked by Conditional Access while traveling

| | |
|---|---|
| **Type** | Incident (Access / Zero Trust) |
| **Priority** | P2 — High (user blocked) |
| **Status** | Resolved |
| **Domain** | Conditional Access · Zero Trust · Sign-in log analysis |
| **Systems** | Microsoft Entra ID (Conditional Access) |

---

## Reported issue

An employee traveling abroad for work could not sign in to email or SSO applications. They entered the correct password and approved MFA, but still received "You can't get there from here" — an access block, not a credential failure.

---

## Investigation

**Step 1 — Go straight to the sign-in logs.** The Entra **sign-in logs** are the source of truth for *why* an access attempt succeeded or failed. Located the user's failed sign-in and opened the record.

**Step 2 — Read the failure reason.** The sign-in showed **Success** for authentication and MFA, but the result was **failure** with reason indicating a **Conditional Access policy** blocked it. The **Conditional Access** tab on the sign-in record named the specific policy that applied and showed it as "Failure" for this sign-in.

**Step 3 — Read the offending policy.** The policy was a "block access from outside approved countries" (named-location) control, intended to reduce attack surface from regions the company does not operate in. The user's legitimate business travel put them in a location the policy treated as disallowed. The control did exactly what it was written to do — it just did not account for approved travel.

**Step 4 — Confirm it was really the policy, not a coincidence.** Used the sign-in log's Conditional Access detail plus the **What If** tool to confirm that a sign-in from the user's current country hit this policy and was blocked, and that from an approved country it would succeed.

---

## Root cause

A geo-based Conditional Access policy blocked a legitimate sign-in because the user was traveling in a country outside the approved named-location list. The policy was correct in intent but had no exception path for approved business travel.

---

## Resolution

1. Verified the travel was legitimate and expected (confirmed with the user's manager) — because loosening a security control for an account is itself sensitive.
2. Applied a **time-bound exception**: added the user to a group excluded from the geo-block policy for the duration of the trip, rather than weakening the policy for everyone.
3. Confirmed the user could sign in, then set a reminder to **remove the exception** when the trip ended so the control returned to full strength.
4. Documented the change as a Conditional Access policy exception with start/end dates.

---

## Evidence

- `evidence/TICKET-1007-signin-log-ca-failure.png` — sign-in log showing CA policy as the block
- `evidence/TICKET-1007-whatif-result.png` — What If tool confirming the policy hit
- `evidence/TICKET-1007-timebound-exception.png` — scoped, time-bound exclusion applied

---

## Prevention

- Build an **approved-travel process** into geo-based policies (a travel group with an expiry, or a documented exception workflow) so legitimate travel does not become an emergency.
- Prefer **time-bound, group-based exceptions** over editing the policy itself — the control stays strong for everyone else and the exception self-expires.
- Sign-in logs plus the What If tool turn "I'm randomly blocked" into a precise, named policy in minutes.

**Lesson:** When a user is blocked but authenticated successfully, it is almost always a policy decision, not a credential problem. The sign-in log's Conditional Access detail tells you exactly which policy and why — and the right fix is usually a scoped exception, not weakening the control.
