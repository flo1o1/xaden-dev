---
id: REQ-057
type: job
epic: security
priority: should
status: done
updated: 2026-10-11
---

# Expired security exceptions fail the checks

## Job

When I accept a vulnerability in `docs/security-exceptions.md` with an owner and an expiry date, I want the checks to fail once that date has passed, so I can be sure an accepted risk is fixed or consciously renewed instead of forgotten.

## Acceptance criteria

- Given a row whose expiry date is before today, when the full `scripts/check.sh` runs, then it fails and names the row's ID and date
- Given a row expiring today or later, when the full run checks it, then it passes
- Given a row without an owner, or with an expiry that is not a valid `YYYY-MM-DD` date (also month 13 or day 32), when the full run checks it, then it fails and names the row
- Given only the table header (no accepted risks) or the commented example row, when the full run checks it, then it passes
- Given a commit, when the pre-commit hook runs the staged checks, then the expiry is not checked, so the same snapshot gives the same result on any day
