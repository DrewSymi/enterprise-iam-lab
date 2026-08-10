# TICKET-1002 — User locked out of MFA after replacing their phone

| | |
|---|---|
| **Type** | Incident (Authentication) |
| **Priority** | P2 — High (user fully blocked) |
| **Status** | Resolved |
| **Domain** | MFA · Entra ID · Authentication methods |
| **Systems** | Microsoft Entra ID |

---

## Reported issue

A user got a new phone and could no longer sign in. Every login prompted for approval on the Microsoft Authenticator app, but the app was gone with the old device. They were fully blocked from email and all SSO applications.

---

## Investigation

**Step 1 — Understand what's actually failing.** The password was correct; the block was at the second factor. Entra was still expecting the Authenticator registration tied to the *old* phone, which no longer exists. The user cannot approve a prompt on a device they no longer have.

**Step 2 — Confirm registered methods.** In Entra admin center, under the user's **Authentication methods**, the only registered strong method was Microsoft Authenticator on the old device. There was no backup method (no phone SMS, no alternate) to fall through to.

**Step 3 — Verify identity out of band before changing anything.** Because resetting an MFA method is itself a security-sensitive action (an attacker who resets MFA owns the account), confirmed the user's identity through a second channel — a verification question set and a callback to their known manager — before proceeding.

---

## Root cause

The user replaced their phone without first adding the new device as an authentication method or setting up a backup method. The old registration was the only strong method on file, so when the device was gone, there was no path to satisfy MFA.

The plain-language version I gave the user: *"Your account is still looking for your old phone to approve the login. We need to tell it about the new one."*

---

## Resolution

1. From Entra **Authentication methods**, removed the stale Microsoft Authenticator registration tied to the old device.
2. Issued a **Temporary Access Pass (TAP)** — a time-limited passcode that satisfies MFA once, so the user can sign in and re-register.
3. Walked the user through installing Authenticator on the new phone and registering it as their method during the TAP window.
4. Had the user add a **second method** (phone/SMS) as a backup so a future device change does not repeat this lockout.
5. Confirmed sign-in worked on the new device and the TAP was consumed.

---

## Evidence

- `evidence/TICKET-1002-auth-methods-before.png` — only stale Authenticator registered
- `evidence/TICKET-1002-tap-issued.png` — Temporary Access Pass issued
- `evidence/TICKET-1002-auth-methods-after.png` — new Authenticator + backup method registered

---

## Prevention

- Encourage users to register **two** authentication methods so a lost device never causes a full lockout.
- Communicate a "changing your phone?" self-service step: add the new device *before* wiping the old one.
- Temporary Access Pass is the clean recovery path; it avoids disabling MFA (which weakens the account) and is time-boxed.

**Lesson:** MFA lockouts feel urgent, but the security-sensitive part is verifying identity *before* resetting the method. A helpful reset for the wrong person is an account takeover.
