---
id: REQ-004
type: job
epic: quality-gates
priority: must
status: done
updated: 2026-10-13
---

# Static code analysis on every commit and in CI

## Job

When I commit or push, I want static analysis to run automatically, so I can find defects and insecure code before review.

## Acceptance criteria

- check.sh runs linters, shellcheck, secret scan, SAST
- hooks and CI call it
- Given CI runs semgrep registry rules that are not pinned, when a reader looks at the workflow or `docs/security.md`, then both say this is intentional and what to do about a new finding
