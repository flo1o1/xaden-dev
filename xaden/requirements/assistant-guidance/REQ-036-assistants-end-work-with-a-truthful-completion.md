---
id: REQ-036
type: job
epic: assistant-guidance
priority: must
status: done
updated: 2026-10-11
---

# Assistants end work with a truthful completion report

## Job

When an assistant finishes a task, I want a truthful completion report, so I can see which checks ran, which were skipped and what is still open.

## Acceptance criteria

- AGENTS.md defines the report (checks run, checks skipped, unresolved findings, acceptance evidence)
- prompts reference it
- skipped checks are never reported as passed
