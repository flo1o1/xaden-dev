---
id: REQ-022
type: job
epic: quality-gates
priority: must
status: done
updated: 2026-10-12
---

# Commit reference checks cannot be bypassed

## Job

When commits reference requirements, I want reference checks that special prefixes and prose cannot bypass, so I can trust the commit history's traceability.

## Acceptance criteria

- Special prefixes skip only the format check
- Refs are parsed as git trailers
- CI validates every commit of a first push
- IDs in comment lines and in the diff that `git commit -v` appends are not checked
- Given a `fix` commit, when its `Refs:` trailer is neither a requirement ID nor exactly `none` (e.g. `Refs: nonexistent`), then the commit is rejected
- Given the commit-msg hook run by git (`GIT_DIR` exported, also in a worktree) with a rules file in a subfolder (the scaffold's `template/AGENTS.md`), when the message cites an existing `CC-nn`, then it is accepted, and an unknown `CC-nn` is still rejected.
