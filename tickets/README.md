# Worked Tickets

Real IAM support scenarios worked end to end in the Link3IT lab environment. Each ticket follows the same structure — reported issue, investigation, root cause, resolution, evidence, and prevention — because that structure is the job: reproduce, diagnose to root cause, fix safely, document so it doesn't recur.

These are laboratory scenarios built to practice and document genuine identity troubleshooting. The systems, queries, and reasoning are real.

## Index

| Ticket | Domain | Skill demonstrated |
|--------|--------|--------------------|
| [TICKET-1001](TICKET-1001-shared-drive-access.md) | File access · NTFS/Share permissions | Group-membership diagnosis, AGDLP model, two-layer permission logic |
| [TICKET-1002](TICKET-1002-mfa-lockout-recovery.md) | MFA · Entra ID | MFA recovery with Temporary Access Pass, identity verification before reset |
| [TICKET-1003](TICKET-1003-sso-saml-attribute-mismatch.md) | SSO · SAML federation | Reading a SAML assertion, fixing NameID/claim-to-attribute mismatch |
| [TICKET-1004](TICKET-1004-incomplete-offboarding.md) | JML (Leaver) · Hybrid identity | Hybrid deprovisioning gap, sync scope, token revocation |
| [TICKET-1005](TICKET-1005-cyberark-vault-lockout-recovery.md) | PAM · CyberArk PASM/vault | Vaulted-credential recovery, reconciliation error handling |
| [TICKET-1006](TICKET-1006-epm-jit-elevation.md) | PAM · CyberArk EPM | Just-in-time elevation, least privilege, elevate actions not users |
| [TICKET-1007](TICKET-1007-conditional-access-travel-block.md) | Conditional Access · Zero Trust | Sign-in log analysis, What If tool, time-bound policy exceptions |

## Coverage

Across these tickets the environment demonstrates hands-on troubleshooting in:

- **Directory & file access** — NTFS vs share permissions, group membership, Kerberos token refresh
- **Authentication** — MFA lockout recovery, authentication methods, Temporary Access Pass
- **Federation** — SAML assertions, claim/attribute mapping, SSO account matching
- **Lifecycle (JML)** — leaver deprovisioning, hybrid sync ordering, session/token revocation
- **Privileged access** — CyberArk EPM just-in-time elevation and PASM/vault credential recovery
- **Zero Trust** — Conditional Access policy analysis and scoped, time-bound exceptions

## How these connect to the rest of the repo

- The offboarding gap in TICKET-1004 is the operational version of a finding in the [`docs/JML-Identity-Lifecycle-Audit.pdf`](../docs/JML-Identity-Lifecycle-Audit.pdf).
- The Conditional Access reasoning in TICKET-1007 is the day-to-day counterpart to the policy incident in [`incidents/INC-001-conditional-access-lockout.md`](../incidents/INC-001-conditional-access-lockout.md).
- The privileged-access tickets (1005, 1006) reflect the CyberArk EPM and PASM operating model.
