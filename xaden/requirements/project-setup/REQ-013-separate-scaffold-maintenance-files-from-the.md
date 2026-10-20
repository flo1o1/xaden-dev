---
id: REQ-013
type: job
epic: project-setup
priority: must
status: dropped
updated: 2026-10-20
---

# Separate scaffold maintenance files from the project template

## Job

When I maintain the scaffold, I want maintenance files kept apart from the project template, so I can change one without leaking into the other.

## Acceptance criteria

- Projects are copied from template/ only
- scaffold has its own requirements, rules and checks

Dropped 2026-10-20 by REQ-133: `xaden project create` writes the `xaden/` layout from the installed Xaden; no project is copied from `template/`, and the Xaden repository keeps its maintenance files apart in `xaden/` and `docs/`.
