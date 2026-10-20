# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) · Versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Added
- One command answers "is something outdated": `xaden upgrade --check` reports the newest Xaden and, inside a project, the outdated npm and pip dependencies, and marks a newest version with a higher major number `(major)`; `xaden upgrade --check --if-due` is the quiet interval form (REQ-130). **Breaking, no deprecation period (nobody uses Xaden yet):** the command `xaden update-check` and the alias `xaden new` are gone, and `xaden upgrade <version>` inside a project installs that Xaden on the machine instead of moving the project (that is `xaden pin <version>`). The `update-check` setting and `XADEN_UPDATE_CHECK` keep their names.
- `xaden pin` keeps your CI workflow and writes the one the new version generates beside it as `.github/workflows/xaden.yml-dist` when the two differ, with the `diff` command and, under `require-signature = true`, a warning that a fresh runner needs the signed-record step (REQ-129).
- The assistant finds the requirements for the files it changes without reading them all (REQ-127, AIDD principle 05): a requirement can name the files it covers in an optional `paths:` line, `xaden req for <path>...` lists the matching ones, `xaden req find <word>...` lists those holding every word, `xaden check` warns about a `paths:` entry that matches nothing, and the session start asks for both and for the `AGENTS.md` of a folder the assistant works in.
- The rules and the requirements index loaded in every session have a size budget (REQ-126, AIDD principle 05): `AGENTS.md` is at most 10240 bytes, because its checks, security, git, documentation, requirements and working-style sections moved word for word to `docs/rules/` with a line that says when to read each; the index lists only requirements that are not done or dropped and counts the rest per epic, with the full table in `INDEX-full.md`; `xaden req list --epic/--status` filters and `xaden req show --brief` prints goal and criteria only; adopted projects read a topic with `xaden doc rules-<topic>`; the context fingerprint covers `docs/rules/`; `xaden update` and `xaden pin` add the files and regenerate the index.
- A prompt `epic` (`/xaden-epic`) builds the approved requirements of one epic in order: you approve the list once, each requirement stays a normal change with its own branch, checks, commit and pull request, the loop stops on a red check, an approval point, a size change or a wrong acceptance criterion, and it ends with one review and a retro that proposes requirement edits as drafts (REQ-124). Prompt only; it never merges.
- `xaden aidd enable` installs the AI-Driven Dev framework in a project that adopted Xaden, through its own CLI at a pinned version and release, and refuses when the pin cannot be held; `status`, `disable` and `pin` (a branch for a pull request) complete it. It asks before it downloads, adds a marked block to `AGENTS.md` that maps the framework's steps to Xaden's gates, and changes nothing in Xaden's own checks (REQ-118).
- A review finding that is not fixed in the change is offered three routes (fix now, ask, defer) and, once you agree, recorded in `docs/deferred-work.md` with source, summary and evidence; `xaden check` fails on an incomplete row or an unknown requirement ID (REQ-125, AIDD principle 06).
- The assistant states a size for each change (small, normal or large) and you can overrule it: a small change skips the requirement draft, the library search, the plan and the security review and keeps the tests, checks, trailer, changelog, guides and a quick diff review; a large one is split into steps (`template/AGENTS.md` §9, REQ-123, AIDD principle 04). Guidance only; no hook or check changes.
- The rules tell the assistant to say when a session lost its coherence and to propose a fresh one, and the developer guide explains how to restart a session from the files (REQ-120, AIDD principle 10).
- The rules tell the assistant to name which of scope, names, tests or context it will change before it retries, and to say what it changed (REQ-119, AIDD principle 09).
- Assistants name a requirement with its epic, title and ID, never the ID alone, when they mention it or ask for a decision about it, and say how to read it (AGENTS.md §0, REQ-122). Guidance only; nothing checks a reply.
- A guide page maps the AI-Driven Development Manifesto's 4 values and 12 principles to Xaden's rules, with a status for each and what is not met yet, and a check that fails when a row is missing or cites a rule that does not exist (REQ-116). The page says Xaden implements the manifesto and claims no certification.
- A decision record weighs the AIDD reference framework (`docs/decisions/0001-aidd-reference-framework.md`, accepted): copy nothing into Xaden, and offer it to projects as an opt-in add-on at a pinned version (REQ-115, REQ-118).
- The smoke tests of adoption run as three areas, `adoption-setup`, `adoption-versions` and `adoption-checks`, so a change to the adoption paths waits for the longest part, not the whole (REQ-121); maintainer-only, no change to any command.
- A pull request waits only for the checks its change can affect (REQ-114): CI runs each smoke area as its own job on both systems, selects the areas from the paths a change touches (`docs/smoke-areas.txt`, `scripts/select-smoke-areas.sh`; a shared file, an unknown path or an unreadable diff runs all areas, as does every merge into `main`), and the checks `check (ubuntu-latest)` and `check (macos-latest)` pass only when every job passed. `SMOKE=skip scripts/check-scaffold.sh` runs everything but the smoke suite.
- `THIRD-PARTY.md` credits the tools Xaden runs or recommends (ShellCheck, Gitleaks, Semgrep, Ruff, ESLint and the rest) with link and license, says Xaden bundles none of them, and notes that the Semgrep registry rules carry the Semgrep Rules License v1.0, not LGPL; it ships in the release archive. `scripts/check-third-party.sh`, part of `scripts/check-scaffold.sh`, fails when a tool named in the stack files, presets, generated CI workflow or `optional-tools.md` has no line with a link and a license (REQ-113).
- `xaden adopt` repositories audit their dependencies and run Bandit like a project from `xaden create` (REQ-106): `audit` (every stack) and `security` (Bandit, Python only) are check kinds next to `test`, `lint` and `typecheck`; a new adoption expects them and reports a gap until `check.audit` and `check.security` map a command; the scan finds a Makefile or npm `audit` command; `xaden preset python` maps `pip-audit` and `bandit`, `xaden preset node` maps `npm audit --audit-level=high`; the generated CI workflow installs the pinned tools; an adoption from before keeps its `expect` line and only gets the `NOT COVERED:` line and a `TIP:`.
- The full run of an adopted project prints a `NOT COVERED:` line for each check a project made by `xaden create` runs for the stack (`bandit`, `pip-audit`, `npm audit`) and nothing maps, and names the `check.<kind>` key that maps it; a new guide page "What Xaden checks" lists what each layout runs, whether a missing tool skips or fails it, which checks need the network and which run in the pre-commit hook, and the three settings that make the gates blocking (REQ-105).
- A human owns and merges every change an assistant prepares (REQ-110): the rules say the assistant opens the pull request and never merges it unless the user tells it to for that one, an assistant trailer discloses and does not replace the author, `Signed-off-by` is optional, and projects made by `xaden create` ask before `gh pr merge` in Claude Code.
- The rules ask the assistant to explain a non-trivial change and name one way to check it, to say what it cannot evaluate, to stop and inspect scope, context, assumptions and tests after a second failed attempt, and to propose entries for `docs/decisions/` that the user approves (AGENTS.md §9, "Judgment stays with the human", REQ-111). The feature, bugfix and refactor prompts point to it.
- The workflow `xaden adopt` writes checks the commit messages of every push and pull request (`xaden verify-commits --ci`), so a commit made with `--no-verify` or without the hooks still needs `Refs: REQ-nnn` and a known ID; with `commit-convention = other` it only warns. `xaden pin` adds the step to a workflow from before, on its upgrade branch (REQ-107).
- `xaden upgrade` updates Xaden itself, like a package manager: it asks, downloads the newest signed release next to the installed ones (`~/.local/share/xaden/versions/<version>`), verifies signature and checksum, and switches the `current` link. The `xaden` command links to `current` and never changes again; a failed download leaves the old version active, old versions stay for projects that pin them; `xaden upgrade --check` only reports; a git clone is told to `git pull` (REQ-097).
- `curl -fsSL https://xaden.dev/install | bash` installs Xaden with one command (`scripts/get-xaden.sh`, published on the website after the release): it asks first, reads the answer from the terminal, checks the zip signature against the embedded key and runs the zip's `scripts/install.sh`. `install.sh` now copies the release into `versions/`, so the extracted folder can be deleted, and it replaces a link to a former Xaden (REQ-098).
- Files you edited are kept and the new version is written next to them as `<file>-dist`: for the command files `xaden pin` brings up to date. `xaden doctor` names leftover `-dist` files (REQ-100).

