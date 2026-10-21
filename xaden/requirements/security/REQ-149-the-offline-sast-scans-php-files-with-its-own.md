---
id: REQ-149
type: job
epic: security
priority: should
status: done
updated: 2026-10-20
---

# The offline SAST scans PHP files with its own rules

## Job

When my project has PHP code, I want the offline checks to scan it with local rules, so I can be sure a green result is not just "no Python or JavaScript file had a finding".

## Acceptance criteria

- Given a staged or changed `.php` file, when the checks run, then the local semgrep rules of `.semgrep/php.yml` scan it, and the scaffold's rule test runs them with their fixtures.
- Given PHP code, then `eval`, `system`/`exec`/`shell_exec`/`passthru`/`popen` with a non-literal command, `unserialize` without `allowed_classes => false`, and `include`/`require` of a request value are findings; their safe forms are not.
- Given the documentation of the rules, then a language without its own rules file stays named as not covered.
