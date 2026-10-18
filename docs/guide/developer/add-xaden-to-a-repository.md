# Add Xaden to a repository

Put Xaden beneath a repository you already have, without changing its build, its tests, its documentation or its CI.
The result is one pull request that your team reviews.

## Before you start

- Xaden is installed ([Install Xaden](../admin/install-xaden.md)).
- You work in a clone of the repository, and it has at least one commit or is empty.

## Adopt the repository

```bash
cd ~/code/shop
xaden adopt
```

- `xaden adopt`: reads the repository and reports its stack, test runner, linters, CI system and git hooks. Then it prints exactly which files it would create or touch and asks once.

On a yes it works on a new branch, `chore/adopt-xaden`, in its own folder next to the repository (`shop-adopt-xaden`), so nothing
lands on your default branch. When it is done, push the branch and open the pull request. If `gh` is installed, Xaden offers to do
both.

Check that it worked: in the new folder, `xaden check` ends with `OK: all checks passed`, or with a warning that names every skipped
check.

## Look first, change nothing

```bash
xaden adopt --scan
xaden adopt --plan
```

- `xaden adopt --scan`: reports what the repository has and changes no file. It also lists rules in an existing `AGENTS.md` or `CLAUDE.md` that contradict `xaden/RULES.md`, with file and line. You decide what to do about them.
- `xaden adopt --plan`: prints the exact diff and the list of files that would be created or changed, and writes nothing.

What Xaden cannot recognise it says so, and it never guesses a command. Name one yourself with `--check test="make verify"`.
Without a terminal (a script, a CI job) `xaden adopt` stops after the plan and prints the command that applies it: `xaden adopt --yes`.

## What it adds, and nothing else

- A visible folder `xaden/` with `xaden.conf` (the pinned Xaden version and checksum, the mode of the checks and the commands Xaden runs), `RULES.md` (the rules for assistants, generated from the pinned version: do not edit), `requirements/`, `personas/`, `security-reviews/`, `baselines/`, an optional `prompts/` and `footprint.txt`. It is plain Markdown plus one settings file.
- A short marked block in `AGENTS.md`. Text you wrote there stays untouched.
- Slash commands for the assistants your team uses, one file for each prompt and nothing else: Claude Code `.claude/commands/<name>.md`, GitHub Copilot `.github/prompts/<name>.prompt.md`, Mistral Vibe and Codex CLI `.agents/skills/<name>/SKILL.md` (one skill that both read). Xaden offers an assistant when it finds a file or folder of its own (`.claude/`, `.github/copilot-instructions.md` or `.github/prompts/`, `.vibe/`, `.codex/`); `--assistants claude,copilot,vibe,codex` answers in advance. A file of the same name that exists already stays as it is.
- For Claude Code users, `CLAUDE.md` with the single line `@AGENTS.md`, or that line added to an existing `CLAUDE.md` that lacks it. Xaden pre-selects Claude when it finds `CLAUDE.md` or `.claude/` and asks you to confirm; `--assistants claude` answers in advance.
- A separate workflow, `.github/workflows/xaden.yml`, in its own commit. It installs the pinned Xaden version, verifies its checksum, runs `xaden check --strict` and checks the messages of the commits the push or pull request brings (`xaden verify-commits --ci`). Your existing workflows are not edited. `--skip-ci` leaves it out.
- On request, a `worktrees/` folder in its own commit, where change worktrees live. A single `worktrees/.gitignore` makes git ignore everything in the folder. `--worktrees` answers yes in advance, `--no-worktrees` no.
- Xaden's checks in your git hooks, chained into the hook manager you have (see [Hooks and CI that do not fit](#hooks-and-ci-that-do-not-fit)).

Your `README.md`, `docs/`, `scripts/`, `CHANGELOG.md` and build files are never changed.

## The commit convention decides how hard the `Refs:` rule is

`xaden/xaden.conf` holds `commit-convention`, `conventional` or `other`. With `conventional`, the commit hook and CI reject a `feat` commit without `Refs: REQ-nnn`, a `fix` without a requirement ID or `none`, and any unknown ID. With `other` they only warn, so a team with its own commit format (a ticket number in the subject, for example) can adopt without a fight.

The scan chooses from your history and shows its evidence, for example `conventional (3 of 3 subjects)`:

