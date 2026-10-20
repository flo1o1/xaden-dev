---
id: REQ-034
type: job
epic: assistant-guidance
priority: should
status: dropped
updated: 2026-10-20
---

# Claude Code permission rules are accurate and documented with their limits

## Job

When I rely on Claude Code permission rules, I want them accurate and their limits documented, so I can know what they do and do not protect.

## Acceptance criteria

- Deny rules block real env files but not .env.example
- docs say which patterns are covered and that they are not a security boundary

Dropped 2026-10-20 by REQ-133: a project made by `xaden project create` has no `.claude/settings.json` and no `CLAUDE.md` of Xaden; the permission rules belonged to the copied-tooling project that no longer exists.
