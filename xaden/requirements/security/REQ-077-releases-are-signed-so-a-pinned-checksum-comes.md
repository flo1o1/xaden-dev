---
id: REQ-077
type: job
epic: security
priority: should
status: done
updated: 2026-10-14
---

# Releases are signed so a pinned checksum comes from the maintainer

## Job

When I install or upgrade to a Xaden version, I want its checksum to be signed by the maintainer, so I can be sure the checksum my team pins is not one an attacker substituted together with the download.

## Acceptance criteria

- Given a maintainer with a signing key, when `scripts/sign-release.sh <version>` runs, then it writes the tree checksum of the tagged release and an SSH signature of it, and prints the upload command without uploading.
- Given `release-signers` with the maintainer's key and a published signature, when `xaden upgrade <version>` runs, then the pinned checksum is the signed one and the output says the signature was verified.
- Given a signature that does not verify (changed checksum file, other key), then nothing is installed and the command exits with code 6.
- Given a release without a published signature, or no key in `release-signers`, then Xaden says the checksum is taken from the download itself (trust on first use) and continues only after the person's yes (REQ-072).
- Given `xaden fetch <version>` and a checksum in `xaden/xaden.conf` that differs from the signed one, then nothing is installed and the command exits with code 5.
- Given the test mode variable `XADEN_SIGNERS_FILE`, then it is ignored unless `XADEN_TEST_MODE=1`, so no environment can change which keys are trusted.
