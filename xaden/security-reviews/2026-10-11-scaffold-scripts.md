# Security review 2026-10-11 — scaffold scripts and CI

Written by `template/prompts/security-review.md` (`/security`, REQ-055).
A completed review records what was checked; it is not proof that the scaffold is secure.

- Reviewer: Claude Code (Claude Opus 5.5); fixes to be approved by the maintainer
- Version / commit: `0135aa3` (scaffold 0.1.0)
- Threat model: `docs/threat-model.md` of 2026-10-11 (updated by this review); ASVS L1

## Scope

First review of the scaffold, so the whole scaffold:

- `scripts/*.sh` (generation, update, release, checks, setup), `.githooks/*`
- `template/scripts/**` (checks, hooks, requirement tools, release, context pack, presets, stacks)
- `.github/workflows/scaffold-ci.yml`, `template/.github/workflows/ci.yml`
- `.claude/settings.json` of template and root

Entry points traced: CLI arguments of every script, files the scripts read (template, requirement
files, commit messages, `CHANGELOG.md`, `VERSION`, `.scaffold/manifest`, `package.json`,
`pyproject.toml`), environment (`PROJECT_ROOT`, `RULES_FILE`, `STRICT`, CI variables), downloads
in CI, the project directory `update-scaffold.sh` writes into.

Out of scope: prompt files and guides as text (no executable content), `tests/smoke.sh` itself,
upstream tools (gitleaks, semgrep, ruff, shellcheck, GitHub Actions) and their supply chain beyond
the pinning recorded in the threat model. Web-only WSTG areas (sessions, authentication, XSS,
CSRF, CORS) do not apply: there is no server.

## Evidence

- `STRICT=1 scripts/check-scaffold.sh` (shellcheck, gitleaks over history, semgrep local rules and
  rule tests, requirement and traceability checks, `tests/smoke.sh`): passed, `9 passed, 0 failed,
  skipped: none`; smoke test 380 assertions. gitleaks: no leaks; semgrep local rules: 0 findings.
  These scanners did not catch #1–#3.
- Proof of concept for #1 and #2 (scratch directory, not committed): generated `demo` with
  `scripts/new-project.sh`, then in the project appended a line to `.clinerules`, removed its
  manifest line, committed `.clinerules.scaffold-new -> ../victim.txt` and a manifest line for
  `src/app.py` with that file's checksum. `scripts/update-scaffold.sh <demo> --apply` printed
  `conflict .clinerules` and `remove src/app.py`; `victim.txt` outside the project then held the
  template's `.clinerules` text, and `git status` showed `D  src/app.py` staged.
- Manual reading of every script listed in the scope for injection (`sed`/`grep` patterns built
  from input, `eval`, unquoted expansion, option injection into `git`/`tar`), path traversal,
  temp-file handling, CI variable use and secret handling.

Verified safe (no finding):

- Project names: `is_project_name` (`[a-z][a-z0-9-]{1,50}`) is checked before any `sed`
  substitution or path use; `update-scaffold.sh` re-validates the name it reads from the project.
- `tar -T` lists in `export_template` start with the template prefix or `./`, never `-`, so no
  file name is read as an option.
- `verify-refs.sh`: IDs inserted into `grep`/`sed` patterns are extracted with
  `REQ-[0-9]{3,}|CC-[0-9]{2}` first. `verify-commits.sh` validates `BASE_REF` and `BEFORE_SHA`;
  `DEFAULT_BRANCH` is only used after `origin/`, so it cannot become an option.
- `pack-context.sh` validates prompt names (`[a-z0-9-]+`) and replaces the output with `mv`
  (no write through a symlink). `req.sh` validates IDs and epic names; titles are written with
  `printf %s`.
- Temporary files and directories come from `mktemp` and are removed by `trap … EXIT`.
- CI: `permissions: contents: read`, actions pinned by commit SHA, gitleaks download verified by
  SHA-256, CI event values passed through `env:` (no `${{ }}` inside `run:`).

## Limitations

- No dynamic testing beyond the proof of concept and the smoke test; zizmor and actionlint are
  not installed here, so the workflows were reviewed by hand only.
