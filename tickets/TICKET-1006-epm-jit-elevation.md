# TICKET-1006 — User needs to install approved software but has no local admin rights

| | |
|---|---|
| **Type** | Service Request (Privileged Access) |
| **Priority** | P3 — Medium |
| **Status** | Resolved |
| **Domain** | PAM · CyberArk EPM · Least privilege · Just-in-time elevation |
| **Systems** | CyberArk EPM, endpoint |

---

## Reported issue

A user needed to install an approved engineering tool but received "You need administrator privileges to install this software." By design, users do **not** have standing local admin rights — least privilege is enforced on endpoints. The user needed a way to perform this one elevated action without being made a permanent admin.

---

## Investigation

**Step 1 — Confirm the model.** Endpoints run under least privilege: no standing local admin. Elevation is handled just-in-time through Endpoint Privilege Management (EPM), which allows a *specific action* to run elevated based on policy, rather than granting the *user* blanket admin rights. This is the difference between "make this person an admin" (persistent risk) and "let this one approved action run elevated" (scoped, temporary, logged).

**Step 2 — Determine how the installer is handled by policy.** Checked whether the installer matched an existing elevation policy:
- If the application is on the **approved/allow** list, EPM elevates it automatically or on a controlled prompt.
- If it is unknown, it falls to a **request/approval** flow rather than silently running with admin rights.

The tool was legitimate but not yet covered by an existing elevation policy, so it landed in the request path rather than auto-elevating.

**Step 3 — Validate the request is legitimate.** Confirmed the software was business-approved and the source installer was the expected, unmodified vendor package (not a random download) before elevating — elevation should never be a rubber stamp, because "just run this as admin" is exactly how malicious installers get privileged.

---

## Root cause

Working as designed: the user had no standing admin rights (correct), and the specific installer was not yet covered by an elevation policy, so it required a just-in-time elevation decision rather than auto-elevating.

---

## Resolution

1. Granted a **just-in-time elevation** for the specific installer action through EPM — the single action ran elevated; the user did **not** receive persistent admin rights.
2. The elevation was **logged and attributed** to the user and action, producing an audit trail.
3. Because this is a legitimately recurring business tool, recommended adding it to an elevation policy so future installs are handled by policy instead of one-off requests.
4. Confirmed the software installed and the user returned to standard (non-admin) rights immediately afterward.

---

## Evidence

- `evidence/TICKET-1006-install-blocked.png` — standard user blocked from installing (least privilege working)
- `evidence/TICKET-1006-jit-elevation.png` — just-in-time elevation granted for the specific action
- `evidence/TICKET-1006-install-success.png` — install completed, no standing admin granted

---

## Prevention

- Maintain elevation policies for known, approved business software so common installs are handled automatically and only genuinely unknown actions require a decision.
- Keep the principle intact: elevate **actions**, not **users**. Making the person a local admin to "just get it done" trades a two-minute task for a permanent standing-privilege risk.
- Every elevation is logged — that audit trail is what lets least privilege coexist with users still getting their work done.

**Lesson:** The right answer to "I need admin to do this" is almost never "here's admin." It's "let's elevate this specific action, log it, and leave you as a standard user." That is the whole point of endpoint privilege management, and it's the model I operate daily.
