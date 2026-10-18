---
id: REQ-102
type: job
epic: quality-gates
priority: must
status: approved
updated: 2026-10-18
---

# An unknown scope of a check never counts as an empty one

## Job

When CI runs after a push or a merge, I want the gate to judge what that push brought, and the whole repository when it cannot tell what changed, so I can catch a violation that slipped through instead of passing on an empty list of files.

## Acceptance criteria

- Given a project in `changed-files` mode, when the scope of the change is unknown, then the check runs under `strict` for that run, says so in the log, and `xaden/xaden.conf` stays as it is
- Given a verified empty change set (the local branch equals the default branch and nothing is edited), then the check passes without a fallback
- Given a push event with `BEFORE_SHA` naming a commit that exists and is an ancestor of `HEAD`, then the changed files are those of `BEFORE_SHA..HEAD`, so a violation in the first commit of a multi-commit push on a clean `main` checkout fails
- Given a push event whose `BEFORE_SHA` is missing, all zero, not a commit in the checkout, or not an ancestor of `HEAD` (first push, shallow clone, rewritten history), then the scope is unknown
- Given a pull request event, then the changed files are those since the merge base with `origin/$BASE_REF`, the actual target branch, including release and maintenance branches; an invalid or missing `BASE_REF` or ref makes the scope unknown
- Given `CI` is set and no event is known, then the scope is unknown
- Given a run outside CI, then the files differ from the first default-branch candidate that exists, plus uncommitted edits, as before; with no candidate at all the scope is unknown
- Given the generated workflows (`template/.github/workflows/ci.yml` and `scripts/adopt/ci.yml`), then the step that runs the checks receives `EVENT_NAME`, `BASE_REF` and `BEFORE_SHA`, and the checkout fetches the full history
- Given `scripts/verify-commits.sh --ci`, then it uses the same previous-commit validation as the gate, not a copy
