---
id: REQ-072
type: job
epic: security
priority: must
status: done
updated: 2026-10-14
---

# Xaden downloads nothing without the person's explicit confirmation

## Job

When the installed Xaden does not match the version my project pins, I want to be asked before anything is downloaded, so I can be sure no code arrives on my machine that I did not approve.

## Acceptance criteria

- Given a hook or command with a terminal attached and a missing pinned version, then it shows the version, source and checksum, a separator line, and asks `Download and install Xaden <version> now? [y/N]` as the last line; no answer or an answer other than yes means no.
- Given a yes, then it downloads that one version, verifies the checksum from `xaden/xaden.conf`, and installs only on a match; the yes is not remembered.
- Given no terminal (IDE git client, script, assistant), then nothing is downloaded and the command exits with a distinct code and the exact `xaden fetch <version>` to run.
- Given a checksum mismatch, then nothing is installed and the error is an exit with a non-zero code and no joking tone.
- Given CI, then the fetch is a committed workflow step that names the version and checksum, changed only by pull request.
- Given an assistant, then it shows the prompt to the user and never answers it.
- Given any other code path, then no part of Xaden fetches from the network without this confirmation (a test greps the scripts for network calls outside the fetch command).
