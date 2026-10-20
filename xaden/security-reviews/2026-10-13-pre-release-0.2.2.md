# Security review 2026-10-13 — changes since 0.2.1, before scaffold 0.2.2

Written by `template/prompts/security-review.md` (`/security`, REQ-055).
A completed review records what was checked; it is not proof that the scaffold is secure.

- Reviewer: Claude Code (Claude Opus 5.5), on the maintainer's request to release 0.2.2
- Version / commit: `5d771f7` (scaffold 0.2.1, release 0.2.2 pending)
- Threat model: `docs/threat-model.md` of 2026-10-13; ASVS L1

## Scope

Everything merged since `v0.2.1` (`20aa8d8`), 4 commits:

- `template/scripts/context-status.sh`: `requirement_summary` replaces `requirement_ids`
  (`dbfd136`, review item C6)
- Comments at the semgrep registry step in `.github/workflows/scaffold-ci.yml` and
  `template/.github/workflows/ci.yml`; a paragraph in `template/docs/security.md` (`56b83cd`, C3)
- Requirement history from git: `template/AGENTS.md` §2, `template/docs/requirements/README.md`,
  `template/prompts/feature.md`, `template/prompts/requirements-update.md` (`0641f1b`, C4)
- `tests/smoke.sh` split into `tests/smoke/*.sh` with area arguments (`5d771f7`, C5; maintainers only,
  not copied into projects)

Out of scope: unchanged scripts (earlier reports).

## Evidence

- `STRICT=1 scripts/check-scaffold.sh` at `5d771f7`: passed (9 passed, 0 failed, skipped: none;
  smoke test 512 assertions; gitleaks, shellcheck, semgrep and its rule tests included).
  CI run 38361017630 on `5d771f7` passed on ubuntu-latest and macos-latest.
- `context-status.sh` read: it reads the output of `scripts/req.sh list` and prints only the
  first two fields (ID, status) per line, as the old `sed` did; titles are not printed. No new
  input, no file writes, no command built from the data. The fingerprint is computed as before.
- Workflows: only comments added; triggers, permissions, pinned actions and
  `persist-credentials: false` unchanged (asserted by `test_ci_credentials`).
- `tests/smoke.sh <area>`: the argument is compared exactly (`grep -qx`) with the fixed `AREAS`
  list before `source "$SMOKE_DIR/$area.sh"`, so a name such as `../x` is rejected
  ("unknown area"); `areas` dies when the files in `tests/smoke/` and the list differ.
- Docs: the C4 change removes an instruction; it does not touch what is validated
  (`check-requirements.sh` never read the change log). The C3 paragraph allows suppressing a
  semgrep finding only with a one-line reason, consistent with `AGENTS.md` §5.

## Limitations

- Static reading plus the regression tests named in `CHANGELOG.md`; no fuzzing.
- The semgrep registry rules stay unpinned by decision (C3): CI can turn red without a code
  change. That affects availability of a green build, not integrity.

## Findings

| # | Severity | Location | Issue (what an attacker does) | Status |
|---|----------|----------|-------------------------------|--------|
| — | — | — | No findings in the scope above. | — |

## Remediation summary

Nothing to remediate; the threat model only gets the new review date (no new entry point, file set or write
target in the template). Next review: before the next release, or when a script starts reading
a new file set or writing new paths.
