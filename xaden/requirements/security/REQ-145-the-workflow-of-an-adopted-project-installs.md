---
id: REQ-145
type: job
epic: security
priority: should
status: approved
updated: 2026-10-20
---

# The workflow of an adopted project installs shellcheck at a pinned, verified release

## Job

When my project's CI runs Xaden's checks, I want every tool it installs to be pinned and verified, so I can be sure a package repository update cannot change what the checks run.

## Acceptance criteria

- Given the workflow `xaden project adopt` writes, then shellcheck comes from the release archive at the version of `.github/shellcheck.version`, installed only after its SHA-256 matched, and not from `apt-get`.
- Given a bump of `.github/shellcheck.version`, then a test fails until the workflow carries the same version and hash.
- Given the workflow, then semgrep without a hash and the macOS jobs of the scaffold's own CI stay as they are; they have their own requirements and the threat model lists them as accepted risks.
