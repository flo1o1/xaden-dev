---
id: REQ-062
type: job
epic: quality-gates
priority: should
status: dropped
updated: 2026-10-17
---

# Maintainer changes reach main only after CI passed on the exact commit

## Job

When I finish a change to the scaffold on my own and nobody else reviews it, I want to put it on
`main` myself without opening a pull request, so I can work fast while a commit that failed CI on
Linux or macOS still never reaches `main`.

## Acceptance criteria

- Given `.github/workflows/scaffold-ci.yml`, when a maintainer pushes any branch, then CI runs on that push
- Given the ruleset on `main` requiring the checks `check (ubuntu-latest)` and `check (macos-latest)` without a bypass, when a maintainer pushes a commit to `main` that has not passed both checks, then GitHub rejects the push
- Given a branch whose tip passed both checks, when the maintainer pushes that commit to `main` (`git push origin <branch>:main`), then GitHub accepts it without a pull request or review
- Given the root `AGENTS.md`, when a maintainer or assistant finishes a change, then it describes this flow, the flow for release commits and the ruleset setup

Dropped 2026-10-17: superseded by REQ-060 (changes reach main by pull request) and REQ-088 (CI runs on pull requests and on main, not on every branch push). Nobody pushes to main.
