# Architecture

How the Xaden repository is organised, and how the `xaden` command finds the Xaden version a project needs. Read this before you change anything.

## The repository

```
template/             the product: copied 1:1 into every new project
  AGENTS.md CLAUDE.md .aider.conf.yml .clinerules .continue/ .github/ .claude/ .obsidian/
  prompts/            prompt library (open template/ or a project as Obsidian vault)
  docs/               user-guide, admin-guide, requirements, ADRs, clean-code, security, local-llm
  scripts/            setup, check, release, hooks, req, context-status, stacks/
scripts/              scaffold tools: xaden, install, get-xaden (the one-line installer), new-project (test fixture),
                      adopt (+ adopt-scan, adopt-lib), fetch (downloads, pin, upgrade), autopilot, setup,
                      check-scaffold, release-scaffold
docs/guide/           the guides; they are also the source of the pages on the website
docs/requirements/    requirements of the scaffold itself
inbox/                local drop zone (git-ignored contents)
tests/smoke.sh        end-to-end test: generates a project and exercises its tooling;
                      areas in tests/smoke/ (one per epic)
AGENTS.md CLAUDE.md   rules for maintaining the scaffold
```

- **`template/` is the product.** Every tracked file in it is copied into new projects, so it holds no maintenance content and nothing personal. Its rules in `template/AGENTS.md` apply to the work on Xaden too.
- **`scripts/` holds the tools of the scaffold itself:** creating, adopting, updating, fetching versions and releasing. The scripts a project runs every day (check, req, release, hooks) live in `template/scripts/`.
- **Nothing project-specific lives at the root,** and nothing of the scaffold's maintenance lives in `template/`.

## Project layout

Projects (`xaden project create`, `xaden project adopt`) keep their team's content in an `xaden/` folder and no copy of the tooling. `xaden/xaden.conf` pins the Xaden version and its checksum. `scripts/new-project.sh` is the maintainers' test fixture: a project with its own copy of the tooling that the smoke suite runs against; `xaden` does not reach it.

## The `xaden` command and versions

The command is one link, `~/.local/bin/xaden`, to `current/scripts/xaden.sh` in the Xaden home (`~/.local/share/xaden`, or `XADEN_HOME`). Every installed release lives in
`versions/<version>`, and `current` points at the active one. In a project that pins a version, `xaden` hands over to that installed version, and when it is
missing it asks before it downloads it. Nothing inside a version folder is edited after it is installed.

`xaden core upgrade` installs a newer release next to the others and moves `current`. `xaden project pin` moves a project to another version on a branch. A clone
runs from where it is; `git pull` updates it.

## The network

Only `scripts/fetch.sh` and the installer `scripts/get-xaden.sh` talk to the network, and only after a person's yes (the update check is the one lookup the
`update-check` setting allows without a question each time). A smoke test searches every other script for network calls.

## The release archive

A release holds only what Xaden needs to run. Maintainer files (tests, requirements, signing scripts, hooks, CI) are listed in `.gitattributes` with `export-ignore`, and
`scripts/check-release-archive.sh` fails when one would reach an archive or when a new top-level path is neither excluded nor on the list of shipped paths.

## Next

[Work on Xaden](work-on-xaden.md) · [Threat model and requirements](threat-model-and-requirements.md).
