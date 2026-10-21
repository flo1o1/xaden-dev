---
id: REQ-147
type: job
epic: security
priority: should
status: done
updated: 2026-10-20
---

# The tree checksum covers which files are executable

## Job

When my project pins a Xaden release, I want the checksum to cover which files are executable, so I can be sure nobody flips a script's mode without the pin changing.

## Acceptance criteria

- Given a checksum written `mode1:<hex>`, then it hashes each file's path, content and executable bit; a bare hex checksum is the version of before (REQ-139) and still verifies every tree it verified, so no pin and no signature made so far breaks.
- Given a new pin, adoption and `xaden project pin` write the newest checksum version the signed release has: `mode1:` for a release signed with both, the bare one for a release signed with the bare checksum only.
- Given `scripts/sign-release.sh`, then the signed checksum file holds the bare checksum on its first line (what a Xaden from before this version reads) and the `mode1:` one on its second, under the one signature.
- Given a project pinned with a bare checksum and a release signed with both lines, then fetch and the run-time pin check compare against the bare line; a project pinned with `mode1:` compares against the other.
- Given the CI workflow of an adopted project, then it recomputes either version from the pin with find, sed, sort and sha256 only, and a changed mode fails a `mode1:` pin.
