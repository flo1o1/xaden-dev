---
id: REQ-112
type: job
epic: assistant-guidance
priority: should
status: done
updated: 2026-10-19
---

# Merge and site-follow-up rules live in each repository's own rule file

## Job

When I land several changes across the Xaden repositories, I want the merge and site-follow-up rules in each repository's own rule file, so I can start a session in any directory and the assistant still follows them.

## Acceptance criteria

- Given two pull requests where the first merge makes the second conflict, when the assistant is told to merge both, then it merges in dependency order, re-checks mergeability before each, merges `main` into the second branch, waits for CI and asks again
- Given a failed merge (conflicts, red CI), then the assistant fixes the cause and reports; it never uses `--admin`
- Given only one of two CI checks green, then the assistant does not ask for a merge
- Given a scaffold change that affects the documentation, then `AGENTS.md` says the website needs a follow-up after the release
- Given the website's rule file, then it says the user merges, and that the site's `main` must show what the scaffold's `main` does
