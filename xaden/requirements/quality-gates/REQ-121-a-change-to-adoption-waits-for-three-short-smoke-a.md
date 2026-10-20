---
id: REQ-121
type: job
epic: quality-gates
priority: should
status: done
updated: 2026-10-19
---

# A change to adoption waits for three short smoke areas, not one long one

## Job

When I change anything under the adoption paths, I want its smoke tests to run as three parallel parts, so I can read a result in about 3 to 4 minutes instead of 6 minutes on ubuntu and 9.5 on macOS.

## Acceptance criteria

- Given `tests/smoke/`, then the area `adoption` is replaced by three areas that each run alone with `tests/smoke.sh <area>` and all together with `tests/smoke.sh`: `adoption-setup` (messages, scan and plan, adopt and remove, assistant commands, reuse of existing tooling, migration, new-project layout, prompts and ignore list, autopilot; about 136 s), `adoption-versions` (versions and downloads, self-upgrade, update check, signed-only generated CI; about 108 s) and `adoption-checks` (convention, modes and baselines, exit statuses, scope of changed files, commit check in CI and its range, hook with untracked Xaden files, audit kinds, `NOT COVERED:`; about 111 s)
- Given the helpers every part needs (`make_repo`, `x_in`, `x_answers`, `message_of` and the fixtures), then they live in one library file that the three areas source, and the runner does not list that file as an area
- Given the former `adoption` test functions, then each runs in exactly one of the three areas, and a check fails when one is in none or in two; no assertion is removed or weakened, so the total number of assertions is unchanged apart from tests added since
- Given `docs/smoke-areas.txt` and the table in the root `AGENTS.md`, then each has a row per new area with the adoption paths, `scripts/check-smoke-areas.sh` passes, and a change under those paths selects all three areas (REQ-114)
- Given `tests/smoke.sh` and `tests/smoke/quality-gates.sh`, then the area list of the runner and the `--list` assertion name the three areas, and no reference to the old name `adoption` is left in `AGENTS.md`, the REQ-092 text or the workflow
- Given CI, then the three areas run as separate jobs on both systems, and the longest of them takes at most 60% of the former `adoption` job (5m46s on ubuntu, 9m29s on macOS), measured on the pull request's run and noted in its description
- Given a part that fails when it runs alone because it depends on an earlier test, then that part is merged back into the area it depends on, not worked around
