---
id: REQ-160
type: quality
epic: security
priority: should
status: draft
updated: 2026-10-22
---

# The pull request gate does not trust its own checker or its own label

## Quality goal

A pull request cannot change how a project is checked by choosing the checker that judges it, or by reusing a label. Today `check-settings.sh` runs from the Xaden version and the workflow file of the pull request, and the label `xaden-settings-accepted` is read as "present now" (pre-release security review 2026-10-22, findings 2 and 3, accepted as documented limits in 0.6.0).

## Acceptance criteria

- Given a pull request that pins an older Xaden version or edits `.github/workflows/xaden.yml`, then the settings check runs from the merge base's pinned version and workflow, or the run fails until the label is added.
- Given the label `xaden-settings-accepted`, then it counts only when someone other than the pull request's author added it after the last push.
- Given a project that adopted before this requirement, then `xaden project pin` offers the new workflow beside the old one, as for every workflow change.
