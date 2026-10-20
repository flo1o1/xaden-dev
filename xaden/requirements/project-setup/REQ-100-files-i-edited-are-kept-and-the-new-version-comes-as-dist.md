---
id: REQ-100
type: job
epic: project-setup
priority: must
status: done
updated: 2026-10-20
---

# Files I edited are kept and the new version comes as `-dist`

## Job

When Xaden is updated or pinned and I changed one of the files it manages, I want my file to stay as it is and the new version next to it as `<file>-dist`, so I can merge when I want and lose no work.

## Acceptance criteria

- Given a managed file that I did not edit, when a pin runs, then it is replaced by the new version.
- Given a managed file that I edited and whose new version differs, then my file stays untouched, the new version is written as `<file>-dist`, and the summary lists every such file.
- Given a managed file that I edited and that did not change upstream, then nothing is written.
- Given `xaden pin` of an adopted project, then the same rule holds for command files; of the workflow only the two pinned lines change, everything else stays.
- Given a leftover `<file>-dist`, then `xaden doctor` warns and names it, and the checks and file scans ignore it.
