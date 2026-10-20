---
id: REQ-119
type: job
epic: assistant-guidance
priority: should
status: done
updated: 2026-10-19
---

# The assistant fixes scope, names, tests and context before it retries

## Job

When the assistant's output gets worse, I want to see the assistant fix the system around the task before it asks again or pushes harder, so I can stop wasting sessions on retries (AIDD manifesto P09).

## Acceptance criteria

- Given a second attempt at the same problem, then `template/AGENTS.md` (the section "Judgment stays with the human", REQ-111) tells the assistant to name which of scope, names, tests or context it will change before it tries again
- Given the assistant changed one of them, then it says which and why in its reply, in one line
- Given the rule, then it extends the stop-and-report step of REQ-111 and does not repeat it
- Given a generated project and an adopted one, then both carry the rule, because it lives in `template/AGENTS.md`
- Given the smoke test, then it finds the rule in the rules file and in a project made from it
