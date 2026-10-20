---
id: REQ-091
type: job
epic: assistant-guidance
priority: should
status: done
updated: 2026-10-17
---

# Maintainers use the feature, requirements, release and persona commands on the scaffold

## Job

When I maintain the scaffold with Claude Code, I want `/xaden-feature`, `/xaden-requirements`, `/xaden-release` and `/xaden-persona` next to the four I already have, so I can run the whole change workflow with the same prompt library that generated projects get.

## Acceptance criteria

- Given the scaffold root in Claude Code, when I list commands, then `xaden-feature`, `xaden-requirements`, `xaden-release` and `xaden-persona` exist beside `xaden-bugfix`, `xaden-refactor`, `xaden-review` and `xaden-security`, and each includes its template prompt (`feature.md`, `requirements-update.md`, `release.md`, `persona.md`) with `@template/prompts/<file>` instead of a copy.
- Given a template prompt names a project path or script, when it runs in the scaffold, then the path map in `AGENTS.md` ("Using the project commands here") covers it: `scripts/release.sh` maps to `scripts/release-scaffold.sh`, `docs/requirements/` and `scripts/req.sh` map to the scaffold's own, `docs/personas/` maps to the same path at the root (created with the first persona, from `template/docs/personas/0000-template.md`), and the landing rule of `AGENTS.md` (branch, worktree, pull request, no push to `main`) wins over the git steps of the prompt.
- Given `/xaden-release` in the scaffold, then it runs only when I ask for a release and follows the release-branch flow in `AGENTS.md`.
- Given `xaden-kickoff` and `xaden-docs`, then they stay out of the scaffold by decision (kickoff does not apply to an existing scaffold; docs was left out under REQ-055), and `AGENTS.md` says so.
- Given a generated project, then it contains none of the scaffold's own command files (REQ-055 still holds).
- Given the smoke test `test_scaffold_commands`, then it covers all eight commands and checks that the two excluded ones are absent.
