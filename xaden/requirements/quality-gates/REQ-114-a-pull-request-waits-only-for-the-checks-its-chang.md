---
id: REQ-114
type: job
epic: quality-gates
priority: should
status: done
updated: 2026-10-19
---

# A pull request waits only for the checks its change can affect

## Job

When I open a pull request that changes little, I want CI to run the checks that cover my change, and to run the rest in parallel, so I can read a result in a few minutes instead of 10 to 13, with no change reaching `main` unchecked.

## Acceptance criteria

- Given the CI workflow, then each smoke area runs as its own job on both operating systems, and one summary job per system, named `check (ubuntu-latest)` and `check (macos-latest)`, passes only when every area job that ran passed and none was cancelled; the ruleset on `main` is unchanged and still requires both names
- Given a pull request whose changed files all map to areas by the table in "Smoke areas", then only those areas run, on both systems, plus the fast offline subset and the commit-message check; the log names the skipped areas and why
- Given a pull request that changes a path outside that table, or a shared file (`template/scripts/lib.sh`, `scripts/xaden.sh`, `tests/smoke.sh`, `tests/smoke/lib.sh`, `scripts/check-scaffold.sh`, anything under `.github/`), then all areas run
- Given a diff that cannot be read, or an empty one, then all areas run; a selection never ends up as "none" (REQ-102)
- Given a merge into `main`, then all areas run on both systems, as REQ-088 requires
- Given the area table, then it lives in one machine-readable file that the selection script and the table in the root `AGENTS.md` both use, and `scripts/check-smoke-areas.sh` fails when they disagree
- Given the selection script, then its smoke test shows: a change in one area's paths selects that area, a shared file selects all areas, an unknown path selects all areas, and an unreadable diff selects all areas
- Given a run in CI, then it prints the duration of each area job, so the split can be tuned
- Given the files nearly every pull request changes, then `CHANGELOG.md`, `THIRD-PARTY.md`, `docs/site-pages.txt`, `GETTING-STARTED.md`, `docs/guide/admin/`, `docs/guide/contributing/` and `docs/requirements/INDEX.md` are in the area table, each in the rows of the areas whose tests read the repository's own copy (the changelog, the third-party list and the site page list in `release-and-docs`, the two guide folders and `GETTING-STARTED.md` in `release-and-docs` and `assistant-guidance`, the requirements index in `requirements`); `README.md` (read by the tests of six areas) and `docs/guide/developer/` (a page of it is read by `adoption`, whose row is not changed here) stay unmapped and still select all areas
- Given a pull request that changes the code of one area and `CHANGELOG.md`, then that area, `release-and-docs` and `adoption-versions` (its fake release copies the changelog) run and the others are skipped; given only `docs/requirements/INDEX.md`, then `requirements` runs; given `README.md`, then all areas run
- Given a pull request with several pushes, then the cancel rule of REQ-093 still holds, and a cancelled run is not a pass
- Given the root `AGENTS.md`, then "Smoke areas" and "Landing a change on main" describe the selection and say that a change to the selection or to the workflow itself runs all areas
- Given a repository that is private, then the minutes of a run count against the plan (macOS minutes count ten times); the public repository pays nothing, and the selection exists for speed, not for cost

## Measured

Before (REQ-093, one serial job per system): the step "Scaffold checks incl. smoke test" took 585 s on ubuntu and 801 s on macOS, so a run took 10 to 13 minutes.

After REQ-114, REQ-121 and the mapping of common files, a full run (every area, both systems; the run of pull request #51 on 2026-10-19) took about 5 minutes of wall time. The longest jobs, ubuntu / macOS:

- `adoption-setup` 2m50s / 4m42s
- `release-and-docs` 2m58s / 4m28s
- `quality-gates` 3m00s / 2m47s
- `adoption-versions` 1m55s / 3m41s
- `adoption-checks` 1m42s / 3m25s
- `project-setup` 1m51s / 2m42s
- `security` 54s / 1m24s, `requirements` 38s / 49s, `assistant-guidance` 33s / 1m04s
- `fast` 1m08s / 51s, the two `check` gates 2 s each

The area `adoption` alone took 5m46s / 9m29s before REQ-121. Times on macOS vary by about 30 seconds between runs.
