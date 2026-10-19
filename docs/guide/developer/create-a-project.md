# Create a project

Start a new project that has Xaden's rules, checks and requirements from the first commit.
You have a working project at the end of this page.

## Before you start

- Xaden is installed and `xaden version` prints a version. If not, see [Install Xaden](../admin/install-xaden.md).
- You have git, and your assistant (Claude Code, Codex, Cursor, Aider or another) is installed.

## Create the project

```bash
xaden project create my-app
cd my-app
```

- `xaden project create my-app`: creates the folder `my-app` in the current directory, starts a git repository in it and makes the first commit on `main`. If anything fails, it removes the half-created folder.
- `cd my-app`: moves your terminal into the new project.

Check that it worked:

```bash
xaden check
```

- `xaden check`: runs the project's checks and ends with a summary. A new project passes, because it has no code yet.

To create the project somewhere else, add the folder: `xaden project create my-app ~/code/x`.

## What you got

| What | Where |
|------|-------|
| Requirements, personas, security reviews and the rules for your assistant | the folder `xaden/` |
| The pointer from your assistant's rule file to those rules | a marked block in `AGENTS.md` |
| A README, `VERSION` and `CHANGELOG.md` | the project root |
| A security policy and a threat model to fill in during the kickoff | `SECURITY.md` and `xaden/threat-model.md` |
| Git hooks that run the checks before each commit | `.git/hooks` of this clone |
| A CI workflow that runs the same checks | `.github/workflows/xaden.yml` |
| The pinned Xaden version and the mode of the checks (`strict`) | `xaden/xaden.conf` |

Nothing is copied from the Xaden folder into the project. The tooling stays in the installed Xaden, and the project
pins the version it uses. See [Pin one Xaden version per project](../admin/pin-one-version-per-project.md).

Claude Code users get `CLAUDE.md` with the single line `@AGENTS.md`. `xaden project create` asks when a terminal is attached;
`--assistants claude` answers it in advance; `--assistants claude,copilot,vibe,codex` also writes the slash commands of GitHub Copilot, Mistral Vibe and Codex CLI.

## Set up a stack in one step (autopilot)

If you already know the stack, let Xaden add the recommended checks, hooks and CI as well:

```bash
xaden project create --autopilot --stack python my-app
```

- `xaden project create --autopilot --stack python my-app`: prints one plan and asks once. Use `--stack node` for a Node project.

The plan covers the layout above, the stack's preset (linter, type checker and test configuration), mode `strict`, hooks, the CI
workflow and the first commit. It prints the exact install commands for the development tools, with pinned versions. You run
them; Xaden does not. A run ends with a summary of the checks: tools that are not installed yet are reported as skipped, and a
run with skipped checks ends with a warning, never a success sign.

Autopilot never pushes, publishes or downloads anything, and a package added later needs its own approval. A folder that
already holds code, a build file or history stops with a pointer to [Add Xaden to a repository](add-xaden-to-a-repository.md).

## Next

[Kick off with your assistant](kick-off-with-your-assistant.md).
