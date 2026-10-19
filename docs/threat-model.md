# Xaden — Threat model

The scaffold's own threat model, read by `/xaden-security` in this repository (REQ-055). Generated
projects get their own from `template/docs/threat-model.md`. Update this file when a change
adds an entry point, a downloaded tool or a new place the scripts write to.

**Last reviewed:** 2026-10-13, security review `docs/security-reviews/2026-10-13-pre-release-0.2.2.md`
(previous: `2026-10-13-pre-release-0.2.1.md`, `2026-10-12-pre-release-0.2.0.md`, `2026-10-11-audit-fixes.md`, `2026-10-11-xaden-command.md`, `2026-10-11-scaffold-scripts.md`).

## System summary

Bash scripts and Markdown files. Maintainers and users run the scripts on their own machines
(Linux, macOS) to generate projects, update them and check them; the same scripts run in GitHub
Actions for the scaffold and for every generated project. No server, no network service, no
stored user data.

## Assets

- Integrity of generated projects: only reviewed template content, hooks that really check.
- Users' machines and CI runners: the scripts run with the user's rights on every commit.
- Secrets near the scaffold or a project (`.env`, keys) that must never be copied or committed.
- Trust in the gates: a green check, a valid `Refs:` trailer and a release tag mean what they say.

## Sensitive data

None stored by the scaffold. Scripts read git metadata (author names and emails in commits) and
may meet secrets in the working tree (`.env`, `inbox/`), which they must not copy, commit or print.

## Entry points

- CLI arguments: project name and target directory (`new-project.sh`), project directory and
  `--apply` (`update-scaffold.sh`), bump part (`release*.sh`),
  requirement IDs, epics and titles (`req.sh`), persona names (`persona.sh`); command and arguments of `xaden`, target
  directory of `install.sh`; `adopt`, `remove`, `upgrade`, `fetch`, `hook`, `prompt`, `doc` and `new --autopilot`
  with their options (`--check <kind>=<command>`, `--assistants`, `--mode`, `--stack`, version numbers).
- Files the scripts read: `template/` (exported to projects), requirement files, commit message
  files, the old requirements table `docs/requirements/REQUIREMENTS.md` (`migrate-requirements.sh`),
  `docs/personas/*.md` (`persona.sh`), `CHANGELOG.md`, `VERSION`, `docs/security-exceptions.md`, `SECURITY.md`, a project's
  `.scaffold/manifest` and `package.json` /
  `pyproject.toml` (which decide which tools run).
- Files of an adopted repository: `xaden/xaden.conf` (version, checksum, mode and the commands `check.<name>`
  that `xaden check` runs), `xaden/footprint.txt` (paths `xaden remove` deletes), `xaden/baselines/`,
  `xaden/prompts/`, the existing `AGENTS.md`, `CLAUDE.md`, hook files and workflows.
- Environment: `XADEN_HOME`, `XADEN_RELEASES_URL`, `XADEN_LATEST_URL`, `XADEN_PLAIN`, `XADEN_UPDATE_CHECK`; `XADEN_TEST_MODE` and
  `XADEN_TEST_ANSWER`, `XADEN_NOW` (tests only; ignored without `XADEN_TEST_MODE=1`); `PROJECT_ROOT`, `RULES_FILE`, `STRICT`, `ALLOW_MAIN_COMMIT`, `PATH`; the current
  branch (pre-commit branch guard); in CI `EVENT_NAME`, `BASE_REF`,
  `BEFORE_SHA`, `DEFAULT_BRANCH`, filled from GitHub event data.
