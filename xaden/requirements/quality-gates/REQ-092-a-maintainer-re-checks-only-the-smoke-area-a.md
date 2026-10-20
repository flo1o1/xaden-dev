---
id: REQ-092
type: job
epic: quality-gates
priority: could
status: done
updated: 2026-10-17
---

# A maintainer re-checks only the smoke area a change touched

## Job

When I change one part of the scaffold and want to see it still works, I want to run only the smoke area that covers it, so I can get an answer in a fraction of the full smoke run and keep the full strict run for the last step before the pull request.

## Acceptance criteria

- Given `AGENTS.md`, when I read "Before done", then it names the fast loop (`tests/smoke.sh <area>`, `tests/smoke.sh --list`, `--staged`) and says the full `STRICT=1 scripts/check-scaffold.sh` still runs once before the pull request.
- Given `AGENTS.md`, then it lists, per area, the paths it covers.
- Given an area in `tests/smoke.sh --list` that has no row in that list, then the scaffold check fails, so the list cannot go stale.
- Given a run of `tests/smoke.sh <area>` for each area alone, then it passes, so an area never depends on another area's leftovers.
