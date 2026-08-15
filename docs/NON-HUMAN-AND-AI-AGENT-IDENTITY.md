# Governing Non-Human and AI-Agent Identities

The fastest-growing population in every enterprise directory is not people. It's machines — service accounts, workloads, CI/CD pipelines, RPA bots, and now **AI agents** — and it is the least governed identity category in security today. This is where identity is heading, and this document lays out how I think about governing it.

---

## The scale of the problem (2026)

The numbers are stark and recent:

- Non-human identities now outnumber human identities by **more than 80 to 1** in the average enterprise (KPMG Cybersecurity Considerations 2026). Machine identities in the average enterprise rose from roughly 50,000 in 2021 to about 250,000 by 2025.
- Only **5.7% of organizations** report full visibility into their service accounts.
- **68% of organizations cannot reliably distinguish AI-agent activity from human activity** (Cloud Security Alliance).
- More than **16% of organizations do not track the creation of AI-related identities at all** (CSA token-sprawl analysis, 2026).

The Cloud Security Alliance has called non-human identity governance *"the defining security gap of the agentic AI era."* This is not a niche curiosity — it is becoming a core part of IAM and IGA design.

---

## Why AI agents are different from ordinary service accounts

A traditional service account is a **static** actor: it holds a credential, authenticates non-interactively, and does one predictable job. You can reason about its blast radius because its behavior is fixed.

An AI agent is a **dynamic, autonomous** actor. It:

- Acquires permissions at runtime rather than holding a fixed set
- Reasons about its own access needs and can request new permissions
- Invokes external APIs, writes and executes code, and chains actions across many systems
- Can spawn sub-agents, multiplying the identities involved in a single task
- Produces emergent behavior its creators did not explicitly script

The consequence: **the credential an agent holds is not a passive key — it is the principal identity of an actor that may act outside the assumptions under which its credential was issued.** A single compromised agent credential has a far wider blast radius than any static service account, because the agent can chain actions across dozens of systems at machine speed.

This is why the industry framing has shifted: *agent governance is a control plane, not a feature.* Policy has to live at the identity and entitlement layer — what the agent **is** and what it's **allowed to do** — not only in application-level guardrails.

---

## How I would govern them — the framework

The same identity fundamentals apply, adapted for autonomous, non-human actors. Six controls:

### 1. Inventory — you cannot govern what you cannot see
Every agent is a non-human identity that must be **discovered and inventoried**, including shadow and embedded agents. The 5.7%-visibility statistic exists because most NHIs are never catalogued. Continuous discovery is control zero.

### 2. Ownership — every agent has a human sponsor
Assign each agent an **owner, a business purpose, and a defined system reach**. An agent without an accountable human owner is an orphan with privileges — the worst kind of identity. This is the non-human version of the "leaver whose manager already left" problem: no owner means no one to attest to or revoke the access.

### 3. Least privilege + runtime authorization
Static roles are not enough for an actor that acquires permissions dynamically. Agents need **runtime authorization** — permission decisions made at execution time based on context, not just a standing entitlement set granted at provisioning. This is where classic RBAC meets just-in-time: grant the narrow scope needed for the current action, not blanket standing access.

### 4. Human approval for high-impact actions
The **read-to-write cliff** is the critical control boundary. An agent that can *read* is a data-exposure risk; an agent that can *write, delete, or transact* can cause direct damage at machine speed. High-impact actions should require **human-in-the-loop approval**, preserving the complete delegation chain (which human authorized this agent to take this action on whose behalf).

### 5. Monitoring, behavioral analytics, and kill switches
Because agents produce emergent behavior, static policy cannot anticipate every path. **Behavioral monitoring** to flag anomalous agent activity, plus a **kill switch** to revoke an agent's access immediately, are non-optional. If 68% of organizations cannot tell agent activity from human activity, the first monitoring win is simply *labeling* agent actions distinctly.

### 6. Lifecycle — agents join, change, and leave too
Agents need the full **joiner-mover-leaver** lifecycle: provisioned with scoped access, reviewed as their purpose changes, and **decommissioned** when retired. NHIs are notorious for never being retired ("they don't log out, they're seldom retired"), so time-bound credentials and periodic recertification matter even more than for humans.

---

## How this connects to the rest of my work

This isn't a separate discipline — it's the identity fundamentals I already practice, extended to a new and harder class of actor:

- **Service-account governance** ([PAM concepts](PAM-CONCEPTS-REFERENCE.md), the CyberArk service-account modeling in this lab) is the on-ramp to NHI governance — agents are service accounts that can think.
- **Least privilege and JIT elevation** ([EPM ticket](../tickets/TICKET-1006-epm-jit-elevation.md)) is exactly the runtime-authorization model agents need — elevate the action, not the actor.
- **Audit-log verification** ([Proving It](PROVING-IT-AUDIT-AND-EDGE-CASES.md)) is how you reconstruct what an autonomous agent actually did, which matters far more when the actor moves at machine speed.
- **Deprovisioning verification** ([checklist](DEPROVISIONING-CHECKLIST.md)) is the decommission control — an un-retired agent credential is an open door that never closes.

---

## Why I'm specializing here

Identity is moving from governing *people* to governing *autonomous non-human actors*, and the gap between how fast agents are being deployed and how well they're governed is widening, not closing. The market is forming right now: dedicated NHI platforms (Astrix, acquired by Cisco in May 2026; Entro; Linx), and the established IGA/PAM vendors (SailPoint, Saviynt, One Identity, CyberArk) all racing to extend governance to agents.

The professionals who understand both **classic identity governance** and **the new behavior of autonomous agents** will be the ones who can actually design controls for this, rather than bolt on a tool. That intersection — real IAM fundamentals plus agent-identity fluency — is where I'm aiming.

---

*Framework synthesized from 2026 industry research including the Cloud Security Alliance's non-human identity and agentic-AI governance work, KPMG's Cybersecurity Considerations 2026, and current NHI-governance practice. Written to document how established identity controls extend to autonomous non-human actors.*
