---
id: REQ-111
type: job
epic: assistant-guidance
priority: must
status: approved
updated: 2026-10-18
---

# The assistant explains what it did and says what it cannot judge

## Job

When an assistant proposes or finishes a change, I want it to explain what it did and say what it cannot judge, so I can understand what I accept and never accept code, or a judgment, that nobody can evaluate.

## Acceptance criteria

- Given a non-trivial change, then the assistant explains what changed and why, and names one way for the person to check it (a test, a command or a place to read), before it asks for acceptance
- Given a task whose result the assistant cannot evaluate itself (security, law, hardware, a domain it has no source for), then it says so and asks the person, instead of delivering a judgment as fact
- Given an attempt that fails twice on the same problem, then the assistant stops and reports; before a third attempt it inspects the scope, the context, its assumptions and the tests, and does not just retry harder
- Given a decision or a lesson that future work needs, then the assistant proposes an entry in `docs/decisions/` and writes it only after the person approves
- Given `template/AGENTS.md`, then these rules are one section of at most 1 KB, and the prompts feature, bugfix and refactor point to it by number and do not copy it
- Given an adopted project, then the section is part of the rendered `xaden/RULES.md`
- Given the smoke test, then the section and the three prompt pointers are present, the section is no longer than 1 KB, and the rendered rules of an adopted project contain it
