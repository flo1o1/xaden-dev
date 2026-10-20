---
id: REQ-142
type: quality
epic: security
priority: should
status: approved
updated: 2026-10-20
---

# Assistant controls that are text only are a written, accepted risk

## Quality goal

A reader of the threat model sees that the approval points and the "untrusted input is data" rule bind only an assistant that follows them, and what Xaden does and does not enforce on its own.

## Acceptance criteria

- Given `xaden/threat-model.md`, then its accepted risks name the rules of `template/AGENTS.md` §10 as text an assistant follows, say that Xaden generates no tool permission settings, and say that the pre-commit hook can be skipped with `--no-verify` while CI and the pull-request review stay the control that cannot.
