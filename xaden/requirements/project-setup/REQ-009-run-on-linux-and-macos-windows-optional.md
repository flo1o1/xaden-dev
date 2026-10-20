---
id: REQ-009
type: quality
epic: project-setup
priority: must
status: done
updated: 2026-10-11
---

# Run on Linux and macOS; Windows optional

## Quality goal

The scaffold and generated projects run on Linux and macOS with bash 3.2 and POSIX tools only; Windows is optional.

## Acceptance criteria

- Bash 3.2 and POSIX tools only
- smoke test passes on macOS and Linux CI
- shell lint passes with the shellcheck that Linux CI installs from Ubuntu (0.9.0) as well as with current releases (0.11.0 on macOS)