### Changed
- `xaden project check` and `xaden project req` are the commands; `xaden check` and `xaden req` stay as aliases with the same output and exit codes, and `xaden version` is an alias of `xaden core version` (REQ-132). `xaden help` lists `core`, `project` and `aidd` as namespaces, and `xaden help aidd` lists the commands of `aidd`.
- A project command outside a git repository now names `xaden project create <name>` and `xaden project adopt`; in a repository that has not adopted Xaden every one of them prints `this repository has not adopted Xaden; run: xaden project adopt` (REQ-132).
- **Breaking:** the commands that manage Xaden and a project sit under two namespaces (REQ-131). `xaden core upgrade [--check [--if-due]]` and `xaden core version` act on Xaden itself; `xaden project create|adopt|remove|pin|fetch|doctor|rules|preset|setup|release|persona|ignore-list` act on one project and the version it uses. The old top-level spellings (`xaden create`, `xaden pin`, `xaden upgrade`, ...) are unknown and print the usage text. `check`, `req`, `context`, `hook`, `verify-commits`, `prompt`, `doc`, `aidd`, `version` and `help` stay where they are, so git hooks, CI workflows and `xaden/RULES.md` keep working; `xaden help core` and `xaden help project` list one namespace. A project pinned to an older Xaden is handed the command as typed, so run `xaden project pin` first.
- **Breaking:** `xaden create --classic` and `xaden update` are gone, and so is the guide "Update a classic project": a project always has the `xaden/` layout, and `xaden pin` moves it to another Xaden version (REQ-001, REQ-100). `*.scaffold-new` files are no longer recognised.
- The Admin Guide no longer describes installing, updating or removing a git clone (REQ-104): a clone is for maintainers, so the section "If you installed with git", the section "Install from a git clone" and the clone line of the uninstall page are gone. The Contributing page "Install with git" stays.
- A pull request that changes one area plus the changelog, the requirements index, `THIRD-PARTY.md`, `GETTING-STARTED.md`, the admin or contributing guides or the site page list now runs only the areas whose tests read those files, no longer all of them (REQ-114).
- The README calls Xaden a starter for AI-Driven Development instead of "vibe" coding and links the manifesto mapping (REQ-117).
- The guides no longer describe downloading, verifying and extracting the release zip by hand: the install guide shows the one command (the installer verifies the zip itself). Everything about working on Xaden moved to a new Contributing section: Install with git (install, update and uninstall of a clone), Architecture, Work on Xaden, Release and sign Xaden, and Threat model and requirements; the website shows it below Reference (REQ-104).
- **Breaking:** moving a project to another Xaden version is `xaden pin [--check] [version]` now. `xaden upgrade <version>` inside a project still does it, with a warning; `xaden upgrade` without a version, or outside a project, updates the tool (REQ-099). `xaden doctor` names `xaden pin <version>` when a newer Xaden is installed than the one the project pins.
- Maintainers: the REQ-072 test also allows `scripts/get-xaden.sh` to reach the network, after a yes.

