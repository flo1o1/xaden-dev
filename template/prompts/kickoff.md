---
title: Project kickoff
type: prompt
status: stable
version: 1.2.0
works-with: [claude-code, chatgpt, local-llm]
tags: [prompt, planning]
---

# Project kickoff

## Goal
Turn my idea into tracked requirements, a stack decision, and a first runnable skeleton.

## Inputs
- Idea: {{describe what you want to build, who uses it, what "done" looks like}}

## Steps
1. Read `AGENTS.md`. Do not write code yet.
2. Ask me up to 7 questions that block decisions: users, platform, data, constraints,
   language/stack preference, hosting, security/privacy needs. Wait for answers.
3. Draft 3 to 5 user personas from my answers ([[persona]]; `scripts/persona.sh new "<name>"`),
   marking facts I did not give "(assumption)". Find the jobs my users hire the software for:
   group them into epics (topic folders under `docs/requirements/`, each with an `EPIC.md`
   goal) and write one file per job with `scripts/req.sh new <epic> job "<title>"`: *When
   <situation>, I want to <motivation>, so I can <expected outcome>*, plus Given/When/Then
   acceptance criteria. Add measurable quality goals (`type: quality`) for performance,
   security or compliance needs. Rewrite the placeholder REQ-001 as the first job and rename
   `first-epic` (folder and `epic:`) to its topic. Keep everything `draft`; run
   `scripts/req.sh index` and `scripts/check-requirements.sh`. **Approval point:** show me
   the personas, `docs/requirements/INDEX.md` and the job stories; set the ones I approve to
   `approved`.
4. Fill `docs/threat-model.md` from my answers: assets, sensitive data, entry points, trust
   boundaries, attackers, deployment assumptions. Propose an OWASP ASVS level with a one-line
   reason. Write "unknown" and ask me where you lack facts; never invent them.
5. Propose a stack with 2 alternatives and a one-line trade-off each. **Approval point:**
   wait for my choice.
6. Record the decision in `docs/decisions/0001-stack.md` (copy `docs/decisions/0000-template.md`).
   Fill `docs/architecture.md` for the chosen stack: layers, composition root, naming, rules for
   new code. Keep it as small as the project.
7. Create the minimal skeleton: source dir, one test, dependency file. Run
   `xaden project preset python|node` for the clean-code linter config (other stacks: create
   an equivalent config mapping CC-01…CC-08, see `docs/clean-code.md`). **Approval point**
   before installing the tools it lists. Keep it runnable. Run `scripts/check.sh`.
8. Update `README.md` (what it is, how to run, how to test) and `CHANGELOG.md`.
   Run [[documentation]] to fill installation and system requirements in both guides.
9. Commit: `chore: bootstrap <stack> skeleton`.

## Done when
- [ ] Personas and requirements approved by me
- [ ] Threat model filled; open questions listed
- [ ] Skeleton runs; `scripts/check.sh` passes
- [ ] Decision record, architecture and README written
- [ ] Completion report given (AGENTS.md §5): checks run, checks skipped, unresolved findings, acceptance evidence
