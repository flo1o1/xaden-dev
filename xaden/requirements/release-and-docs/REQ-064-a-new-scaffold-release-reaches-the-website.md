---
id: REQ-064
type: job
epic: release-and-docs
priority: should
status: done
updated: 2026-10-14
---

# A scaffold release is published on the website under the same version

## Job

When I release the scaffold, I want to release the website with the same version, so I can be sure the site shows the documentation of exactly that release and nothing is published from an untagged commit.

## Acceptance criteria

- Given a pushed release tag `vX.Y.Z`, when I run the site's release step for `X.Y.Z`, then the site renders the docs from the archive of exactly that tag, shows `X.Y.Z`, and is published from the site tag `vX.Y.Z`
- Given a site fix without a new scaffold release, then the site is published again under the same version with a sequence (`vX.Y.Z-0001`, `vX.Y.Z-0002`), and only the newest site tag publishes
- Given the scaffold repository, then it holds no credential for the site repository (the site fetches released archives; the scaffold never pushes to it)
- Given the doc files the site renders, then their paths are stable and listed in the scaffold's maintainer documentation, and the scaffold's checks fail when one is missing
- Given an untagged commit on main, then it never appears on the site
