---
id: REQ-093
type: job
epic: quality-gates
priority: should
status: done
updated: 2026-10-17
---

# A maintainer waits for CI once, not for the same suite twice

## Job

When I finish a change to the scaffold, I want to open the pull request after only the checks that cover my change have passed, so I can wait about 12 minutes for one full run in CI instead of about 32 minutes for a full local run followed by the same run in CI.

## Acceptance criteria

- Given the root `AGENTS.md`, then "Before done", "Landing a change on main" and "Smoke areas" all say the same: before the pull request, run `scripts/check-scaffold.sh --staged` and the smoke areas the change touched (`tests/smoke.sh <area>`, areas per the table in "Smoke areas"); the full `STRICT=1 scripts/check-scaffold.sh` is not required before opening the pull request, because CI runs it once
- Given the same `AGENTS.md`, then it still requires the full local run before a release and when CI is red and the cause is not clear, and it names a change that touches no row of the area table (for example the workflow or `check-scaffold.sh` itself) as a reason to run the full check
- Given REQ-088, then its criterion that the maintainer runs `STRICT=1 scripts/check-scaffold.sh` locally before opening the pull request is marked superseded by REQ-093 in that file, not deleted
- Given a pull request with several pushes, when I push a new commit to the same branch, then the older CI run for that branch is cancelled and only the newest one finishes
- Given a run on `main` (the merge commit), then it is never cancelled by a later run
- Given the ruleset on `main`, then it still requires `check (ubuntu-latest)` and `check (macos-latest)`, and a cancelled run does not count as a pass
- Given the smoke test of the workflow triggers, then it asserts the cancel rule for pull requests and its absence for `main`
