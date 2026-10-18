---
id: REQ-065
type: job
epic: release-and-docs
priority: should
status: done
updated: 2026-10-18
---

# Getting started documents how to get Xaden: one command, and a clone for contributors

## Job

When I want to try Xaden, I want Getting Started to describe how to get it, with one command for using it and a clone for working on it, so I can start with the one that fits me.

## Acceptance criteria

- Given `docs/guide/admin/install-xaden.md`, then it describes the one-command install with its steps up to a working `xaden` command, and `GETTING-STARTED.md` links to it (REQ-098)
- Given the clone way, then `docs/guide/contributing/install-with-git.md` describes install, update (`git pull`, picking a release tag instead of `main`) and uninstall of a clone, and the admin guides link to it (REQ-104)
- Given the install guide, then it says when the clone is the right choice and links to the Contributing section
- Given `docs/guide/admin/requirements-and-platforms.md`, then it has a short section per operating system (Linux, macOS, Windows) for the differences: prerequisites, which shell profile receives the `PATH` line, and for Windows the route (WSL recommended, Git Bash) with its support status (untested until verified, native PowerShell not supported)
- Given each documented command sequence, when run on a clean Linux or macOS machine, then it works (verified by the smoke test where possible, otherwise marked untested)
