---
id: REQ-050
type: job
epic: assistant-guidance
priority: should
status: done
updated: 2026-10-13
---

# Optional add-on rule sets such as Ponytail are documented and never override the project rules

## Job

When my AI tool supports add-on rule sets such as Ponytail (leaner code, reuse before writing), I want to know how to install one and how it relates to the project rules, so I can use it without weakening the requirements, checks and reports the scaffold enforces.

## Acceptance criteria

- Given the getting-started guide, when I read the prerequisites, then Ponytail, Caveman, Token Optimizer, claude-mem and obsidian-skills are each one optional row, and the guide points to `docs/optional-tools.md` for install commands, sources, licenses and risks instead of repeating them.
- Given `docs/optional-tools.md`, when I read Ponytail, then it gives the Claude Code install commands and the `AGENTS.md` route for other tools.
- Given a new project, when it is generated, then nothing installs or enables an add-on automatically and no plugin is configured in `.claude/settings.json`.
- Given a generated project's AGENTS.md, when an add-on rule set conflicts with it, then AGENTS.md wins (for example, the completion report replaces a shorter end-of-reply note).
- Given `docs/optional-tools.md`, when I read Caveman, then it gives the install command and source and says that project files (rule files, requirements, guides) stay in normal prose and are never compressed or extended by it.
- Given `docs/optional-tools.md`, when I read Token Optimizer, then it gives the install command and source, states its license (PolyForm Noncommercial with a small-business permission, not open source), warns that compressed tool output must not replace the verbatim failing lines the completion report quotes, and that it keeps full tool output on disk in the home directory (credentials removed by pattern only).
- Given `docs/optional-tools.md`, when I read claude-mem, then it gives the install command and source and warns that it stores sessions in the home directory, that its hosted memory service receives session content, and that injected memories never replace looking up rules and requirements in the files.
- Given `docs/optional-tools.md`, when I read obsidian-skills, then it gives the install command and source and says that Obsidian syntax belongs in `prompts/` only while rule files, requirements and guides stay plain Markdown.
- Given a project with a web UI, when the user reads `docs/optional-tools.md`, then impeccable is listed with its install, its downloaded engine, its edit hook and how to skip it, and its network calls with the telemetry opt-out
