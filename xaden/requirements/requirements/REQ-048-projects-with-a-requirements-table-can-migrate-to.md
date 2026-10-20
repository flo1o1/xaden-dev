---
id: REQ-048
type: job
epic: requirements
priority: should
status: dropped
updated: 2026-10-20
---

# Projects with a requirements table can migrate to the per-file format

## Job

When my project still uses the requirements table, I want a migration to the per-file format, so I can adopt it without losing history.

## Acceptance criteria

- scripts/migrate-requirements.sh converts every table row into a requirement file without losing ID, status, priority, date, text or acceptance criteria, moves the change log, writes the index and refuses to overwrite existing files
- Given a table row whose ID is not `REQ-nnn` (e.g. `REQ-/../../x`), when the migration runs, then it stops before writing any file, so a crafted table cannot write outside `docs/requirements/`

Dropped 2026-10-20 by REQ-133: every project has the `xaden/` layout; no `xaden` command reaches `scripts/migrate-requirements.sh`, and nobody has a requirements table.
