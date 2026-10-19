---
id: REQ-115
type: job
epic: assistant-guidance
priority: should
status: done
updated: 2026-10-19
---

# Xaden weighs the AIDD reference framework before it takes anything from it

## Job

When Xaden wants to align with the AI-Driven Development Manifesto, I want the reference framework `ai-driven-dev/framework` assessed first, so I can decide what to take on facts and not on the name.

## Acceptance criteria

- Given the assessment, then it follows `template/AGENTS.md` §9 "Look before you build": name, one-line summary, license, website and maturity (maintenance, adoption), and it is checked against the source, not written from memory
- Given the assessment, then it lists what overlaps with Xaden, what Xaden lacks and what conflicts with REQ-045 (keep the scaffold generic) or with the tool-agnostic promise
- Given the framework carries a license with attribution duties, then the assessment names them and says where Xaden would have to credit it (REQ-113)
- Given the assessment is finished, then it is a decision record in `docs/decisions/` with the status `proposed`; it becomes `accepted` only after the person approves it
- Given the decision is not yet approved, then nothing from the framework is copied, vendored or added as a dependency
- Given the person approves adopting an item, then it becomes a requirement of its own, one for each item; this requirement ends with the decision record
