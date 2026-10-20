---
id: REQ-151
type: job
epic: security
priority: should
status: approved
updated: 2026-10-20
---

# The offline SAST scans Rust files with its own rules

## Job

When my project has Rust code, I want the offline checks to scan it with local rules, so I can be sure a green result is not just "no Python or JavaScript file had a finding".

## Acceptance criteria

- Given a staged or changed `.rs` file, when the checks run, then the local semgrep rules of `.semgrep/rust.yml` scan it, and the scaffold's rule test runs them with their fixtures.
- Given Rust code, then `Command::new("sh")` or `"bash"`, `danger_accept_invalid_certs(true)`, SQL built with `format!` and MD5 or SHA-1 digests are findings; their safe forms are not.
- Given the documentation of the rules, then a language without its own rules file stays named as not covered.
