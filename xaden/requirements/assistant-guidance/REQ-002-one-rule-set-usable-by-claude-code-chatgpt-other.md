---
id: REQ-002
type: job
epic: assistant-guidance
priority: must
status: done
updated: 2026-10-12
---

# One rule set usable by Claude Code, ChatGPT, other agents and local LLMs

## Job

When I switch between Claude Code, ChatGPT, other agents or local models, I want one rule set they all read, so I can get the same behaviour regardless of the tool.

## Acceptance criteria

- AGENTS.md plus pointer files for Claude, Aider, Cline, Continue, Copilot
- Given a tool that already loaded the requirements index (for example through `CLAUDE.md`), when a session starts, then `AGENTS.md` lets it skip reading the index again.
