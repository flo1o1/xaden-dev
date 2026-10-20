---
id: REQ-129
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-19
---

# A version change offers a CI workflow candidate for older installs

## Job

When I move a project to a newer Xaden with `xaden pin` and its CI workflow is older than the one Xaden now generates, I want to be shown what is missing without my edited workflow being overwritten, so I can be sure a signed-only project does not stop on a fresh runner with "no matching signature on record".

## Acceptance criteria

- Given `xaden pin` and a workflow that differs from the one a fresh adoption of the target version writes (for example it lacks the step that records the pinned checksum, or the Python audit tools), then `pin` still updates version and checksum as before, writes the generated workflow as `.github/workflows/xaden.yml-dist` on the branch (REQ-100), never over the project's file, and prints the `diff` command.
- Given a workflow that equals the generated one, then no `-dist` file is written.
- Given `require-signature = true` and a workflow without the signed-record step, then `pin` warns that a fresh runner will refuse, and does not fail.
- Given the candidate, then it is the file a fresh adoption writes, whose install step the smoke test `adoption-versions` already runs on a fresh home under `require-signature = true` (REQ-103); a second test takes an older workflow through the real `pin` and checks the candidate, the untouched original, the warning and the footprint line.
