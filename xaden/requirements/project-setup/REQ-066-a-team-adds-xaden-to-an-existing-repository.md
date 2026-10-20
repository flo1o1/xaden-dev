---
id: REQ-066
type: job
epic: project-setup
priority: must
status: done
updated: 2026-10-14
---

# A team adds Xaden to an existing repository without changing its build

## Job

When my team inherits or owns a repository whose build, CI and conventions already work, I want to put Xaden beneath it and use AI assistants on it, so I can adopt the process without migrating the project.

## Acceptance criteria

- Given a repository with its own `README.md`, `docs/`, `scripts/` and `CHANGELOG.md`, when `xaden adopt` is applied, then none of those files changes and the project's own build and tests still run as before.
- Given `xaden adopt` is applied, then it works on its own branch and worktree and ends in a pull request the team reviews; nothing lands on the default branch directly.
- Given an empty repository, when `xaden adopt` runs, then the result is the same layout a new project gets (one code path for new and existing projects).
- Given a repository where Xaden was adopted, when the team runs `xaden remove`, then the Xaden paths listed in REQ-073 are gone and the build is unchanged.
- Given the assistants the team picks with `--assistants` (default: pre-selected from what the scan finds, confirmed by the person), then pointer files exist only for those assistants; `CLAUDE.md` is created only for Claude users, as the single line `@AGENTS.md`, and an existing `CLAUDE.md` gains that line only when it is missing.
