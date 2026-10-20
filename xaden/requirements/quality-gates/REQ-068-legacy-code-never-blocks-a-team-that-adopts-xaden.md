---
id: REQ-068
type: job
epic: quality-gates
priority: must
status: done
updated: 2026-10-14
---

# Legacy code never blocks a team that adopts Xaden

## Job

When my team adopts Xaden on code that already has lint findings, missing tests and no requirements, I want the checks to hold new work to the rules without failing on what was there before, so I can adopt now and improve step by step.

## Acceptance criteria

- Given the modes `advisory`, `changed-files` and `strict` in `xaden/xaden.conf`, when a check finds a violation, then `advisory` warns and passes, `changed-files` fails only for files changed in the diff, and `strict` fails for all.
- Given existing violations at adoption time, then they are recorded in `xaden/baselines/` and do not fail the checks.
- Given a change that removes a baselined violation, then the baseline shrinks; given a change that adds a violation, then the check fails even in `changed-files` mode, and the baseline never grows.
- Given the repository uses a commit convention other than Conventional Commits, then the `Refs:` checks run in `advisory` mode only until the team opts in.
- Given a mode change in `xaden/xaden.conf`, then it is an Approval point (it loosens or tightens a gate, REQ-044).
