---
id: REQ-164
type: job
epic: requirements
priority: should
status: approved
updated: 2026-11-03
paths: template/scripts/req.sh, template/scripts/requirements-lib.sh, scripts/xaden.sh
---

# A mistyped req call shows the call I type and accepts a short ID

## Job

When I mistype a `xaden req` call, I want the message to show the call I actually type and to accept the obvious short form of an ID, so I can fix the call without reading the script.

## Acceptance criteria

- Given `xaden req` with a missing or unknown verb, when it prints the usage, then the usage starts with `xaden req`; run as `scripts/req.sh` directly, it still starts with `scripts/req.sh`
- Given `show 15`, `show REQ-15` or `show req-015`, when the requirement exists, then it shows REQ-015
- Given an ID that does not exist, when `show` fails, then the error names the last existing ID and `list`
