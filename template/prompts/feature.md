---
title: Build a feature
type: prompt
status: stable
version: 1.6.0
works-with: [claude-code, chatgpt, local-llm]
tags: [prompt, development]
---

# Build a feature

## Goal
Implement one capability, test-first, tracked in requirements.

## Inputs
- Feature: {{what the user can do afterwards}}
- Related requirement: {{REQ-nnn or "new"}}

## Steps
1. Run `scripts/context-status.sh`; read `AGENTS.md` and `docs/requirements/INDEX.md`. Look
   requirements up with `scripts/req.sh show REQ-nnn`; never from memory.
   Then state the size as AGENTS.md §9 (Size the task) says; on a small change skip the steps it names
   (the requirement draft, the library search, the plan and persona check, the security review).
2. If the feature has no `REQ-nnn`, draft one as a job in the chat (*When …, I want to …, so I can …*,
   with acceptance criteria). **Approval point:** show me the draft; create no branch, worktree or file
   before my OK. After my OK, start the change as AGENTS.md §7 says (sparse worktree), create the
   requirement there with `scripts/req.sh new <epic> job "<title>"` as `approved`, commit it first, then
   set it to `in-progress` and widen the checkout.
   If it conflicts with an existing requirement, stop and ask me.
3. Look before you build (AGENTS.md §9): if a mature library, service or platform feature
   could cover the feature, list the candidates (name, summary, license, website, maturity).
   **Approval point** if I pick one. Then plan in at most 5 small steps, placing code as `docs/architecture.md` → "Rules for new code"
   says; if the feature changes the structure, update that file in the same change.
   Check the plan against every persona in `docs/personas/` (AGENTS.md §9); name any it fails.
   **Approval point** if the plan touches more than 2 files or adds a dependency.
4. If the code is hard to change for this feature, refactor first ([[refactor]], separate
   commit, tests green). Otherwise leave unrelated code alone (CC-09).
5. For each step: write a failing test that cites the `REQ-nnn`, make it pass, refactor
   (Red → Green → Refactor). Validate all external input at the boundary (CC-07); make errors
   explicit (CC-05). Details and examples for the CC rules: `docs/clean-code.md`.
6. Run `scripts/check.sh`; fix all findings.
7. If the feature touches input, auth, data, files, network or dependencies: run the
   [[security-review]] prompt on the changed files.
8. Update `docs/user-guide.md` (usage) and, if config/ports/dependencies/deployment changed,
   `docs/admin-guide.md` — see [[documentation]].
9. Set requirement status to `done`, add a `CHANGELOG.md` → Unreleased bullet, commit
   `feat(<scope>): <summary>` with the trailer `Refs: REQ-nnn` (the hook rejects unknown IDs).

## Done when
- [ ] Acceptance criteria met and tested
- [ ] `scripts/check.sh` passes
- [ ] Requirements, changelog, docs, security review handled
- [ ] Completion report given (AGENTS.md §5): checks run, checks skipped, unresolved findings, acceptance evidence
- [ ] Explained and handed over as AGENTS.md §9 (Judgment stays with the human) says
