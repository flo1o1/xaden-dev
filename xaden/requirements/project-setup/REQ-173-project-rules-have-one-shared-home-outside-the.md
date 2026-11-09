---
id: REQ-173
type: job
epic: project-setup
priority: should
status: approved
updated: 2026-11-10
paths: docs/guide/developer/add-xaden-to-a-repository.md, docs/guide/admin/pin-one-version-per-project.md, tests/smoke/adoption-setup.sh, tests/smoke/adoption-versions.sh
---

# Project rules have one shared home outside the Xaden block

## Job

When my adopted project has its own rules for assistants, I want one shared place for those rules and a clear description of what Xaden owns, so I can upgrade or remove Xaden without losing the team's instructions.

## Acceptance criteria

- Given an adopted project, then the adoption guide names `AGENTS.md` outside the Xaden markers as the shared home of project rules, explains links to longer project-owned documents, and keeps `CLAUDE.md` for Claude-specific instructions rather than duplicate shared rules.
- Given the guide, then it explains that `xaden/RULES.md` is generated and must not be edited, and that Xaden owns only the marked block in `AGENTS.md`.
- Given `xaden project pin`, then the guide and a regression test establish that it regenerates `xaden/RULES.md` and leaves the project's `AGENTS.md` unchanged.
- Given an already adopted repository, when adoption is requested again, then it is refused without rewriting the project's rules.
- Given `created-block AGENTS.md` in the footprint and project rules added outside the block, when Xaden is removed, then the project rules remain; the guide explains that the footprint entry does not give Xaden ownership of the whole file forever.
- Given regression tests, then they cover the documented placement and preservation of project rules.

Refs: issue 133, REQ-066, REQ-071, REQ-073.
