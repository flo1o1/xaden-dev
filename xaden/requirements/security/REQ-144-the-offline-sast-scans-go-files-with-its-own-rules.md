---
id: REQ-144
type: job
epic: security
priority: should
status: done
updated: 2026-10-20
---

# The offline SAST scans Go files with its own rules

## Job

When my project has Go code, I want the offline checks to scan it with local rules, so I can be sure a green result is not just "no Python or JavaScript file had a finding".

## Acceptance criteria

- Given a staged or changed `.go` file, when the checks run, then the local semgrep rules scan it; a rules file per language lives in `.semgrep/` (`go.yml`), and the scaffold's rule test runs every rules file with its fixtures.
- Given Go code, then a command run through `sh -c` or `bash -c`, `InsecureSkipVerify: true`, SQL built with `fmt.Sprintf` or `+`, and `template.HTML` of a non-literal are findings; an argument-list command, a TLS config without it, placeholders and a literal are not.
- Given the documentation of the rules, then it says that Go has four rules and that Java, PHP, Ruby and Rust have none yet.
