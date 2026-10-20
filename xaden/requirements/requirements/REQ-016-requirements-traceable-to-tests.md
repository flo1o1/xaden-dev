---
id: REQ-016
type: job
epic: requirements
priority: must
status: done
updated: 2026-10-11
---

# Requirements traceable to tests

## Job

When a requirement is marked done, I want a test that references it, so I can prove each requirement is verified.

## Acceptance criteria

- Every done requirement is referenced by a test
- matrix script lists requirement to tests
- check and matrix count the same citations; lines marked `traceability: ignore` count for neither
