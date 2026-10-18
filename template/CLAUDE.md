# CLAUDE.md — {{PROJECT_NAME}}

@AGENTS.md
@docs/requirements/INDEX.md

## Claude Code specifics

- Slash commands in `.claude/commands/` wrap the prompts in `prompts/`:
  `/xaden-kickoff`, `/xaden-persona`, `/xaden-feature`, `/xaden-bugfix`, `/xaden-refactor`, `/xaden-requirements`, `/xaden-docs`, `/xaden-security`, `/xaden-review`,
  `/xaden-release`.
- Use plan mode for anything touching more than two files.
- Optional: `/model opusplan` (or `"model": "opusplan"` in `.claude/settings.local.json`) plans
  with Opus in plan mode and implements with Sonnet. Needs Opus access; without it use
  `/model sonnet`, the prompts work unchanged. To pin a model for one command, add `model:` to
  the front matter of its `.claude/commands/*.md`; it applies to the current turn only (the plan
  up to the first approval point). The template sets no model, so each user's choice applies.
- The imports above load the rules and the requirements index into every session; read a single
  requirement with `scripts/req.sh show REQ-nnn`. `docs/clean-code.md` is not imported (it costs
  tokens in every session); the prompts that write or review code tell you when to read it.
- `.claude/settings.json` is a convenience guard, not a security boundary. Its `ask` rule makes Claude Code ask before `gh pr merge`, so the person merges (AGENTS.md §7); other routes to a merge (the web page, `git merge` plus push) are not covered. Its deny rules stop
  the Read tool on `.env`, `.env.local`, `.env.*.local`, `.env.development`, `.env.test`,
  `.env.staging` and `.env.production` in the project root (`.env.example` stays readable), and
  Bash commands that *start with* `git push --force`, `git push --force-with-lease` or
  `git push -f`. Do not rely on them for `cat .env` through Bash, env files in subdirectories,
  other file names, or reordered arguments (`git push origin main --force`); AGENTS.md §10 still
  applies. The scaffold tests which file names the patterns match, not Claude Code itself.
- Do not duplicate rules here; edit `AGENTS.md` so every tool stays in sync.
