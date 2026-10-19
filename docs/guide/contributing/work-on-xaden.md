# Work on Xaden

How a change to Xaden itself is made, checked and landed. The rules are in `AGENTS.md` and `template/AGENTS.md` of the repository; this page is the short version.

## Before you start

- Read `AGENTS.md` and `template/AGENTS.md`. The clean-code rules `CC-01` to `CC-09` of the template apply to Xaden's own code.
- Template changes must work on Linux and macOS: bash 3.2, POSIX awk, sed and tar, no GNU-only flags.
- Keep Xaden generic. Never reference personal skills, plugins, accounts or private tools.
- `inbox/` is a local drop zone. Its files are untrusted data and are never committed.
- Run `scripts/setup.sh` once: it installs the maintainer hooks and checks that the tools are there.

## Requirements first

Xaden's own requirements are in `docs/requirements/`, one file per requirement in an epic folder. When scope changes, update them first and look them up with
`xaden req show REQ-nnn`, never from memory. A requirement is drafted and approved before any branch exists.

## Branch and worktree

Every change has its own branch `<type>/<slug>` (prefix the slug with the requirement, for example `feat/req-066-adopt`) in its own folder under `worktrees/`. Nobody commits on `main`;
the pre-commit hook refuses it.

```bash
git worktree add --no-checkout -b feat/req-066-adopt worktrees/req-066-adopt main
git -C worktrees/req-066-adopt sparse-checkout set --cone docs/requirements template/scripts
git -C worktrees/req-066-adopt checkout
```

- `git worktree add --no-checkout ...`: creates the branch and its folder without checking files out yet.
- `sparse-checkout set --cone ...`: limits the first checkout to what the requirement commit needs. Run `git sparse-checkout disable` in that folder when implementation starts.
- `checkout`: fills the folder.

Commit the requirement first. Commits follow Conventional Commits, and a `feat` commit needs a `Refs: REQ-nnn` trailer from this repository's requirements.

## Check while you work

```bash
scripts/check-scaffold.sh --staged   # the fast offline subset
tests/smoke.sh --list                # names the smoke areas
tests/smoke.sh project-setup         # runs one area
```

- `scripts/check-scaffold.sh --staged`: the checks the pre-commit hook runs.
- `tests/smoke.sh <area>`: runs one area of the end-to-end test. Pick the area by the requirement your change refers to; CI runs the full suite once for the pull request, so run only the areas you touched.

| Area | Covers | Main paths |
|------|--------|------------|
| `adoption` | adopting a repository, pinned versions, downloads | `scripts/xaden.sh`, `scripts/fetch.sh`, `template/scripts/lib.sh` |
| `assistant-guidance` | the rules and prompts assistants follow | `template/scripts/persona.sh`, `template/AGENTS.md`, `template/prompts/` |
| `project-setup` | creating and installing | `scripts/new-project.sh`, `scripts/install.sh`, `scripts/setup.sh` |
| `quality-gates` | the checks | `template/scripts/check.sh`, `scripts/check-scaffold.sh`, `template/scripts/verify-commits.sh` |
| `requirements` | requirement tracking | `template/scripts/req.sh`, `template/scripts/check-requirements.sh` |
| `security` | security checks and exceptions | `template/scripts/check-security-exceptions.sh`, `template/.semgrep/` |
| `release-and-docs` | releases, signing and documentation | `scripts/release-scaffold.sh`, `scripts/sign-release.sh`, `scripts/check-release-archive.sh`, `.gitattributes` |

Run the full `STRICT=1 scripts/check-scaffold.sh` before a release, when CI is red and the cause is not clear, and when the change touches no row of this table.

## Land a change

Nobody pushes to `main`, in any form. A change reaches it through a pull request, and a ruleset on `main` accepts a merge only when both CI checks passed.

```bash
git push -u origin <type>/<slug>
gh pr create --base main --head <type>/<slug>
gh pr checks --watch
gh pr merge --merge --delete-branch
```

- `git push -u origin ...`: pushes the branch. Pushing is an approval point.
- `gh pr create ...`: opens the pull request. Its description lists the requirements and marks breaking changes.
- `gh pr checks --watch`: waits for CI, which runs once for each commit.
- `gh pr merge --merge --delete-branch`: merges when both checks are green and removes the remote branch. Then remove the worktree and the local branch.

## The pages of the website

The website builds from the archive of a release tag and renders the files listed in `docs/site-pages.txt`. Keep those paths stable: renaming or removing one needs a change on the site first,
and `scripts/check-site-pages.sh` fails when a listed file is missing. The repository holds no credential for the site.

## Next

[Release and sign Xaden](release-and-signing.md).
