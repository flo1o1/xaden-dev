---
id: REQ-148
type: job
epic: security
priority: should
status: approved
updated: 2026-10-20
---

# The offline SAST scans Java files with its own rules

## Job

When my project has Java code, I want the offline checks to scan it with local rules, so I can be sure a green result is not just "no Python or JavaScript file had a finding".

## Acceptance criteria

- Given a staged or changed `.java` file, when the checks run, then the local semgrep rules of `.semgrep/java.yml` scan it, and the scaffold's rule test runs them with their fixtures.
- Given Java code, then a command string run through `Runtime.exec` or `sh -c`, SQL built with `+`, `ObjectInputStream.readObject` and MD5 or SHA-1 digests are findings; their safe forms are not.
- Given the documentation of the rules, then a language without its own rules file stays named as not covered.
