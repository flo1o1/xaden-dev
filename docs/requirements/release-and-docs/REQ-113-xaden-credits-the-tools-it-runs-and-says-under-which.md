---
id: REQ-113
type: job
epic: release-and-docs
priority: should
status: approved
updated: 2026-10-19
---

# Xaden credits the tools it runs and says under which license

## Job

When I decide whether to adopt Xaden or to redistribute a project that uses it, I want a list of the tools Xaden runs or recommends with their licenses and links, so I can see what I depend on and that the authors are credited.

## Acceptance criteria

- Given the repository root, then `THIRD-PARTY.md` lists every tool that the stack files, the presets, the generated CI workflow and `template/docs/optional-tools.md` run or recommend, each with a link and its license, and says Xaden bundles none of them: the user or the generated CI installs them and Xaden only invokes them.
- Given `scripts/check-scaffold.sh`, then it fails when a tool named in `template/scripts/stacks/*.sh`, `template/presets/*` or `scripts/adopt/ci.yml` has no entry in `THIRD-PARTY.md`, or an entry has no link or license.
- Given a release archive, then `THIRD-PARTY.md` is in it.
- Given the Semgrep registry rules (`p/default`) that CI may run, then the file says they carry the Semgrep Rules License v1.0, not LGPL.
- Given the smoke test, then a stack file tool missing from the file fails the check and the complete file passes.
