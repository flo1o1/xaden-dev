---
id: REQ-154
type: job
epic: quality-gates
priority: should
status: done
updated: 2026-10-21
---

# A project can make a missing tool fail its checks

## Job

When a check's tool is missing on the machine that runs it, I want my project to count that as a failure instead of an INCOMPLETE run, so I can be sure the team's gate cannot be passed without the scanners it named.

## Acceptance criteria

- Given `missing-tools = fail` in `xaden/xaden.conf`, then a run in which a check's tool is missing counts it as a failure and exits 1, locally and in the pre-commit, like the `--strict` option and the generated CI already do; the key absent or `skip` keeps today's INCOMPLETE run (exit 0).
- Given any other value for `missing-tools`, then the run stops with `missing-tools must be skip or fail (got: ...)`, the way `require-signature` names a wrong value.
- Given a pull request that changes or adds `missing-tools`, then it is an approval point: the run fails with `check settings changed` until the label `xaden-settings-accepted` is on it.
- Given the guides, then "Make the gates blocking" names the setting, the prerequisites line of the admin guide names it, and the threat model's missing-scanner row cites it.
