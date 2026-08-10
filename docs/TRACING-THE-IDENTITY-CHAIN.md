# Tracing the Identity Chain — how an "access issue" gets solved

Most identity tickets arrive with three vague words: *"I lost access."* The skill in IAM is not knowing one fix — it is knowing the **path an identity travels** from the user to the application, and being able to find where the chain breaks.

This is a worked walkthrough of that reasoning, using a real pattern: a user who could authenticate but could not get into an application.

---

## The timeline

A support ticket came in labeled simply "access issue." Here is how it actually resolved:

| Time | Action | Result |
|------|--------|--------|
| 8:15 | User reports they "lost access" to an application | Vague symptom, no root cause yet |
| 8:20 | Check Active Directory group membership | Group is correct |
| 8:27 | Confirm the group grants the expected access | Fine |
| 8:35 | Check the Entra ID app assignment | User is assigned |
| 8:42 | Confirm app assignment is active | Fine too |
| 8:50 | Test the SSO flow directly | Authentication succeeds, app rejects the user |
| 9:00 | Inspect the SAML response | The assertion is missing the attribute the app matches on |
| 9:15 | Update the attribute / claim mapping in the IdP | Assertion now carries the right value |
| 9:20 | User signs in | Access restored |

The ticket said "access issue." The real problem was **identity data not matching what the application expected.** That is IAM.

---

## Why this is the core skill

Access failures feel like they should have one cause. They don't. The same symptom — "I can't get in" — can come from any link in a chain:

```
   User
    │   (correct password? not the issue here)
    ▼
  Directory (Active Directory)
    │   group membership ✓  ← checked first, was fine
    ▼
  Identity Provider (Entra ID / Okta)
    │   app assignment ✓    ← checked second, was fine
    │   Conditional Access ✓
    │   SAML/OIDC claims ✗   ← the break was HERE
    ▼
  Application (Service Provider)
    │   matches the user on an attribute it expected... and didn't receive
    ▼
  Access decision → DENIED
```

Sometimes it's not the password. Sometimes it's not MFA. Sometimes it's not the group. Sometimes one small claim, attribute, or mapping breaks the entire login flow — and every layer *above* it looks perfectly healthy, which is exactly why you have to walk the chain in order.

---

## What "walking the chain" actually means

Each link has a specific thing to verify and a specific tool to verify it with:

| Link | Question | How to check |
|------|----------|--------------|
| **User** | Right credentials, not locked/expired? | `Get-ADUser -Properties *` / sign-in logs |
| **Directory** | In the right groups, attributes populated? | `Get-ADUser`, `MemberOf`, `mail`/`UPN` values |
| **Sync** | Did the on-prem state reach the cloud? | Entra user state, `Start-ADSyncSyncCycle` |
| **IdP** | App assigned? Policy passing? Claims correct? | Enterprise app assignment, Conditional Access tab, **SAML trace** |
| **Application** | What identifier does it match on? | App SSO config vs. the assertion's NameID/claims |

The failure in this walkthrough was at the **IdP → Application** boundary: the identity provider was sending an assertion that authenticated the user correctly but did not carry the attribute the application used to find their account. Authentication succeeded; **matching** failed. Those are two different things, and separating them is what turned a vague ticket into a five-minute fix once the SAML response was read.

---

## SSO looks simple when it works

Behind a single click, a successful SSO login depends on identity data, app assignments, certificates, policies, attributes, and trust between systems **all lining up at once.** When one of them drifts — a claim mapped to the wrong source attribute, a signing certificate rotated, a policy scoped too broadly — the login breaks, and the error the user sees rarely names the real cause.

IAM isn't just granting access. It's tracing the identity path from the user, to the directory, to the IdP, to the application, and finding where the chain breaks.

---

## Where this lives in this repo

This reasoning is the connective tissue behind the worked tickets:

- The exact SAML attribute-mismatch break is documented end to end in [`tickets/TICKET-1003-sso-saml-attribute-mismatch.md`](../tickets/TICKET-1003-sso-saml-attribute-mismatch.md).
- The "check both AD and the cloud" link is the failure mode in [`tickets/TICKET-1004-incomplete-offboarding.md`](../tickets/TICKET-1004-incomplete-offboarding.md).
- The IdP-policy link (Conditional Access as the block) is in [`tickets/TICKET-1007-conditional-access-travel-block.md`](../tickets/TICKET-1007-conditional-access-travel-block.md).
- The first-five-minutes triage that starts every walk of the chain is in [`docs/IAM-TRIAGE-PLAYBOOK.md`](IAM-TRIAGE-PLAYBOOK.md).

Individually they're fixes. Together they're the same skill applied at different links: **know the path, find the break.**
