---
id: REQ-159
type: quality
epic: security
priority: must
status: approved
updated: 2026-10-22
---

# The AIDD pin is validated and approved like the check settings

## Quality goal

A pull request cannot make `xaden aidd disable` run another package by editing the pin. `disable` and `status` read `aidd-cli` and `aidd-release` from `xaden/xaden.conf` without checking their shape, and the `aidd-*` keys were not among the settings a pull request needs the team's label for, so `aidd-cli = npm:other@1.0.0` with a matching `aidd-integrity` passed the REQ-153 check and ran after one yes (pre-release security review 2026-10-22, finding 4).

## Acceptance criteria

- Given `aidd-cli` that is not a version (`MAJOR.MINOR.PATCH`) or `aidd-release` that is not a tag like `v5.12.0`, then every command that reads the pin refuses it before the CLI runs, and names the value.
- Given a pull request that changes `aidd-cli`, `aidd-release`, `aidd-integrity` or `aidd-commit`, then `check-settings.sh` reports the change and fails without the label `xaden-settings-accepted`.
- Given `xaden aidd disable`, then the question names the CLI version and the release that will run.
