---
id: REQ-136
type: job
epic: security
priority: should
status: approved
updated: 2026-10-20
---

# A release that should be signed is refused when its signature is missing

## Job

When my project pins or upgrades Xaden, I want to see a release that should be signed fail loudly when its signature is missing, so I can be sure that deleting a file on GitHub cannot downgrade my trust to "whatever arrived".

## Acceptance criteria

- Given `release-signers` holds a key and a release at or above the first signed version (0.3.0), when its signature cannot be fetched, does not verify, or `ssh-keygen` is missing, then pin, upgrade and fetch stop with exit code 6 and install nothing.
- Given a release below the first signed version, then the trust-on-first-use path stays, with its warning and the person's yes (REQ-077).
- Given `release-signers` holds no key, then the trust-on-first-use path stays, as before.
- Given a project created or adopted by this Xaden, then its `xaden/xaden.conf` carries `require-signature = true`; a project that exists keeps its setting, and the upgrade notes say how to opt in.
- Given production mode, when `XADEN_RELEASES_URL`, `XADEN_ASSETS_URL` or `XADEN_LATEST_URL` is set, then Xaden names the override and asks before using it; without a terminal it stops. `XADEN_TEST_MODE=1` skips the question.
