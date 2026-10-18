---
id: REQ-108
type: job
epic: project-setup
priority: should
status: approved
updated: 2026-10-18
---

# Adopting Xaden never switches the reference rule off without telling the team

## Job

When my team adopts Xaden on a young repository, I want to see the commit convention chosen from evidence and shown with its consequence, so I can tell whether the `Refs:` rule is enforced or only advised.

## Acceptance criteria

- Given a repository with no history, then the convention is `conventional`
- Given 1 to 4 commits whose subjects all follow Conventional Commits, then the convention is `conventional`; given at least one that does not, it is `other`
- Given 5 or more commits, then the rule is unchanged: `conventional` when at least 60 percent of the last 30 subjects follow Conventional Commits
- Given `xaden adopt --scan` and `--plan`, then the output shows the chosen value with its evidence (for example `conventional (3 of 3 subjects)`), and for `other` one sentence: the `Refs:` checks only advise; set `commit-convention = conventional` in `xaden/xaden.conf` to enforce them, which tightens a gate and is an Approval point (REQ-044)
- Given `xaden adopt --commit-convention <conventional|other>`, then the flag overrides the scan, and the plan says the value was chosen by the user; any other value is rejected with the allowed ones named
- Given the full run of `xaden check` in a project with `commit-convention = other`, then it prints one `TIP:` line naming the setting
- Given `docs/guide/developer/add-xaden-to-a-repository.md`, then it explains both values, how the scan chooses and how to opt in, in the section that describes `xaden/xaden.conf`
- Given the smoke test, then fixtures with 0 commits, 3 conventional, 3 mixed and 6 mixed commits yield `conventional`, `conventional`, `other` and `other`, and the plan for `other` contains the sentence
