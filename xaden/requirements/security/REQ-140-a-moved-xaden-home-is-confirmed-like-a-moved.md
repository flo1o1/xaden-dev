---
id: REQ-140
type: job
epic: security
priority: could
status: done
updated: 2026-10-20
---

# A moved Xaden home is confirmed like a moved download

## Job

When Xaden installs or verifies a version in production mode, I want a moved Xaden home to be named and confirmed, so I can be sure a hostile environment variable cannot make Xaden run or install files from another place unseen.

## Acceptance criteria

- Given production mode, when `fetch`, `pin` or `upgrade` runs with `XADEN_HOME` set, then Xaden names it and asks before using it; without a terminal it stops. `XADEN_TEST_MODE=1` skips the question (as for REQ-136).
- Given `XADEN_HOME` is unset, then nothing changes.
