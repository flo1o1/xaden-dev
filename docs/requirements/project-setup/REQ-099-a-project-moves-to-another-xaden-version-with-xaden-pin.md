---
id: REQ-099
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-18
---

# A project moves to another Xaden version with `xaden pin`

## Job

When my team decides to use another Xaden version, I want a command named for that decision, so I can rely on `xaden upgrade` meaning an update of the tool.

## Acceptance criteria

- Given an adopted project, when I run `xaden pin <version>`, then it does what `xaden upgrade <version>` did before (REQ-071): a branch, a worktree, pinned version and checksum, `xaden/RULES.md`, command files and workflow, then the changelog.
- Given `xaden pin --check`, then it reports the newest release against the pinned version after the yes (REQ-072).
- Given an adopted project, when I run `xaden upgrade <version>`, then it pins as `xaden pin` does and warns that the name changes; `xaden upgrade` without a version updates the tool.
- Given an adopted project after a tool upgrade, then `xaden doctor` names the installed newest version and the line `xaden pin <version>`; it moves nothing.
- Given the help text, the docs and the changelog, then they name `xaden pin` as the project command (breaking change in `xaden upgrade`).
