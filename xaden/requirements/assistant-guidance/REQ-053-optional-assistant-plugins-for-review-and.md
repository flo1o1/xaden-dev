---
id: REQ-053
type: job
epic: assistant-guidance
priority: could
status: done
updated: 2026-10-11
---

# Optional assistant plugins for review and security are documented in every project

## Job

When I use Claude Code on a project, I want to know which public plugins add deeper code review and security analysis and which ones clash with this workflow, so I can extend my assistant without breaking the project rules.

## Acceptance criteria

- Given a generated project, when I read `docs/optional-tools.md`, then it lists the Trail of Bits plugins and Anthropic's official `code-review` and `security-guidance` plugins with install commands, says they are optional, and says AGENTS.md takes precedence (§10).
- Given a workflow framework that replaces this project's workflow, when the document mentions it, then it is listed as not recommended, with the reason.
- Given `scripts/setup.sh` on a machine with the `claude` command, when it runs, then it points to `docs/optional-tools.md`.
- Given a new project, when it is generated, then no plugin is installed or enabled.
- Given the Claude Code `/review` command, when it finishes, then it offers `/ponytail-review` as an optional second pass only if Ponytail is installed, and the project prompt, rule IDs and completion report take precedence.