- Release archives of Xaden itself from GitHub (`fetch.sh`, only after a person's yes) and the release API
  (`xaden pin --check` and `xaden upgrade --check`, same). The update check (REQ-084, run as `xaden upgrade --check --if-due`, REQ-130) asks the same API without a yes each time, but only when
  the person set `update-check` in `xaden/xaden.conf` or `XADEN_UPDATE_CHECK` (off by default); it also runs `npm outdated` and
  `pip list --outdated` in the project (`upgrade --check` asks for a yes and runs them too). Its result is cached in `.git/xaden-update-check` and printed by `doctor` and
  `context-status.sh`, which an assistant reads: names are filtered to package-name characters before they are cached.
- Downloaded tools in CI: gitleaks archive, semgrep and ruff from PyPI, GitHub Actions, Homebrew.
- `inbox/`: files dropped by the user, untrusted by definition.

## Trust boundaries

- Untracked or ignored files in `template/` vs. the reviewed, tracked template content.
- A project's own files vs. the files the scaffold manages there (`update-scaffold.sh`).
- Pull-request and push data (branch names, commit messages) vs. the CI shell.
- Downloads from GitHub, PyPI and Homebrew vs. the CI runner.
- A release archive from the network vs. the installed versions folder (`fetch.sh`): checked for unsafe members,
  then for the checksum pinned in the project, before anything is installed.
- A repository's `xaden/xaden.conf` vs. the machine: its `check.*` commands run on `xaden check` and in the hooks,
  like the repository's own test scripts.
- Content in `inbox/`, prompts' task input and tool output vs. instructions the assistant follows.

## Attackers and capabilities

- Contributor sending a pull request: controls branch names, commit messages and file contents.
- Contributor to a generated project, or the author of a project cloned from elsewhere: controls
  its tracked files, including symbolic links and `.scaffold/manifest`, which
  `update-scaffold.sh` reads and writes next to.
- Compromised upstream tool or action: code runs in CI with the job's permissions (read-only
  repository token).
- Malicious file in `inbox/` or pasted content: tries to make the assistant run commands or
  commit secrets (prompt injection).
- Careless use: a secret left in `template/`, a project name with shell or path characters.

## Deployment assumptions

Runs as the invoking user; no `sudo` except tool installation in CI. CI jobs use
`permissions: contents: read`. Nothing is pushed or published by the scripts. `scripts/install.sh` writes one symbolic link
(`~/.local/bin/xaden` by default) and nothing else outside the checkout.

## Security baseline

Verification standard: OWASP ASVS (what to build), OWASP WSTG (how to test it).

- ASVS level: L1, applied to input validation, secrets handling and build and dependency
  integrity.
- Not applicable areas: no web client, sessions, authentication or authorization of users;
  web-only WSTG items do not apply.

## Threats and mitigations

