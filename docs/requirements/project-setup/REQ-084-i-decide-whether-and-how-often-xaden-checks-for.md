---
id: REQ-084
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-19
---

# I decide whether and how often Xaden checks for updates

## Job

When a newer Xaden or newer dependencies exist for my project, I want to choose whether I am told and how often, so I can plan updates myself and never be surprised by one.

## Acceptance criteria

- Given no setting, then `update-check=off`: Xaden makes no network call for update checks.
- Given `update-check=<interval>` in `xaden/xaden.conf`, where the interval is `off` or a number with `h` or `d` (`12h`, `1d`, `7d`), when a command or session start runs and the last check is older than the interval, then one check runs and its result is cached in a git-ignored file.
- Given an interval under `1h` or an unreadable value, then Xaden refuses it, names the allowed forms, and checks nothing.
- Given the environment variable `XADEN_UPDATE_CHECK` (same values), then it overrides the project value for that person only, and `xaden doctor` shows which value is in effect and where it came from.
- Given `xaden upgrade --check` run by hand, then it asks, checks now whatever the interval and the setting, prints the result and writes no cache (REQ-130); `xaden upgrade --check --if-due` is what scripts call: silent, only when the interval has passed, cached.
- Given the pre-commit hook, `xaden doctor` or `context-status.sh`, then they only print the cached result and never use the network.
- Given a cache entry, then it lists Xaden (pinned or installed vs latest) and the project's outdated dependencies (`npm outdated`, `pip list --outdated`) as separate lines.
- Given an update, then Xaden only reports it: applying a Xaden update stays `xaden upgrade` on a branch (REQ-071), and dependency updates stay the user's.
- Given `xaden upgrade`, then no file the user owns (lockfiles, `package.json`, `requirements-dev.txt` after `preset`) changes.
- Given no network, then the check fails silently, keeps the old cache and retries after the next interval.
- Given `xaden create` or `xaden adopt` with a terminal attached, then it asks once which interval to use, with `off` as the default answer; without a terminal it sets nothing.
- Given the REQ-072 grep test, then it allows the update check and nothing else.
