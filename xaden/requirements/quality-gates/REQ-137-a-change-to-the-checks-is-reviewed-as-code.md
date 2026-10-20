---
id: REQ-137
type: job
epic: quality-gates
priority: should
status: approved
updated: 2026-10-20
---

# A change to the checks is reviewed as code

## Job

When a pull request changes how my project is checked, I want to see CI judge it by the settings of the target branch, so I can be sure the pull request cannot approve itself.

## Acceptance criteria

- Given a pull request, when CI runs, then `mode`, `hook-checks`, `expect`, `check.*`, `findings-status.*`, `require-signature`, `version`, `checksum`, the baselines and the workflow of `xaden/xaden.conf` are compared with the merge base, and a difference makes the run fail with "check settings changed" and the changed lines, before any mapped command runs.
- Given that failure, when the pull request carries the label `xaden-settings-accepted` (the workflow passes it as `SETTINGS_ACCEPTED=true`), then the run names the changes, accepts them and continues.
- Given a baseline in the pull request with more lines than at the merge base, then the run fails like any other settings change.
- Given a repository that was not adopted at the merge base, then nothing is compared.
- Given a baseline key that occurs n times, then a run that finds more than n new occurrences fails for the extra ones (a regression test records the behaviour of the multiset comparison).
- Given a staged `check.*` line that differs from the commit before, when pre-commit would run it, then the hook prints the line and runs it only after a yes; without a terminal it skips that command and says so.
