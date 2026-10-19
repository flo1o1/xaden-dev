---
id: REQ-127
type: job
epic: assistant-guidance
priority: must
status: approved
updated: 2026-10-19
---

# Assistants load only the requirements and conventions that touch the code they change

## Job

When I work on one part of a large project, I want the assistant to find the requirements and conventions for the files it changes without reading everything, so I can keep sessions fast and cheap as the project grows (AIDD manifesto P05).

## Acceptance criteria

- Given a requirement whose front matter has the optional line `paths:` (files, directories or globs, separated by commas), when I run `scripts/req.sh for <path>...`, then it prints the matching requirements (ID, status, title); a requirement without `paths:` never matches
- Given `scripts/req.sh find <words>`, then it lists the requirements whose title or text contain all the words, one line each, and never prints a whole file
- Given the session start in `AGENTS.md`, then it tells the assistant to run `scripts/req.sh for` on the files it plans to change, next to the index
- Given a directory with its own `AGENTS.md` (purpose, conventions, public API, where the tests are), then the assistant reads that file when it works there, and a `CLAUDE.md` next to it holding `@AGENTS.md` lets Claude Code load it
- Given a `paths:` entry that matches no file or directory of the repository, then `scripts/check-requirements.sh` warns and names the requirement, because a stale entry hides a requirement; the warning does not fail the check
- Given `scripts/req.sh new`, then it leaves `paths:` out
- Given `xaden adopt` on an existing repository, then it adds no scoped notes; the team writes them, one directory at a time
- Given the user guide, then it documents `paths:`, `req.sh for`, `req.sh find` and scoped notes
- Given the smoke test, then it covers matching by file, by directory and by glob, a requirement without `paths:`, `req.sh find` and the stale-entry warning

## Notes

Depends on REQ-123, merged on `main` on 2026-10-19, and shares the goal of REQ-126, which keeps the always-loaded files small; this one finds the rest by location.

Checked against the code on 2026-10-19: unknown front-matter keys are stored and ignored by `scripts/check-requirements.sh` (the draft in the inbox assumed they fail), so `paths:` needs no change to the validator except the stale-entry warning. The format is one line with commas, parsed with awk like the other keys, no YAML list.

Out of scope: a generated code map (ctags or tree-sitter symbols) and an MCP query layer over the files; both add tooling and need a decision of their own.
