---
id: REQ-078
type: job
epic: quality-gates
priority: could
status: done
updated: 2026-10-15
---

# Branches name the requirement they relate to

## Job

When I look at the list of branches or worktrees, I want each branch name to start with the ID of the requirements document it relates to, so I can see at a glance what a branch is for.

## Acceptance criteria

- Given a change that relates to a requirement, when an assistant creates its branch, then the slug starts with the lower-case requirement ID, for example `feat/req-066-adopt`
- Given a change without a requirement, when an assistant creates its branch, then a plain `<type>/<slug>` is fine
- Given the root `AGENTS.md`, when a maintainer or assistant starts a change, then it states this convention and that it is not mandatory