### Added
- `require-signature = true` in `xaden/xaden.conf` makes a project accept only signed Xaden releases: `xaden fetch`, `xaden pin` and `xaden upgrade` install nothing (exit code 6) when no signature can be verified, the first download included, and Xaden runs for the project only when the installed files match the checksum the maintainer signed and the project pins. A copy installed before (or from the release zip) is verified once with `xaden fetch <version>`. Another value than `true` or `false` stops every `xaden` command in the project; loosening the setting is an approval point. Without it nothing changes (REQ-103).

### Fixed
- `xaden aidd enable` and `xaden aidd pin` ask before the framework's CLI runs at all: the check that it can hold the release (`setup --help`, which `npx` downloads) now comes after your yes, not before (REQ-128).
- The pre-commit hook of an adopted project whose `xaden/` folder is present but not tracked (listed in `.git/info/exclude`, as in a foreign repository) no longer fails with "docs/requirements not found": it reads the Xaden files from the working tree, and everything that is tracked is still checked as staged.
- `xaden adopt --scan` finds `unittest`: a `tests/` (or `test/`) folder with a `test*.py` file that imports it, and no pytest configuration, maps `python3 -m unittest discover -s tests` as the test command instead of reporting "none". pytest still wins when both exist.
- The commit check of CI (`scripts/verify-commits.sh --ci`, `xaden verify-commits --ci`) no longer reports OK for a range it could not read: a shallow checkout and a range git cannot list fail with exit status 2 and name `fetch-depth: 0` (before, a depth-1 checkout passed after looking at one commit), under any commit convention. In an adopted project the check also starts after the commit that added `xaden/xaden.conf`, so commits from before the adoption never fail a first push (REQ-109).
- `xaden adopt` no longer reads a history of fewer than 5 commits as "another commit convention" when every subject follows Conventional Commits (the `Refs:` rule stayed advisory without anyone being told). The scan shows its evidence (`conventional (3 of 3 subjects)`) and, for `other`, what that means and how to enforce the rule; `--commit-convention conventional|other` overrides the scan, and a full `xaden check` prints a `TIP:` while the convention is `other` (REQ-108).
- **Breaking:** `xaden adopt` records `findings-status.<name>` only when a check exits with status 1; any other status printed with findings is no longer learned, so a tool that crashes while the baseline is recorded stays a failure. The output names the line to add if that status does mean "violations found" (REQ-101).
- `require-signature = true`: the workflow `xaden adopt` writes now runs on a fresh CI machine (it records the pin it just verified), a git checkout or worktree of Xaden is never accepted, and an empty `require-signature =` line is refused instead of read as `false` (REQ-103).
- In `changed-files` mode a check no longer passes on an empty list of changed files when the scope is unknown: on a clean default branch after a merge, on a first push, after a rewritten history, and in CI without an event, the run checks all files as `strict` does and says so. A push is measured from its previous tip (`BEFORE_SHA`), a pull request from the merge base with its actual target branch (`BASE_REF`). The workflows `xaden adopt` and the template write now pass `EVENT_NAME`, `BASE_REF` and `BEFORE_SHA` to the check step; a workflow of your own needs the same (REQ-102).
- **Breaking:** a check that exits with a status it does not declare as "violations found" fails, even when everything it printed was already in the baseline; before, a tool that crashed after printing a baselined finding counted as passed. Built-in checks and the presets declare their statuses; a mapped command declares them with `findings-status.<name> = 1` in `xaden/xaden.conf` (`xaden adopt` records it, `test` never has one), otherwise any non-zero exit fails. A mapped command that exits non-zero with baselined output needs that line after upgrading (REQ-101).

## [0.5.0] - 2026-10-18

### Added
- Xaden installs from a signed release zip (`xaden-<version>.zip` on the release page) that holds only what Xaden needs to run: no tests, scaffold requirements, signing documents or scripts, hooks or CI files. `docs/guide/admin/install-xaden.md` makes the zip the recommended way and shows how to verify its signature before extracting; cloning is described as the way for contributors. Maintainers: `scripts/sign-release.sh` also writes and signs the zip, `.gitattributes` lists the files left out, and `scripts/check-release-archive.sh` fails when one of them would reach an archive (REQ-094).
- Projects made by `xaden create` have a `worktrees/` folder for change worktrees (`git worktree add worktrees/<slug> ...`); git ignores its contents and `AGENTS.md` §7 names it instead of `../<repo>-<slug>`. `xaden adopt` asks whether to add it as a separate commit (`--worktrees` / `--no-worktrees`); `xaden remove` takes it out again. Worktrees you already have stay where they are (REQ-090).

