---
id: REQ-109
type: job
epic: quality-gates
priority: must
status: approved
updated: 2026-10-18
---

# The CI commit check reads a range it can trust, and judges only the commits since the adoption

## Job

When CI checks the commits of a push or pull request, I want to see it fail when it cannot read the range and to see it skip history from before Xaden was adopted, so I can trust a green result without being blocked by commits Xaden never governed.

## Acceptance criteria

- Given `scripts/verify-commits.sh --ci` in a shallow checkout, then it fails, says that the history is incomplete and names `fetch-depth: 0`; it never prints that the messages are OK
- Given a range that `git rev-list` cannot read (for example `origin/<base>` is missing), then the script fails and names the range; the OK line is printed only for a range that was read, including a range with no commits
- Given a project made by `xaden create` and the same events, then the checks of the first two criteria apply too, because both layouts run the same script
- Given an adopted project (`xaden/xaden.conf` is tracked) and a range that would cover the whole history (a first push of the default branch, a force-push, no remote-tracking default branch), then `xaden verify-commits --ci` checks only the commits after the one that first added `xaden/xaden.conf`; the adoption commit itself is not checked
- Given a project made by `xaden create`, then the whole history is checked in that case, as before
- Given a wrong message before the adoption and a wrong message after it, when the whole-history case occurs, then the step names only the second and fails on it; with only the first it passes
- Given `commit-convention = other`, then findings stay warnings (REQ-068, REQ-107); a shallow checkout or an unreadable range fails in either convention, because the check did not run (REQ-101, REQ-102)
- Given a pull request, or a push with a usable previous tip, in a full checkout, then the range is unchanged (REQ-022)
- Given the smoke test, then a shallow clone and a range that cannot be read fail in both layouts, a fixture with commits before and after the adoption passes or fails as the sixth criterion says, and `xaden create` still checks the whole history
- Given the troubleshooting guide, then it names the shallow-checkout failure and its fix; the guide sentence that commits from before the adoption are not checked holds without exception
