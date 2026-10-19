---
title: Refactor
type: prompt
status: stable
version: 1.3.0
works-with: [claude-code, chatgpt, local-llm]
tags: [prompt, development, clean-code]
---

# Refactor

## Goal
Improve structure without changing behaviour.

## Inputs
- Target: {{files / module}}
- Pain: {{what is hard to read or change}}

## Steps
1. Read `AGENTS.md` and `docs/clean-code.md`.
   Then state the size as AGENTS.md §9 (Size the task) says; on a small change skip the steps it names.
2. Ensure tests cover current behaviour; add characterization tests if missing. Run them: green.
3. List the smells found (name each: duplication, long method, god class, …) with file:line,
   and why fixing each one helps (CC-09). **Approval point:** show the list and the steps.
4. Fix one smell per step; tests green after every step. Keep the project runnable.
5. Run `scripts/check.sh`.
6. Commit `refactor(<scope>): <summary>`. No behaviour change → no requirement change.

## Done when
- [ ] Behaviour unchanged (tests identical or only added)
- [ ] Smell list resolved or consciously deferred (note in commit body)
- [ ] Completion report given (AGENTS.md §5): checks run, checks skipped, unresolved findings, acceptance evidence
- [ ] Explained and handed over as AGENTS.md §9 (Judgment stays with the human) says
