# 0001. The AIDD reference framework: an opt-in, pinned add-on for projects

- Status: accepted
- Date: 2026-10-19
- Requirements: REQ-115, REQ-118

## Context

Xaden aligns with the AI-Driven Development Manifesto (REQ-116, REQ-117). The manifesto's authors publish
a reference implementation, [`ai-driven-dev/framework`](https://github.com/ai-driven-dev/framework).
Before Xaden takes anything from it (`template/AGENTS.md` §9, "Look before you build"), this record
weighs it. Facts come from the GitHub API and the repository files named, read on 2026-10-19.

Two scopes need different answers:

- **(a) Maintaining Xaden:** this repository. Bash and standard tools only, one rule set for every assistant.
- **(b) Projects created or adopted with Xaden:** `template/` and `xaden project adopt`. The maintainer wants full
  AI-Driven Development here, wherever the environment supports it.

| | |
|---|---|
| Name | AI-Driven Dev Framework |
| Summary | Plugins with skills, agents, commands, hooks and MCP configs that install an SDLC (frame, plan, implement, validate, review, ship) into an AI coding tool, plus a CLI (`@ai-driven-dev/cli`) that installs them |
| License | MIT, "Copyright (c) 2026 AI-Driven Dev contributors" |
| Website | https://www.ai-driven-dev.fr/ |
| Maturity | Created 2026-02-06; last push 2026-10-19; release v5.12.0 (2026-10-16); 521 stars, 57 forks, 88 open issues, 13 contributors (API count), not archived |
| Tools | Claude Code native; Cursor, Copilot, Codex, OpenCode, Kilo Code through the CLI or flat files; Gemini and Mistral in progress |
| Install | `aidd setup --ai claude --plugins recommended --yes`; `aidd clean` removes what it wrote; `.aidd/manifest.json` hash-tracks every file |
| Needs | CLI: Node 22.12 or later and `git`. Plugins with hooks: Node 22 or later |

**Read:** `README.md`, `LICENSE`, `GOVERNANCE.md`, `THIRD_PARTY_LICENSES.md`, `docs/ARCHITECTURE.md`, `cli/README.md`,
`.claude-plugin/marketplace.json`. **Not read:** the contents of the 51 skills, the 2 agents, the CLI source,
`ROADMAP.md`, `docs/FAQ.md`. A judgment on a skill's quality is out of reach of this record. **Not verified:**
whether the plugins (not only the CLI) can be held to one version; the catalog's plugin sources are relative
paths in the repository, and `aidd plugin update` moves to "the catalog's current version".

## What overlaps with Xaden

- The same cycle: spec or story, plan, implement, validate, review, ship, with human approval at the end.
- Rules and skills as files in the repository, for several assistants.
- Hooks as deterministic programs at lifecycle events.
- Project memory kept in files.

## What the framework adds in (b)

- An orchestrating workflow that runs the whole cycle from one command (Xaden has prompts and rules, not a runner).
- Agents and skills for planning, review, testing and refactoring that follow the manifesto's principles.
- An installer for six assistants with drift detection.

## Where the two meet

Xaden enforces; the framework guides. The maintainer wants them aligned and loosely coupled, and that is
possible when the interface is explicit and written in files:

- Xaden owns the contract: `REQ-nnn` as the spec, `Refs:` trailers, `xaden check` as the validation step, the person merges.
- The framework owns the workflow: skills, agents and orchestration.
- On a conflict between the two rule sources, the project's rules win (`template/AGENTS.md` §10, REQ-050), and the
  add-on states the mapping so a conflict is visible and not decided silently by the assistant.

The risks that remain, and what answers them:

| Risk | Answer |
|------|--------|
| Two rule sources disagree and the assistant picks silently | A marked mapping block in the project's rules file; Xaden's rules win |
| A newer framework release changes behaviour under the project | An exact pinned version; a bump only on request, in a pull request (REQ-118) |
| The plugins cannot be pinned | `enable` refuses to install (REQ-118) |
| Node 22 is missing | Only the add-on needs it; `enable` names it and stops. Xaden's core stays bash-only |
| The framework's name, logo and "certification" belong to a commercial training programme | Xaden credits it as MIT-licensed software, uses no logo, and never says certified (REQ-116) |

## Attribution

MIT requires the copyright and licence notice with any copied code or text. Xaden copies none: the add-on
runs the framework's own installer. Once Xaden recommends and installs it, `THIRD-PARTY.md` lists it with its
link and license (REQ-113), and the guide page names the source. The framework's logo and the name "AIDD" for
products are not used: no trademark statement was found in the files read, and that is not a permission.

## Decision

1. **(a) Maintaining Xaden:** copy nothing from the framework and add no dependency on it. This repository is not a project that runs it.
2. **(b) Projects:** support it as an opt-in add-on, switched on with one command and switched off with one (REQ-118). Xaden installs it through the framework's own CLI and copies none of its files into `template/`.
3. **Pin:** the exact CLI version is recorded in the project and used on every call, never `@latest`. A bump is a pull request on the person's request. If the plugins cannot be held to the pin, the add-on does not install.
4. **Recommend it:** `template/docs/optional-tools.md` lists it, and `THIRD-PARTY.md` credits it, when REQ-118 is implemented.
5. **Ideas from the framework** that Xaden would build itself (a one-command cycle, a memory refresh) each need a requirement of their own, with the source named.

## Consequences

- Positive: full AIDD workflow where the environment supports it; no change to Xaden's bash-only core; the person decides, per project.
- Negative: two rule sources in one project need the mapping block and a clear precedence; the add-on needs Node and `git` and depends on the framework's release cadence (v5.12.0 after eight months); the check that the pin holds adds work.
- Follow-up: REQ-118 is approved and not implemented. Before implementing, verify whether the plugins can be pinned (the first acceptance criterion that fails stops the work). The maintainer accepted this record on 2026-10-19.
