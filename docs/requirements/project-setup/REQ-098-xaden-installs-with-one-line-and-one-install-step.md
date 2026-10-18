---
id: REQ-098
type: job
epic: project-setup
priority: should
status: approved
updated: 2026-10-18
---

# Xaden installs with one command and one install step

## Job

When I want Xaden on a new machine, I want one command to get it, so I can skip a long recipe and still verify everything myself.

## Acceptance criteria

- Given `curl -fsSL https://xaden.dev/install | bash`, then the script runs only when it was received completely (everything sits in one function called on its last line).
- Given that script, then it shows version, source and checksum, asks the yes on the terminal even when its input is the pipe, and downloads nothing without it; without a terminal it exits with code 3 and prints what to run (REQ-072).
- Given the downloaded zip, then its signature is verified against the key embedded in the script, and a wrong signature installs nothing.
- Given the zip route (`scripts/install.sh` from an extracted zip) and the one-line route, then both use the same install step: copy the folder to `versions/<version>/`, switch `current`, link `xaden`.
- Given an extracted zip folder that is deleted afterwards, then `xaden version` still works.
- Given an older `xaden` link that points into a former extracted folder, then the install step names it and replaces it; a link or file that is not a Xaden link is left unchanged.
- Given `docs/guide/admin/install-xaden.md`, then it shows the one-line route, the read-first route, the signed zip and upgrading with `xaden upgrade`.
