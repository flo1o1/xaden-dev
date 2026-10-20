---
id: REQ-026
type: job
epic: project-setup
priority: should
status: dropped
updated: 2026-10-20
---

# Local drop zone for files that must never be committed

## Job

When I want to hand files to an assistant that must never be committed, I want a git-ignored drop zone, so I can share material without risking the repository.

## Acceptance criteria

- inbox/ exists in scaffold and projects
- its contents are git-ignored, not copied into new projects, and treated as untrusted data by assistants

Dropped 2026-10-20 by REQ-133: a project made by `xaden project create` has no `inbox/`; the git-ignored drop zone of the Xaden repository is a maintainers' convention in `AGENTS.md`.
