---
id: REQ-117
type: job
epic: release-and-docs
priority: should
status: done
updated: 2026-10-19
---

# Xaden calls itself AI-Driven Development, not vibe coding

## Job

When I read the README, I want Xaden to describe itself as AI-Driven Development, so I can see it as a disciplined method and not as a shortcut.

## Acceptance criteria

- Given `README.md`, then its opening sentence says AI-Driven Development and no longer says `AI-assisted ("vibe") coding`
- Given the files of this repository outside `inbox/` and `CHANGELOG.md`, then "vibe coding" appears only where the manifesto is quoted as the contrast term; the product name "Mistral Vibe" and the `vibe` assistant key stay as they are
- Given the REQ-116 page, then the README links to it
- Given the website hero, then it is not part of this requirement and stays as it is for now; the site follow-up (REQ-112) lists it as an open decision
