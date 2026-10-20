---
id: REQ-138
type: job
epic: security
priority: should
status: done
updated: 2026-10-20
---

# The installed Xaden is checked against the pin before it runs

## Job

When I run `xaden` in a project, I want the Xaden copy that runs to be the one the project pinned, so I can be sure a changed file in `~/.local/share/xaden/versions/<version>` cannot run with my rights unnoticed.

## Acceptance criteria

- Given an adopted project, when Xaden runs the pinned version (itself or an installed copy it hands over to), then the tree checksum of that copy is compared with `checksum` in `xaden/xaden.conf` first; on a mismatch it stops with exit code 1 and names `xaden core fetch <version>`.
- Given `require-signature = true`, then the check of the signed record (REQ-103) stays on top of this one.
- Given the check takes more than one second on a normal machine, then the measurement is recorded in the changelog and the criterion is reopened before release.
