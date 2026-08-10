# TICKET-1003 — New hire cannot sign in to SaaS app via SSO ("no account found")

| | |
|---|---|
| **Type** | Incident (Federation / SSO) |
| **Priority** | P3 — Medium |
| **Status** | Resolved |
| **Domain** | SSO · SAML · Attribute mapping · Provisioning |
| **Systems** | Microsoft Entra ID (IdP), SaaS application (SP) |

---

## Reported issue

A new hire could sign in to Windows and email but got an error when launching a SaaS application through the SSO portal: the app returned **"No account found for this user."** Other users reached the same app without issue.

---

## Investigation

**Step 1 — Locate where the flow breaks.** SSO has two independent halves: **authentication** (the identity provider proves who the user is) and **provisioning/matching** (the application has an account to match them to). "No account found" is a *matching* failure, not an authentication failure — the user authenticated fine at Entra, but the application had no record to map them to.

**Step 2 — Check the SAML assertion.** Used the browser SAML trace to inspect the assertion Entra sent. The `NameID` was being sent as the user's **objectID (GUID)**, while the application was configured to match users on **email address**. The identifiers did not line up, so the app could not find the account.

**Step 3 — Compare against a working user.** A user who *could* access the app had been created before the app's claim configuration changed and had been matched manually. New users, matched only by the assertion, failed — which explained why the problem was isolated to the new hire.

---

## Root cause

Mismatch between the **claim** Entra sent as the user identifier and the **attribute** the application used to match accounts. Entra was sending objectID as NameID; the application expected `user.mail`. Existing users had been matched before this drift; new users had not.

---

## Resolution

1. In the Entra enterprise application's **single sign-on** settings, set the **Unique User Identifier (NameID)** claim to `user.mail` to match what the application expected.
2. Confirmed the application's own SSO config keyed on email as the matching attribute.
3. Verified the user had a value in the `mail` attribute (a missing source attribute would have produced an empty claim).
4. Had the user retry — SSO succeeded and the account matched.
5. Re-tested an existing user to confirm the change did not break current access.

---

## Evidence

- `evidence/TICKET-1003-saml-trace-before.png` — NameID sent as objectID
- `evidence/TICKET-1003-claim-config.png` — corrected NameID claim mapping to user.mail
- `evidence/TICKET-1003-sso-success.png` — user reaching the application

---

## Prevention

- Standardize on a stable, present-for-everyone identifier (email or UPN) for SSO matching, and document it per application during onboarding.
- Validate SSO with a **test user** when onboarding a new application, before real users are affected.
- Watch for source attributes (like `mail`) that are empty for some accounts — an SSO claim can only be as good as the attribute behind it.

**Lesson:** In SSO issues, separate "did they authenticate?" from "did the app find their account?" first. Reading the SAML assertion turns a vague "SSO is broken" into a specific, fixable claim mismatch.