### Changed
- Maintainers: a pull request no longer needs the full local check first; run the staged check and the touched smoke areas, and CI runs the full suite once. A new push cancels the older CI run of the same pull request; runs on `main` are never cancelled (REQ-093).
- Maintainers: `/xaden-feature`, `/xaden-requirements`, `/xaden-release` and `/xaden-persona` now work on the scaffold itself, next to the four existing commands; `AGENTS.md` maps their paths and names the two commands left out (REQ-091).
- Maintainers: CI runs once for each commit of a pull request instead of twice: branch pushes no longer start it, the pull request and the merge into `main` do (REQ-088). `AGENTS.md` describes landing by pull request only.
- Maintainers: `scripts/release-scaffold.sh` no longer runs the full check by default, because CI checks the release pull request; `--check` runs it first (REQ-089).

## [0.4.0] - 2026-10-17

### Changed
- **Breaking:** every slash command and skill that Xaden generates carries the `xaden-` prefix, so it is told apart from the commands of other tools: `/xaden-kickoff`, `/xaden-feature`, `/xaden-bugfix`, `/xaden-refactor`, `/xaden-review`, `/xaden-security`, `/xaden-requirements`, `/xaden-persona`, `/xaden-release`, `/xaden-docs` (Claude Code, Copilot prompt files, Vibe and Codex skills, `--classic` projects, and the maintainer commands in this repository). `xaden upgrade` and `xaden update` remove the old unprefixed files Xaden created and write the prefixed ones; files of the same name that someone else created stay (REQ-087).

### Fixed
- Maintainers: `scripts/sign-release.sh` exited with an error after signing successfully and left its temporary folder behind; it now exits 0 and cleans up (REQ-077).

## [0.3.0] - 2026-10-17

### Added
- A full check, the smoke test or a project's `scripts/check.sh` started from inside itself now stops at once with a clear message instead of spawning processes without end; `XADEN_ALLOW_NESTED=1` allows it on purpose (REQ-086).
- Maintainers: `xaden req`, `xaden check` and `xaden context` work in the scaffold checkout like in any project (REQ-085).
- `xaden update-check` looks for a newer Xaden and outdated npm or pip dependencies. The setting `update-check` in `xaden/xaden.conf` (or `XADEN_UPDATE_CHECK` for one person) is `off` by default, or an interval such as `12h` or `7d`; `xaden doctor` and `context-status.sh` only print the cached result and Xaden never applies an update (REQ-084).
- Maintainers: a pre-push hook checks the commit messages CI checks, `scripts/check-scaffold.sh` fails when `core.hooksPath` points nowhere and warns when your shellcheck differs from the version CI pins in `.github/shellcheck.version` (REQ-083).
- `xaden adopt` puts Xaden beneath an existing repository without changing its build, on its own branch and worktree: `--scan` reports what the repository has, `--plan` prints the exact diff, applying creates the folder `xaden/`, a marked block in `AGENTS.md` and, for Claude Code users, `CLAUDE.md` with one line. Your tests and linters are run through `xaden/xaden.conf`, existing hooks and workflows are chained or left alone, and gaps can be filled with Xaden's Python or Node preset as a separate commit. `xaden remove` undoes it (REQ-066, REQ-067, REQ-069, REQ-070, REQ-073).
- Check modes `advisory`, `changed-files` and `strict` and baselines in `xaden/baselines/` that only shrink, so legacy findings never block a team that adopts Xaden (REQ-068).
- The tooling stays in the installed Xaden and is selected by the version and checksum pinned in `xaden/xaden.conf`. `xaden doctor`, `xaden fetch` and `xaden upgrade` keep a team on one version; nothing downloads without a typed yes, and a download is installed only if its checksum matches (REQ-071, REQ-072).
- `xaden create --autopilot --stack python|node` sets up a new project with the recommended checks, hooks and CI after one confirmation (REQ-076).
- Claude Code users get a slash command for each default prompt (`/feature`, `/bugfix`, ...) in an adopted or created project; each asks the assistant to run `xaden prompt <name>`, existing files are never overwritten, `xaden remove` deletes only the created ones and `xaden upgrade` follows the new prompt list (REQ-080).
- Slash commands for GitHub Copilot (`.github/prompts/`), Mistral Vibe and Codex CLI (`.agents/skills/`, one skill both read) next to the Claude Code ones: `xaden adopt` offers an assistant when it finds a file or folder of its own, `--assistants claude,copilot,vibe,codex` names them; the files, the skip of existing ones, `xaden remove` and `xaden upgrade` work as for Claude (REQ-081).
- `xaden ignore-list` prints the paths Xaden owns for `.dockerignore` and archive excludes (REQ-075).
- Every message is one of four kinds with a fixed sign (🐉 question, ⚠️ warning, 🔥 error, ✅ success) and a plain-text form (`[?]`, `WARNING:`, `ERROR:`, `OK:`) when output is not a terminal, in CI, with `XADEN_PLAIN=1` or without a UTF-8 locale (REQ-074).
- `xaden prompt`, `doc`, `rules`, `context`, `persona`, `preset` and `release` for repositories that adopted Xaden.
- Signed releases: `scripts/sign-release.sh` signs the tree checksum of a tagged release with an SSH key, `xaden fetch` and `xaden upgrade` verify it against `release-signers` and pin the signed checksum; a bad signature stops with exit code 6 (REQ-077, `docs/release-signing.md`). The maintainer still has to add the public key to `release-signers`.

