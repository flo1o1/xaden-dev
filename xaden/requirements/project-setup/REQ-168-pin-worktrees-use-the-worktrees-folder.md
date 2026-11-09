---
id: REQ-168
type: job
epic: project-setup
priority: should
status: approved
updated: 2026-11-09
paths: scripts/fetch.sh, scripts/aidd.sh
---

# `xaden project pin` and `xaden aidd pin` put their worktree in `worktrees/`

## Job

When I run `xaden project pin` or `xaden aidd pin` in a project that has a `worktrees/` folder, I want the new worktree in `worktrees/`, so the change lives where my other change worktrees and my tool permissions already are.

## Acceptance criteria

- Given a project with `worktrees/`, when `xaden project pin <version>` runs, then the worktree is `worktrees/upgrade-xaden-<version>`
- Given a project with `worktrees/`, when `xaden aidd pin <cli> <release>` runs, then the worktree is `worktrees/pin-aidd-<release>`
- Given a project without `worktrees/`, then both commands keep the path `../<repo>-<slug>`, and nothing is created or moved (REQ-090)
- Given the smoke tests, then they check the path with and without `worktrees/` for both commands

Refs: issue 124, REQ-090.
