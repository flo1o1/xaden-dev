# Security review 2026-10-12 — changes since 2026-10-11, before scaffold 0.2.0

Written by `template/prompts/security-review.md` (`/security`, REQ-055).
A completed review records what was checked; it is not proof that the scaffold is secure.

- Reviewer: Claude Code (Claude Opus 5.5); the maintainer approved fixes 1–3 on 2026-10-12
- Version / commit: `02cc165` (scaffold 0.1.0, release 0.2.0 pending)
- Threat model: `docs/threat-model.md` of 2026-10-11 (updated by this review); ASVS L1

## Scope

Everything merged since the last review (`2026-10-11-audit-fixes.md`, commits after `7fa5706`):

- `template/scripts/persona.sh` (new, REQ-061): CLI argument `<name>`, writes `docs/personas/<slug>.md`
- `template/scripts/pack-context.sh`: new `append_personas` glob over `docs/personas/*.md`;
  `append_section`, which all pack sections use
- `refuse_commit_on_protected_branch` in `template/scripts/lib.sh` and its callers: both
  pre-commit hooks, `scripts/new-project.sh`, `commit_release_or_restore` (REQ-060)
- `template/docs/personas/0000-template.md`, `template/prompts/persona.md`,
  `template/.claude/commands/persona.md`, the persona lines in AGENTS.md §9 and the prompts
- Token Optimizer add-on docs (`GETTING-STARTED.md`, `template/docs/optional-tools.md`),
  checked against the plugin's source (version 5.13.37)
- `actions/checkout` pin (`4832018`), shellcheck portability fix (`09e78f5`)

Out of scope: unchanged scripts (reviewed 2026-10-11), prompts as text beyond the persona
changes, Token Optimizer's code beyond where and how it stores tool output.

## Evidence

- `STRICT=1 scripts/check-scaffold.sh` at `02cc165`: passed (9 passed, 0 failed, skipped: none;
  smoke test 456 assertions; gitleaks, shellcheck, semgrep rule tests included).
- Finding 1 reproduced in a generated throwaway project: `docs/personas/eve.md` as a symlink to
  a file outside the project holding `FAKE_SECRET=xyz`; `scripts/pack-context.sh` put
  `FAKE_SECRET=xyz` into the pack under `# USER PERSONA (docs/personas/eve.md)`.
- Finding 2 reproduced: `docs/personas/mallory.md` as a dangling symlink to a path outside the
  project; `scripts/persona.sh new Mallory` created that outside file with the template content.
- `persona.sh` name validation read: one line, at most 60 characters, no `/ \ & :`; the slug
  contains only `a-z0-9-`, so the file name cannot leave `docs/personas/`. The sed replacement
  cannot be broken out of with the allowed characters.
- Branch guard read: allowed with `ALLOW_MAIN_COMMIT=1`, while `MERGE_HEAD` exists and on a
  detached HEAD; the branch name comes from git (no control characters possible in ref names).
- Token Optimizer source (`archive_result.py`): large tool results are archived to disk under
  its snapshot directory in the user's home (`tool-archive/<session>`), files `0600`, credentials
  redacted by pattern before writing, old archives cleaned up by age.
- Workflows: every action pinned by commit SHA (`actions/checkout@3d3c42e…` v7.0.1).

## Limitations

- Static reading plus two reproductions; no fuzzing of `persona.sh` names.
- The pre-commit guard runs on the committer's machine only. `git commit --no-verify`,
  `ALLOW_MAIN_COMMIT=1` or a detached HEAD skip it. At review time the scaffold repository had
  no server-side branch protection (private repository on the free plan), so the guard kept
  honest assistants on branches but did not stop a deliberate push to `main`. Update
  2026-10-12: the repository is public and ruleset 24936940 rejects a push to `main` unless
  `check (ubuntu-latest)` and `check (macos-latest)` passed on that commit, without bypass
  (REQ-062; verified: a push before CI was rejected with GH013). No review is required.
- Token Optimizer's redaction is pattern-based; secrets it does not recognise stay in the
  archive. Its other hooks and any network behaviour were not reviewed (unverified).

## Findings

| # | Severity | Location | Issue (what an attacker does) | Status |
|---|----------|----------|-------------------------------|--------|
| 1 | low | `template/scripts/pack-context.sh:36` (`append_section`), new caller at `:65` | A contributor commits `docs/personas/<name>.md` (or any packed file) as a symlink to an absolute path such as `~/.aws/credentials`; a symlink is easy to miss in a pull request. The next `scripts/pack-context.sh` copies that file's content into the pack, which the user pastes into a chat assistant. The persona glob takes any number of files, so it widens an existing gap. | fixed in `9e51325` |
| 2 | low | `template/scripts/persona.sh:38-39` | A contributor commits `docs/personas/<slug>.md` as a dangling symlink to a path outside the project. `persona.sh new "<name>"` sees no file (`-e` follows the link) and writes the template through the link, creating a file outside the project (e.g. in an autostart folder; content comes from `0000-template.md`, which the same contributor can edit). | fixed in `4e14f62` |
| 3 | low | `GETTING-STARTED.md:66`, `template/docs/optional-tools.md:54` | Not an attack: the docs do not say that Token Optimizer keeps full tool output on disk. A user who printed a secret in a session (e.g. a command's output) keeps a copy in the archive unless the pattern redaction catches it. | fixed in `d81e508` (documented) |
| 4 | info | `template/scripts/lib.sh:214` | The branch guard is client-side and bypassable (see Limitations). AGENTS.md §7 calls it a refusal by the hook, which is accurate; recorded so nobody treats it as a security control. | accepted (design); server-side ruleset added afterwards (REQ-062) |

Proposed fixes:

```bash
# 1 — pack-context.sh: never follow a link into the pack
append_section() {
  [ ! -L "$2" ] || die "refusing to pack a symbolic link: ${2#"$ROOT"/}"
  printf '\n# %s\n\n' "$1" >>"$PACK"
  strip_frontmatter "$2" >>"$PACK"
}

# 2 — persona.sh: a dangling link counts as existing
[ ! -e "$path" ] && [ ! -L "$path" ] || die "persona exists already: ${path#"$ROOT"/}"
```

3 — one sentence in both docs: "It archives full tool output on disk in your home directory
(private file permissions, credentials redacted by pattern only); do not print secrets in a
session."

## Remediation summary

Findings 1–3 fixed, each with a regression test in `tests/smoke.sh` (`test_personas`,
`test_add_on_rule_sets`) that failed before the fix. Finding 4 accepted as a design limit. Next review: before the next release,
or when a script starts reading a new file set (globs) or writing new paths.
