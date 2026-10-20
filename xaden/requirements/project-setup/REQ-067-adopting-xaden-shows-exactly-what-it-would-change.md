---
id: REQ-067
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-14
---

# Adopting Xaden shows exactly what it would change before it changes anything

## Job

When I consider adding Xaden to a repository I do not know well, I want a read-only report and an exact plan first, so I can decide with the team without risk.

## Acceptance criteria

- Given an existing repository, when `xaden adopt` runs, then it first reads the repository without changing any file and reports stack, test runner, linters, type checker, CI system, hook manager, commit convention, existing `AGENTS.md`, `CLAUDE.md` and `.claude/`.
- Given the findings, then `xaden adopt` prints the exact diff and the list of files that would be created or touched, and ends with one question (`Apply this plan on a new branch? [y/N]`, default no); nothing is written before a yes.
- Given `xaden adopt --dry-run`, then it stops after the plan, even in a terminal, and writes nothing.
- Given no terminal (script, CI, assistant), when `xaden adopt` runs, then it stops after the plan, writes nothing and prints `xaden adopt --yes` as the command that applies it.
- Given the read finds rules in an existing `AGENTS.md` or `CLAUDE.md` that contradict `xaden/RULES.md`, then it lists each contradiction with file and line and leaves the decision to a human.
- Given a tool or setup it cannot recognise, then it says so and asks; it never guesses a command.
