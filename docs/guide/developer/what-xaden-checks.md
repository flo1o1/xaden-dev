# What Xaden checks

Read this before you trust a green result: which checks ran, which did not, and what you can change.

A project made by `xaden create` (the classic layout) and a repository that adopted Xaden (the adopted layout) do not run the same
checks. The classic layout has built-in checks for Python and Node. The adopted layout keeps your own tests and linters: it runs
only the commands you map with `check.<kind>` in `xaden/xaden.conf`, plus Xaden's own checks.

## The checks

| Check | Classic project | Adopted project | If the tool is missing | Network | Pre-commit hook |
|-------|-----------------|-----------------|------------------------|---------|-----------------|
| Requirements format, traceability, documentation structure | yes | yes (no guides to check) | no tool | no | yes, except expired security exceptions |
| `gitleaks` secret scan | yes | yes | skipped; fails with `--strict` and in CI | no | yes |
| `semgrep` with local rules | yes | yes, rules from the pinned Xaden | skipped; fails with `--strict` and in CI | no | yes |
| `shellcheck` on shell files | yes | yes, under the mode and baseline | skipped; fails with `--strict` and in CI | no | yes |
| `actionlint` on workflows | yes, optional | yes, optional, under the mode and baseline | not run | no | yes |
| `zizmor` on workflows | yes, optional | yes, optional, under the mode and baseline | not run | no | yes |
| `jscpd` duplication | only with `.jscpd.json` | only with `.jscpd.json` | skipped | no | no |
| `ruff` (Python lint and format) | built in, required | only what `check.lint` maps | fails | no | yes |
| `mypy` (Python types) | built in, required | only what `check.typecheck` maps | fails | no | no |
| `pytest` (Python tests) | built in, required | only what `check.test` maps | fails | no | no |
| `npm run` (Node lint, typecheck, test) | built in, required | only what the same three keys map | fails | no | lint only |
| `bandit` (Python security) | yes | **not run** | skipped; fails with `--strict` and in CI | no | no |
| `pip-audit` (Python dependencies) | yes | **not run** | skipped; fails with `--strict` and in CI | yes | no |
| `npm audit` (Node dependencies) | yes | **not run** | skipped; fails with `--strict` and in CI | yes | no |

A skipped check makes the run INCOMPLETE, never a success. A row that is "not run" in the adopted layout is not a bug: nothing maps
it yet.

## What an adopted project is told

The full run of an adopted project prints a `NOT COVERED:` line for each check the classic layout runs for your stack and nothing
maps, and names the key that would map it:

```
NOT COVERED: pip-audit; a project made by xaden create runs it. Map it with check.audit in xaden/xaden.conf (see "What Xaden checks")
```

The line only informs. When `expect` in `xaden/xaden.conf` names the kind (`expect = test,lint,audit`), a missing mapping is a gap
instead: a warning in `advisory` and `changed-files`, a failure in `strict`.

A project made by `xaden create` never prints this line for what its stacks run.

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
