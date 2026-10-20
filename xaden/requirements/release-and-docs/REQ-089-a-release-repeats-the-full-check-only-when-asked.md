---
id: REQ-089
type: job
epic: release-and-docs
priority: should
status: done
updated: 2026-10-17
---

# A release repeats the full check only when asked

## Job

When I cut a release, I want to skip the full local check of `scripts/release-scaffold.sh` unless I ask for it, so I can finish a release in minutes instead of waiting about 10 minutes for a check that CI runs on the release pull request anyway.

## Acceptance criteria

- Given `scripts/release-scaffold.sh <part>`, then it does not run `scripts/check-scaffold.sh`, says on one line that the full check was skipped and that CI checks the release pull request, and still stops on an unclean working tree and on an existing tag before any file changes
- Given `scripts/release-scaffold.sh --check <part>`, then it runs `STRICT=1 scripts/check-scaffold.sh` first, and a failing check aborts before any file changes (REQ-024)
- Given a release made without `--check`, then the release commit still reaches `main` only through a pull request whose checks passed (REQ-088, ruleset)
- Given the smoke tests, then they cover the default (check stub not called), `--check` (check stub called, a failing stub aborts with all files unchanged) and the unchanged failure handling of REQ-024
- Given the release documentation and `AGENTS.md`, then they name the `--check` option

REQ-024 stays valid; its "failing check aborts" criterion now applies to `--check`.
