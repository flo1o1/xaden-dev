---
id: REQ-122
type: job
epic: assistant-guidance
priority: should
status: approved
updated: 2026-10-19
---

# Assistants cite a requirement with its epic, title and ID

## Job

When an assistant mentions a requirement, or asks me to approve or decide something about it, I want to see the epic, the title and the ID, so I can look it up and judge it without remembering numbers.

## Acceptance criteria

- Given a reply that mentions a requirement, then it names the epic and the title and gives the ID, for example "requirement REQ-123 'Pause a running export' in the epic 'Exports'"
- Given a question that asks me to approve or decide something about a requirement, then it contains the epic, the title and the ID, never the ID alone
- Given a reply that asks me to check a requirement, then it names the command that shows it (`xaden req show REQ-nnn`)
- Given `template/AGENTS.md`, then the rule is one bullet in section 0 (Grounding), the same text for every assistant
- Given an adopted project, then the bullet is part of the rendered `xaden/RULES.md`
- Given the smoke test, then the bullet is present in `template/AGENTS.md` and in the rendered rules of an adopted project

## Notes

Guidance only: nothing checks an assistant's reply. The completion report already lists `REQ-nnn` and stays as it is. Overlap checked: REQ-011 and REQ-036 are not amended, because this adds a wording rule for citations and no other behaviour.
