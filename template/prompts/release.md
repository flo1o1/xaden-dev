---
title: Release
type: prompt
status: stable
version: 1.3.0
works-with: [claude-code, chatgpt, local-llm]
tags: [prompt, release, semver]
---

# Release

## Goal
Choose the correct SemVer bump and cut the release safely.

## Steps
1. Read `CHANGELOG.md` → Unreleased and `git log` since the last tag.
2. Decide the bump: any breaking change → `major`; else any `feat` → `minor`; else `patch`.
   Breaking includes incompatible changes to stored or exchanged data formats, public APIs and
   configuration; check that each comes with an automatic migration (`docs/architecture.md`).
   (While `0.x`, breaking changes may bump `minor`; tell me if you use that rule.)
   A pre-release (`--pre alpha`, then `pre`, `pre --pre beta`, `final`) is a bump like any other: propose it and the reason.
3. Confirm all `done` requirements are reflected in the changelog. Show me
   `scripts/check-traceability.sh --matrix`.
4. Run `scripts/check.sh --release`. It also fails on TODO markers in `SECURITY.md` and
   `docs/threat-model.md`. Guides incomplete: run [[documentation]] first; security documents
   incomplete: fill them with me (never invent contacts or owners).
5. Run [[security-review]] on everything changed since the last tag. Check
   `docs/security-exceptions.md`: an expired row fails `scripts/check.sh` and blocks the release
   until it is fixed or I renew it.
6. **Approval point:** show me the proposed bump and reason. Releasing always needs my
   explicit yes in this session.
7. On an up-to-date `main` with every branch for this release merged, run
   `scripts/release.sh <part> [--pre <id>]`. It checks, stamps changelog and guides, commits and tags. Do not push.

## Done when
- [ ] Tag `vX.Y.Z` exists locally
- [ ] Completion report given (AGENTS.md §5): checks run, checks skipped, unresolved findings, acceptance evidence
