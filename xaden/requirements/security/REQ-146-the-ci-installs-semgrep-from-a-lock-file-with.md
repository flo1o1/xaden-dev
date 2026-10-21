---
id: REQ-146
type: job
epic: security
priority: should
status: done
updated: 2026-10-20
---

# The CI installs semgrep from a lock file with hashes

## Job

When my project's CI installs semgrep, I want every file it downloads checked against a hash from a reviewed lock file, so I can be sure a changed package on the index cannot change what the checks run.

## Acceptance criteria

- Given the workflow `xaden project adopt` writes, then semgrep and its dependencies are installed with `pip install --require-hashes --only-binary=:all:` from `scripts/adopt/semgrep.lock` of the Xaden tree whose checksum was verified in the step before, not with `pipx install`.
- Given `SEMGREP_VERSION` in the workflow, then the lock holds `semgrep==` at that version and every line of the lock carries a hash; a test fails otherwise.
- Given a maintainer, then `scripts/semgrep-lock.sh` rewrites the lock for a version, and the release archive holds the lock but not the script.
- Given the guides, then they say that the lock is for Linux x86_64 and Python 3.12, so a different runner image fails closed, and that bandit, pip-audit and the scaffold's own CI jobs are not covered by it.