### Changed
- A new requirement is drafted in the chat and approved before any branch or worktree exists; the worktree then starts sparse (requirements folder and the scripts that check it) and is widened when implementation starts. This is in the rules, the feature and requirements-update prompts and `xaden/RULES.md` of adopted projects (REQ-082, REQ-060).
- `xaden create` creates the `xaden/` layout, the same one `xaden adopt` gives an empty repository: no copied scripts, prompts or guides, the Xaden version pinned in `xaden/xaden.conf`, a README, `VERSION` and `CHANGELOG.md`, mode `strict`, hooks and a CI workflow. The old layout is `xaden create --classic` and keeps `xaden update` (REQ-066).
- Warnings print `WARNING:` instead of `WARN:` in plain output, and a run that passed prints `OK: all checks passed`.
- A project created by `xaden create` can move to the adopted layout with `xaden adopt`.
- `xaden new` is now `xaden create`, matching the other verbs. `xaden new` still works and tells you the new name.
- **Breaking:** `xaden pack` and `scripts/pack-context.sh` are removed (REQ-079). Xaden supports only assistants with file access; a chat window without it is no longer covered. `xaden update` removes the old script from a project that still has it and leaves your own files, such as an ignored `context-pack.md`.

### Fixed
- Download and clone URLs name the repository `flo1o1/xaden-dev`, and the lookup of the newest release follows redirects, so `xaden upgrade --check` keeps working after the repository rename.
- `scripts/new-project.sh` no longer configures hooks on another repository when `PROJECT_ROOT` is set in your environment; the new project gets its own hooks.

## [0.2.3] - 2026-10-13

### Added
- The pages the website renders are listed in `docs/site-pages.txt`; `scripts/check-scaffold.sh` fails when one is missing or when a workflow holds a credential for the site.
- Getting Started documents both ways to get Xaden, the zip download and the clone, with how to verify, update and choose, and notes for Linux, macOS and Windows (WSL recommended; Windows untested).
- impeccable (design guidance and deterministic checks for web UIs) is documented as an optional add-on, with its downloaded engine, the edit hook it installs and how to skip it, and its calls to impeccable.style with the telemetry opt-out.

## [0.2.2] - 2026-10-13

### Changed
- `scripts/context-status.sh` prints the number of requirements per status and the IDs of those not done (`requirements: 63 (62 done, 1 draft); not done: REQ-063(draft)`) instead of every ID, so the session-start output stays short in projects with hundreds of requirements.
- CI and `docs/security.md` state that semgrep's registry rules (`p/default`) are not pinned on purpose, so a new finding can appear without a code change, and how to handle it.
- Requirement changes no longer need a line in a `Change log` in `docs/requirements/README.md`: the history is `git log -- docs/requirements`, the commit message says what changed and why (`AGENTS.md` §2, the feature and requirements-update prompts). Existing projects keep their log as it is.
- `tests/smoke.sh` (scaffold maintainers) is split into one file per requirements epic in `tests/smoke/`; `tests/smoke.sh <area>` runs one area, `--list` names them.

## [0.2.1] - 2026-10-13

