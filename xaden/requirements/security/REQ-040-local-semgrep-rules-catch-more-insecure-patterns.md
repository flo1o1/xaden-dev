---
id: REQ-040
type: job
epic: security
priority: should
status: done
updated: 2026-10-11
---

# Local semgrep rules catch more insecure patterns

## Job

When I commit code, I want local rules that catch common insecure patterns, so I can fix them before they reach review.

## Acceptance criteria

- Rules for open redirect, insecure randomness for secrets, weak password hashing, cookies without security flags, unsafe XML parsing and regular expressions built from input, each proven by fixtures in tests/semgrep for Python and JS where applicable
