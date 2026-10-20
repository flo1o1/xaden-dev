# Security review 2026-10-13 — site page list and credential check (REQ-064)

Written by `template/prompts/security-review.md` (`/security`, REQ-055).
A completed review records what was checked; it is not proof that the scaffold is secure.

- Reviewer: Claude Code (Claude Sonnet 5.5), on the maintainer's request; the maintainer approved fixing findings
- Version / commit: `c104db5`..`a04b5cb` reviewed, fix in `b7373fa` (branch `feat/site-doc-paths`)
- Threat model: `docs/threat-model.md` of 2026-10-13; ASVS L1

## Scope

`docs/site-pages.txt`, `scripts/check-site-pages.sh`, its call in `scripts/check-scaffold.sh`, the
smoke test `test_site_pages`, and the "Website contract" section of `AGENTS.md`. Entry points: the
committed page list and the files under `.github/`; both are maintainer-controlled and committed.

Out of scope: the website repository (`bump-docs.yml`, `bump-docs-version.sh`, its token and CI)
is a separate repository with its own review; GitHub-side settings (rulesets, secrets).

## Evidence

- Path list entries are only tested with `[ -f ]`; nothing is read, executed or written. An entry
  like `../etc/passwd` is only checked for existence (tried: reported missing, no content read).
- Two defects found by running the script against crafted inputs (see Findings), each fixed with a
  regression test in `tests/smoke/release-and-docs.sh`.
- `STRICT=1 scripts/check-scaffold.sh` before the fix: 10 passed, 0 failed, skipped none. After the
  fix: `tests/smoke.sh release-and-docs` 64 assertions passed; commit hook (staged checks) passed.
  The full run was not repeated after the fix.

## Limitations

- The credential check is a text search for the word `secrets` in `.github/`. It cannot see
  tokens in other places (a repository secret used by a reusable workflow in another repository,
  a token written into a script) and does not know what a secret is allowed to do.
- It proves the absence of credentials in this repository only; whether the website repository's
  token is scoped narrowly is not verified here.
- Entries of `docs/site-pages.txt` are trusted; a page that exists but holds wrong content passes.

## Findings

| # | Severity | Location | Issue (what an attacker does) | Status |
|---|----------|----------|-------------------------------|--------|
| 1 | low | `scripts/check-site-pages.sh:13` | A last entry without trailing newline was never checked, so a missing site page passed the gate | fixed in `b7373fa` |
| 2 | low | `scripts/check-site-pages.sh:20` | `secrets.` matching missed `secrets["X"]`, `toJSON(secrets)` and `secrets: inherit`, so a site credential in a workflow passed | fixed in `b7373fa` |

## Remediation summary

Both findings fixed with regression tests; none open. Cosmetic: the "N present" count uses
`wc -l` and is one too low when the list has no trailing newline (does not affect the result).
Next trigger: any change to what the site renders or to who may push to it.
