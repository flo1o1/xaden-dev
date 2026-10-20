---
id: REQ-079
type: job
epic: assistant-guidance
priority: should
status: done
updated: 2026-10-15
---

# Xaden supports only assistants with file access

## Job

When I read what Xaden offers, I want it to cover only assistants that can read and run files in my project, so I can rely on one tested way of working and not on a path that cannot be checked.

## Acceptance criteria

- Given `xaden help` and the project commands, then there is no `pack` command and no `pack-context.sh` in the tooling.
- Given the scaffold and docs (README, GETTING-STARTED, user guide, `local-llm.md`, AGENTS.md), then none of them tells me to paste a file into a chat assistant, and they say that Xaden needs an assistant with file access.
- Given REQ-002, REQ-023, REQ-028, REQ-042, REQ-056 and REQ-061, then the "context pack" criteria are removed or marked as replaced by this requirement; REQ-023 gets status `dropped`.
- Given `docs/threat-model.md`, then the pack rows (prompt names, requirement IDs, symlink copy into a pack) are removed.
- Given a project that still has `scripts/pack-context.sh` or an ignored `context-pack.md`, when it runs `xaden update`, then the managed script is removed, the update report says so, and my own files stay untouched.
- Given the smoke tests, then the pack tests are removed and a test fails when a script, doc or help text still mentions `pack-context` or `xaden pack`.
