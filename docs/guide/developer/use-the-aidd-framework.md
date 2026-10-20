# Use the AIDD framework

The [AI-Driven Dev framework](https://github.com/ai-driven-dev/framework) (MIT) adds a workflow to your assistant: skills and agents that take a task from spec to review. Xaden stays the rule and check layer; the framework is an optional add-on you switch on per project. It needs a project that adopted Xaden (`xaden project adopt`, or a project made by `xaden project create`).

## Before you start

- Node 22.12 or later, `git`, and `npx` (it comes with Node). Xaden itself needs none of them for this; only the framework's installer does.
- One of the assistants the framework supports: Claude Code, Cursor, GitHub Copilot, Codex CLI, OpenCode or Kilo Code. Mistral Vibe is not one of them and is skipped.
- A terminal. Xaden downloads only after your yes (REQ-072), so a script or an assistant cannot switch it on for you.

## Switch it on

```bash
xaden aidd enable
```

Xaden shows the exact command it will run, then asks. The command is the framework's own installer, `@ai-driven-dev/cli`, at the version and release that `xaden/xaden.conf` pins. It writes `.aidd/` and the assistant's own settings into the project and downloads the plugins of the pinned release. For Claude Code it also registers the marketplace `aidd-framework` in your user settings, which every project on this machine shares.

Afterwards Xaden prints the files it added or changed. Review them with `git diff` and commit. `AGENTS.md` gets a short block, marked `xaden:aidd`, that maps the framework's steps to Xaden's gates and says that Xaden's rules win when a framework skill and the rules disagree.

`--ai claude,cursor` chooses the assistants; without it Xaden uses the ones in `xaden/xaden.conf`.

## What is pinned

`aidd-cli` is the exact version of the installer, and `aidd-release` is the release tag of the plugins (for example `v5.12.0`). Xaden never uses "latest". If the framework's installer cannot be held to a release, `enable` stops before it installs anything. After the install Xaden reads `.aidd/manifest.json` and checks that every plugin comes from the pinned release; if one does not, it removes the installation again.

```bash
xaden aidd status
```

shows the pin next to what is installed.

## Move the pin

```bash
xaden aidd pin 5.5.0 v5.12.0
```

Nothing moves the pin by itself. This command asks, then creates a branch and a worktree, runs the installer there at the new pin, commits, and prints a link to the framework's changes between the two releases. Review the diff and open the pull request your team reviews.

## Switch it off

```bash
xaden aidd disable
```

runs the framework's own `clean` at the pinned version, removes the rules block and the pin, and leaves every other file alone. The marketplace registered in your user settings stays, because other projects may use it; remove it with `claude plugin marketplace remove aidd-framework`.

## Limits

- Xaden pins the installer by version and the plugins by release tag. It does not check a signature of the framework; npm and GitHub vouch for what they serve.
- Xaden's rules win on a conflict, but an assistant can still pick a framework skill over a rule. `xaden check` and the pull request review are the gates that catch it.
- Xaden does not copy or change any file of the framework. It credits it in `THIRD-PARTY.md`.

## Next

[How Xaden maps to the AI-Driven Development Manifesto](xaden-and-the-aidd-manifesto.md).
