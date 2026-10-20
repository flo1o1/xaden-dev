---
id: REQ-051
type: job
epic: quality-gates
priority: should
status: done
updated: 2026-10-11
---

# Optional quality tools are suggested when the project would benefit and run once adopted

## Job

When my project uses a language or CI setup for which extra checks exist (dead code, duplication, workflow security, mutation and property-based testing), I want to be told which ones fit and how to adopt them, and have them run once I adopt them, so I can harden the code step by step without installing tools I do not need.

## Acceptance criteria

- Given a Python project without dead-code configuration, when `scripts/check.sh` runs in full mode, then it prints a `TIP:` line for vulture, and the run's result does not change.
- Given a Python project with `[tool.vulture]` in `pyproject.toml`, when the full check runs and vulture reports dead code, then the check fails.
- Given a Node project without a `deadcode` npm script, when the full check runs, then it prints a `TIP:` line for knip.
- Given a project with `.jscpd.json`, when the full check runs and jscpd fails, then the check fails.
- Given GitHub workflow files and actionlint or zizmor installed, when the check runs, then they lint the workflows and findings fail the check; when they are missing, a `TIP:` line names them.
- Given Python or Node, when no mutation-testing or property-testing library is declared, then the full check prints a `TIP:` line for each; neither is run by the check.
- Given the staged (pre-commit) mode, when it runs, then it prints no tips.
- Given AGENTS.md, when an assistant sees `TIP:` lines, then it mentions them to the user once and installs nothing without approval.
- `docs/optional-tools.md` lists each tool, when it helps, and how to adopt it.