| Threat | Asset | Mitigation | Requirement / test |
|--------|-------|------------|--------------------|
| Project name with shell, `sed` or path characters | users' machines | `is_project_name` allows `[a-z][a-z0-9-]{1,50}` only | REQ-001, smoke "reject bad project name" |
| Secrets, dependencies or symlinks copied into a project | secrets, project integrity | only tracked template files exported; symlinks refused; failed runs cleaned up | REQ-018, smoke `test_generation_safety` |
| Dangling symlink in `docs/personas/` makes `persona.sh` write outside the project | users' machines | a link counts as an existing persona (review 2026-10-12-pre-release-0.2.0 #2) | REQ-061, smoke `test_personas` |
| Commit lands on `main` without passing CI | trust in the gates | pre-commit guard keeps work on branches (client-side; `--no-verify`, `ALLOW_MAIN_COMMIT=1`, detached HEAD skip it); GitHub ruleset on `main` accepts a merge only when both CI checks passed on the pull request, no bypass; nobody pushes to `main`; no review required (single maintainer) | REQ-060, REQ-088, smoke `test_branch_rule`, `test_ci_credentials` |
| Secret committed | secrets | gitleaks in pre-commit and CI; a missing scanner fails `--strict` | REQ-004, REQ-019, smoke `test_missing_tools`; no test plants a secret yet |
| Unstaged fix hides a staged problem | trust in the gates | checks run on an export of the git index | REQ-020, smoke `test_staged_snapshot` |
| Commit cites invented requirements or slips past checks | trust in the gates | ID and trailer checks on every commit, re-run in CI | REQ-011, REQ-022, smoke `test_commit_bypasses` |
| Malicious `BASE_REF` in CI | CI runner | value validated before use | REQ-022, smoke "CI rejects a malformed base ref" |
| Update overwrites a project's own edits | project integrity | three-way comparison; conflicts written as `*-dist` | REQ-017, smoke `test_scaffold_update` |
| Symlink in a project redirects an update's writes outside the project | users' machines | writes refused when the path or a parent is a symlink (review 2026-10-11 #1) | REQ-017, smoke `test_update_safety` |
| Edited manifest makes an update delete project-owned files | project integrity | manifest paths outside `MANAGED_PATHS` ignored (review #2) | REQ-017, smoke `test_update_safety` |
| Crafted ID in an old requirements table makes the migration write outside `docs/requirements/` | users' machines | every ID must be `REQ-nnn` before anything is written (review 2026-10-11-audit-fixes #1) | REQ-048, smoke `test_requirements_migration` |
| Impossible expiry date keeps an accepted vulnerability "valid" | trust in the gates | month 01–12 and day 01–31 required (review 2026-10-11-audit-fixes #2) | REQ-057, smoke `test_security_exceptions` |
| `fix` trailer with any text containing "none" passes | trust in the gates | only the exact value `none` replaces a requirement (review 2026-10-11-audit-fixes #3) | REQ-022, smoke `test_commit_bypasses` |
| Repository token left in `.git/config` while CI runs project code | CI runner | `persist-credentials: false` on every checkout (review #3) | REQ-019, smoke `test_ci_credentials` |
| `install.sh` replaces a user's own `xaden` file, or `--uninstall` removes one | users' machines | never overwrites an existing name; removes only a link to this checkout | REQ-056, smoke `test_xaden_command` |
| `xaden` project commands run a malicious project's scripts | users' machines | same trust as running `scripts/*.sh` by hand; documented in GETTING-STARTED ("only in projects you trust"); commands are a fixed list | REQ-056 |
| Tampered gitleaks download in CI | CI runner | pinned version, SHA-256 verified | REQ-019 |
| A downloaded release is not what the project pinned, or is a different build | users' machines | the download is installed only when its SHA-256 tree checksum equals the one in `xaden/xaden.conf`; the question shows version, source and checksum and defaults to no; no terminal means no download (exit 3); a test greps the scripts for other network calls | REQ-072, smoke `test_versions_and_downloads` |
| Release archive with `..`, absolute paths or links writes outside the versions folder | users' machines | `safe_archive` rejects such members before extraction; size limit on the download | REQ-072, smoke `test_versions_and_downloads` |
| A substituted release comes with a matching checksum | users' machines | the checksum is signed with the maintainer's SSH key and verified against `release-signers`; a bad signature exits with code 6 and installs nothing; `XADEN_SIGNERS_FILE` works only in test mode | REQ-077, smoke `test_versions_and_downloads` |
| An assistant, script or IDE answers the download question | users' machines | the answer is read from the terminal only; `XADEN_TEST_ANSWER` works only with `XADEN_TEST_MODE=1`; AGENTS.md §10 tells assistants never to answer | REQ-072, smoke `test_messages` |
| `xaden remove` or a hook edit deletes a team's own text | project integrity | only marked blocks and the files listed in `xaden/footprint.txt` are touched; paths with `..` or leading `/` are refused; text outside the markers is never changed | REQ-066, REQ-073, smoke `test_adopt_and_remove` |
| A new Xaden on one machine changes the rules for everyone | trust in the gates | tooling is selected by the pinned version; `RULES.md` that differs from the pinned version fails the check; `upgrade` is a reviewed pull request | REQ-070, REQ-071, smoke `test_versions_and_downloads` |
| Legacy findings are hidden by a baseline that grows | trust in the gates | the baseline only shrinks; mode changes and baseline growth are approval points | REQ-068, smoke `test_modes_and_baselines` |
| Instructions hidden in `inbox/` or pasted content | users' machines, secrets | `inbox/` ignored by git; AGENTS.md §10 treats it as data | REQ-026, REQ-033 |

## Accepted risks

- `xaden check` and the hooks run the commands in `check.*` of `xaden/xaden.conf`, the same trust as running the
  repository's own test and lint scripts. A pull request that changes `xaden.conf` therefore needs the same
  review as one that changes a build script. The adoption pull request and every `xaden pin` show it.
- A release without a signature (or while `release-signers` holds no key) is pinned by the checksum of the
  archive just downloaded (trust on first use); the person sees the checksum and the team reviews it in the
  pull request. A stolen signing key or a maintainer who signs something malicious is not covered.

- `xaden setup|check|req|release` run the current repository's own `scripts/*.sh`, the
  same trust as running them by hand; use them only in projects you trust (review
  2026-10-11-xaden-command #1).
- `update-scaffold.sh` changes a project's Claude Code permissions (`.claude/settings.json`,
  REQ-059) when the project left the file unchanged; edited files are kept.
- The macOS CI job installs Homebrew's current shellcheck, semgrep, ruff and gitleaks without
  pinning; the Linux job is the pinned reference.
- semgrep and ruff are pinned by version from PyPI, not by hash.
