# {{PROJECT_NAME}}

> Describe the project in one sentence here.

Built with the Xaden scaffold: AI-assisted, requirements-tracked, statically
analysed, security-reviewed, SemVer-versioned.

## Quick start

```bash
scripts/setup.sh   # once after every clone: activates git hooks, lists missing tools
scripts/check.sh   # static analysis, requirements and docs checks
```

Start an AI session by pointing the tool at this folder, then run the kickoff prompt:
`prompts/kickoff.md` (Claude Code: `/xaden-kickoff`).

## Where things are

| Path | Purpose |
|------|---------|
| `AGENTS.md` | Rules for every AI assistant (`CLAUDE.md` imports it) |
| `docs/requirements/` | Requirements: one file per job or quality goal, grouped by epic; `INDEX.md` lists them |
| `docs/user-guide.md`, `docs/admin-guide.md` | End-user and operator documentation (install, system requirements, config, upgrade) |
| `docs/architecture.md` | Layers, composition root, naming, rules for new code; filled at kickoff |
| `SECURITY.md` | How to report vulnerabilities; secret rotation; incident basics |
| `docs/threat-model.md` | Assets, entry points, trust boundaries, ASVS level; filled at kickoff |
| `docs/security.md`, `docs/security-exceptions.md` | Secure coding checklist and dependency policy; accepted vulnerabilities with owner and expiry |
| `prompts/` | Reusable prompts; open the folder in Obsidian |
| `scripts/` | check, release, hooks, context packing |
| `CHANGELOG.md`, `VERSION` | SemVer history |
| `worktrees/` | One folder per change in progress (`git worktree add worktrees/<slug> ...`); contents are git-ignored |
| `inbox/` | Local drop zone for your files; contents are git-ignored and never committed |
| `.scaffold/` | Scaffold version and managed-file manifest |

## Release

```bash
scripts/release.sh patch   # or minor / major
```

## Optional tools (checks skip missing ones; `scripts/check.sh --strict` requires them)

shellcheck, gitleaks, semgrep, plus per stack: ruff, mypy, bandit, pip-audit, pytest (Python)
or npm scripts `lint` / `typecheck` / `test` (Node/TypeScript).
More optional checks and assistant plugins, suggested by `scripts/check.sh` when they fit:
`docs/optional-tools.md`.
