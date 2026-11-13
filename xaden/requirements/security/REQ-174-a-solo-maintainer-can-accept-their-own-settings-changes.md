---
id: REQ-174
type: quality
epic: security
priority: should
status: done
updated: 2026-11-13
---

# A solo maintainer can accept their own settings changes

## Quality goal

A project with one maintainer can accept a change of its check settings. Today the label `xaden-settings-accepted` counts only from a person other than the pull request's author (REQ-160), which a solo maintainer can never satisfy (issue 146). The project states in `xaden/xaden.conf` that it has no second reviewer; a pull request cannot grant itself that.

## Acceptance criteria

- Given `settings-review = solo` in `xaden/xaden.conf` of the base branch, then the label counts when its author is the pull request's author, as long as it was added after the last push and was not removed.
- Given `settings-review` missing, `team`, or any other value, then the label still counts only from someone other than the author (REQ-160 unchanged).
- Given a pull request that adds or changes `settings-review`, then the workflow reads the value from the base branch, so the change itself is judged by the old value, and `check-settings.sh` reports the line as a changed setting.
- Given the guide "What Xaden checks", then it documents `settings-review = solo` and says that it makes the label a self-review.
