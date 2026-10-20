---
id: REQ-087
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-17
---

# Xaden's slash commands carry the xaden- prefix

## Job

When I use Xaden in an assistant next to other tools that bring their own commands, I want every Xaden command to start with `xaden-`, so I can tell at a glance which commands are Xaden's and avoid name clashes.

## Acceptance criteria

- Given the default prompts, then each generated command is named `xaden-<name>`: `xaden-kickoff`, `xaden-feature`, `xaden-bugfix`, `xaden-refactor`, `xaden-review`, `xaden-security`, `xaden-requirements`, `xaden-persona`, `xaden-release`, `xaden-docs`; the mapping from prompt to name (REQ-080) stays and only the prefix is new
- Given each assistant layout, then the files carry the prefix: `.claude/commands/xaden-<name>.md`, `.github/prompts/xaden-<name>.prompt.md` and `.agents/skills/xaden-<name>/SKILL.md` (with `name: xaden-<name>`), and the command files of a project made by `xaden create --classic` (`.claude/commands/xaden-<name>.md` from the template)
- Given a command file, then the line `Run `xaden prompt <name>` and follow it` inside it is unchanged, because the prompt keeps its name
- Given a project whose footprint lists the old unprefixed files that Xaden created, when I run `xaden upgrade` or `xaden update`, then those files are removed and the prefixed ones are created, and a file of the same name that Xaden did not create stays
- Given `xaden adopt --plan`, `xaden/footprint.txt` and `xaden remove`, then they list and remove the prefixed files exactly as REQ-080 describes for the old names
- Given the Xaden repository itself, then its maintainer commands (REQ-055) are named `xaden-bugfix`, `xaden-refactor`, `xaden-review` and `xaden-security`
- Given the guides, `template/CLAUDE.md`, the prompt index and the README, then they name the new commands and no longer name the old ones
- Given the smoke tests, then they check the prefixed files for every assistant layout, the rename on upgrade including the kept foreign file, and the removal

Breaking: the old command names (`/feature`, `/bugfix`, ...) stop working after the next upgrade. REQ-080 and REQ-081 describe the files by their old names; this requirement replaces those names.
