---
id: REQ-167
type: job
epic: release-and-docs
priority: should
status: done
updated: 2026-11-05
---

# `xaden check --release` is the release gate the release prompt names

## Job

When the release prompt tells my assistant to run `xaden check --release`, I want that command to exist, so I can run the gate before I approve a release and my assistant does not stop on "unknown option".

## Acceptance criteria

- Given `xaden check --release`, then it runs the full check and additionally fails on `<!-- TODO` markers in `SECURITY.md` and the threat model (REQ-058) and on template placeholders in the requirements, and it names each file at fault
- Given `--staged --release`, then the run is refused with a usage message
- Given `xaden project release`, then its own gates stay as they are; no existing check is weakened
- Given the release prompt, `xaden doc rules-git` and the help text, then they name this command
- Given the smoke tests, then they cover a pass and a fail of `--release`
