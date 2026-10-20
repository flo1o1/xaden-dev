---
id: REQ-006
type: job
epic: requirements
priority: must
status: done
updated: 2026-10-13
---

# Track requirements and update them when a session changes scope

## Job

When the user changes scope during a session, I want the assistant to update the requirements before coding, so I can keep requirements and code in sync.

## Acceptance criteria

- REQUIREMENTS.md validated by script
- AGENTS.md mandates update before code
- /requirements prompt
- Given a requirement change, when it is committed, then its history is found with `git log -- docs/requirements` and no hand-kept change log has to be updated
