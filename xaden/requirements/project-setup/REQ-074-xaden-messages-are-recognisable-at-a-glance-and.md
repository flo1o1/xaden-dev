---
id: REQ-074
type: quality
epic: project-setup
priority: could
status: done
updated: 2026-10-14
---

# Xaden messages are recognisable at a glance and readable in plain logs

## Quality goal

Every message that Xaden prints is one of four kinds, each marked the same way, and every message stays understandable when only plain text is available.

## Acceptance criteria

- Given a question that waits for an answer, then it starts with 🐉, is the last line after a separator line, and shows the default answer (`[y/N]`).
- Given a warning (the run continues), then it starts with ⚠️ and goes to stderr; given an error (the run stops with a non-zero exit), then it starts with 🔥 and goes to stderr; given a verified success, then it starts with ✅.
- Given `XADEN_PLAIN=1`, `CI` set, output that is not a terminal, or a locale without UTF-8, then the signs are replaced by `[?]`, `WARNING:`, `ERROR:` and `OK:` and the text is otherwise identical.
- Given any script, then messages go through shared helpers; a test fails when a script prints a sign or a prompt by hand.
- Given a run with skipped checks, then it ends with a warning, never a ✅ (AGENTS.md §5).
- Given facts in a message (versions, URLs, checksums, commands), then the voice never rephrases them; security and data-loss messages carry no jokes.
