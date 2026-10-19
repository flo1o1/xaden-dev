# Rules: security

Moved from `AGENTS.md` (REQ-126), rule IDs and wording unchanged. `AGENTS.md` says when to read this file.

## 6. Security (mandatory)

- Follow `docs/security.md` while coding (secrets, injection, authz, crypto, deps).
- `docs/threat-model.md` records assets, entry points, trust boundaries and the OWASP ASVS level.
  Update it when a change adds an entry point, a sensitive data type, an external service or a
  deployment target.
- `SECURITY.md` holds vulnerability reporting, secret rotation and incident basics. A leaked
  secret is rotated and revoked, not just removed from git.
- After finishing a feature that touches input, auth, data, files, network, or
  dependencies — and before every release — run a security review:
  - Claude Code: `/xaden-security` (runs `prompts/security-review.md`).
  - Any other LLM: paste `prompts/security-review.md` plus the changed files.
  - Save the report in `docs/security-reviews/` (scope, evidence, limitations, findings, status).
    A completed checklist is not proof of security.
- Never hardcode or print secrets. Never commit `.env`. Ask before adding dependencies and follow
  the dependency policy in `docs/security.md`; accepted vulnerabilities go to
  `docs/security-exceptions.md` with owner and expiry; the full `scripts/check.sh` fails once
  a row has expired.
