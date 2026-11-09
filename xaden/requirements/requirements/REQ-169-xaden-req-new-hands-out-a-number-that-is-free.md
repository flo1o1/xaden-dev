---
id: REQ-169
type: job
epic: requirements
priority: should
status: approved
updated: 2026-11-09
paths: template/scripts/req.sh, template/scripts/requirements-lib.sh
---

# xaden req new hands out a number that is free across the repository

## Job

When I draft requirements on several branches or in several sessions at the same time, I want `xaden req new` to hand out a number no other branch uses, so I can keep every `REQ-nnn` unique without checking the other branches by hand, because the rules forbid renumbering afterwards.

## Acceptance criteria

- Given two worktrees from the same `main`, when the first has drafted a requirement and pushed its branch and the second then runs `xaden req new`, then the second gets a different number than the first.
- Given a repository with a remote, when `xaden req new` runs, then it fetches the remote, takes the highest `REQ-nnn` found in the working tree and in every `origin/*` branch, uses the highest plus one, and names each branch that holds a higher number than the working tree.
- Given the remote is not reachable or there is none, when `xaden req new` runs, then it still creates the requirement from the local state and says that it could not check the remote.
- Given an existing project, then no existing requirement file, number or index entry changes.

Refs: issue 114. Not covered: two drafts created before either branch is pushed still clash; that needs a number assigned at merge or a reservation (options 2 and 3 of the issue).
