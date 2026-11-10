# Security review 2026-11-10 — local requirement indexes

- Reviewer: AI assistant; the user approved completing REQ-172 and the existing REQ-173 documentation/tests in this session.
- Version / commit: changes based on `157451607d88ea77cd76e113dc175a80affca615`; this report accompanies the implementation commit.
- Threat model: `xaden/threat-model.md`, ASVS L1; added the local-index regeneration entry point.

## Scope

Reviewed `write_requirement_indexes` and `refresh_local_requirement_indexes` in
`template/scripts/requirements-lib.sh`, their callers in requirement lookup, context, validation,
adoption, and `enter_staged_snapshot` in `template/scripts/lib.sh`. Also checked the scaffold's
index migration and the REQ-173 documentation/preservation tests.

Inputs are requirement directories and files, Git tracking and ignore state, and staged snapshots.
Outputs are the two generated Markdown indexes and the adoption ignore file. No new external
service, executable dependency, authentication surface, or sensitive data type is introduced.
Unchanged download/signature code, the existing settings gate, and the rest of the repository
are outside this scoped review. Web/authentication/session controls are not applicable.

## Evidence

- Requirements smoke failed first on the missing generated-index ignore file; the expanded
  regression suite subsequently passed, including parallel merges, fresh clones, tracked legacy
  indexes, both requirement directory shapes, symlink refusal, and staged snapshots.
- Both automatic and explicit index generation refuse index symlinks and preserve their targets.
- Generated files are rendered into a private temporary directory before replacement; failures
  are propagated, and the temporary directory is cleaned up.
- Tracking either index prevents automatic regeneration, even when ignore entries exist.
- Staged checks use the real Git index for tracking, but staged ignore rules and staged
  requirement content for regeneration; stale tracked indexes still fail validation.
- Adoption refuses a symlink as the requirements ignore file and preserves existing ignore entries.
- `scripts/check-scaffold.sh --staged` passed with no skipped checks.
- Initial full `STRICT=1 xaden check` failed because the cross-branch requirement test unset the
  shared smoke Git identity. A new REQ-025 regression reproduced that failure; the redundant
  export/unset was removed without changing the user's Git configuration. Final full
  `STRICT=1 xaden check` passed: 15 checks, 1664 smoke assertions, no skipped checks.
- The final requirements-only smoke run passed 94 assertions, including opposing staged and
  unstaged ignore rules and preservation of the shared Git author and committer identities.

## Limitations

A scoped code review and a completed checklist are not proof of security. No hostile same-user
process racing parent-directory replacement was simulated. Linux CI and the pinned Linux
ShellCheck 0.9.0 have not run on these changes yet; local ShellCheck is 0.11.0. The earlier macOS
`adoption-versions` CI exit was not reproduced locally and is not claimed fixed by this review.
No named project personas are present in this checkout.

## Findings

No confirmed exploitable finding in the reviewed change. Existing risks recorded in the threat
model remain outside this scope; this review does not accept or close them.

## Remediation summary

The new automatic write path rejects index symlinks and preserves tracked-index validation.
Re-review if index paths, the opt-in condition, snapshot construction, or write destinations change.
