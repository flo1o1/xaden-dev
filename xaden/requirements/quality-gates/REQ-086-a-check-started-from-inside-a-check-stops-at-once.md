---
id: REQ-086
type: job
epic: quality-gates
priority: should
status: approved
updated: 2026-10-16
---

# A check started from inside a check stops at once

## Job

When a check or test accidentally starts the full check again, I want it to stop at once with a clear message, so I can be sure a mistake costs one failed run and not an hour of runaway processes.

## Acceptance criteria

- Given `scripts/check-scaffold.sh` is already running, when it is started again from inside that run, then it exits non-zero within a second and prints "check-scaffold.sh is already running in this process tree (recursion?)".
- Given the same for the template's `scripts/check.sh` and for `tests/smoke.sh`, then each refuses with a message that names it.
- Given two runs one after the other, not nested, then both run normally.
- Given a test that starts the check on purpose, then it can say so explicitly with a documented override variable, and a smoke test uses it.
- Given the smoke tests, then one starts each check from inside a check and asserts the refusal.

## Notes

The mechanism is an exported variable that each entry point reads and then sets (bash 3.2, no lock file: a lock goes stale after a crash and is shared across worktrees). `xaden check` passes the variable through unchanged. The trigger found on 2026-10-16 (a stray `xaden check` in `tests/smoke/adoption.sh` run from the scaffold root) is already fixed by REQ-085; this requirement guards against the next one.
