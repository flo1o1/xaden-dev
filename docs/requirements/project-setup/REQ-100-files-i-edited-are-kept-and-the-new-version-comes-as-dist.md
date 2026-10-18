---
id: REQ-100
type: job
epic: project-setup
priority: must
status: approved
updated: 2026-10-18
---

# Files I edited are kept and the new version comes as `-dist`

## Job

When Xaden is updated and I changed one of the files it manages, I want my file to stay as it is and the new version next to it as `<file>-dist`, so I can merge when I want and lose no work.

## Acceptance criteria

- Given a managed file that I did not edit, when an update or a pin runs, then it is replaced by the new version.
- Given a managed file that I edited and whose new version differs, then my file stays untouched, the new version is written as `<file>-dist`, and the summary lists every such file.
- Given a managed file that I edited and that did not change upstream, then nothing is written.
- Given the same rule, then it holds for `xaden update` of a classic project and for `xaden pin` of an adopted project (command files; of the workflow only the two pinned lines change, everything else stays).
- Given a leftover `<file>-dist` or `<file>.scaffold-new`, then `xaden doctor` warns and names it, and the checks and file scans ignore it.
- Given `-dist` files, then they are git-ignored like `*.scaffold-new` was.
- Given `xaden update` before this change, then `*.scaffold-new` stays recognised for one release and is named in the same warning.
