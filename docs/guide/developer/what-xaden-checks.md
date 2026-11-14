# What Xaden checks

Read this before you trust a green result: which checks ran, which did not, and what you can change.

A project keeps your own tests and linters: Xaden runs only the commands you map with `check.<kind>` in `xaden/xaden.conf`,
plus Xaden's own checks.

## The checks

| Check | Adopted project | If the tool is missing | Network | Pre-commit hook |
|-------|-----------------|------------------------|---------|-----------------|
| Requirements format, traceability, documentation structure | yes (no guides to check) | no tool | no | yes, except expired security exceptions |
| `gitleaks` secret scan | yes | skipped; fails with `--strict` and in CI | no | yes |
| `semgrep` with local rules | yes, rules from the pinned Xaden | skipped; fails with `--strict` and in CI | no | yes |
| `shellcheck` on shell files | yes, under the mode and baseline | skipped; fails with `--strict` and in CI | no | yes |
| `actionlint` on workflows | yes, optional, under the mode and baseline | not run | no | yes |
| `zizmor` on workflows | yes, optional, under the mode and baseline | not run | no | yes |
| `jscpd` duplication | only with `.jscpd.json` | skipped | no | no |
| `ruff` (Python lint and format) | only what `check.lint` maps | fails | no | yes |
| `mypy` (Python types) | only what `check.typecheck` maps | fails | no | no |
| `pytest` (Python tests) | only what `check.test` maps | fails | no | no |
| `npm run` (Node lint, typecheck, test) | only what the same three keys map | fails | no | lint only |
| `bandit` (Python security) | **unless mapped**: `check.security` | skipped; fails with `--strict` and in CI | no | no |
| `pip-audit` (Python dependencies) | **unless mapped**: `check.audit` | skipped; fails with `--strict` and in CI | yes | no |
| `npm audit` (Node dependencies) | **unless mapped**: `check.audit` | skipped; fails with `--strict` and in CI | yes | no |

The local semgrep rules are one file per language in the pinned Xaden's `.semgrep/` folder (REQ-144): `rules.yml` for Python and JavaScript/TypeScript, `go.yml` for Go, and so on. A file in a language without such a file gets no SAST finding, so a green run says nothing about it.

A skipped check makes the run INCOMPLETE, never a success. The three audit rows are check kinds of an adopted project like `test` and
`lint`: `check.audit` (every stack) and `check.security` (Bandit, Python only). `xaden project adopt` finds an existing command (a Makefile
target `audit` or `security`, an npm script `audit`); `xaden project add-preset python` maps `pip-audit` and `bandit -q -r . -x ./.venv,./node_modules,./tests`,
`xaden project add-preset node` maps `npm audit --audit-level=high`. The audits never run in the pre-commit hook (they need the network and are slow); the
generated CI workflow installs the pinned tools before `xaden check --strict`. An audit finding names no file, so it cannot be baselined: it
fails in `changed-files` and `strict` and warns in `advisory`.

## What an adopted project is told

A new adoption expects the audits: `expect` names `audit` (and `security` for Python), so an unmapped one is a gap until you map it. An
adoption from before keeps its `expect` line; `xaden core upgrade` and `xaden project pin` never add to it, so no run turns red by an update. Its full run
prints a `NOT COVERED:` line for each check Xaden knows for your stack and nothing
maps, and names the key that would map it:

```
NOT COVERED: pip-audit; a project made by xaden project create runs it. Map it with check.audit in xaden/xaden.conf (see "What Xaden checks")
```

The line only informs. When `expect` in `xaden/xaden.conf` names the kind (`expect = test,lint,audit`), a missing mapping is a gap
instead: a warning in `advisory` and `changed-files`, a failure in `strict`.

A project made by `xaden project create` never prints this line for what its stacks run.

## Make the gates blocking

Four settings turn the checks from advice into a gate:

```
mode = strict
expect = test,lint,typecheck
missing-tools = fail
require-signature = true
```

- `mode = strict`: any new finding fails, in any file ([Check modes and baselines](check-modes-and-baselines.md)).
- `expect` naming every kind of check your stack should have: a kind without a command fails instead of passing unnoticed.
- `missing-tools = fail`: a check whose tool is missing fails the run, locally and in the pre-commit, instead of ending INCOMPLETE (CI and releases already fail on a missing tool, REQ-154).
- `require-signature = true`: every Xaden your project runs came from a signed release ([Verify releases](../admin/verify-releases.md)).

Loosening any of the four is an approval point.

## A change to the checks is reviewed as code

The settings that decide how a project is checked live in the repository, so a pull request could loosen them and pass by its own rules.
In a pull request run, CI compares `mode`, `missing-tools`, `hook-checks`, `expect`, `check.*`, `findings-status.*`, `require-signature`, `settings-review`, `version`, `checksum`, the AIDD pin (`aidd-cli`, `aidd-release`, `aidd-integrity`, `aidd-commit`), the
baselines and `.github/workflows/xaden.yml` with the merge base. A difference fails the run with `check settings changed` and the changed lines,
and no mapped command runs: a `check.lint = ...` line from a pull request never executes before someone read it. A baseline that grew counts as a change. A key with leading whitespace counts too, because the settings reader ignores the whitespace.

A person other than the pull request's author reads the lines and adds the label `xaden-settings-accepted` after the last push; the run then continues with the changed settings. A label from the author, added before the last push (or before a force push), or removed again does not count, and a label the workflow cannot evaluate does not count either.
A project with one maintainer sets `settings-review = solo` in `xaden/xaden.conf`; then the label counts from the author as well, still only after the last push and only while it is on the pull request (REQ-174). That is a self-review: it keeps the pause and the record, not a second pair of eyes. The workflow reads the value from the base branch, so a pull request cannot switch it on for itself; any other value, or none, means a person other than the author.
The workflow `xaden project adopt` writes passes the label as `SETTINGS_ACCEPTED`; an older workflow needs the new one (`xaden project pin` writes it beside yours as `xaden.yml-dist`).

The workflow `xaden-settings.yml` (REQ-160) makes this judgment independent of the pull request. It runs on `pull_request_target`, so GitHub reads it from the base branch and a pull request can neither edit nor delete it. It installs the Xaden version pinned on the base branch, verifies its checksum, fetches the pull request as git objects and compares both sides with `git show`: nothing of the pull request is checked out or run. An unknown scope (no merge base, a ref that is missing) fails the run. Make the job `settings` a required status check of the default branch, next to `xaden`. A project adopted before this workflow existed gets it from `xaden project pin` as `.github/workflows/xaden-settings.yml-dist`; rename it, merge it, and add the required check.

Limits: the label `xaden-settings-accepted` is as strong as the right to label (it counts only from a person other than the author, after the last push), and the settings check of `xaden.yml` is still there for a quick local result but is not what the ruleset trusts. Protect `xaden/xaden.conf`, `xaden/baselines/` and `.github/workflows/` with required review as well (CODEOWNERS and branch protection).
A repository that was not adopted at the merge base, and every run outside a pull request, compares nothing.

In pre-commit, a `check.*` line that differs from the last commit is shown and runs only after a yes; without a terminal it is skipped, and `xaden check` runs it later.
