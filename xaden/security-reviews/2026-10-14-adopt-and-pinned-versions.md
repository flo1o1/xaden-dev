# Security review 2026-10-14 — adopting Xaden, pinned versions and downloads (REQ-066 to REQ-076)

Written by `template/prompts/security-review.md` (`/security`, REQ-055).
A completed review records what was checked; it is not proof that the scaffold is secure.

- Reviewer: Claude Code (Claude Sonnet 5.5), on the maintainer's request
- Version / commit: branch `feat/adopt` after `e9387c8` (before the next release)
- Threat model: `docs/threat-model.md` of 2026-10-14; ASVS L1

## Scope

`scripts/fetch.sh` (downloads, checksum, `upgrade`), `scripts/adopt.sh`, `scripts/adopt-lib.sh`,
`scripts/adopt-scan.sh`, `scripts/autopilot.sh`, `scripts/xaden.sh` (version selection, hooks),
`template/scripts/layout.sh`, `gate.sh`, the messages in `lib.sh`, and `scripts/adopt/ci.yml`.
Entry points: command-line options, `xaden/xaden.conf`, `xaden/footprint.txt`, release archives from the
network, and the environment variables in the threat model.

Out of scope: the website; GitHub-side settings; the behaviour of the repository's own build commands.

## Evidence

- Release archives are written to a temporary file, listed with `tar -t`, and rejected for absolute paths,
  `..` segments and links before extraction; tried with a crafted `..` member and a symlink member
  (smoke `test_versions_and_downloads`: both refused, nothing installed, nothing written outside).
- A download is installed only when `tree_checksum` equals the pinned value; a wrong value exits with code 5
  and installs nothing (smoke). No terminal: exit code 3, nothing downloaded (smoke). `XADEN_TEST_ANSWER` has
  no effect without `XADEN_TEST_MODE=1` (smoke `test_messages`).
- `grep` over `scripts/` and `template/scripts/` finds `curl`, `wget` and `git clone|fetch|pull|ls-remote`
  only in `scripts/fetch.sh` (smoke).
- `xaden remove` reads paths from `xaden/footprint.txt`; entries that start with `/`, contain `..` or are
  empty abort the run before anything is deleted (code review of `remove_adoption`).
- Configuration is parsed (`conf_get`), never sourced; check names must match `[a-z][a-z0-9-]*`.
- `STRICT=1 scripts/check-scaffold.sh` before this review was written: see the result recorded in the release notes of the next release.

## Limitations

- The checksum protects against a different build of the same version. Signatures (REQ-077) add that the checksum
  comes from the maintainer, but only once the maintainer's public key is in `release-signers`; until then, and for
  older releases, `upgrade <version>` pins the checksum of the first download it sees. A stolen key or a
  maintainer who signs something malicious is not covered.
- `check.*` commands in `xaden/xaden.conf` run as the person who runs `xaden check`; reviewing changes to that
  file is the control. The scan reads files and never runs the repository's code; applying a plan does run the
  check commands once, to record the baselines, and says so in the plan.
- The contradiction scan is a phrase search; it misses rules worded differently and flags some neutral lines.
- Hook chaining appends to existing shell hooks; a hook written in another language is refused with a manual
  step, a hook manager that regenerates its hooks (`pre-commit install`) drops the block until `xaden setup`.
- `tree_checksum` hashes file names and contents, not file modes.

## Findings

| # | Severity | Location | Issue (what an attacker does) | Status |
|---|----------|----------|-------------------------------|--------|
| 1 | medium | `scripts/fetch.sh` `safe_archive` | A first draft piped `tar -t` into `grep -q`; `grep` closing the pipe made `tar` die of SIGPIPE and `pipefail` hid the match, so an archive with `..` members would have passed. Found in code review before the first test run; the crafted-archive tests now cover it | fixed, tests in `test_versions_and_downloads` |
| 3 | medium | `scripts/fetch.sh` `tools_for` | `exit` inside `$(install_release ...)` only left the subshell, so a bad signature or a checksum mismatch on `upgrade` did not stop the script: it went on with an empty checksum and no installed copy. Found by the signature tests | fixed (`|| exit $?`), covered by the exit-code assertions |
| 2 | low | `scripts/adopt-lib.sh` `remove_block` | The first version left a blank line behind, so `xaden remove` did not restore the file exactly | fixed, covered by `test_adopt_and_remove` |

## Remediation summary

Both findings fixed with tests; none open. Next trigger: any new network call (it must live in `fetch.sh`),
any new place that deletes files, or signed releases.
