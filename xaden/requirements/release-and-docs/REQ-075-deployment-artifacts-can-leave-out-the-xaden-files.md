---
id: REQ-075
type: job
epic: release-and-docs
priority: could
status: done
updated: 2026-10-14
---

# Deployment artifacts can leave out the Xaden files

## Job

When my team builds an image or release archive, I want to get a ready list of the Xaden-owned paths, so I can make the deployed artifact contain only the product.

## Acceptance criteria

- Given an adopted repository, when `xaden ignore-list` runs, then it prints the Xaden-owned paths (`xaden/`, `AGENTS.md`, and `CLAUDE.md` when present) one per line, for use in `.dockerignore`, `.npmignore` and archive excludes.
- Given the output, then it changes no file.
- Given a deployment concern beyond this list, then it is out of scope until a further requirement says otherwise.
