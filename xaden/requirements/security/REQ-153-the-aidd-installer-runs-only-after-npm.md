---
id: REQ-153
type: job
epic: security
priority: should
status: done
updated: 2026-10-21
---

# The AIDD installer runs only after npm and GitHub answered the pin

## Job

When Xaden runs the AIDD framework's installer through npx, I want the integrity npm answers for the pinned CLI version and the commit the release tag points at to match the pin recorded in `xaden/xaden.conf`, so I can be sure a replaced package or a moved tag does not run on my machine, even after my yes.

## Acceptance criteria

- Given `enable`, `disable` or `pin` and the person's yes, then before the framework's CLI runs once, Xaden asks npm for `dist.integrity` of the pinned CLI version and the framework's repository for the commit the release tag points at; both must match the pin (`aidd-integrity` and `aidd-commit` in `xaden/xaden.conf`, the built-in pin for `enable`), and a different answer or none stops the command with nothing of the framework's CLI run.
- Given `enable`, then the pin it records next to `aidd-cli` and `aidd-release` includes `aidd-integrity` and `aidd-commit`, `status` shows all four values, and `disable` removes all four.
- Given `pin <cli-version> <release>` and the yes, then it reads the integrity and the commit of the new pin from npm and from the framework's repository and records them in the branch it creates.
- Given a pin recorded before this requirement (no `aidd-integrity` and no `aidd-commit` in `xaden/xaden.conf`), then `disable` refuses to run the framework's CLI and names `xaden aidd pin` as the way to record the values.
- Given the test that greps the scripts for network calls outside the fetch command (REQ-072), then `scripts/aidd.sh` is allowed next to `scripts/fetch.sh` and `scripts/get-xaden.sh`, because it reaches the network only after a person's yes (REQ-128); the smoke tests replace the registry and the tag answers, so no test reaches the network.
- Given the limits of the check, then the threat model states them: the CLI resolves the release tag again itself (a check-then-use gap), the CLI's own dependencies stay unpinned (it ships no lock file), and the integrity comes from the same registry that serves the package.
