---
id: REQ-106
type: job
epic: security
priority: must
status: done
updated: 2026-10-18
---

# An adopted project audits its dependencies and runs Bandit like a new one

## Job

When my team adopts Xaden on a Python or Node repository, I want the dependency audit and, for Python, Bandit to run in `xaden check` and in CI, so I can rely on the security coverage of a project made by `xaden create` without wiring it by hand.

## Acceptance criteria

- Given the check kinds in `xaden/xaden.conf`, then `audit` (dependency audit, every stack) and `security` (Bandit, Python only) are kinds like `test`, `lint` and `typecheck`: `check.audit = <command>`, `expect` may name them, and an expected kind without a command is a gap (a warning, an error in `strict`)
- Given `xaden adopt` on a Python repository, then the scan detects an existing audit or Bandit command (Makefile, tox, CI, pre-commit) the way it detects test and lint, and otherwise lists `audit` and `security` as gaps; on a Node repository it lists `audit`
- Given `xaden preset python`, then it maps `check.audit = pip-audit` and `check.security = bandit -q -r . -x ./.venv,./node_modules,./tests` with `findings-status.audit = 1` and `findings-status.security = 1`; given `xaden preset node`, then it maps `check.audit = npm audit --audit-level=high` with `findings-status.audit = 1`; tool versions stay pinned where the preset pins them
- Given a new adoption, then `expect` includes `audit` (and `security` for Python) next to the existing kinds; given an adopted project from before, then `expect` is not changed on upgrade or on `xaden pin`, and `xaden check` shows a `TIP:` and the `NOT COVERED:` line of REQ-105, so no existing run turns red by an upgrade
- Given the output of the audits, which names no file, then a finding cannot be baselined: it fails in `changed-files` and `strict` and warns in `advisory`, as REQ-068 says for failures without file names
- Given the pre-commit hook, then the audits do not run there (network, slow): `hook-checks` stays `lint`
- Given no network in the full run, then the audit fails with the tool's own message and says that it needs the network; it is never reported as passed
- Given the generated CI workflow (`scripts/adopt/ci.yml`), then it installs the pinned audit tools for the detected stack before `xaden check --strict`, so the audit does not fail there as a missing tool
- Given the smoke test, then an adopted Python and an adopted Node fixture with a stub audit command exiting 1 and exiting 2 show: fail in `strict`, warn in `advisory`, a crash is not a finding (REQ-101), a gap when unmapped and expected, and no gap when `expect` leaves the kind out
