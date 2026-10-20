---
id: REQ-015
type: job
epic: quality-gates
priority: must
status: done
updated: 2026-10-11
---

# Clean-code rules enforced by linters; a detected stack without checks fails

## Job

When a project uses a known stack, I want clean-code rules enforced by linters and a failing check when lint, type or test setup is missing, so I can trust that a green run means the checks really ran.

## Acceptance criteria

- Stack presets map CC rules to linter settings
- missing lint/type/test steps fail check.sh
- CI installs requirements-dev.txt only when it exists; a Python project configured in pyproject.toml reaches check.sh, which names any missing tool
