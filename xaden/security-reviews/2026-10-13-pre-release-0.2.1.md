# Security review 2026-10-13 — changes since 0.2.0, before scaffold 0.2.1

Written by `template/prompts/security-review.md` (`/security`, REQ-055).
A completed review records what was checked; it is not proof that the scaffold is secure.

- Reviewer: Claude Code (Claude Opus 5.5), on the maintainer's request to release 0.2.1
- Version / commit: `51c25cb` (scaffold 0.2.0, release 0.2.1 pending)
- Threat model: `docs/threat-model.md` of 2026-10-12 (updated by this review); ASVS L1

## Scope

Everything merged since `v0.2.0` (`5b7cc3f`), 18 commits:

- `scripts/scaffold-lib.sh` `is_managed`: manifest paths with `..` are no longer managed (`4718ba7`,
  fixed during the 2026-10-12 code review, finding M1)
- `template/scripts/verify-refs.sh` `read_committed_version`: drops `GIT_DIR`/`GIT_WORK_TREE`
  and makes a relative `GIT_INDEX_FILE` absolute before reading the rules file (`cdc39b0`)
- `template/scripts/pack-context.sh`: new `--brief [REQ-nnn ...]` arguments, requirement files
  chosen by ID; `requirement_path` moved to `template/scripts/requirements-lib.sh`
- `template/scripts/check-requirements.sh` exact field matching; `template/scripts/lib.sh`
  `rewrite_file` write status and `stamp_release_or_restore`; both release scripts
- Requirement lookups changed from `printf | grep -q` to here-strings (`check-traceability.sh`,
  `verify-refs.sh`, `hooks/pre-commit`)
- `.github/workflows/scaffold-ci.yml`: runs on every branch push; ruleset on `main` (REQ-062)
- Add-on docs (`GETTING-STARTED.md`, `template/docs/optional-tools.md`): claude-mem,
  obsidian-skills, consolidated add-on notes; `opusplan` note in `template/CLAUDE.md`;
  clean-code import removed from `template/CLAUDE.md` and `template/.aider.conf.yml`

Out of scope: unchanged scripts (reviewed in earlier reports), the add-ons' own code (only the
documented storage and network behaviour was checked when they were added on 2026-10-12).

## Evidence

- `STRICT=1 scripts/check-scaffold.sh` at `51c25cb`: passed (9 passed, 0 failed, skipped: none;
  smoke test 503 assertions; gitleaks, shellcheck, semgrep and its rule tests included).
- `is_managed` read: `case "/$1/" in */../*)` rejects `..` as any segment, including first and
  last; regression test "project file behind a climbing manifest path kept" (`test_update_safety`).
- `pack-context.sh --brief` traced: an argument starting with `REQ-` is checked against
  `^REQ-[0-9]{3,}$` and then compared exactly (awk `$1 == id`) with the IDs of files listed by
  `find -type f` two levels below `docs/requirements`. `find` does not follow symbolic links, so
  a linked file or epic folder never appears; `append_section` refuses links as well. An ID with
  an embedded newline passes the line-based grep but matches no record and dies. Other arguments
  still go through `validate_prompt_names` (`^[a-z0-9-]+$`). Nothing is written before
  validation; the pack is built in a `mktemp` file and moved into place.
- `verify-refs.sh` read: the subshell changes only the environment for one `git show`; on any
  failure it falls back to the working-tree file, as before. Tests: "rule in a subfolder found
  with GIT_DIR exported (worktree hook)", "unknown rule still rejected with GIT_DIR exported".
- Release scripts read: the tree is verified clean before stamping, so `git checkout -- <files>`
  on failure discards only the script's own writes. Tests: "files restored after failed docs
  stamp", "scaffold release files restored after failed stamp".
- Workflow read: trigger `push` on `'**'`, `permissions: contents: read`, actions pinned by SHA,
  `persist-credentials: false` (asserted by `test_ci_credentials`).
- Add-on docs read: the claude-mem entry states where sessions are stored and that its hosted
  memory service receives session content; no install command runs from the scaffold.

## Limitations

- Static reading plus the regression tests named above; no fuzzing of `pack-context.sh` arguments.
- Running CI on every branch push spends runner minutes for any pushed branch; branches can only
  be pushed by collaborators, so this is not an abuse path for outsiders (forks run in their own
  repositories).
- The commit-msg and pre-commit hooks run on the committer's machine and can be skipped with
  `--no-verify`; CI and the `main` ruleset re-check (see the 0.2.0 report).

## Findings

| # | Severity | Location | Issue (what an attacker does) | Status |
|---|----------|----------|-------------------------------|--------|
| — | — | — | No new findings in the scope above. | — |

The security-relevant fix of this release, `is_managed` (a project's `.scaffold/manifest` could
make `update-scaffold.sh --apply` delete a project file), was found and fixed with a regression
test before this review (`4718ba7`); it is listed in `CHANGELOG.md` under Security.

## Remediation summary

Nothing to remediate. Threat model updated: `pack-context.sh` takes requirement IDs. Next
review: before the next release, or when a script starts reading a new file set or writing new
paths.
