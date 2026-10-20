# Check modes and baselines

Decide how strict the checks are, and let a repository with existing findings adopt Xaden without failing on what was already
there.

## The three modes

The `mode` in `xaden/xaden.conf` decides what a new finding does:

| Mode | A new finding |
|------|---------------|
| `advisory` | warns and passes |
| `changed-files` (default when you adopt a repository) | fails if it is in a file the change touches |
| `strict` (default for a new project) | fails in any file |

Changing the mode is an approval point: loosening a gate needs the team's agreement, so make the change in a pull request.

## Baselines

When a repository is adopted, Xaden runs your check commands once and records what they report in `xaden/baselines/`, one list per
check. A finding in the baseline never fails a check, in any mode.

A baseline only shrinks. When you fix a finding, the next full run on your machine removes it from the list and tells you to commit
the smaller file. In CI the run only warns, because CI does not change files. A new finding is never added to a baseline; it fails
the check in the mode you chose. Letting a baseline grow is an approval point.

A failure that names no file, such as a failing test, cannot be baselined. In `advisory` it warns; in the other modes it fails.

## A check that crashes is a failure

A tool that finds violations exits with a known status (ruff, eslint, mypy and shellcheck use 1). Only that status sends its output
through the baseline and the mode. Any other non-zero status means the tool did not run to the end, so the check fails in `changed-files`
and `strict` and warns in `advisory`, even when everything it printed was in the baseline. Xaden shows the output and the status.

Built-in checks and Xaden's presets know their tool's status. For a command you mapped yourself, name it in `xaden/xaden.conf`:

```
check.lint = my-linter --all
findings-status.lint = 1,3
```

`xaden project adopt` writes `findings-status.<name> = 1` for you when the command exited with status 1 while it recorded the baseline (review the line in the adoption pull request). Any other status is not written, because a tool that crashes after printing findings would be accepted for good; the output tells you the line to add if that status does mean "violations found". The check `test` never has one:
a failing test is always a failure. A command without the line fails on every non-zero status.

**Upgrading from an earlier version:** a mapped command that exits non-zero with only baselined output used to pass. It now fails until
you add its `findings-status.<name>` line. Weakening or removing such a line is an approval point, like changing the mode.

## Which files "the change" means

In `changed-files` mode a finding fails when its file is in the change. Xaden works out the change like this:

| Where | The change is |
|-------|---------------|
| pre-commit | the staged files |
| CI, a push | the files from the previous tip of the push (`BEFORE_SHA`) to `HEAD` |
| CI, a pull request | the files since the merge base with the target branch (`origin/$BASE_REF`) |
| your machine | the files that differ from the default branch, plus uncommitted edits |

If Xaden cannot tell (a first push, a rewritten history, a shallow clone, a target branch that is not fetched, CI without an event),
that run checks all files as `strict` does and says so. An empty list of files never stands in for "unknown". `xaden/xaden.conf` stays
as it is. The workflows `xaden project adopt` writes, and the template's `ci.yml`, hand `EVENT_NAME`, `BASE_REF` and `BEFORE_SHA` to the check step;
a workflow of your own that runs `xaden check` needs the same three variables and `fetch-depth: 0`.

## Commit convention

If your repository does not use Conventional Commits, the `Refs:` checks only advise. Set `commit-convention = conventional` in
`xaden/xaden.conf` when the team opts in.

## Gaps: no tests or linters yet

If the repository lacks tests, linters or a type checker for its stack, `xaden project adopt --scan` lists each gap. A gap is reported by
`xaden check`: a warning in `advisory` and `changed-files`, an error in `strict`.

You can close a gap in two ways:

- Name your own command: add `check.test = <command>` (or `check.lint`, `check.typecheck`, and for the security checks `check.audit` and, in Python, `check.security`) to `xaden/xaden.conf`. What each kind covers: [What Xaden checks](what-xaden-checks.md).
- Use Xaden's preset for Python or Node: `xaden project adopt --preset` while adopting, or later:

```bash
xaden project preset python
```

- `xaden project preset python`: writes the preset's configuration at the repository root where its tools expect it, maps the check commands in `xaden/xaden.conf` (including `pip-audit` and Bandit for Python, `npm audit` for Node), and prints the command that installs the tools. You run that command yourself. A file you already have is never overwritten; Xaden shows the difference and asks before it saves its version next to yours as `<file>.xaden-new`.

Which checks each layout runs, and which an adopted project does not: [What Xaden checks](what-xaden-checks.md).

## Next

[Kick off with your assistant](kick-off-with-your-assistant.md).
