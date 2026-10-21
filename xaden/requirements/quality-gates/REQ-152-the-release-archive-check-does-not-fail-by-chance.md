---
id: REQ-152
type: quality
epic: quality-gates
priority: should
status: done
updated: 2026-10-20
---

# The release archive check does not fail by chance

## Quality goal

`scripts/check-release-archive.sh` gives the same verdict for the same tree on every run and every system. It failed on a macOS runner in CI with "the release archive lacks: VERSION" although the file was there, because `grep -q` ended the pipe while `printf` was still writing the file list.

## Acceptance criteria

- Given a tree whose archive lists 30000 shipped files, when the check runs, then it passes and names no required path as missing.
- Given the check, then no required-path test reads the file list through a pipe that `grep -q` can close early.
