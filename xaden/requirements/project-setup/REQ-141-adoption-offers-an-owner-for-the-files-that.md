---
id: REQ-141
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-20
---

# Adoption offers an owner for the files that control the checks

## Job

When I adopt Xaden, I want the files that control the checks protected by review, so I can be sure that one contributor cannot change them alone.

## Acceptance criteria

- Given adoption with `--codeowner <owner>` (or the owner typed at the question in a terminal), then it writes `.github/CODEOWNERS-dist` as a candidate, never over a `CODEOWNERS` file, assigning `xaden/xaden.conf`, `xaden/baselines/`, `AGENTS.md` and `.github/workflows/` to that owner, in its own commit and on the footprint list.
- Given no owner (no option, `--yes` without the option, or no terminal), then no candidate is written; the owner is asked, never guessed.
- Given `--codeowner` with a value that is not `@user` or `@org/team`, then adoption stops before changing anything; the same text typed at the question writes no candidate.
- Given the admin guide, then it explains the branch-protection settings that make the entry bite: require review from code owners, and the Xaden check as a required status check.
