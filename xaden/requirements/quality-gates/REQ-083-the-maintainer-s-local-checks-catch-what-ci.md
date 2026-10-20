---
id: REQ-083
type: job
epic: quality-gates
priority: should
status: done
updated: 2026-10-16
---

# The maintainer's local checks catch what CI catches

## Job

When I commit or push a change to the scaffold, I want the same commit-message and shellcheck rules that CI applies to run on my machine first, so I can fix a problem in seconds and not after a CI round of ten minutes.

## Acceptance criteria

- Given a clone or worktree of the scaffold, when I run `scripts/setup.sh`, then `core.hooksPath` points to a directory that exists, and the commit-msg and pre-commit hooks run on the next commit.
- Given `scripts/check-scaffold.sh`, when `core.hooksPath` is set to a path that does not exist, then the run fails and names the path.
- Given a commit message with `Refs:` outside the last paragraph, a `feat` without `Refs: REQ-nnn`, or a subject over 72 characters, then the commit is refused locally with the same message CI would give.
- Given `git push`, then a pre-push hook runs `verify-commits.sh` on the commits that are not on `origin/main` yet and refuses the push on failure.
- Given the shellcheck version CI uses is pinned in one file, when the local version differs, then `check-scaffold.sh` prints a WARNING naming both versions and runs the check anyway.
- Given the smoke tests, then a test installs the hooks into a scratch scaffold clone and checks the three refused messages and the pre-push refusal.
