---
title: Fix a bug
type: prompt
status: stable
version: 1.3.0
works-with: [claude-code, chatgpt, local-llm]
tags: [prompt, development]
---

# Fix a bug

## Goal
Fix the root cause, prove it with a regression test.

## Inputs
- Symptom: {{what happens vs. what should happen}}
- Repro: {{steps, input, error text}}

## Steps
1. Read `AGENTS.md` (CC rule details: `docs/clean-code.md`). Find which `REQ-nnn` the correct behaviour belongs to; if none, ask me.
   Then state the size as AGENTS.md §9 (Size the task) says; on a small change skip the steps it names.
2. Reproduce with a failing test. Do not change production code before the test fails for the right reason.
3. Find the root cause (state it in one sentence). No symptom patches. **Approval point** if
   the fix touches more than 2 files, changes a requirement or adds a dependency.
4. Make the smallest change that turns the test green. Refactor afterwards, and only the code
   the fix touched (CC-09).
5. Run `scripts/check.sh`.
6. Commit `fix(<scope>): <summary>` with trailer `Refs: REQ-nnn` (or `Refs: none`); add a `CHANGELOG.md` → Unreleased "Fixed" bullet.
7. If the bug was a security flaw, say so and run [[security-review]].

## Done when
- [ ] Regression test exists and passes
- [ ] `scripts/check.sh` passes
- [ ] Completion report given (AGENTS.md §5): checks run, checks skipped, unresolved findings, acceptance evidence
- [ ] Explained and handed over as AGENTS.md §9 (Judgment stays with the human) says
