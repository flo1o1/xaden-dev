---
title: Prompt index
type: index
tags: [prompts, index]
---

# Prompt library

Open this repository folder as an **Obsidian vault**; review and edit prompts here.
Every prompt has frontmatter (`status`, `version`, `works-with`) visible in Obsidian's Properties panel.

| Prompt | Use when | Claude Code |
|--------|----------|-------------|
| [[kickoff]] | New project: capture goals, requirements, stack | `/xaden-kickoff` |
| [[persona]] | Add a user persona that solutions are checked against | `/xaden-persona` |
| [[feature]] | Build a new capability | `/xaden-feature` |
| [[epic]] | Build all approved requirements of one epic in order | `/xaden-epic` |
| [[bugfix]] | Fix a defect | `/xaden-bugfix` |
| [[refactor]] | Improve structure, same behaviour | `/xaden-refactor` |
| [[requirements-update]] | Scope changed mid-session | `/xaden-requirements` |
| [[code-review]] | Review a diff against clean-code rules | `/xaden-review` |
| [[security-review]] | Security audit (OWASP WSTG based) | `/xaden-security` |
| [[documentation]] | Write/update user and admin guides | `/xaden-docs` |
| [[release]] | Cut a SemVer release | `/xaden-release` |

Related: [[prompt-template]] · rules in `AGENTS.md` · requirements in `docs/requirements/INDEX.md`

## How to use with each tool

- **Claude Code**: slash command above; it loads `AGENTS.md` through `CLAUDE.md`.
- **Aider / Cline / Continue / Cursor / Codex**: they read `AGENTS.md` (Aider via `.aider.conf.yml`);
  paste or reference the prompt file.

## Conventions

- One prompt = one job. Keep each under ~60 lines so small models cope.
- Variables are written `{{like_this}}`; fill them before sending.
- Bump `version` when you change the wording; set `status: draft | stable`.
