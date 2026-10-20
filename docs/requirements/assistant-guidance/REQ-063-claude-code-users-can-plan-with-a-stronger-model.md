---
id: REQ-063
type: job
epic: assistant-guidance
priority: could
status: dropped
updated: 2026-10-20
---

# Claude Code users can plan with a stronger model and implement with a cheaper one

## Job

When I use Claude Code in a generated project and plan larger changes in plan mode, I want to know how to plan with Opus and implement with Sonnet, so I can get better plans without paying Opus prices for the whole implementation, and still work when my account has no Opus access.

## Acceptance criteria

- Given a new project, when I read `CLAUDE.md`, then it names `/model opusplan` and `"model": "opusplan"` in `.claude/settings.local.json` as an optional way to plan with Opus and implement with Sonnet.
- Given an account without Opus access, when I read `CLAUDE.md`, then it tells me to use `/model sonnet` and that the prompts work unchanged.
- Given a project that wants a stronger model for one command, when I read `CLAUDE.md`, then it names the `model:` front matter of `.claude/commands/*.md` and that it applies only to the current turn.
- Given a new project, when I inspect `.claude/settings.json` and `.claude/commands/*.md`, then none sets a model, so every user keeps the model their account and settings choose.

Dropped 2026-10-20 by REQ-133: a project made by `xaden project create` has no `CLAUDE.md` or `.claude/` files of Xaden to document a model in; the person chooses the model in their own tool.