- no history at all: `conventional`;
- 5 or more commits: `conventional` when at least 60 percent of the last 30 subjects follow Conventional Commits;
- fewer than 5 commits: `conventional` only when every subject follows them, because a few commits say too little about a share.

When the answer is `other`, the scan says so and names the setting. To enforce the rule, set `commit-convention = conventional` in `xaden/xaden.conf` (a change that tightens a gate, so your team reviews it), or adopt with `xaden adopt --commit-convention conventional`. `xaden adopt --commit-convention other` does the opposite. A full `xaden check` in a project with `other` prints one `TIP:` line about it.

## CI is the gate, the hooks are a convenience

`git commit --no-verify`, a clone that never ran `xaden setup` and an unattended assistant all skip the local hooks. The workflow
`xaden.yml` therefore checks every commit a push or pull request brings, with the same rules as the commit hook (see the commit
convention above): a wrong format, a `feat` without `Refs: REQ-nnn`, or an unknown ID fails the job and the log names the commit.
With `commit-convention = other` the same findings are warnings. Commits from before the adoption are never checked, not even on the first push of the default branch: the check starts after the commit that added `xaden/xaden.conf`.

The check needs the full history. In a shallow checkout (the default depth of `actions/checkout` is 1) it fails with exit status 2 and names `fetch-depth: 0`, whatever the convention, because a range it cannot read is not a range with nothing wrong in it. The workflow Xaden writes already sets `fetch-depth: 0`; a workflow you edited or another CI system must do the same.

A failing job only stops a merge when the repository requires it. In GitHub, add a branch ruleset (or branch protection) for your default
branch with "Require status checks to pass" and select the `xaden` job. Xaden changes no repository setting. A project adopted before this
check existed gets the step through `xaden pin`, on the branch it prepares for the upgrade pull request.

## Your own tools keep running

The scan maps the commands it finds (`npm test`, `make lint`, `pytest`, `ruff check .` and similar) to `check.test`, `check.lint` and
`check.typecheck` in `xaden/xaden.conf`, and `xaden check` runs them. Xaden's own language presets stay unused.

Existing findings never block your team. When the plan is applied, Xaden runs your check commands once and records what they
report. How strict the checks are from then on is explained in [Check modes and baselines](check-modes-and-baselines.md).

## Hooks and CI that do not fit

Xaden chains into husky, plain git hooks, pre-commit and lefthook, and keeps what your hooks already do. It never sets
`core.hooksPath` over a manager. husky hooks are files in the repository, so that step is its own commit. The others live inside
`.git`, so each teammate runs `xaden setup` once after cloning.

A hook manager or CI system outside this list stops the run with exit code 4 and a manual step. Adopt without that part with
`--skip-hooks` or `--skip-ci`.

## Take it out again

```bash
xaden remove
```

- `xaden remove`: deletes `xaden/` and undoes exactly the paths listed in `xaden/footprint.txt`. Review the result with `git status`, then commit.

`xaden ignore-list` prints `xaden/`, `AGENTS.md` and, when present, `CLAUDE.md`, one per line, for `.dockerignore`, `.npmignore` and archive
excludes.

## A project with its own copy of the tooling

A project created with `xaden create --classic` (it has a `.scaffold/` folder) moves to this layout with the same command. Its
requirements, personas and reviews move into `xaden/`, the copied files you did not edit are removed, and the ones you edited stay and
are listed.

## Working with assistants afterwards

Claude Code, GitHub Copilot and Mistral Vibe users get a slash command for each prompt (`/xaden-kickoff`, `/xaden-feature`, `/xaden-bugfix` and so on), and
Codex CLI users a skill they start with `$xaden-kickoff`, `$xaden-feature` and so on. Each one only tells the assistant to run `xaden prompt <name>`; a file of
the same name that exists already stays as it is. Other assistants run `xaden prompt kickoff`, `xaden prompt feature` and so on to print the
task prompt. A prompt of the same name in `xaden/prompts/` replaces the default for all of them. Copilot prompt files work in VS Code, and Vibe
reads project skills only from a folder you marked as trusted.

## Next

[Check modes and baselines](check-modes-and-baselines.md), then [Kick off with your assistant](kick-off-with-your-assistant.md).
