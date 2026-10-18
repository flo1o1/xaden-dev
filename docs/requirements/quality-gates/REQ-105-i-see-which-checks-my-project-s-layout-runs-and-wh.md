---
id: REQ-105
type: job
epic: quality-gates
priority: should
status: approved
updated: 2026-10-18
---

# I see which checks my project's layout runs and which it does not

## Job

When I adopt Xaden or read a green result, I want to see what was checked and what was not, so I can tell what "passed" covers instead of assuming the checks of a project made by `xaden create`.

## Acceptance criteria

- Given `docs/guide/developer/`, then a page "What Xaden checks" holds a table per layout (classic, adopted) and stack, with for each row: the tool, whether a missing tool skips or fails it, whether it needs the network, and whether it runs in the pre-commit hook or only in the full run
- Given the full run of an adopted project, when a check that the classic layout runs for the detected stack has no mapped counterpart (dependency audit, Bandit), then the summary prints a `NOT COVERED:` line for each and names the `check.<kind>` key that maps it; in `strict` mode with `expect` naming the kind it is a gap and fails (REQ-106), otherwise it only informs
- Given a project made by `xaden create`, then no `NOT COVERED:` line appears for what its stacks run
- Given the smoke test, then every tool named in the page's table appears in a stack file, a preset or a mapping, so the page cannot name a check that does not exist, and the adopted rows match what `xaden check` prints on an adopted Python and an adopted Node fixture
- Given the same page, then a "production" recipe names the three settings that make the gates blocking: `mode = strict`, `expect` with every kind, `require-signature = true` (REQ-103); no new setting is added
