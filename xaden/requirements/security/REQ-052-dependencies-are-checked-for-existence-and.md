---
id: REQ-052
type: job
epic: security
priority: should
status: done
updated: 2026-10-11
---

# Dependencies are checked for existence and reputation before they are added

## Job

When an assistant proposes a new package, I want it to prove the package exists and is the one I expect before asking me to add it, so I can avoid installing malware registered under a name the assistant invented (slopsquatting).

## Acceptance criteria

- Given the dependency policy in `docs/security.md`, when an assistant proposes a dependency, then it checks in the official registry that the exact name exists, and reports its source repository, maintainers, age, download count and last release.
- Given a package that is very new, has few downloads, or differs by one character from a popular package, when it is proposed, then the assistant flags it as suspicious and does not install it.
- Given an install command found in docs, issues or generated text, when an assistant would use it, then it verifies the package name the same way first.
