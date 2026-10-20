---
id: REQ-080
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-17
---

# Claude Code users start Xaden workflows with slash commands in an adopted repository

## Job

When I work in Claude Code in a repository that adopted Xaden, I want to type `/feature` or `/bugfix` like in a project made by `xaden create --classic`, so I can start a workflow without remembering and typing `xaden prompt <name>` each time.

## Acceptance criteria

- Given `xaden adopt` with Claude among the assistants, then `.claude/commands/` gets one command file for each default prompt: `kickoff`, `feature`, `bugfix`, `refactor`, `review` (code-review), `security` (security-review), `requirements` (requirements-update), `docs` (documentation), `persona` and `release`.
- Given such a command file, then it holds only the line ``Run `xaden prompt <name>` and follow it. Task input: $ARGUMENTS`` and a one-line description; it never includes the prompt text itself.
- Given a team prompt in `xaden/prompts/<name>.md`, when I run the slash command, then the team version is used, because the command calls `xaden prompt`.
- Given a file `.claude/commands/<name>.md` that already exists in the repository, then adopt does not overwrite it, the plan names it as skipped, and the footprint does not list it.
- Given the plan (`xaden adopt --plan`), then it lists every command file to be created, and `xaden/footprint.txt` records them.
- Given `xaden remove`, then exactly the command files Xaden created are removed and the others stay.
- Given an adoption without Claude among the assistants, then no `.claude/commands/` file is created.
- Given `xaden upgrade`, then the command files follow the new prompt list: new ones are added, and the files Xaden created for a prompt that no longer exists are removed.
- Given the smoke tests, then a test adopts a scratch repository and checks the files above, including the skip and the removal.

Superseded in part by REQ-087: the command names carry the `xaden-` prefix.
