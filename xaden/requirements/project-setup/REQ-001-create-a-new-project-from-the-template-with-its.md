---
id: REQ-001
type: job
epic: project-setup
priority: must
status: done
updated: 2026-10-19
---

# Create a new project from the template with its own git repository and active hooks

## Job

When I start a new project, I want one command that creates a repository from the template with active hooks, so I can begin coding under the scaffold's rules immediately.

## Acceptance criteria

- Given `xaden create <name>`, then it yields a repository on `main` with one commit and git hooks that run Xaden's checks (smoke test).
- Given `PROJECT_ROOT` set in the caller's environment to another repository, when `xaden create` runs, then the new project gets its own hooks and the other repository's git configuration stays unchanged.
- Given `xaden adopt` in an existing git repository, then Xaden is chained into that clone's hooks (pre-commit and commit-msg, also with husky or another supported hook manager) unless `--skip-hooks` is given; `xaden setup` does it for every other clone.
- Given a folder that is no git repository, then `xaden adopt` stops and names `git init`.
- Given `xaden create --classic ...` or `xaden update`, then Xaden answers like for any unknown option or command.
