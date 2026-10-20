---
id: REQ-054
type: job
epic: assistant-guidance
priority: should
status: done
updated: 2026-10-11
---

# Assistants look for mature existing solutions before building their own

## Job

When an assistant is about to build something others have probably solved already, I want it to search the web for mature existing solutions and offer them as options with name, summary, license and website, so I can choose a proven solution instead of paying for and maintaining a reinvented wheel.

## Acceptance criteria

- Given AGENTS.md, when an assistant plans non-trivial new code, then it first checks the codebase, the standard library and installed dependencies, then searches the web for mature solutions.
- Given a found candidate, when the assistant presents it, then it states name, one-line summary, license, website and maturity (maintenance, adoption), next to the option of building it.
- Given the user picks a candidate, when it would be added, then the dependency approval point and the registry check in `docs/security.md` apply.
- Given an assistant without web access, when the rule applies, then it says so and marks candidates it names from memory as unverified.
- Given the feature prompt, when an assistant plans a feature, then it applies this rule before planning new code.
