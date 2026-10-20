---
id: REQ-003
type: job
epic: assistant-guidance
priority: must
status: done
updated: 2026-10-12
---

# Apply clean-code rules when generating code

## Job

When an assistant generates code, I want it to apply numbered clean-code rules, so I can keep the code understandable and cheap to change.

## Acceptance criteria

- Numbered CC rules in template AGENTS.md
- review and refactor prompts cite them
- Given a generated project, when a session starts, then `CLAUDE.md` and `.aider.conf.yml` load `AGENTS.md` with the CC summary but not `docs/clean-code.md`, and the feature, bugfix, refactor and code-review prompts point to `docs/clean-code.md`.
