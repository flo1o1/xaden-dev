---
id: REQ-070
type: job
epic: project-setup
priority: must
status: done
updated: 2026-10-14
---

# Team content lives visibly in the repository, tooling stays pinned outside it

## Job

When my team shares a repository, I want to keep requirements, personas and reviews in a visible folder as plain Markdown and the Xaden tooling outside the repository, so I can review our decisions, hide nothing, and use any editor.

## Acceptance criteria

- Given an adopted repository, then the team content is in a visible `xaden/` directory (`requirements/`, `personas/`, `security-reviews/`, optional `prompts/`, `baselines/`, `xaden.conf`) as plain Markdown and one config file, with no editor-specific files.
- Given the tooling (scripts, default prompts, presets), then it lives in the installed Xaden and is selected by the version pinned in `xaden/xaden.conf`; none of it is copied into the repository.
- Given `xaden/RULES.md`, then it is generated from the pinned version, marked "generated, do not edit", and `AGENTS.md` contains only a short marked block that points to it.
- Given text in `AGENTS.md` outside the marked block, then Xaden never changes it.
- Given a team prompt of the same name in `xaden/prompts/`, then it overrides the default prompt from the installed version.
