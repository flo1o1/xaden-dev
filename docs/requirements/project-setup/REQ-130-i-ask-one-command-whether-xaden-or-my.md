---
id: REQ-130
type: job
epic: project-setup
priority: should
status: approved
updated: 2026-10-19
---

# I ask one command whether Xaden or my dependencies are outdated

## Job

When I want to know what is outdated, I want one command with one verb, so I can stop wondering which of two commands to run.

## Acceptance criteria

- Given `xaden upgrade --check` in a project, then it reports the installed Xaden against the newest release and prints the `Dependencies:` line of REQ-084, and it changes nothing (REQ-097, REQ-084).
- Given `xaden upgrade --check` outside a project, then it reports the Xaden line only, as before.
- Given `xaden upgrade --check` with `update-check = off`, then it still checks now, after the question it asks today.
- Given `xaden upgrade --check --if-due`, then it does what `xaden update-check --if-due` did: silent, only when the interval has passed, cached, and no error when the network is down.
- Given `xaden update-check` (any flags but `--if-due`), then it behaves as before and says on stderr that `xaden upgrade --check` is the new form; `--if-due` stays silent.
- Given an outdated dependency whose newest version has a higher major number than the installed one, then the `Dependencies:` line marks its name `(major)`.
- Given `xaden help`, then it marks `update-check` as deprecated and adds no new command; the setting `update-check` and `XADEN_UPDATE_CHECK` keep their names, and `xaden update` (bringing a project made by `create` to this Xaden) stays as it is.
- Given an update, then Xaden still only reports: no dependency is changed (REQ-084).