### Fixed
- The commit-msg check finds `CC-nn` rules in a rules file outside the repository top (the scaffold's `template/AGENTS.md`) when git runs it as a hook. Before, scaffold commits citing a rule failed with "commit cites unknown rule".
- `scripts/check-requirements.sh` accepted a status, type or priority written as a pattern (`status: d.*e` passed as `done`); values must now match a listed name exactly.
- `scripts/release.sh` left `CHANGELOG.md` stamped when writing a guide failed, and could even report success; it now stops and restores `VERSION`, `CHANGELOG.md` and both guides.
- `scripts/release-scaffold.sh` (scaffold maintainers) left `CHANGELOG.md` stamped when writing `VERSION` failed; it now restores both files.
- `scripts/check-traceability.sh`, the commit-msg check and the pre-commit hook could, rarely, report a listed requirement as missing ("tests cite REQ-013, which is not in docs/requirements"): a lookup piped into `grep -q` failed when grep stopped reading early. The lookups no longer use a pipe.

### Changed
- `CLAUDE.md` and `.aider.conf.yml` no longer load `docs/clean-code.md` into every session (about 2,000 tokens); the feature, bugfix, refactor and review prompts point to it instead.
- `AGENTS.md` session start no longer asks to re-read the requirements index when the tool already loaded it.
- `tests/smoke.sh` (scaffold maintainers) prints only failures and the total by default, the full scaffold check drops from about 610 to 120 lines; `SMOKE_VERBOSE=1` restores the per-assertion log, and CI sets it.
- Add-on details (install commands, sources, licenses, risks) live only in `docs/optional-tools.md`; `GETTING-STARTED.md` keeps one row per add-on and points there, so each add-on is documented once.

### Security
- `scripts/update-scaffold.sh` ignores manifest paths containing `..`. A project's `.scaffold/manifest` could list `scripts/../src/app.py`, and `--apply` then deleted that project file.

### Added
- `scripts/pack-context.sh --brief REQ-nnn <prompt>` builds a smaller pack for local models: rules, security checklist, personas, the requirements index and only the named requirements (a new project: about 7,300 instead of 11,000 tokens). Every pack run prints its estimated size in tokens and warns above 12,000.
- claude-mem (memory across sessions) is documented as an optional add-on, with where it stores sessions, the warning that its hosted memory service receives session content, and the rule that memories never replace the rule and requirement files.
- obsidian-skills (Obsidian formats for the prompt library) is documented as an optional add-on, with the rule that Obsidian syntax stays in `prompts/` and rule files, requirements and guides stay plain Markdown.
- `CLAUDE.md` documents `opusplan` as an optional Claude Code model setting (plan with Opus in plan mode, implement with Sonnet), the fallback `/model sonnet` without Opus access, and per-command `model:` front matter; new projects still set no model.

## [0.2.0] - 2026-10-12

### Breaking
- Requirements are one file per requirement in epic folders (`docs/requirements/<epic>/REQ-nnn-<slug>.md` with an `EPIC.md` per epic and a generated `INDEX.md`) instead of one table. Functional requirements are Jobs To Be Done (*When …, I want to …, so I can …*), non-functional ones measurable quality goals. `scripts/req.sh new|show|list|index` manages them; `check-requirements.sh`, the commit hook, traceability, context fingerprint and packs read the new layout. Existing projects run `scripts/migrate-requirements.sh` after updating.

### Security
- `scripts/pack-context.sh` refuses symbolic links, so a committed link (for example in `docs/personas/`) can no longer copy a file from outside the project, such as a credentials file, into a context pack.
- `scripts/persona.sh` treats a dangling symbolic link as an existing persona, so a committed link can no longer make it write a file outside the project.
- The Token Optimizer docs say that it keeps full tool output on disk in your home directory and removes credentials by pattern only, so secrets printed in a session may stay there.
- A `fix` commit's trailer must be a requirement ID or exactly `Refs: none`; values that merely contain "none" (such as `Refs: nonexistent`) are rejected.
- `scripts/check-security-exceptions.sh` rejects expiry dates with an impossible month or day (such as `2026-13-01`), which used to be accepted and silently extended the exception.
- `scripts/migrate-requirements.sh` stops when a table row's ID is not `REQ-nnn`, so a crafted requirements table can no longer make the migration write files outside `docs/requirements/`.
- The full `scripts/check.sh` fails when a row in `docs/security-exceptions.md` has expired, has no owner or no `YYYY-MM-DD` expiry, so accepted risks are fixed or consciously renewed. The pre-commit hook skips this date-dependent check.
- Releases are refused while `SECURITY.md` or `docs/threat-model.md` still contain `<!-- TODO` markers, so no release ships without a vulnerability contact and a threat model.
- `scripts/update-scaffold.sh` refuses to write through a symbolic link in the project, so a committed symlink can no longer make an update overwrite files outside the project; paths in `.scaffold/manifest` outside the scaffold-managed files are ignored, so an edited manifest can no longer make an update delete project files.
- CI checkouts no longer keep the job token in `.git/config` (`persist-credentials: false`) while dependency installs and tests run.
- Dependency policy requires checking that a proposed package really exists in the official registry (source, maintainers, age, downloads) before it is added, against slopsquatting: malware registered under package names assistants invent.
- AGENTS.md §10 separates trusted instructions from untrusted content (code comments, issues, web pages, tool output, documents, `inbox/`) and lists actions that need explicit user approval: destructive changes, dependencies, production, sending data out, secrets, releases.
- Pre-commit checks run on an export of the git index, so a staged problem can no longer be hidden by an unstaged fix; commit messages are validated against the staged requirements.
- Skipped checks are reported as INCOMPLETE instead of success; CI and releases run `--strict`, so a missing scanner fails. CI installs pinned tool versions (gitleaks verified by SHA-256), sets up Python/Node automatically and requires a committed `package-lock.json`.
- Project generation copies only git-tracked template files; untracked or ignored files (`.env`, `node_modules/`, `inbox/` content) are never copied or committed. Symlinks are refused; failed runs remove the partial project.

### Fixed
- Shell lint failed on Linux CI: Ubuntu's shellcheck 0.9.0 rejects `A && B || C` in `scripts/pack-context.sh` and `scripts/install.sh`, which newer versions accept; both are now plain `if` statements.
- The full check chose the files for each checker with several processes per tracked file (about 12 s per checker for 5,000 files); it now filters the list in one pass.
- `scripts/context-status.sh` reads the rules from `RULES_FILE` when set, so maintainers get a complete `CONTEXT CHECK` at the scaffold root (command in the root AGENTS.md) instead of an error and an empty rule list.
- `xaden update` and `scripts/update-scaffold.sh` work in git worktrees and submodules, where `.git` is a file instead of a folder.
- The pre-commit hook copied every tracked file into its snapshot on each commit, so large tracked assets slowed every commit; files over 1 MiB that the commit does not change are now left out.
- `check-traceability.sh --matrix` listed tests that cite a requirement only on a `traceability: ignore` line, while the check did not count them; both now skip those lines.
- `scripts/release-scaffold.sh` released and tagged even when `CHANGELOG.md` had no `[Unreleased]` section, leaving the release without notes; the shared changelog stamp now refuses that for both release scripts.
- `check-docs.sh --release` counted every "TODO" word, so a guide mentioning TODO items (e.g. of a to-do app) blocked every release; only `<!-- TODO` markers count now.
- CI of a Python project without `requirements-dev.txt` (ruff configured in `pyproject.toml`) stopped at the install step with "No such file"; it now installs the file only when present, and `scripts/check.sh --strict` names any missing tool.
- Commits made with `git commit -v` were rejected when the appended diff mentioned an unknown `REQ-nnn`; the commit-msg check now reads the message as git stores it, without comments and diff.
- Obsidian per-user files (`appearance.json`, plugins, workspace, cache) were not ignored; projects now track only the shared vault config (`app.json`, `core-plugins.json`, `templates.json`), and the scaffold root ignores `.obsidian/` entirely.
- `/security`, AGENTS.md, CLAUDE.md and the docs referred to a personal security skill other users do not have; the review now runs the tool-agnostic prompt only, and a smoke test rejects skill references in generated projects.
- The feature prompt created requirements as `in-progress`, skipping the user's approval; new rows now start as `draft`. All prompts mark **Approval points** the same way and honour approval already given in the session; feature refactors first only when needed, bug fixes are regression-test first.
- Claude Code deny rules blocked `.env.example`, which `/docs` must read; they now list real env file names, cover `git push -f` and `--force-with-lease`, and `CLAUDE.md` states what they do not cover.
- Releases validate the tag before changing files, restore all files if the release commit fails, and print recovery steps if tagging fails.
- Context packs include the security checklist and unreleased changes, list what they leave out, and are written atomically (an invalid prompt name keeps the previous pack). Docs now describe the fingerprint as a consistency aid, not proof.
- Merge/Revert/fixup!/squash! commits no longer bypass ID checks; `Refs:` is parsed as a git trailer; CI checks every commit of a first push or pull request (`verify-commits.sh --ci`).
- Requirements validation rejects empty text or acceptance criteria, invalid dates and (for releases) template placeholders; `feat`/`fix` commits may only reference approved, in-progress or done requirements.
- Smoke test failures now show the command output; tests ignore global git config; tool fixtures are mandatory in CI and visibly skipped locally.
- Python projects were never detected unless pyproject.toml, setup.py and requirements*.txt all existed.

### Added
- Every change happens on its own branch in its own git worktree and reaches `main` through a pull request (AGENTS.md §7), so several changes can be worked on in parallel without touching each other. The pre-commit hook refuses commits on `main`/`master`; project generation, releases and concluding a merge are allowed, `ALLOW_MAIN_COMMIT=1` overrides.
- User personas: `scripts/persona.sh new "<name>"` (or `/persona <description>` in Claude Code) creates a prefilled `docs/personas/<name>.md`. AGENTS.md, kickoff, feature and code review check every solution against the project's 3 to 5 personas and name the one it fails; context packs include them.
- `xaden` command: `scripts/install.sh` links it into `~/.local/bin`; `xaden new my-app` creates `./my-app` from any directory, `xaden update` updates the project you are in, and `xaden setup|check|req|pack|release` run that project's own scripts from any of its subdirectories.
- Caveman (shorter assistant replies) is documented as an optional add-on next to Ponytail, with the rule that project files stay in normal prose.
- Token Optimizer (context and tool-output compression) is documented as an optional add-on, with its noncommercial license and the rule that completion reports quote failing lines from the full, uncompressed output.
- Maintainers can run `/bugfix`, `/refactor`, `/review` and `/security` on the scaffold itself: root commands include the template prompts unchanged, `AGENTS.md` maps their project paths, and `docs/threat-model.md` describes the scaffold's own attack surface.
- `/review` in Claude Code offers Ponytail's `/ponytail-review` as an optional second pass when the plugin is installed; the project's review prompt and completion report stay authoritative.
- "Look before you build" rule (AGENTS.md §9, feature prompt): before writing something others have likely solved, assistants search for mature existing solutions and offer them as options with name, summary, license, website and maturity; adopting one follows the dependency approval and registry check.
- Optional tools, suggested where they fit: the full `scripts/check.sh` prints `TIP:` lines for actionlint and zizmor (GitHub workflows), jscpd (duplication), vulture or knip (dead code), Hypothesis or fast-check (property-based tests) and mutmut or StrykerJS (mutation testing), depending on the project's language. Adopted tools run in the check; tips never change the result. `docs/optional-tools.md` also lists Claude Code plugins for deeper reviews (Anthropic `code-review`/`security-guidance`, Trail of Bits, Ponytail).
- GETTING-STARTED documents [Ponytail](https://github.com/DietrichGebert/ponytail) as an optional add-on rule set (install per tool, trusted sources); nothing is installed automatically. AGENTS.md §10 states that add-on rule sets never override the project rules.
- Migration rules for persisted data in `docs/architecture.md`: versioned formats, automatic migration, isolated failures with a message, old data kept until migrated, a test per old version. The release prompt treats incompatible data, API and configuration format changes as major.
- Architecture template (`docs/architecture.md`): goals, layers and dependency direction, composition root, interaction, naming, rules for new code, third-party code. Kickoff fills it, the feature and review prompts follow it, context packs include it.
- Twelve local semgrep rules (Python and JS/TS): open redirect, regular expressions built from request data, `random`/`Math.random` for secrets, fast hashes on passwords, cookies without `secure`/`httpOnly`, unsafe XML parsing (stdlib parsers, entity expansion). Each is proven by fixtures; `docs/security.md` says what the rules cover and what they miss.
- The scaffold is published under the MIT License (`LICENSE`); generated projects do not inherit it.
- Completion report format in AGENTS.md §5 (checks run, checks skipped, unresolved findings, acceptance evidence); every working prompt ends with it, and skipped checks are never reported as passed.
- Security reviews are saved as reports (`docs/security-reviews/`, template managed by the scaffold) with scope, evidence, limitations, findings and remediation status; reviews look at callers, configuration and dependencies, not only changed lines.
- `SECURITY.md` in new projects: vulnerability reporting, secret rotation, incident response basics; SBOM/provenance stays optional guidance without tooling.
- Dependency policy in `docs/security.md` (approval, lockfiles, licenses, install scripts, update cadence, optional SBOM/provenance) and `docs/security-exceptions.md` for accepted vulnerabilities with owner and expiry; the release prompt blocks on expired exceptions.
- Threat model template (`docs/threat-model.md`): assets, sensitive data, entry points, trust boundaries, attackers, deployment assumptions, OWASP ASVS level. Kickoff fills it, security reviews read it, context packs include it.
- `inbox/` drop zone in scaffold and projects: contents are git-ignored; assistants treat them as untrusted data.
- Initial scaffold: AGENTS.md rules for any LLM, Claude Code commands, Obsidian prompt vault.
- Static analysis runner (`scripts/check.sh`), requirements tracking and validation.
- SemVer release script, Conventional Commits hook, changelog.
- User and admin guide templates with release gating (`/docs`).
- Grounding: numbered rules (CC-nn), `req.sh`, context fingerprint, ID verification in commits.
- `scripts/setup.sh` for fresh clones, commit-message checks in CI, GETTING-STARTED guide.

### Changed
- CI workflows (scaffold and generated projects) pin `actions/checkout` v7.0.1 instead of v4.2.2, which ran on the deprecated Node 20. Self-hosted runners need runner version 2.327.1 or newer.
- `.claude/settings.json` is now updated by `scripts/update-scaffold.sh`, so existing projects receive corrected Claude Code permissions; a project that edited the file keeps it and gets `.claude/settings.json.scaffold-new` to merge.
- The scaffold is now called Xaden (formerly Vibe Coding Scaffold). New projects name it in their README, first CHANGELOG entry and first commit; script names and the `.scaffold/` state folder are unchanged, so existing projects update as before.
- Commit hooks are faster with many requirements: the traceability check reads each test file once, and the commit-msg check exports the staged requirements in one step.
- Loosening a linter or type-checker rule, raising a threshold or adding a suppression is an approval point (AGENTS.md §5); when adopting linters on existing code, violations go into a baseline that may only shrink.
- `docs/clean-code.md` adds design heuristics (composition root, do-or-coordinate, polymorphism over repeated switches, visible order dependencies, Law of Demeter, size heuristics), naming by scope, comment upkeep and language, refactoring techniques, and test practices (state over interaction, no logic in tests, flaky tests, test doubles, pyramid, Given/When/Then). The ESLint preset forbids `var`.
- Security checklist and review prompt cover more OWASP WSTG test areas: open redirect, parameter pollution, header injection and request smuggling, NoSQL/LDAP/XPath/template injection, file inclusion, vertical privilege escalation, user enumeration, default accounts, session scope and tokens in URLs, HSTS, exposed files and methods, client-side secrets, encryption at rest, upload origin and limits, anti-automation, `LIKE` wildcards, ReDoS, audit trail, segregation of duties, `postMessage` and web storage, card payments via a provider.
- `check-docs.sh` and the docs say it checks structure only, not content. The documentation prompt and admin guide ask generated apps to document timeouts, bounded retries, graceful shutdown, health checks, safe logs, migrations with rollback and tested restores where they apply.
- Security checklist (`docs/security.md`) is anchored to OWASP ASVS and covers CSRF precisely (SameSite is defence in depth), SSRF with redirects and DNS rebinding, archive and symlink traversal, upload limits, object- and tenant-level authorization tests, session revocation, password reset, rate and resource limits, safe parsing and data retention; web-only items are marked.
- Clean-code rules are proportional and language-appropriate: CC-05 accepts exceptions, result or option types; CC-06 documents public APIs and contracts instead of every function; CC-03 warns against premature abstraction; CC-04 covers dependency direction and explicit side effects; CC-09 forbids unrelated refactoring. `docs/clean-code.md` says what tools cannot check.
- Projects record their scaffold version and a manifest of managed files (`.scaffold/`);
  `scripts/update-scaffold.sh <project> [--apply]` brings them to a newer scaffold with a
  three-way comparison, never overwriting local edits (`*.scaffold-new` instead).
- New projects receive only tracked, non-ignored template files (no `.DS_Store` etc.).
- Requirement traceability (`check-traceability.sh`): `done` requirements must be cited by a test,
  tests must not cite unknown IDs; `--matrix` prints requirement → tests → commits.
- Clean-code linter presets (`template/presets/`, `scripts/apply-preset.sh python|node`) map
  CC rules to ruff/mypy and ESLint settings; a detected stack with missing config, tools,
  scripts or tests now fails instead of passing silently.
- Pre-commit checks are fast and offline: staged files only, versioned local semgrep rules
  (`template/.semgrep/rules.yml`, tested by fixtures), `gitleaks --staged`. Types, tests, audits
  and semgrep registry rules run in the full check and CI.
- Project files moved to `template/`; the scaffold has its own requirements, rules,
  maintainer hooks (`.githooks/`), `check-scaffold.sh`, `release-scaffold.sh` and CI (Linux + macOS).
