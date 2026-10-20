---
id: REQ-019
type: job
epic: quality-gates
priority: must
status: done
updated: 2026-10-11
---

# Required checks cannot be skipped silently

## Job

When a required tool is missing, I want the check reported as skipped and the run as incomplete, so I can tell a skipped check from a passed one.

## Acceptance criteria

- Every check reports passed, failed or skipped
- any skip marks the run INCOMPLETE
- CI and releases run strict so a missing scanner fails
- CI provisions pinned tool versions
