---
id: REQ-157
type: quality
epic: security
priority: must
status: approved
updated: 2026-10-22
---

# The settings gate reads a key the way the parser does

## Quality goal

A pull request cannot change how a project is checked without the team's yes by writing a key with leading whitespace. `conf_get` and `conf_keys` trim a key's leading whitespace, but `check-settings.sh` matched its controlled keys at the start of the line, so `  check.lint = <command>` (a key the merge base lacked) ran in CI with no label (pre-release security review 2026-10-22, finding 1).

## Acceptance criteria

- Given a pull request that adds `  check.x = <command>` (spaces or a tab before the key) for a key the merge base lacked, then `check-settings.sh` reports the change and fails without the label, as it does for the same line without indentation.
- Given the same for `findings-status.<name>`, `expect`, `hook-checks`, `mode`, `missing-tools`, `require-signature`, `version` and `checksum`, then each is reported.
- Given a conf whose controlled lines only differ in leading whitespace from the merge base, then nothing is reported.
