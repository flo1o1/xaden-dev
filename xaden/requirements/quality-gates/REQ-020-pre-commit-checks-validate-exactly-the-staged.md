---
id: REQ-020
type: job
epic: quality-gates
priority: must
status: done
updated: 2026-10-11
---

# Pre-commit checks validate exactly the staged snapshot

## Job

When I commit only part of my changes, I want checks to validate exactly the staged snapshot, so I can trust a green pre-commit hook.

## Acceptance criteria

- A staged regression cannot be hidden by an unstaged fix
- a requirement ID present only in an unstaged file cannot validate a commit
- the working tree is never modified
