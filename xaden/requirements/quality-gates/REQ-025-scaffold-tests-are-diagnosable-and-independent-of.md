---
id: REQ-025
type: quality
epic: quality-gates
priority: should
status: done
updated: 2026-10-13
---

# Scaffold tests are diagnosable and independent of user configuration

## Quality goal

Scaffold tests show the failing command's output, ignore the user's global git configuration, and require tool-dependent fixtures in CI.

## Acceptance criteria

- Failed assertions show the command output
- tests ignore global git configuration
- Given `PROJECT_ROOT` set in the maintainer's environment, when the smoke test runs, then the result is the same as without it
- tool-dependent fixtures are mandatory in CI
- Given a local run, when assertions pass, then the smoke test prints no line per assertion, only failures and the total; `SMOKE_VERBOSE=1` (set in CI) prints every passed assertion.
- Given a maintainer working on one epic, when they run `tests/smoke.sh <area>`, then only that area runs, after the demo project is created; an unknown area is rejected
