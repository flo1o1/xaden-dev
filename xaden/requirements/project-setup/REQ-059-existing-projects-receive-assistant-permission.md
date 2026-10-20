---
id: REQ-059
type: job
epic: project-setup
priority: should
status: dropped
updated: 2026-10-19
---

# Existing projects receive assistant permission updates without losing their edits

## Job

When the scaffold improves the Claude Code permission rules in `.claude/settings.json`, I want my existing project to get them through the normal scaffold update, so I can benefit from corrected deny rules without my own permissions being overwritten.

## Acceptance criteria

- Given a project whose `.claude/settings.json` is unchanged since generation, when a newer scaffold changes that file and I run the update with `--apply`, then the file is updated
- Given a project that edited `.claude/settings.json`, when the scaffold's version differs, then the project's file is kept and the new version is written as `.claude/settings.json.scaffold-new` to merge by hand
- Given a project generated before this change (no manifest entry for the file), when its file differs from the scaffold's, then it is treated as edited: kept, with a `.scaffold-new` file

Dropped 2026-10-19 by REQ-001: there is no classic project and no `xaden update`; `xaden pin` moves a project to another Xaden version.
