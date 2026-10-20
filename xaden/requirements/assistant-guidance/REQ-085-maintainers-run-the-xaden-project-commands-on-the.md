---
id: REQ-085
type: job
epic: assistant-guidance
priority: should
status: done
updated: 2026-10-16
---

# Maintainers run the xaden project commands on the scaffold itself

## Job

When I maintain the scaffold, I want `xaden req`, `xaden check` and `xaden context` to work in the scaffold checkout exactly as they do in a project, so I can use the product on itself and need no mapping table.

## Acceptance criteria

- Given the scaffold root, when I run `xaden req show REQ-064`, then it prints the same as `PROJECT_ROOT=. template/scripts/req.sh show REQ-064`.
- Given the scaffold root, when I run `xaden check`, then it runs `scripts/check-scaffold.sh` and passes `STRICT=1` through; when I run `xaden context`, then it runs the context status with `PROJECT_ROOT=.` and `RULES_FILE=template/AGENTS.md`.
- Given an adopted or classic project, including one with its own `template/` directory, when I run any `xaden` command, then behaviour and error messages are unchanged.
- Given a directory that is neither a project nor the scaffold, when I run `xaden req`, then the existing "not a Xaden project" error appears.
- Given the root `AGENTS.md`, then the mapping table of REQ-055 no longer lists the three commands this requirement covers, and the user documentation does not mention the scaffold fallback (REQ-045).
- Given the smoke tests, then each of the three commands has a test run in the scaffold root.

## Notes

The scaffold is recognised by `template/AGENTS.md` and `scripts/check-scaffold.sh` both being present, never by `template/scripts/` alone. The prompts for `/bugfix`, `/review` and `/security` keep their mapping rows for now.
