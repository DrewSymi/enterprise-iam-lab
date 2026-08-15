# Role Mining — designing RBAC from real access patterns

Assigning roles is easy. **Designing** them is the hard part — and it's where most RBAC programs stall. This project mines a realistic identity population to discover what roles *should* exist, then measures how much standing access those roles would replace.

This is role **design**, not role assignment: the analysis an identity governance program runs *before* it rolls out RBAC.

**Script:** [`scripts/Invoke-RoleMining.ps1`](../scripts/Invoke-RoleMining.ps1)

---

## The problem role mining solves

In a real directory, access accretes. Someone joins Finance and gets the Finance apps. They cover for someone in Sales for a month and pick up a CRM entitlement that never gets removed. They get promoted and gain approval rights. Multiply that across a thousand people over several years, and nobody can answer the basic governance question: *what access should a Finance Analyst actually have?*

Role mining answers it by working backwards from the access people **already** have:

1. Group identities by attributes (department, title)
2. Find the entitlements that are **common** within each group — those are your role candidates
3. Find the entitlements that are **rare** within a group — those are over-provisioning to review
4. Measure coverage: how much individual, standing access a role model would replace

---

## What the script does

It generates a synthetic population (default 1,000 identities) with realistic structure:

- **Birthright access** everyone gets (email, SSO portal, VPN, domain membership)
- **Department-driven access** (Finance gets ERP + expense + finance share; Engineering gets git + CI + cloud dev; etc.)
- **Title-driven access** (managers get approvals and team dashboards)
- **Realistic mess** — ~12% of identities carry a stray entitlement from another department, the kind of access that accretes from transfers and one-off requests and never gets cleaned up

Then it mines that population:

- **Proposes base roles** per department from entitlements ≥85% of the department shares
- **Flags over-provisioning** — entitlements fewer than 15% of a peer group hold
- **Reports coverage** — the percentage of individual grants a role model would replace with role membership

The population is generated with a fixed seed, so the analysis is reproducible.

---

## Reading the output

The report answers three questions a hiring manager or an auditor would ask:

| Question | What the report shows |
|----------|----------------------|
| What roles should exist? | The proposed base roles, one per department, with their core entitlements |
| How much would RBAC help? | Coverage % — the share of standing individual grants roles would replace |
| What's already wrong? | The over-provisioned grants — access that doesn't fit any peer pattern |

The over-provisioned list is the direct feed into an **access certification campaign** — those are exactly the grants a reviewer should be asked to confirm or revoke. This connects role mining to the [reconciliation and audit work](JML-Identity-Lifecycle-Audit.pdf) elsewhere in this repo: mining designs the roles, certification cleans up what falls outside them.

---

## Why this matters as a skill

Most people in IAM can *assign* a role. Fewer can *design* one, because it requires thinking about access as patterns across a population rather than as individual grants. Role mining is how mature IGA programs move from "everyone requests access individually" to "access follows role," and it's a named capability in enterprise IGA platforms (SailPoint, Saviynt, One Identity all ship role-mining features).

Building the analysis from scratch — generating the population, finding the patterns, measuring coverage, flagging the outliers — demonstrates that I understand what those platform features are actually doing under the hood, not just which button to click.

---

*Analysis only. The script generates its own synthetic data and makes no changes to any directory. Entitlement names are illustrative.*
