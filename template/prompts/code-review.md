---
title: Code review
type: prompt
status: stable
version: 1.3.0
works-with: [claude-code, chatgpt, local-llm]
tags: [prompt, review, clean-code]
---

# Code review

## Goal
Review the change against clean-code rules and requirements. Report, do not rewrite.

## Inputs
- Scope: {{diff, branch, or files}}

## Steps
1. Read `AGENTS.md`, `docs/clean-code.md`, `docs/architecture.md`, requirements.
2. Check: does the change satisfy its `REQ-nnn` and nothing more? Layering and dependency
   direction as in `docs/architecture.md`, naming, function size, SRP, duplication, error
   handling, input validation, tests (FIRST), comments. For user-facing changes: does it fail
   a persona in `docs/personas/` (AGENTS.md §9)? Name the persona and the red flag.
3. Output one line per finding: `file:line — severity (high|medium|low) — CC-nn — problem — fix`.
   Cite only rule IDs that exist in `AGENTS.md` section 3.
   Skip style nits a formatter handles.
4. For a finding that is not fixed in this change, offer the three routes of AGENTS.md §9 (Findings not fixed now): fix now, ask me, or defer.
5. End with a verdict: approve / changes requested, and the single most important fix.

## Done when
- [ ] Every finding has a location and a concrete fix
