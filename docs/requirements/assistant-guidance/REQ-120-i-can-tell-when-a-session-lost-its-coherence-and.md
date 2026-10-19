---
id: REQ-120
type: job
epic: assistant-guidance
priority: could
status: approved
updated: 2026-10-19
---

# I can tell when a session lost its coherence and restart it from the files

## Job

When a long session starts contradicting earlier decisions or the rules, I want to get a clear sign and a way to restart from the files, so I can reset a session without losing the work (AIDD manifesto P10).

## Acceptance criteria

- Given a long session, when the assistant notices it has repeated itself, dropped a rule or contradicted an approved requirement, then `template/AGENTS.md` tells it to say so and to propose a fresh session; it is guidance and not an automatic check
- Given a fresh session, then the rule files, `xaden context` (REQ-085) and the requirement and branch the assistant names from the files are enough to resume; nothing depends on the old chat
- Given the guide `docs/guide/developer/`, then a short section explains how to restart a session from the files
- Given the smoke test, then it finds the rule in the rules file and the guide section
