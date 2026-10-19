---
title: Build an approved epic
type: prompt
status: stable
version: 1.0.0
works-with: [claude-code, chatgpt, local-llm]
tags: [prompt, development, planning]
---

# Build an approved epic

## Goal
Work through the approved requirements of one epic in order, check after each, review once at the end.
Each requirement stays a normal change; the loop only saves you from starting each one by hand.

## Inputs
- Epic: {{epic folder under docs/requirements/}}

## Steps
1. Run `scripts/context-status.sh`; read `AGENTS.md` and the requirements of the epic (`scripts/req.sh list`,
   `scripts/req.sh show REQ-nnn`). Skip `done` and `dropped` ones. If one is still `draft`, name it and stop:
   the loop runs only on approved requirements.
2. **Approval point:** show me the requirements in the order you will build them, each with its size
   (AGENTS.md §9, Size the task). Build in ID order unless a requirement says it needs another first. Make no
   change before my go; the go covers the branches, pushes and pull requests of this list.
3. For each requirement, as [[feature]] says: own branch and worktree, test first, `scripts/check.sh` green,
   its own commit with `Refs: REQ-nnn`; never two requirements in one commit. Open its pull request.
4. **Stop** and report, never continue, when a check is red (before a second attempt name which of scope, names,
   tests or context you change, AGENTS.md §9), when the normal flow reaches an approval point I have not given,
   when a change turns out larger than its size (AGENTS.md §9), or when an acceptance criterion is wrong or
   cannot be met. Never edit an approved requirement on your own: show me what is wrong and ask.
5. Never push to `main`. Never merge a pull request unless I tell you in this session to merge that one
   (AGENTS.md §7). If the next requirement needs the previous change on `main`, stop after its pull request.
6. At the end run [[code-review]] once over the whole epic; findings follow AGENTS.md §9 (Findings not fixed now).
7. Give a short retro in the chat: per requirement what was harder than it said and which acceptance criteria
   were wrong. Propose edits to requirements as drafts in the chat only; write nothing.

## Done when
- [ ] Every listed requirement is `done` with its own commit, or the loop stopped and said why
- [ ] No pull request merged without my instruction
- [ ] Review and retro given
- [ ] Completion report given (AGENTS.md §5): checks run, checks skipped, unresolved findings, acceptance evidence
