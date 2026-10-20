---
id: REQ-143
type: job
epic: security
priority: should
status: approved
updated: 2026-10-20
---

# The offline SAST rules cover more classes of common mistakes in Python and JavaScript

## Job

When the offline checks say a Python or JavaScript change is clean, I want the local rules to cover the common classes that were missing, so I can trust a green result more than one that only knew injection, eval and weak crypto.

## Acceptance criteria

- Given Python code, then `os.system`/`os.popen`, a JWT decoded without a verified signature or with `none`, a wildcard CORS origin, request data reaching the URL of an outgoing request (SSRF) and request data reaching a file path (path traversal) are findings; a fixed list, an argument-list `subprocess` call, a named origin, `secure_filename` and `os.path.basename` are not.
- Given JavaScript or TypeScript code, then a JWT verified with `none`, a wildcard CORS origin, `unserialize`/`vm.run*`, request data reaching an outgoing request URL and request data reaching a file path are findings; `JSON.parse`, a named origin and `path.basename` are not.
- Given the rule fixtures, then each new rule has a case that fires and one that stays quiet, and `semgrep --test` (part of the full check of the scaffold) passes.
- Given the documentation of the rules, then it says what these rules do not cover: they match patterns and single-file data flow, so a value passed through a helper in another file is not followed, and only Python and JavaScript/TypeScript are covered.
