# Build features

Add a feature the way Xaden expects: from a requirement, test first, checked before every commit. Repeat for every feature.

## Before you start

You finished the [kickoff](kick-off-with-your-assistant.md), so the project has approved requirements and a stack with working checks.

## Build one feature

In Claude Code, type:

```text
/xaden-feature <what users can do afterwards>
```

The assistant first drafts the requirement in the chat. It creates the branch and worktree only after you approve the draft, and the worktree starts with just the requirements folder, so a large repository is not copied for an idea you may drop. Worktrees live in `worktrees/` at the project root; git ignores them and the checks skip them. Remove one with `git worktree remove worktrees/<slug>` after the merge.

In any other assistant, tell it:

```text
Run `xaden prompt feature` and follow it. Feature: <what users can do afterwards>
```

The assistant links the work to a requirement, plans, writes the test first, implements, runs `xaden check`, and runs a security
review when the change touches input, logins, data, files, the network or dependencies. It updates your documentation and changelog
and commits with a `Refs: REQ-nnn` trailer that names the requirement. It opens the pull request and stops: you review and merge the pull request, once CI is green. An assistant never merges its own work unless you tell it to for that one pull request.

You see:

- a commit per coherent step, in Conventional Commit form (`feat: ...`, `fix: ...`);
- a completion report at the end: the checks that ran, the checks that were skipped, unresolved findings, and the evidence for each acceptance criterion.

## When the checks fail

Fix the finding; do not silence a rule without a one-line reason. A commit that cites a requirement that does not exist is rejected,
and so is a `feat` commit without a `Refs:` line. Loosening a linter setting or the mode of the checks is an approval point.

## Other tasks

Claude Code, GitHub Copilot and Mistral Vibe have a slash command for each prompt (Codex CLI a `$name` skill) when your team chose them; other assistants run the `xaden prompt` command.

| You want to | Claude Code | Tell another assistant to run |
|-------------|-------------|-------------------------------|
| Fix a bug (failing test first) | `/xaden-bugfix` | `xaden prompt bugfix` |
| Refactor without changing behavior | `/xaden-refactor` | `xaden prompt refactor` |
| Review code | `/xaden-review` | `xaden prompt code-review` |
| Review security | `/xaden-security` | `xaden prompt security-review` |
| Change or add requirements | `/xaden-requirements` | `xaden prompt requirements-update` |
| Update documentation | `/xaden-docs` | `xaden prompt documentation` |
| Create a user persona | `/xaden-persona` | `xaden prompt persona` |

Changed your mind during a feature? Say so; the assistant updates the requirement first and then the code.

## Small changes take a short path

At the start the assistant says whether a change is small, normal or large, with one line of reason. You can overrule it. A small change is covered by one approved requirement, touches at most 2 files and adds no dependency and no new input, auth, data, files or network surface. It skips the requirement draft, the library search, the plan and the security review, and keeps the test, `xaden check`, the `Refs:` trailer, the changelog bullet, the guide update and a quick review of the diff. If the change grows, the assistant stops and switches to the normal flow. A large change gets a plan in `docs/architecture.md`, split into steps that are each a normal change. The size is guidance: the hooks and the checks run the same for every size.

## Keep the context small

The assistant loads `AGENTS.md` and the requirements index in every session, so both stay under a byte budget however large the project grows (REQ-126):

- `AGENTS.md` is at most 10240 bytes. It keeps the grounding rules, the nine clean-code rules, the trust and approval rules, the size table and the judgment rules. The rest moved word for word to `docs/rules/` (requirements and tests, checks, security, git, documentation, working style), and `AGENTS.md` tells the assistant when to read each file. In a project with an `xaden/` folder the same text is printed by `xaden doc rules-<topic>`, for example `xaden doc rules-git`.
- `docs/requirements/INDEX.md` lists only requirements that are not `done` or `dropped`; those are counted per epic. The full table is `docs/requirements/INDEX-full.md`, which no tool imports. With 500 requirements and 50 of them open the index stays under 6144 bytes.
- `xaden req list --epic <epic> --status <status>` filters the list, and `xaden req show REQ-nnn --brief` prints the goal and the acceptance criteria only.
- A hook or check that enforces a moved rule names the file that holds it in its message.

### Find the requirements for the files you change

In a large project the assistant need not read every requirement (REQ-127). Add an optional `paths:` line to the front matter of a requirement, with files, folders or globs separated by commas:

```yaml
paths: src/billing/, tests/billing_*.py, docs/export.md
```

- `xaden req for <path>...` lists the requirements whose `paths:` cover the files you plan to change: an entry ending in `/` covers the folder, a glob such as `tests/*.py` matches the whole path (a `*` also crosses `/`), anything else is one file. A requirement without `paths:` never matches.
- `xaden req find <word>...` lists the requirements whose title or text holds every word, one line each.
- `xaden check` warns, and does not fail, about a `paths:` entry that matches no file or folder, because a stale entry hides its requirement.
- A folder can have its own `AGENTS.md` with its purpose, conventions, public API and where its tests are; the assistant reads it when it works there. A `CLAUDE.md` next to it holding the line `@AGENTS.md` lets Claude Code load it. `xaden adopt` adds none of these; the team writes them, one folder at a time.

A trigger line in `AGENTS.md` can be ignored by a model; the hooks and checks catch the result at commit or at "done", not before.

## Build a whole epic

When every requirement of an epic is approved, ask for the loop (`/xaden-epic <epic>`, or paste `prompts/epic.md`). The assistant lists the requirements in the order it will build them and waits for your go; that go covers the branches, pushes and pull requests of the list. Each requirement then goes through the normal flow, with its own branch, green checks and its own commit, and one pull request. The loop stops on a red check, an approval point you have not given, a change that grows beyond its size, or an acceptance criterion that is wrong. It never edits an approved requirement and never merges a pull request unless you tell it to. At the end it reviews the whole epic once and gives a short retro: what was harder than the requirement said, and which criteria were wrong, with proposed edits as drafts in the chat.

## Findings that are not fixed now

When a review finds a real problem that the change did not cause or that is too big to fix now, the assistant offers three routes: fix now, ask you, or defer. It defers only after you agree, as one row in `docs/deferred-work.md` (in an adopted project `xaden/deferred-work.md`, created with the first deferral) with its source (a requirement ID or a branch), a one-sentence summary and the evidence that it is real. The file is append only: a row leaves it when it becomes a requirement or is dropped, and the commit message says which. `xaden check` fails on a row with a part missing or an unknown requirement ID. Accepted vulnerabilities with an owner and an expiry stay in `docs/security-exceptions.md`.

## Restart a session

A long session can lose its coherence: the assistant repeats itself, forgets a rule or contradicts a requirement you approved. The rules ask it to say so and to suggest a fresh session; you can also call it yourself. Nothing is lost, because the work lives in files, not in the chat:

1. Commit or stash what is ready, so the branch holds the state.
2. Start a new session in the same folder.
3. Ask the assistant to read the rule files, run `xaden context` and say which requirement and branch it is working on, from the files.
4. Check that it names the right ones before it continues.

## Next

[Release a version](release-a-version.md).
