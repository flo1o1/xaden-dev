---
id: REQ-110
type: job
epic: assistant-guidance
priority: must
status: done
updated: 2026-10-18
---

# A human owns and merges every change an assistant prepares

## Job

When an assistant prepares a change for my project, I want to be the one who approves and merges it, so I can stay accountable for everything that ships, whoever wrote it.

## Acceptance criteria

- Given `template/AGENTS.md` section 7, then it says that the assistant opens the pull request and never merges it, by `gh pr merge` or any other route, unless the user tells it to in that session; the user's merge is the approval
- Given a commit an assistant helped with, then the human stays the author; an assistant trailer such as `Co-Authored-By` discloses its part and does not replace the author, and `Signed-off-by` (`git commit -s`) is optional and never required by a Xaden check
- Given `template/.claude/settings.json`, then `gh pr merge` is in the `ask` permissions, so Claude Code asks the person each time; the guide in `template/CLAUDE.md` says that this is a convenience guard with the limits of the deny rules, not a boundary
- Given `AGENTS.md` of the scaffold ("Landing a change on main"), then the merge command is run by the maintainer after both checks are green, not by the assistant
- Given a person who tells the assistant in the current session to merge a named pull request, then it does so once; the rule is not a prohibition of the person's own decision and covers no later pull request
- Given the smoke test, then the rule text is present in `template/AGENTS.md` and the rendered `xaden/RULES.md` of an adopted project, the `ask` entry is valid JSON in a project made by `xaden create`, and the landing section no longer tells the assistant to merge
- Given the developer guide on building features, then it says that the person reviews and merges the pull request and that CI must be green first
