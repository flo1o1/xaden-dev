---
id: REQ-007
type: job
epic: release-and-docs
priority: must
status: done
updated: 2026-10-11
---

# Semantic versioning of projects

## Job

When I release, I want semantic versions derived from Conventional Commits, so I can tell users what kind of change to expect.

## Acceptance criteria

- VERSION, CHANGELOG, Conventional Commits hook, release.sh bumps and tags
- release.sh and release-scaffold.sh refuse a CHANGELOG without an [Unreleased] section and change nothing
