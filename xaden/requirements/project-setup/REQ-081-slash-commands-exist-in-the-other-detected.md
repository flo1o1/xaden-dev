---
id: REQ-081
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-17
---

# Slash commands exist in the other detected assistants too

## Job

When my team uses GitHub Copilot, Mistral Vibe or Codex CLI in a repository that adopted Xaden, I want the same shortcuts for the Xaden workflows as Claude Code users have under REQ-080, so I can start a workflow without remembering and typing `xaden prompt <name>`.

## Acceptance criteria

- Given `xaden adopt`, then it detects each supported assistant by a file or folder of its own and offers only the detected ones, which I confirm or change with `--assistants`.
- Given GitHub Copilot among the assistants, then `.github/prompts/<name>.prompt.md` exists for each default prompt of REQ-080, with a description and the line `Run `xaden prompt <name>` and follow it.` plus the task input in Copilot's input syntax.
- Given Mistral Vibe among the assistants, then `.agents/skills/<name>/SKILL.md` exists for each default prompt, marked user-invocable, with the same instruction line and no prompt text.
- Given Codex CLI among the assistants, then the commands or skills Codex documents as invocable by name exist for each default prompt with the same instruction line; where Codex has no such mechanism, adopt says so and creates nothing.
- Given any generated file, then it never contains the prompt text itself, so a team prompt in `xaden/prompts/` is used by every assistant.
- Given a file of the same name that already exists, then adopt does not overwrite it, the plan names it as skipped, and the footprint does not list it.
- Given the plan, `xaden/footprint.txt`, `xaden remove` and `xaden upgrade`, then they handle these files exactly as REQ-080 does for the Claude files.
- Given the smoke tests, then a test adopts a scratch repository once per supported assistant and checks the files, the skip and the removal.

Superseded in part by REQ-087: the command names carry the `xaden-` prefix.
