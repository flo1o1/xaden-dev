---
id: REQ-171
type: job
epic: release-and-docs
priority: should
status: approved
updated: 2026-11-10
paths: template/scripts/release.sh, template/scripts/verify-commits.sh, template/docs/rules/git.md, template/prompts/, scripts/release-scaffold.sh, tests/smoke/release-and-docs.sh, docs/guide/
---

# Parallel changes keep separate changelog fragments until release

## Job

When several branches add user-visible changes in parallel, I want each change recorded in its own changelog fragment until release, so I can merge the branches without resolving conflicts in the shared changelog.

## Acceptance criteria

- Given a project that uses a `changelog.d/` folder, when two branches add separate fragments, then neither change edits `CHANGELOG.md` and merging them causes no changelog conflict.
- Given valid fragments and existing `Unreleased` entries, when a release is prepared, then all entries appear under the new version exactly once, existing entries are preserved, and only the consumed fragment files are removed.
- Given a project without `changelog.d/`, when checks and releases run, then the existing changelog workflow keeps working without migration.
- Given a project using fragments, then its rules, task prompts and guides explain the fragment format, unique filenames and release assembly, and its checks report malformed fragments explicitly.
- Given the scaffold's own development workflow, then it supports the same fragment workflow without putting maintainer-only files into release archives.
- Given a release fails validation, then it consumes no fragments and preserves the changelog.
- Given regression tests, then they cover fragment assembly, legacy entries, legacy projects and invalid input.

Refs: issue 131.
