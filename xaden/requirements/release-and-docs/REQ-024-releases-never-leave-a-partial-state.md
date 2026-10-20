---
id: REQ-024
type: job
epic: release-and-docs
priority: must
status: done
updated: 2026-10-17
---

# Releases never leave a partial state

## Job

When a release step fails, I want no partial state left behind, so I can retry without manual repair.

## Acceptance criteria

- An existing tag or failing check aborts before any file changes
- a failing commit restores the files
- a failing tag is reported with recovery steps
- Given a guide that cannot be written, when a release stamps the files, then it aborts and `VERSION`, `CHANGELOG.md` and both guides are unchanged
- Given a scaffold `VERSION` that cannot be written, when `scripts/release-scaffold.sh` stamps the files, then it aborts and `VERSION` and `CHANGELOG.md` are unchanged

Amended by REQ-089: the full local check before a release is opt-in with `--check`.
