---
id: REQ-060
type: job
epic: assistant-guidance
priority: should
status: done
updated: 2026-10-16
---

# Every change happens on its own branch and worktree and reaches main through a pull request

## Job

When I or several assistants work on more than one change at the same time, I want each change
on its own branch in its own folder, so I can review, test and merge each one on its own without
one change overwriting or blocking another.

## Acceptance criteria

- Given AGENTS.md §7, when an assistant starts a change whose requirement the user has approved (REQ-082), then it is told to create a branch `<type>/<slug>` from `main` in its own worktree (`git worktree add ../<repo>-<slug> -b <type>/<slug> main`), to finish with the full check, push the branch and open a pull request (approval points), to leave the merge to the user, and to remove the worktree and branch after the merge
- Given a commit on `main` or `master`, when the pre-commit hook runs, then it refuses the commit and names `git worktree add` as the way out, in generated projects and in the scaffold itself
- Given `ALLOW_MAIN_COMMIT=1`, or a merge being concluded on `main`, when the hook runs, then the commit is allowed
- Given a commit on a feature branch, when the hook runs, then the branch rule does not block it
- Given project generation or a release (`scripts/release.sh`, `scripts/release-scaffold.sh`), when they commit on `main`, then the commit succeeds without the user setting anything
