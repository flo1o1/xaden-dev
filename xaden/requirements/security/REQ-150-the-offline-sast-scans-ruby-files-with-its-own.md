---
id: REQ-150
type: job
epic: security
priority: should
status: done
updated: 2026-10-20
---

# The offline SAST scans Ruby files with its own rules

## Job

When my project has Ruby code, I want the offline checks to scan it with local rules, so I can be sure a green result is not just "no Python or JavaScript file had a finding".

## Acceptance criteria

- Given a staged or changed `.rb` file, when the checks run, then the local semgrep rules of `.semgrep/ruby.yml` scan it, and the scaffold's rule test runs them with their fixtures.
- Given Ruby code, then `eval`/`instance_eval`, a shell command string with interpolation (`system`, `exec`, `IO.popen`, backticks), `Marshal.load`/`YAML.load`, SQL interpolated into `where`/`find_by_sql`/`execute`, and `send` with a request value are findings; their safe forms are not.
- Given the documentation of the rules, then a language without its own rules file stays named as not covered.
