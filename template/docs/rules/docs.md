# Rules: documentation

Moved from `AGENTS.md` (REQ-126), rule IDs and wording unchanged. `AGENTS.md` says when to read this file.

## 8. Documentation (mandatory)

- Two guides are part of the product: `docs/user-guide.md` (end users) and
  `docs/admin-guide.md` (install, system requirements, configuration, security hardening,
  deployment, backup, monitoring, upgrade, uninstall).
- A feature is not done until the guides describe it. Update them in the same change.
- Fill the `<!-- TODO -->` markers with verified facts; ask if a fact is unknown. Never invent
  system requirements or commands. Prompt: `prompts/documentation.md` (`/xaden-docs` in Claude Code).
- `scripts/check-docs.sh` enforces the section structure; releases are blocked while TODO
  markers remain. It checks structure only, not whether the content is true: run the
  documented commands, or mark them "untested". `scripts/release.sh` stamps the version into
  both guides.
