---
id: REQ-130
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-19
---

# I ask one command whether Xaden or my dependencies are outdated

## Job

When I want to know what is outdated, I want one command with one verb, so I can stop wondering which of two commands to run.

## Acceptance criteria

- Given `xaden upgrade --check` in a project, then it reports the installed Xaden against the newest release and prints the `Dependencies:` line of REQ-084, and it changes nothing (REQ-097, REQ-084).
- Given `xaden upgrade --check` outside a project, then it reports the Xaden line only, as before.
- Given `xaden upgrade --check` with `update-check = off`, then it still checks now, after the question it asks today.
- Given `xaden upgrade --check --if-due`, then it is silent, checks only when the interval has passed, writes the cache, and exits `0` when the network is down.
- Given `xaden update-check` or `xaden new`, then Xaden answers like for any unknown command; no alias or notice stays behind. The setting `update-check` and `XADEN_UPDATE_CHECK` keep their names.
- Given an outdated dependency whose newest version has a higher major number than the installed one, then the `Dependencies:` line marks its name `(major)`.
- Given `xaden help`, then it lists no `update-check` and no `new`, and `xaden update` stays as it is.
- Given `xaden upgrade <version>` anywhere, including inside a project, then it installs that Xaden version on the machine and does not touch the project; after it, a project is told to move with `xaden pin <version>`. Without a version it installs the newest release.
- Given an update, then Xaden still only reports: no dependency is changed (REQ-084).
