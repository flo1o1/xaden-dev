---
id: REQ-097
type: job
epic: project-setup
priority: should
status: approved
updated: 2026-10-18
---

# `xaden upgrade` updates Xaden itself in one command

## Job

When a newer Xaden is out, I want to run `xaden upgrade` and have the tool updated and verified, so I can stay current without downloading, unzipping, relinking and deleting by hand.

## Acceptance criteria

- Given an install, then Xaden lives in `versions/<version>/` under the Xaden home, `current` is a link to the active version, and the `xaden` command links to `current/scripts/xaden.sh`, so the command link never changes.
- Given `xaden upgrade` outside a project or with `--self`, when a newer release exists and the person answers yes, then the release is installed into `versions/`, `current` switches to it atomically, and the changelog between both versions is printed.
- Given a download that fails, a wrong signature or a wrong checksum, then `current` still points to the old version and nothing new stays behind.
- Given no terminal, then nothing is downloaded and the command exits with code 3 and prints the command to run (REQ-072).
- Given `xaden upgrade --check`, then it only reports the newest version and changes nothing.
- Given the installed version is the newest, then `xaden upgrade` says so and changes nothing.
- Given older versions in `versions/`, then an upgrade never removes them, because pinned projects hand over to them (REQ-070).
- Given a Xaden that runs from a git clone, then `xaden upgrade` changes nothing and names `git -C <folder> pull`.
- Given the upgrade ran, then no file inside an older `versions/<version>/` folder changes.
