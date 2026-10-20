---
id: REQ-014
type: quality
epic: quality-gates
priority: must
status: done
updated: 2026-10-11
---

# Fast, offline and reproducible pre-commit checks

## Quality goal

Pre-commit checks inspect only staged files, need no network, use pinned rules and finish in seconds; the full run happens in CI.

## Acceptance criteria

- Pre-commit checks only staged files, needs no network, uses pinned rules
- full run in CI
- files larger than 1 MiB that the commit does not change are not copied into the pre-commit snapshot; staged files always are
- choosing the files for each checker filters the whole file list in one pass, not one process per file; 5,000 tracked files take well under a second, and the same files are chosen (names with spaces included, exclusions honoured)
