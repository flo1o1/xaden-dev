---
id: REQ-128
type: job
epic: project-setup
priority: must
status: done
updated: 2026-10-19
---

# The AIDD installer never runs before my yes

## Job

When I run `xaden aidd enable` or `xaden aidd pin`, I want to confirm the plan before anything of the framework's package downloads, starts or runs, so I can be sure my yes covers every foreign byte, as REQ-072 promises.

## Acceptance criteria

- Given `enable` or `pin`, then the order is: prerequisites, plan, my yes, and only then every call of the framework's CLI, including the `setup --help` check that it can hold the release (REQ-118).
- Given I answer no, or there is no terminal, then the CLI runner is never called; a stub runner that logs each call has an empty log.
- Given I say yes and the CLI cannot hold the release, then nothing is installed and no branch or worktree is made, with the refusal of REQ-118.
- Given the plan text, then it says that `npx` downloads the CLI on my yes, because the help check already needs it.
- Given the smoke test `project-setup`, then it covers no terminal, no, and yes-then-unpinnable for `enable` and for `pin`, and asserts the empty runner log.
