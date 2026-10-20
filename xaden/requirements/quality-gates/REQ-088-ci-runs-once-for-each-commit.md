---
id: REQ-088
type: job
epic: quality-gates
priority: should
status: done
updated: 2026-10-17
---

# CI runs once for each commit

## Job

When I push a commit on a branch with an open pull request, I want to see CI run once for it, so I can read the result in about 11 minutes instead of waiting on, and paying for, a duplicate run.

## Acceptance criteria

- Given `.github/workflows/scaffold-ci.yml`, then it runs on `pull_request` and when a commit lands on the default branch (the `push` trigger restricted to `main`, which GitHub fires when a pull request is merged), and on no other branch push; nobody pushes to `main`, and the ruleset and the pull-request-only rule stay
- Given a pull request, when I push a new commit to its branch, then exactly one run of each check (`check (ubuntu-latest)`, `check (macos-latest)`) starts for that commit
- Given a merge into `main`, then the checks run once more on the merged commit
- Given the ruleset on `main`, then it still requires both checks
- Given a branch without a pull request, then no CI runs until the pull request is opened, and the maintainer runs `STRICT=1 scripts/check-scaffold.sh` locally before opening it (superseded by REQ-093: the maintainer runs only the touched smoke areas locally and CI runs the full suite)
- Given the root `AGENTS.md`, then it describes landing by pull request (push the branch, open the pull request, merge when `check` is green) and no longer describes pushing a branch to `main`
- Given the smoke test of the workflow triggers, then it asserts these triggers instead of "every branch push runs CI"

REQ-062 (push a green branch tip to `main`) is superseded in part by this requirement and by REQ-060.
