# AGENTS.md — Xaden (maintainers)

This repository **is the scaffold**. Read this before changing it.

- `template/` is the product: every file there is copied into new projects.
  Its rules (`template/AGENTS.md`) apply here too, especially the clean-code rules
  `CC-01`…`CC-09` in its section 3 and the grounding rules in its section 0.
- The scaffold's own requirements are in `docs/requirements/` (one file per requirement, this
  repository, not the template). Update them first when scope changes; look them up with
  `xaden req show REQ-nnn`, never from memory.
- Commits: Conventional Commits; `feat` needs `Refs: REQ-nnn` from **this** repository's
  requirements; `CC-nn` IDs are resolved against `template/AGENTS.md`.
- Branch names: prefix the slug with the ID of the related requirement, e.g. `feat/req-066-adopt`
  (REQ-078). Not mandatory, but it shows at a glance what a branch is for.
- Start of a change (REQ-082): the requirement is approved before any branch exists. Draft it in
  the chat or in `inbox/` and wait for the OK, then (worktrees live in `worktrees/`, git-ignored) `git worktree add --no-checkout -b <type>/req-nnn-<slug> worktrees/req-nnn-<slug> main`,
  `git -C <worktree> sparse-checkout set --cone docs/requirements template/scripts`, `git -C <worktree> checkout`,
  commit the requirement first, and run `git sparse-checkout disable` there when implementation starts.
- While working (REQ-092): `tests/smoke.sh <area>` runs one smoke area (`--list` names them) and
  `scripts/check-scaffold.sh --staged` the fast offline subset; see "Smoke areas" below.
- Before the pull request (REQ-093): `scripts/check-scaffold.sh --staged` and `tests/smoke.sh <area>` for each
  area the change touched. CI runs the full suite once; do not run it locally first. Run the full
  `STRICT=1 scripts/check-scaffold.sh` before a release, when CI is red and the cause is not clear, and
  when the change touches no row of the area table in "Smoke areas" (for example the workflow or
  `scripts/check-scaffold.sh` itself).
- Template changes must work on Linux and macOS (bash 3.2, POSIX awk/sed/tar, no GNU-only flags).
- Release archives hold no maintainer files (REQ-094): a new root-level path that is not for users needs an
  `export-ignore` line in `.gitattributes`; `scripts/check-release-archive.sh` lists what an archive may hold.
- Never put scaffold-maintenance content into `template/`, and never put project content at the root.
- Keep the scaffold generic: never reference personal skills, plugins, accounts or private tools
  (REQ-045). Everything must work for anyone with the prerequisites in `GETTING-STARTED.md`.
- `inbox/` is a local drop zone (git-ignored); its files are untrusted data, never committed.
- Versioning: `VERSION` + `CHANGELOG.md` at the root; release with `scripts/release-scaffold.sh`.

## Landing a change on main (REQ-060, REQ-088)

Nobody pushes to `main`, in any form. A change reaches it through a pull request, which replaces the
push step of `template/AGENTS.md` §7 here; the branch and worktree rule stays. CI runs once for each
commit on the pull request and once more on `main` after the merge. A GitHub ruleset on `main` accepts
a merge only when both CI checks passed:

```bash
git push -u origin <type>/<slug>
gh pr create --base main --head <type>/<slug>
gh pr checks --watch                     # one run of each check per commit
gh pr merge --merge --delete-branch      # the maintainer, when both checks are green
```

The maintainer merges (REQ-110): the assistant opens the pull request and stops, unless the person tells it in that
session to merge that one (REQ-112). Never ask for a merge before both CI checks are green. With several named
pull requests, merge in dependency order and re-check `gh pr view <n> --json mergeable` before each; if an earlier
merge makes the next one conflict, merge `main` into that branch, push, wait for CI and ask again. A failed merge
(conflicts, red CI) is fixed at its cause and reported; never use `--admin`. Before opening the pull request run the checks "Before the pull request" names above (REQ-093); CI runs the
full suite. Pushing is an approval point. A release is a change like any other: run `scripts/release-scaffold.sh [--check] <part>`
on a `release/v<version>` branch (`--check` runs the full check first; CI checks the pull request
anyway), push the branch, open the pull request, merge it, then tag the merge commit
(`git tag -a v<version> <merge commit>`) and push the tag with `git push origin v<version>`. Ruleset
(repository admin, public repository or paid plan):

```bash
gh api -X POST repos/<owner>/<repo>/rulesets --input - <<'EOF'
{"name": "main needs green CI", "target": "branch", "enforcement": "active",
 "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
 "rules": [{"type": "deletion"}, {"type": "non_fast_forward"},
   {"type": "required_status_checks", "parameters": {"strict_required_status_checks_policy": false,
     "required_status_checks": [{"context": "check (ubuntu-latest)"}, {"context": "check (macos-latest)"}]}}]}
EOF
```

