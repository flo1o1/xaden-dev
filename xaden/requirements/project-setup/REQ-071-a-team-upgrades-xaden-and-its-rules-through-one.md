---
id: REQ-071
type: job
epic: project-setup
priority: must
status: done
updated: 2026-10-14
---

# A team upgrades Xaden and its rules through one reviewed pull request

## Job

When a newer Xaden version is out, I want to switch the whole team in one reviewed change, so I can be sure the AI rules and checks never change underneath anyone.

## Acceptance criteria

- Given `xaden upgrade`, then it bumps the version and checksum in `xaden/xaden.conf`, regenerates `xaden/RULES.md`, shows the diff and the changelog entries, and works on a branch for a pull request.
- Given a newer Xaden installed on one machine, then no repository file changes; `xaden doctor` only reports "installed X, project pinned Y".
- Given `xaden/RULES.md` that does not match the pinned version, when the hook or CI runs, then the check fails and names the fix.
- Given `xaden doctor`, then it contacts no network; looking for newer releases happens only with `xaden upgrade --check`.
- Given a project that still holds the old copied layout, then the migration path is `xaden adopt` and it supersedes the copy-based update of REQ-017 and REQ-059 for projects that choose it.
