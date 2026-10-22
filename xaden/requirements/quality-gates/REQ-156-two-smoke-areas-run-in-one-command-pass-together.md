---
id: REQ-156
type: quality
epic: quality-gates
priority: should
status: approved
updated: 2026-10-22
---

# Two smoke areas run in one command pass together

## Quality goal

`tests/smoke.sh adoption-setup adoption-versions` gives the same verdict as the two areas run one after the other. It failed at "REQ-147 a bare-signed release can be pinned": both areas build a repository named `bare`, and `make_repo` removed that directory but not the `bare-adopt-xaden` worktree the first area had left next to it, so the second `project adopt` stopped with "exists already".

## Acceptance criteria

- Given a leftover `<repo>-adopt-xaden` folder from an earlier area, when `make_repo` makes `<repo>` again, then the folder is gone and the adoption makes a fresh one.
- Given `tests/smoke.sh adoption-setup adoption-versions`, then the run passes.