- Running `scripts/check.sh`, the hooks or CI on a repository executes that repository's code
  (stack tools, `npm ci` install scripts, `pip install -e .`). This is by design and not
  counted as a finding; it is why untrusted repositories must not be set up blindly.
- Assumptions about attackers come from the threat model; macOS CI tool versions are unpinned
  (accepted risk there).
- A completed checklist is not proof of security.

## Findings

| # | Severity | Location | Issue (what an attacker does) | Status |
|---|----------|----------|-------------------------------|--------|
| 1 | medium | `scripts/update-scaffold.sh:96-103`, `scripts/scaffold-lib.sh:91-98` | A contributor commits a symlink at a managed path, at a parent directory of one, at `<managed>.scaffold-new` or at `.scaffold`. When a maintainer runs `update-scaffold.sh --apply`, the script writes template text through the link and overwrites any file the user can write outside the project (e.g. `~/.bashrc`, `~/.ssh/authorized_keys`). Content is the template's, not the attacker's: loss of data or access, no code execution. Verified by proof of concept. | fixed, smoke `test_update_safety` |
| 2 | low | `scripts/update-scaffold.sh:63-69` | `candidate_paths` takes every path from the project's `.scaffold/manifest` without `is_managed`. A contributor adds a manifest line for a project-owned file (e.g. `src/app.py` with its checksum); the next update stages its deletion. Visible in `git diff --cached` and recoverable from git, so impact is limited. Verified by proof of concept. | fixed, smoke `test_update_safety` |
| 3 | low | `.github/workflows/scaffold-ci.yml:18`, `template/.github/workflows/ci.yml:21` | `actions/checkout` keeps the job token in `.git/config` (`persist-credentials` defaults to true) while later steps run repository and dependency code (`npm ci` install scripts, `pip install -e .`, tests). A malicious dependency reads the token. Impact is bounded by `contents: read` and short token lifetime; on push to `main` the token can still read private repositories' content. | fixed, smoke `test_ci_credentials` |

### Proposed fixes

#1 — refuse to write through symbolic links (new helper in `scaffold-lib.sh`, used by
`apply_action` for the target and the `.scaffold-new` file, and by `write_manifest`):

```bash
# has_symlink_on_path <root> <relative-path>: true if <path> or any directory between <root>
# and it is a symbolic link; writing there could leave <root>.
has_symlink_on_path() {
  local current=$1 rest=$2
  while [ -n "$rest" ]; do
    current="$current/${rest%%/*}"
    [ -L "$current" ] && return 0
    case "$rest" in */*) rest=${rest#*/} ;; *) rest="" ;; esac
  done
  return 1
}
```

```bash
# in apply_action, before the case:
local target="$path"
[ "$action" = conflict ] && target="$path.scaffold-new"
! has_symlink_on_path "$PROJECT" "$target" || die "refusing to write through a symbolic link: $target"
```

`write_manifest` refuses the same way for `$SCAFFOLD_STATE_DIR/version`, `project-name` and
`manifest`. Regression test in `tests/smoke.sh` (`test_scaffold_update`): a committed symlink
`.clinerules.scaffold-new` pointing outside makes `--apply` fail and leaves the target unchanged.

#2 — only managed paths from the manifest are candidates:

```bash
cut -f2 "$PROJECT/$SCAFFOLD_STATE_DIR/manifest" 2>/dev/null |
  while IFS= read -r file; do if is_managed "$file"; then printf '%s\n' "$file"; fi; done
```

Regression test: a manifest line for `src/app.py` leaves the file in place after `--apply`.

#3 — in both workflows:

```yaml
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
        with:
          fetch-depth: 0
          persist-credentials: false
```

`verify-commits.sh` only reads local history after the full-depth checkout, so it needs no token.
Regression test: smoke check that every `actions/checkout` step in both workflows sets
`persist-credentials: false`.

## Remediation summary

Fixed with maintainer approval in the `fix(security)` commit after `d12200e`: #1, #2 (`scripts/update-scaffold.sh`,
`scripts/scaffold-lib.sh`, smoke `test_update_safety`), #3 (both workflows, smoke
`test_ci_credentials`). Accepted: none. Open: none. An update that hits a symlink stops at that
file; actions applied before it stay staged (`git reset --hard` undoes them). Next review: before the next scaffold release, or when a script gains
a new entry point or write location.
