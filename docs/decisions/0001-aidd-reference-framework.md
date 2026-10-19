# 0001. The AIDD reference framework: take no code, take ideas one at a time

- Status: proposed
- Date: 2026-10-19
- Requirements: REQ-115

## Context

Xaden aligns with the AI-Driven Development Manifesto (REQ-116, REQ-117). The manifesto's authors publish
a reference implementation, [`ai-driven-dev/framework`](https://github.com/ai-driven-dev/framework).
Before Xaden takes anything from it (`template/AGENTS.md` §9, "Look before you build"), this record
weighs it. Facts below come from the GitHub API and the repository files named, read on 2026-10-19.

| | |
|---|---|
| Name | AI-Driven Dev Framework |
| Summary | "Marketplace framework": plugins with skills, agents, commands, hooks and MCP configs that install an SDLC (frame, plan, implement, validate, review, ship) into an AI coding tool |
| License | MIT, "Copyright (c) 2026 AI-Driven Dev contributors" |
| Website | https://www.ai-driven-dev.fr/ |
| Maturity | Created 2026-02-06; last push 2026-10-19; release v5.12.0 (2026-10-16); 521 stars, 57 forks, 88 open issues, 13 contributors (API count), not archived |
| Tools | Claude Code native; Cursor, Copilot, Codex, OpenCode, Kilo Code through a CLI or flat files; Gemini and Mistral in progress |
| Needs | Node 22 or later for the plugins that ship hooks (`aidd-context`, `aidd-telemetry`) |

**Read:** `README.md`, `LICENSE`, `GOVERNANCE.md`, `THIRD_PARTY_LICENSES.md`, `docs/ARCHITECTURE.md`.
**Not read:** the contents of the 51 skills, the 2 agents, the CLI source, `ROADMAP.md`, `docs/FAQ.md`.
A judgment on a skill's quality is therefore out of reach of this record.

## What overlaps with Xaden

- The same cycle: spec or story, plan, implement, validate, review, ship, with human approval at the end.
- Rules and skills as files in the repository, one set for several assistants.
- Hooks as deterministic programs at lifecycle events (Xaden: git hooks and `xaden hook`).
- Project memory kept in files (`aidd-context` refreshes a memory block in the assistant's context files).

## What Xaden lacks

- An orchestrating skill that runs the whole cycle from one command (see the epic-loop idea in `inbox/2026-10-18-draft-right-sized-process.md`).
- Token telemetry per task (`aidd-telemetry`); Xaden has `xaden context`, which only reports size.
- A CLI that translates one set of capabilities into the layouts of many tools beyond slash commands.

## What conflicts

- **Node 22 for hooks.** Xaden's prerequisites are bash and standard tools (`GETTING-STARTED.md`); adding Node for hooks changes that for every user.
- **Plugin marketplace as the install path.** It is native to Claude Code. Xaden promises files any assistant reads (REQ-045, tool-agnostic), and local models.
- **Enforcement versus workflow.** The framework is a delivery workflow; Xaden is a rule and check layer (ID checks, signed releases). Merging the two would blur both.
- **Governance tied to a commercial programme.** Its tiers (Core Team, Certified Members, Maintainer) come from paid training and certification at ai-driven-dev.fr. Xaden has no such tier and must not suggest one (REQ-116: "implements", never "certified").

## Attribution

MIT requires the copyright and licence notice with any copied code or text. Nothing is copied, so nothing
is owed today. The framework is also not installed or recommended by Xaden, so it needs no line in
`THIRD-PARTY.md` (REQ-113). If an item is adopted later, that requirement adds the notice and the line.
The logo and the name "AIDD" for products are not used: no trademark statement was found in the files
read, and that is not a permission.

## Decision

1. Add no dependency on the framework and copy none of its files.
2. Do not recommend it in `template/docs/optional-tools.md` until someone has used it on a real project and reported what they found.
3. Take ideas only through a requirement of their own, one per idea, each with its source named. Candidates, none decided:
   - a one-command cycle (links to the right-sized-process draft);
   - a hook that refreshes the memory block (links to the small-context draft and principle 06);
   - per-task token reporting.
4. Revisit when the framework publishes a tool-neutral, dependency-free core, or when a user asks for it.

## Consequences

- Positive: no new dependency, licence duty or Node requirement; the tool-agnostic promise holds.
- Negative: Xaden does not use a ready-made orchestration; it may build a smaller one later.
- Follow-up: this record stays `proposed` until the maintainer approves it. Until then nothing in the list above starts.
