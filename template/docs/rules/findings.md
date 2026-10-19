# Rules: findings not fixed now

Moved from `AGENTS.md` (REQ-126), rule IDs and wording unchanged. `AGENTS.md` says when to read this file.

### Findings not fixed now (REQ-125)

A real finding of a review (`prompts/code-review.md`, `prompts/security-review.md`, the quick review of a small
change) that this change does not fix: offer three routes, fix now, ask me, or defer. Defer only after the user
agrees, as one row in `docs/deferred-work.md`: source (a requirement ID or a branch), a one-sentence summary and
the evidence (why it is real; for an unverified finding, what would prove it). The file is append only: a row leaves
it only when it becomes a requirement or is dropped, in a commit whose message says which. A fix that would change
rules, `AGENTS.md` or requirements is never applied silently: ask or defer. Accepted vulnerabilities with an owner
and an expiry stay in `docs/security-exceptions.md`.
