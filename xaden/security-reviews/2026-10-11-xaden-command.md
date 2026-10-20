# Security review 2026-10-11 — xaden command and follow-ups

Written by `template/prompts/security-review.md` (`/security`, REQ-055).
A completed review records what was checked; it is not proof that the scaffold is secure.

- Reviewer: Claude Code (Claude Opus 5.5); maintainer asked for the review
- Version / commit: `28b95ab` (scaffold 0.1.0, unreleased)
- Threat model: `docs/threat-model.md` of 2026-10-11 (updated by this review); ASVS L1

## Scope

Changes since the first review (`docs/security-reviews/2026-10-11-scaffold-scripts.md`):

- `scripts/xaden.sh` and `scripts/install.sh` (REQ-056): new entry points, writes outside the
  checkout (`~/.local/bin/xaden`)
- `template/scripts/check-security-exceptions.sh` and its call in `check.sh` (REQ-057)
- `template/scripts/check-docs.sh --release` on `SECURITY.md` and the threat model (REQ-058)
- `.claude/settings.json` as a scaffold-managed path in `scripts/scaffold-lib.sh` (REQ-059)
- Refactors `61e15cd`, `8312b92`, `dea008c` in the update and generation code
- Both GitHub workflows (re-checked with zizmor)

Out of scope: unchanged scripts (reviewed in the first report), prompts and guides as text, the
logo image (inspected only: PNG without embedded text other than the creating software).

## Evidence

- `STRICT=1 scripts/check-scaffold.sh` at `2a96e59` (same code as `28b95ab`, which only adds the
  logo): passed, `9 passed, 0 failed, skipped: none`, smoke test 416 assertions, including
  `test_xaden_command`, `test_security_exceptions`, `test_settings_update`, `test_release` and
  the first review's `test_update_safety` and `test_ci_credentials`.
- `zizmor --offline` 1.30.1 on both workflows: no findings. With `--persona=auditor`: only
  `concurrency-limits` and `anonymous-definition` hints (no security impact).
- Manual reading of the scripts in scope for injection, option injection, path traversal,
  symlink handling, temporary files and what runs whose code.

Verified safe:

- `xaden create` passes the name to `new-project.sh`, which validates it before any use; the
  default target `$PWD/<name>` is built only from the validated name.
- `xaden update` resolves the project root with `git rev-parse --show-toplevel` and runs the
  checkout's own `update-scaffold.sh`, which keeps the symlink and manifest protections of the
  first review. Run in a repository that is no generated project, it stops at "cannot determine
  project name".
- Project commands are a fixed list mapped to fixed file names; arguments are passed as an
  array, never through a shell string.
- `install.sh` never replaces an existing file or link of that name and `--uninstall` removes
  only a link to this checkout (`readlink` compared with the exact path; smoke-tested).
- `resolve_link` cannot loop forever: a cyclic link cannot be executed in the first place (ELOOP).
- `check-security-exceptions.sh` only reads the file with `awk`; field values are compared,
  never executed. Its date comes from `date +%F` or a validated `CHECK_DATE`.
- `.claude/settings.json` updates use the three-way update: a project's own permission edits
  are kept and the scaffold's version arrives as `.scaffold-new` (smoke-tested).

## Limitations

- Linux was not tested (no remote, CI never ran); macOS only.
- actionlint is not installed; zizmor ran offline (no online audits such as known-vulnerable
  action versions).
- A completed checklist is not proof of security.

## Findings

| # | Severity | Location | Issue (what an attacker does) | Status |
|---|----------|----------|-------------------------------|--------|
| 1 | low | `scripts/xaden.sh` (`run_project_script`) | Someone who gets a user to run `xaden check`, `setup`, `req`, `pack` or `release` inside a repository they control runs their own `scripts/*.sh` with the user's rights. Same trust as typing `scripts/check.sh` there by hand, which the scaffold already requires; the short command makes it easier to forget. | accepted: by design, documented in `GETTING-STARTED.md` ("only in projects you trust") and in the threat model's accepted risks |

No other findings.

## Remediation summary

Fixed: none needed. Accepted: #1 (owner: maintainer; revisit if `xaden` ever runs project
commands automatically, e.g. from a shell hook). Open: none. Next review: before the first
release, after the first Linux CI run.
