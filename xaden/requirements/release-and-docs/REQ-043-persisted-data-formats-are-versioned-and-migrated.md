---
id: REQ-043
type: job
epic: release-and-docs
priority: should
status: done
updated: 2026-10-11
---

# Persisted data formats are versioned and migrated without data loss

## Job

When a release changes how data is stored or exchanged, I want versioned formats and automatic migrations, so I can upgrade without losing user data.

## Acceptance criteria

- Architecture template and clean-code.md state versioned formats, automatic migration, partial failure isolated with a message, tests per old version
- release prompt counts incompatible data, file, API or config format changes as major
