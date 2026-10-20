---
id: REQ-047
type: job
epic: requirements
priority: should
status: done
updated: 2026-10-11
---

# One file per requirement, grouped in epic folders

## Job

When a project has many requirements, I want one file per requirement grouped by topic, so I can find, change and review them easily.

## Acceptance criteria

- docs/requirements/<epic>/REQ-nnn-<slug>.md with front matter (id, type, epic, priority, status, updated) and an EPIC.md per folder
- IDs stay global REQ-nnn
- a generated INDEX.md must be current
- req.sh lists, shows and creates requirements
- all tools and the commit hook read the new layout
