# Requirements and platforms

What Xaden needs on your machine, and what differs between Linux, macOS and Windows.

## What you need

| Needed | Why |
|--------|-----|
| Linux or macOS (Windows: WSL or Git Bash, untested) | Scripts are bash + POSIX tools |
| git, bash, awk, sed, tar, grep, cksum | Preinstalled on Linux/macOS |
| An AI coding tool | Claude Code recommended; Aider, Cline, Continue, Cursor, Codex, Copilot, ChatGPT or a local model (Ollama, LM Studio) also work — see [Use Xaden with other assistants and local models](../../../template/docs/local-llm.md) |
| Recommended: shellcheck, gitleaks, semgrep | Static analysis and secret scanning. Locally a missing tool is skipped and the run reported INCOMPLETE; CI and releases use `--strict`, where it fails, and `missing-tools = fail` in `xaden/xaden.conf` makes it fail locally too (REQ-154). Once a stack exists, its tools are required too: ruff, mypy, bandit, pip-audit, pytest (Python) or npm with `lint`/`typecheck`/`test` scripts (Node) |
| Optional: Obsidian | Comfortable reading and editing of the prompt library |
| Optional: extra checks and plugins | `xaden check` suggests the ones that fit your project (`TIP:` lines); list in `template/docs/optional-tools.md` |
| Optional: [Ponytail](https://github.com/DietrichGebert/ponytail) | Third-party rule set (MIT) that pushes assistants towards less new code; see the add-ons note below |
| Optional: [Caveman](https://github.com/JuliusBrussee/caveman) | Third-party rule set (Apache-2.0) that makes assistant replies shorter; see the add-ons note below |
| Optional: [Token Optimizer](https://github.com/alexgreensh/token-optimizer) | Third-party plugin (PolyForm Noncommercial, not open source) that compresses context and tool output; see the add-ons note below |
| Optional: [claude-mem](https://github.com/thedotmack/claude-mem) | Third-party plugin (Apache-2.0) that carries memory of past sessions into new ones; see the add-ons note below |
| Optional: [obsidian-skills](https://github.com/kepano/obsidian-skills) | Third-party plugin (MIT) that teaches assistants Obsidian's Markdown, Bases and Canvas formats; see the add-ons note below |
| Optional: [impeccable](https://github.com/pbakaus/impeccable) | Third-party plugin (Apache-2.0) for projects with a web UI: design guidance and 59 deterministic checks for generated frontend design; see the add-ons note below |

## Optional: assistant add-ons

The add-ons in the table above are third-party; the scaffold installs none of them, and your
project's `AGENTS.md` takes precedence over each (§10). Install commands, sources, licenses and
the risks to know before installing are in `template/docs/optional-tools.md` → "Assistant
plugins" (in a generated project: `docs/optional-tools.md`).

## Linux

git, bash, awk, sed, tar, grep and cksum are normally preinstalled; install a missing one with your distribution's package manager.
If `~/.local/bin` is not on your `PATH`, `scripts/install.sh` prints the line to add, usually to `~/.bashrc` (bash) or `~/.zshrc` (zsh).

## macOS

bash 3.2, the version macOS ships, is supported. If `git` is missing, running it once offers to install Apple's command line tools.
The default shell is zsh: put the `PATH` line that `scripts/install.sh` prints into `~/.zshrc`.

## Windows

Untested: nobody has run these steps on Windows yet, so expect to adapt them. WSL is recommended: open a WSL shell and follow the
Linux steps, keeping Xaden and your projects in the Linux file system (your WSL home directory) rather than under `/mnt/c`. Git
Bash is also possible but untested. Native PowerShell is not supported, because the scripts are bash.

## Next

[Install Xaden](install-xaden.md).
