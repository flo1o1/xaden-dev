---
id: REQ-090
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-17
---

# My change worktrees live in one known folder

## Job

When I start a change in a Xaden project, I want its worktree in `worktrees/` inside the project, so I can find, clean up and exclude all change worktrees in one place.

## Acceptance criteria

- Given `xaden create`, when the project is generated, then `worktrees/` exists with a short README and git ignores everything in it except that README
- Given `xaden adopt`, when the plan is shown, then adding `worktrees/` is a separate question and a separate commit; declining (or `--no-worktrees`) leaves no folder and no ignore rule, and `xaden remove` removes what it added
- Given `xaden upgrade` or `xaden pin` in an existing project, then worktrees the person already has (`../<repo>-<slug>`) stay where they are and nothing is moved
- Given a checkout inside `worktrees/`, then `scripts/check.sh` and the pre-commit hook do not scan it, and `git add -A` never stages it
- Given `AGENTS.md` §7 and the commit-refusal message, then they name `worktrees/<slug>` and `worktrees/req-nnn-<slug>` instead of `../<repo>-…`
- Given the smoke tests, then they check the created folder, the ignore rule, the adopt question with both answers, and the removal
