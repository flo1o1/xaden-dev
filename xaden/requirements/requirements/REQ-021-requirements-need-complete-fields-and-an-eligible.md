---
id: REQ-021
type: job
epic: requirements
priority: must
status: done
updated: 2026-10-12
---

# Requirements need complete fields and an eligible status

## Job

When I record a requirement, I want complete fields and a status that allows implementation to be enforced, so I can build only on complete, approved requirements.

## Acceptance criteria

- Empty requirement text or acceptance criteria and invalid dates fail
- template placeholders block releases
- feat and fix may only reference approved, in-progress or done requirements
- Given a status, type or priority written as a pattern such as `d.*e`, when the requirements are checked, then it fails as unknown; values must match a listed name exactly
