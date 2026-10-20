---
id: REQ-055
type: job
epic: assistant-guidance
priority: should
status: done
updated: 2026-10-11
---

# Maintainers use the project commands on the scaffold itself

## Job

When I maintain the scaffold with Claude Code, I want to use the same `/bugfix`, `/refactor`, `/review` and `/security` commands that generated projects get, so I can test the prompts on real work and keep one prompt library.

## Acceptance criteria

- Given the scaffold root in Claude Code, when I list commands, then `/bugfix`, `/refactor`, `/review` and `/security` exist and each includes the matching prompt from `template/prompts/` instead of a copy.
- Given a template prompt names a project path (`scripts/check.sh`, `docs/clean-code.md`, `docs/threat-model.md`, …), when it runs in the scaffold, then the root AGENTS.md maps it to the scaffold's equivalent.
- Given `/security` in the scaffold, when it starts, then a scaffold threat model in `docs/threat-model.md` names its assets, entry points and trust boundaries, and reports go to `docs/security-reviews/`.
- Given a generated project, when it is created, then it contains none of the scaffold's own commands or threat model.
- Given a maintainer session at the scaffold root, when it runs the context status as AGENTS.md maps it, then the `CONTEXT CHECK` line covers the template's rules and the scaffold's requirements, lists the `CC-nn` rules and prints no error
