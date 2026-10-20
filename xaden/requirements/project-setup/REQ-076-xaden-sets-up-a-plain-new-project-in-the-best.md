---
id: REQ-076
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-14
---

# Xaden sets up a plain new project in the best possible way with one confirmation

## Job

When I start a plain new project and do not want to decide on every tool myself, I want to run Xaden in autopilot mode, so I can get the recommended setup for my stack after one confirmation.

## Acceptance criteria

- Given an empty or plain new repository, when `xaden create --autopilot` runs (stack from `--stack` or one question), then it prints one plan with everything it will do and asks once; a yes applies the plan, anything else changes nothing.
- Given the plan, then it covers: the `xaden/` layout from REQ-070, the stack's preset (REQ-069), hooks, a CI workflow, mode `strict` in `xaden/xaden.conf`, git initialisation with the first commit on a branch, and the exact install commands for every development dependency the preset needs.
- Given the dependencies in the plan, then each passes the existence and reputation check of REQ-052, and the one yes covers exactly the listed packages and versions; a package added later needs its own approval.
- Given autopilot, then it never pushes, never publishes and never downloads Xaden or any package without the confirmation of REQ-072; it prints the install commands unless the person said to run them in the plan prompt.
- Given a repository that already contains code, a build file or history, when `--autopilot` is requested, then it stops, points to `xaden adopt`, and changes nothing.
- Given the finished run, then it ends with a summary of what was created, which checks pass, and which are skipped; skipped checks end the run with a warning, never a success sign (REQ-074).
- Given the recommended setup for a stack changes in a later Xaden version, then existing projects are unaffected until `xaden upgrade` (REQ-071).
