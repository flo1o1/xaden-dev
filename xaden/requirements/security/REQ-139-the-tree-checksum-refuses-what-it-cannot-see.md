---
id: REQ-139
type: job
epic: security
priority: should
status: approved
updated: 2026-10-20
---

# The tree checksum refuses what it cannot see

## Job

When Xaden hashes a release, I want every entry of the tree to count, so I can be sure a symlink cannot carry code the checksum skips.

## Acceptance criteria

- Given a tree that holds a symlink or an entry that is neither a regular file nor a folder, when `tree_checksum` runs, then it fails and names the entry; pin, fetch and the install step of the generated CI workflow stop.
- Given a release archive or a git checkout of a release, then the checksum is the same as before (no pinned checksum changes).
- Mode bits stay out of the checksum on purpose: hashing them changes the checksum of every released version; a later checksum version may add them.
