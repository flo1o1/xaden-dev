---
id: REQ-134
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-20
---

# The Xaden repository is an adopted project

## Job

When I work on Xaden itself, I want to use the layout every project has, so I can exercise Xaden's own requirements, reviews and layout handling every day.

## Acceptance criteria

- Given the Xaden repository, then `xaden/xaden.conf` exists, and the requirements, security reviews, security exceptions, deferred work, threat model, decisions and architecture notes live under `xaden/`, not under `docs/`; the guides stay in `docs/guide/` and the paths of `docs/site-pages.txt` do not change.
- Given `xaden/xaden.conf` of the Xaden repository, then its `version` equals `VERSION`; `scripts/release-scaffold.sh` stamps both in the release commit, and a check fails when they differ.
- Given `xaden check` or `xaden project check` in the Xaden repository, then both run `scripts/check-scaffold.sh` and print the same; in every other project they run the checks that project maps.
- Given `xaden req` and `xaden context` in the Xaden repository, then they read `xaden/requirements` and the rules in `template/AGENTS.md`.
- Given the Xaden repository, then Xaden has not written a marked block into its `AGENTS.md`, a line into its `CLAUDE.md` or an `xaden/RULES.md`, and its own hooks in `.githooks` and its CI workflow are unchanged.

Requirement files written before this change name `docs/requirements/` as the place of the Xaden repository's requirements: read it as `xaden/requirements/`.
