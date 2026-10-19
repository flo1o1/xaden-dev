---
id: REQ-123
type: job
epic: assistant-guidance
priority: must
status: done
updated: 2026-10-19
---

# A small change takes a short path and a large change takes the full one

## Job

When I make a small, clear change, I want the assistant to skip planning steps that add nothing, so I can finish quickly without giving up traceability or checks (AIDD manifesto P03, P04).

## Acceptance criteria

- Given a change request, when the assistant starts, then it states the size (small, normal or large) and the reason in one line, and I can overrule it; the size is a proposal and never a silent decision (approval point)
- Given a small change (one approved requirement covers it, at most 2 files, no new dependency, no new input, auth, data, files or network surface), then the assistant skips the new-requirement draft, the library search, the plan with the persona check and the security review, and keeps test-first, `scripts/check.sh`, the `Refs: REQ-nnn` trailer, the changelog bullet, the guide update of `template/AGENTS.md` §8 and a quick review of the diff (`/xaden-review`)
- Given a normal change, then the flow is the one of today, unchanged
- Given a large change (new structure, a new dependency, or more than one epic), then the plan is written to `docs/architecture.md` and split into steps that each are a normal change
- Given a change that starts small and then touches a third file, adds a dependency, or touches input, auth, data, files or network, then the assistant stops, says the size changed and switches to the normal flow
- Given a request with two or more independently shippable goals, then the assistant lists them, recommends a first one and asks whether to split or keep all; I decide
- Given the prompts feature, bugfix and refactor, then each names the small path by pointing to one size table and does not copy it
- Given `fix` commits, then the rule is unchanged (`Refs: REQ-nnn` or `Refs: none`), and `scripts/verify-refs.sh` and the hooks are unchanged: the size is guidance for the assistant and not a new check, so there is nothing to bypass
- Given an adopted project, then it carries the size table the same way it carries the other rules of this epic
- Given the smoke test (area `assistant-guidance`), then it finds the size table, finds the pointer in each of the three prompts, and fails if the small path drops a step that a hook enforces

## Notes

Origin: the feature prompt has nine steps for every feature, the same ceremony for a one-line change as for a new subsystem. Heavy flow on small work teaches people to skip the flow. Row P04 of the AIDD mapping table says "no rule sizes the task, planned"; when this is done, update that row (`docs/guide/developer/xaden-and-the-aidd-manifesto.md`, checked by `scripts/check-aidd-mapping.sh`).

The thresholds (2 files, no new surface) are not measured yet. They match the approval point that step 3 of the feature prompt already has (a plan that touches more than 2 files or adds a dependency). Collect a few real sessions before changing them.

Where the one size table lives (a section of `template/AGENTS.md` or a prompt, linked) is decided at implementation; REQ-111 caps its own section at 1 KB and the always-loaded size is a live question (see the draft on a small context).

Idea source: BMAD-METHOD, skill `bmad-build`, which picks a route by a prompt rule that nothing enforces. Xaden takes the idea of sizing, not code, and measures by files and risk surface, which can be checked afterwards; a line count cannot be known in advance. Personas as agent roles are out of scope: Xaden already checks plans against `docs/personas/`.
