---
id: REQ-103
type: job
epic: release-and-docs
priority: should
status: approved
updated: 2026-10-18
---

# A team can require that every Xaden it runs came from a signed release

## Job

When my team runs Xaden in a production repository, I want every installation and every run to refuse a release whose checksum the maintainer did not sign, so I can be sure the pinned checksum comes from the maintainer and not from the first download.

## Acceptance criteria

- Given `require-signature = true` in `xaden/xaden.conf`, when `xaden fetch`, `xaden pin` or `xaden upgrade` finds no key in `release-signers`, no `ssh-keygen`, no published signature or a signature that fails to download, then nothing is installed and the command exits with the signature status; without the setting it warns and trusts the first download as before
- Given a signature that does not verify, then nothing is installed, with or without the setting
- Given `require-signature` is absent or `false`, then behaviour is unchanged
- Given any other value than `true` or `false`, then every `xaden` command in that project stops with a message naming the setting; the control is never silently off
- Given the setting is on and no checksum is pinned yet (the first download), then the signed checksum is required as well and is the one that gets pinned
- Given the setting is on and an installed copy of the pinned version has no verified signature on record, or its files no longer match the signed checksum, then `xaden` refuses to run it for the project and names `xaden fetch <version>`, which re-verifies the copy against the signed checksum after a yes and records the result next to the versions folder, outside the checksummed tree
- Given the setting is on, then the running Xaden of a project is accepted only when its checksum equals the signed checksum on record and the pinned one; a git clone of Xaden is not
- Given the generated CI workflow, then it installs only the version and checksum pinned in `xaden/xaden.conf`; under the setting `xaden pin` writes only a signed checksum, and the guide states that CI trusts the pin your team reviewed, not a signature of its own
- Given the setting is changed from `true` to `false` or removed, then that is an Approval point in `template/AGENTS.md` §5, like the mode
- Given the guide, then it says what the setting proves (the checksum was signed by a key in `release-signers`) and that key authenticity, rotation and compromise stay with the team
