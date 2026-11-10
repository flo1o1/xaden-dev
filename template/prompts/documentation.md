---
title: Write documentation
type: prompt
status: stable
version: 1.1.0
works-with: [claude-code, chatgpt, local-llm]
tags: [prompt, documentation]
---

# Write documentation

## Goal
Keep `docs/user-guide.md` (end users) and `docs/admin-guide.md` (operators) complete and true
to the code: installation, system requirements, configuration, usage, security, upgrade.

## Inputs
- Scope: {{"all" or the REQ-nnn / feature that changed}}

## Steps
1. Read `AGENTS.md`, `docs/requirements/INDEX.md`, both guides, `README.md`, `.env.example`,
   dependency files (`pyproject.toml`, `package.json`, `requirements*.txt`, Dockerfile, CI config).
2. Replace every `<!-- TODO: ... -->` marker in the scope with real content. Remove the marker.
   Keep all `##` headings; `scripts/check-docs.sh` requires them.
3. System requirements: derive from facts (runtime versions in dependency files, ports in code,
   external services, OS-specific code). Where a fact is unknown, **ask me**; never invent numbers.
4. Installation: write commands you could verify. If you cannot run them, say "untested" in the text.
5. Configuration (admin): one table row per setting read by the code, matching `.env.example`.
   Never write real secrets.
6. Usage (user): one subsection per `done` job, written for its situation and outcome, with
   an example.
7. Admin security section: summarize `docs/security.md` as concrete setup steps and note
   the date of the last security review. Fill the TODO markers in `SECURITY.md` (supported
   versions, contact, secrets list, incident roles); ask me for contacts and promises.
8. Operations (admin), where the software runs as a service or calls other systems: document
   timeouts, bounded retries with backoff, cancellation and graceful shutdown, health checks,
   what logs contain (no secrets or personal data), database migrations with a rollback path,
   and backups with a restore that was actually tested. Describe only what the code does; if
   something is missing, say so and propose a requirement instead of documenting it.
9. Update `**Applies to version:**` only through `scripts/release.sh` (it stamps it).
10. Run `scripts/check-docs.sh` (add `--release` to find leftover TODOs). It checks structure
    only; report which documented commands you ran and which are "untested". Add a
    `CHANGELOG.md` → Unreleased bullet (or a `changelog.d/` fragment, see `docs/rules/git.md`) only for user-visible doc changes.
11. Commit `docs: <summary>`.

## Done when
- [ ] No TODO markers in scope; headings intact
- [ ] Every setting, port and dependency in the code appears in the guides
- [ ] Unknown facts were asked, not guessed
- [ ] Completion report given (AGENTS.md §5): checks run, checks skipped, unresolved findings, acceptance evidence
