---
id: REQ-133
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-20
---

# Xaden knows one project layout

## Job

When I read Xaden's scripts or run its checks, I want to meet one project layout and one set of tests for it, so I can skip learning a second layout that no project uses.

## Acceptance criteria

- Given the smoke suite, then its demo project is created by `xaden project create` and every area runs `xaden` against it; `scripts/new-project.sh` does not exist.
- Given `template/scripts`, `scripts/xaden.sh`, `scripts/adopt.sh` and `scripts/adopt-lib.sh`, then none names a classic layout, a project with a copy of the tooling or the `.scaffold/` folder.
- Given `xaden project adopt` in a folder that holds a `.scaffold/` folder, then it treats the folder like any other repository: nothing is migrated or removed.
- Given a project made by `xaden project create` in a git repository, then a smoke assertion proves that pre-commit and commit-msg hooks run Xaden's checks (REQ-001).
- Given an assertion of the old smoke suite that only proved a behaviour of a copied guide or script, then the pull request that removes it names it; every other assertion runs against the adopted demo project or, when it checks the text Xaden ships (rules, prompts, guides), against `template/`.

Requirement files written before this change speak of "classic" projects, `new-project.sh` and `xaden update`: they describe what was true then (REQ-001 and REQ-100 state what remains).
