---
id: REQ-101
type: job
epic: quality-gates
priority: must
status: done
updated: 2026-10-18
---

# A check that fails to run to completion never counts as passed

## Job

When a linter, scanner or test command dies halfway or is misconfigured, I want the gate to fail, so I can trust that a green gate means the tool ran to the end.

## Acceptance criteria

- Given a check with a declared findings status (`findings-status.<name> = 1` in `xaden/xaden.conf`, or the status a built-in check declares) that prints only baselined violations and exits with that status, when the gate runs in `advisory`, `changed-files` or `strict` mode, then it passes
- Given the same check exiting with any other non-zero status after printing only baselined violations (a crash), then it fails in `changed-files` and `strict` mode and warns "failed (advisory mode: not blocking)" in `advisory` mode
- Given output with a new violation and a fatal error, exit status not declared, then the check fails and shows the output
- Given a custom check (`check.<name>`) without a declared findings status that exits non-zero, then it fails, even when every violation line in its output is baselined
- Given a test command with failing assertions, then it fails in `changed-files` and `strict` mode; its failures are never baselined
- Given a mapped project command, then the declared status is honoured as it is for the built-in checks (`gate_run` is the one place that decides)
- Given an invalid `findings-status.<name>` value (not a comma list of numbers 1 to 255), one naming neither a `check.<name>` nor a built-in check (`shellcheck`, `semgrep`, `actionlint`, `zizmor`), or one for the check named `test`, then the configuration check fails
- Given adoption records the baseline of a mapped check (not `test`) that prints violations and exits with status 1, the convention of linters, then `findings-status.<name> = 1` is written to `xaden/xaden.conf` and named in the adoption output for review; given any other non-zero status, then nothing is written and the output says which line to add if that status means "violations found", because a crash at adoption time must not be learned as a finding
- Given a project that relied on a custom check passing with baselined output and a non-zero exit, then CHANGELOG and the guide say this is a breaking change and how to declare the status