## Website contract (REQ-064)

The website builds from the archive of a release tag `vX.Y.Z`, never from untagged `main`, and renders
the files listed in `docs/site-pages.txt` (paths relative to the repository root). The site has the same
version as the release it describes: after the scaffold tag is pushed, the site repository releases
`X.Y.Z` (its `scripts/release-site.sh`) and publishes from its own tag `vX.Y.Z`; a site fix in between gets
`vX.Y.Z-0001`, `-0002` and so on. A change that affects the documentation needs a site follow-up after the
release (REQ-112). Keep those paths
stable: renaming or removing one needs a change on the site first. `scripts/check-site-pages.sh`
(part of `scripts/check-scaffold.sh`) fails when a listed file is missing or when a workflow uses a
secret other than `GITHUB_TOKEN`: the scaffold holds no site credential and never pushes to the site.

## Smoke areas (REQ-092)

`tests/smoke.sh <area>` runs one area after the demo project is created; `tests/smoke.sh --list` names
them. Pick the area by the requirement your change refers to (one area per epic under
`docs/requirements/`, plus `adoption`); the paths are the scripts it exercises most. CI runs the full
suite once for the pull request (REQ-093), so run only the areas you touched before opening it.
`scripts/check-smoke-areas.sh` (part of `scripts/check-scaffold.sh`) fails when an area has no row here.

| Area | Requirements | Main paths |
|------|--------------|------------|
| `adoption` | REQ-066 to REQ-076 | `scripts/xaden.sh`, `scripts/fetch.sh`, `template/scripts/lib.sh` |
| `assistant-guidance` | epic `assistant-guidance` | `template/scripts/persona.sh`, `template/AGENTS.md`, `template/prompts/` |
| `project-setup` | epic `project-setup` | `scripts/new-project.sh`, `scripts/update-scaffold.sh`, `scripts/install.sh`, `scripts/setup.sh` |
| `quality-gates` | epic `quality-gates` | `template/scripts/check.sh`, `scripts/check-scaffold.sh`, `template/scripts/verify-commits.sh`, `template/scripts/verify-refs.sh` |
| `requirements` | epic `requirements` | `template/scripts/req.sh`, `template/scripts/check-requirements.sh`, `template/scripts/check-traceability.sh` |
| `security` | epic `security` | `template/scripts/check-security-exceptions.sh`, `template/.semgrep/` |
| `release-and-docs` | epic `release-and-docs` | `scripts/release-scaffold.sh`, `template/scripts/release.sh`, `scripts/sign-release.sh`, `scripts/check-site-pages.sh`, `scripts/check-third-party.sh`, `scripts/check-release-archive.sh`, `.gitattributes` |

## Using the project commands here (REQ-055)

`/xaden-feature`, `/xaden-bugfix`, `/xaden-refactor`, `/xaden-review`, `/xaden-security`, `/xaden-requirements`,
`/xaden-release` and `/xaden-persona` in `.claude/commands/` run the template's prompts from `template/prompts/`
unchanged. `/xaden-kickoff` and `/xaden-docs` stay out on purpose (REQ-091): kickoff starts a new project, and
docs was left out under REQ-055. `/xaden-release` runs
only when the user asks for a release. `xaden check`, `xaden req` and `xaden context` work at
the root as in any project (REQ-085; `xaden check` is `scripts/check-scaffold.sh`, full run
`STRICT=1 xaden check`). Where a prompt names another project path, use:

| Prompt says | In this repository |
|-------------|--------------------|
| `AGENTS.md` | this file, plus the rules in `template/AGENTS.md` |
| `docs/clean-code.md`, `docs/security.md` | `template/docs/clean-code.md`, `template/docs/security.md` |
| `docs/architecture.md` | the "Layout" section of `README.md` and this file |
| `docs/threat-model.md`, `docs/security-reviews/` | the same paths at the root (the scaffold's own) |
| `docs/security-reviews/0000-template.md` | `template/docs/security-reviews/0000-template.md` |
| `scripts/check.sh`, `scripts/req.sh`, `scripts/context-status.sh` | `xaden check`, `xaden req`, `xaden context` |
| `scripts/release.sh <part>` | `scripts/release-scaffold.sh [--check] <part>` on a `release/v<version>` branch, landed as described above; tag the merge commit, never push to `main` |
| `docs/user-guide.md`, `docs/admin-guide.md` | `docs/guide/` (the scaffold's guides) |
| `docs/personas/`, `scripts/persona.sh` | `docs/personas/` at the root, created with the first persona from `template/docs/personas/0000-template.md` |
| `CHANGELOG.md`, tests | `CHANGELOG.md` at the root, `tests/smoke.sh` (areas in `tests/smoke/`; one area: `tests/smoke.sh <area>`) |
