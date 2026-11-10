---
id: REQ-172
type: job
epic: requirements
priority: should
status: done
updated: 2026-11-10
paths: template/scripts/requirements-lib.sh, template/scripts/req.sh, template/scripts/check-requirements.sh, template/scripts/context-status.sh, scripts/adopt-lib.sh, tests/smoke/requirements.sh, docs/guide/developer/build-features.md
---

# Parallel requirement changes merge without index decisions

## Job

When parallel branches add or update requirements, I want their generated indexes to need no manual merge decision, so I can review the requirement files instead of resolving changes to derived tables.

## Acceptance criteria

- Given a newly created or adopted project, when parallel branches add different requirements and merge, then `INDEX.md` and `INDEX-full.md` cause no merge conflict because they are ignored local generated files.
- Given a fresh clone without generated indexes, when `xaden context` runs before the assistant reads the index, then both indexes are generated from the requirement files and reflect the merged state.
- Given local generated indexes that are missing or stale, when the requirements check runs, then it regenerates them and still validates the requirement files.
- Given an existing project whose indexes remain tracked, then stale indexes still fail the check; adding ignore entries alone does not bypass that validation.
- Given an existing project, when its maintainer follows the documented opt-in migration, then only the two generated indexes are removed from Git tracking, their local files remain available, and the requirement files and numbers do not change.
- Given the scaffold repository, then it follows the same local-index workflow and does not statically import an absent generated index before its session-start command.
- Given tests, then they cover a real parallel-branch merge, a fresh clone, local generation and validation, both adopted and template layouts, and compatibility with tracked legacy indexes.

Refs: issue 132.
