---
id: REQ-107
type: job
epic: quality-gates
priority: must
status: approved
updated: 2026-10-18
---

# An adopted project's CI rejects commits whose references are wrong, even when the hooks were skipped

## Job

When a commit reaches my adopted repository without passing the local hooks (`--no-verify`, a clone without `xaden setup`, an unattended run), I want CI to apply the same commit-message rules, so I can trust that every commit on `main` cites a real requirement.

## Acceptance criteria

- Given a repository adopted with CI, then `.github/workflows/xaden.yml` runs `xaden verify-commits --ci` for the commits a push or pull request introduces, in the same job as `xaden.sh check --strict`, with no new secret and no new third-party action
- Given the command `xaden verify-commits --ci`, then it runs the pinned tree's `verify-commits.sh --ci` and reads `EVENT_NAME`, `BASE_REF` and `BEFORE_SHA` as the workflow already exports them
- Given `commit-convention = conventional`, when a commit in the range has the wrong format, a `feat` without `Refs: REQ-nnn`, a `fix` without a requirement ID or `none`, or an unknown `REQ-nnn` or `CC-nn`, then the step fails and names the commit and the rule
- Given `commit-convention = other`, then the same findings are warnings in the job log and the step passes (REQ-068)
- Given the first push of a branch, a push after a force-push and a pull request, then the range is the one `verify-commits.sh --ci` derives today (REQ-022); a range that cannot be derived fails the step and is never read as empty (REQ-102)
- Given merge commits, then they are not checked themselves; every commit they bring in is
- Given a project that adopted an earlier Xaden, then `xaden upgrade` proposes the added step in its upgrade pull request (REQ-071) and never edits the workflow in place; commits from before the adoption are not checked
- Given the smoke test, then a fixture repository with a conventional history receives a `feat` commit without `Refs:` made with `--no-verify`, and the command of the generated workflow's step fails on it with `conventional`, warns with `other`, and passes a commit with a valid `Refs: REQ-nnn`
- Given the guide `docs/guide/developer/add-xaden-to-a-repository.md`, then it says that the local hook is a convenience and CI the gate, and names the ruleset setting that makes the `xaden` job a required check; Xaden changes no repository setting
