---
id: REQ-058
type: job
epic: release-and-docs
priority: should
status: done
updated: 2026-10-11
---

# Releases are blocked while security documents have unfilled markers

## Job

When I cut a release, I want it refused while `SECURITY.md` or `docs/threat-model.md` still contain unfilled template markers, so I can never ship without a vulnerability contact, a secret rotation plan and a threat model.

## Acceptance criteria

- Given `SECURITY.md` or `docs/threat-model.md` contains a `<!-- TODO` marker, when `scripts/release.sh` runs, then it stops before changing anything and names the file
- Given both files are filled in, when `scripts/release.sh` runs, then these files do not block it
- Given the word TODO in prose (not a `<!-- TODO` marker), when the release check runs, then it does not block
