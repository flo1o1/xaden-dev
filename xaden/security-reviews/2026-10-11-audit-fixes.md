# Security review 2026-10-11 — whole scaffold after the move, with audit fixes

Written by `template/prompts/security-review.md` (`/security`, REQ-055).
A completed review records what was checked; it is not proof that the scaffold is secure.

- Reviewer: Claude Code (Claude Opus 5.5). The maintainer asked for a code audit and a security
  review with the recommended changes applied, before going offline; that request is the approval
  for the fixes below.
- Version / commit: reviewed at `7c3ac51`, fixes up to `c1d7834` (scaffold 0.1.0, unreleased)
- Threat model: `docs/threat-model.md` of 2026-10-11 (updated by this review); ASVS L1

## Scope

Nothing had changed since the previous review (`2026-10-11-xaden-command.md`), so this review
covered scripts the earlier reviews did not name, re-read the rest, and reviewed the fixes from
the code audit done in the same session:

- `template/scripts/migrate-requirements.sh` (not covered before): reads a project's
  `docs/requirements/REQUIREMENTS.md` and writes files built from its content
- The gates: `verify-refs.sh`, `verify-commits.sh`, `hooks/commit-msg`, `check-security-exceptions.sh`,
  `check-requirements.sh`, `check-traceability.sh`, `check-docs.sh`
- `lib.sh` (staged snapshot, file selection, release helpers), `check.sh`, `stacks/*.sh`,
  `release.sh`, `req.sh`, `pack-context.sh`, `setup.sh`, `apply-preset.sh`, `context-status.sh`
- `scripts/new-project.sh`, `update-scaffold.sh`, `scaffold-lib.sh`, `xaden.sh`, `install.sh`,
  `check-scaffold.sh`, `release-scaffold.sh`
- Both GitHub workflows (zizmor, actionlint)
- The audit fixes: `collect_files` rewrite (`lib.sh`), `RULES_FILE` in `context-status.sh`, the
  worktree check in `update-scaffold.sh`

Out of scope: prompts and guides as text, the semgrep rules' coverage (tested by their fixtures),
`tests/smoke.sh` beyond the parts added here.

## Evidence

- `STRICT=1 scripts/check-scaffold.sh` at `c1d7834`: passed, `9 passed, 0 failed, skipped: none`,
  smoke test 428 assertions (416 before this review).
- `zizmor --offline` 1.30.1 on both workflows: no findings (4 suppressed by its defaults).
  `actionlint` 1.7.12: no findings.
- `semgrep` 1.180.0 with the local rules on the whole repository (fixtures excluded): no findings.
- Finding 1 was shown with a proof of concept in a scratch directory: the migration wrote
  `escaped-pwn.md` outside `docs/requirements/`. After the fix the same input stops with
  `invalid requirement ID in the table` and writes nothing.
- Findings 2 and 3 were reproduced by running the scripts on hand-written inputs before and after
  the fix (outputs quoted in the findings).

Verified safe (by reading the code):

- Values from requirement files, commit messages and the security-exceptions table are compared
  or printed, never evaluated. IDs used in `grep`/`sed` patterns are first restricted to
  `REQ-[0-9]+` or `CC-[0-9]{2}`.
- `req.sh new` validates the epic name; titles become file names only through `slugify`
  (`[a-z0-9-]`).
- `pack-context.sh` validates prompt names (`[a-z0-9-]+`) before building paths.
- The new `collect_files` hands file names to the checkers as array elements. Names with spaces
  are kept (smoke-tested); names containing newlines are unsupported, as before.
- `RULES_FILE` in `context-status.sh` is only read (`cat`, `grep`), like in `verify-refs.sh`.
- `update-scaffold.sh` now accepts `.git` as a file (worktrees, submodules). The symlink and
  manifest protections of the first review are unchanged and still pass `test_update_safety`.

## Limitations

- Linux was not tested (no remote, CI has never run); macOS only.
- zizmor ran offline (no online audits such as known-vulnerable action versions).
- Running the checks, hooks or CI in a repository runs that repository's code. This is by design
  (accepted in the threat model), not a finding.
- A completed checklist is not proof of security.

## Findings

| # | Severity | Location | Issue (what an attacker does) | Status |
|---|----------|----------|-------------------------------|--------|
| 1 | low | `template/scripts/migrate-requirements.sh:61` (before the fix) | A contributor to a project still using the old table commits a row with the ID `REQ-/../../../../x` and an empty folder `docs/requirements/unsorted/REQ-/`. When a maintainer runs the one-time migration, it writes `x-<slug>.md` with partly attacker-chosen text wherever the user can write, and may overwrite an existing file of that name. No code runs. Verified by proof of concept. | fixed in `9d85f4a`, smoke "migration rejects an ID that is not REQ-nnn" |
| 2 | low | `template/scripts/check-security-exceptions.sh:33` (before the fix) | The expiry pattern allowed months 13–19 and days 32–39. An exception dated `2026-13-01` (typo or on purpose) passes and sorts after every real 2026 date, so an accepted vulnerability stays "valid" until 2027 without anyone renewing it. | fixed in `76ec9ff`, smoke "exception with an impossible month fails" |
| 3 | low | `template/scripts/verify-refs.sh:90` (before the fix) | The `fix` trailer check matched the substring `none`, so `Refs: nonexistent` or any value containing it passed in the hook and in CI. This weakens the gate that every fix names its requirement or says "none". | fixed in `3ae4a93`, smoke "fix with a word merely containing none rejected" |

### Fixes as applied

1. Before writing anything, check every ID in the table:

   ```bash
   validate_ids() {
     local id
     while IFS= read -r id; do
       printf '%s' "$id" | grep -Eq '^REQ-[0-9]{3,}$' || die "invalid requirement ID in the table: $id"
     done < <(table_rows | cut -f1)
   }
   ```

2. Use the same date pattern as `check-requirements.sh`:
   `/^[0-9][0-9][0-9][0-9]-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$/`

3. Match the exact trailer value: `grep -Eq 'REQ-[0-9]{3,}|^Refs:[[:space:]]*none[[:space:]]*$'`.
   No earlier `fix` commit in this repository uses another form, so CI's first full-history check
   still passes.

Non-security fixes from the same audit, with regression tests: `c1d7834` (file selection in one
pass, REQ-014), `1c31429` (context status at the scaffold root, REQ-055), `6394e7e` (updates in
worktrees, REQ-017).

## Remediation summary

Fixed: #1, #2, #3. Accepted: none new (the earlier review's accepted risk stays in the threat
model). Open: none. Next review: before the first release, after the first Linux CI run.
