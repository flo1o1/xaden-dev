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

A skipped check makes the run INCOMPLETE, never a success. The three audit rows are check kinds of an adopted project like `test` and
`lint`: `check.audit` (every stack) and `check.security` (Bandit, Python only). `xaden project adopt` finds an existing command (a Makefile
target `audit` or `security`, an npm script `audit`); `xaden project preset python` maps `pip-audit` and `bandit -q -r . -x ./.venv,./node_modules,./tests`,
`xaden project preset node` maps `npm audit --audit-level=high`. The audits never run in the pre-commit hook (they need the network and are slow); the
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

Three settings turn the checks from advice into a gate:

```
mode = strict
expect = test,lint,typecheck
require-signature = true
```

- `mode = strict`: any new finding fails, in any file ([Check modes and baselines](check-modes-and-baselines.md)).
- `expect` naming every kind of check your stack should have: a kind without a command fails instead of passing unnoticed.
- `require-signature = true`: every Xaden your project runs came from a signed release ([Verify releases](../admin/verify-releases.md)).

Loosening any of the three is an approval point.
