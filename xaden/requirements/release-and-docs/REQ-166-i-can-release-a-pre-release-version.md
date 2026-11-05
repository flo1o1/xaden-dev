---
id: REQ-166
type: job
epic: release-and-docs
priority: should
status: done
updated: 2026-11-05
---

# I can release a pre-release version

## Job

When I want to ship `0.1.0-alpha` or `0.2.0-rc.1`, I want `xaden project release` to make it, so I can keep the checks, the changelog stamp, `VERSION`, the release commit and the tag instead of tagging by hand.

## Acceptance criteria

- Given a stable version and `xaden project release <major|minor|patch> --pre <id>`, then the version is bumped by the part and gets the suffix `-<id>` (`0.0.0`, `minor`, `alpha` gives `0.1.0-alpha`); an id is a letter followed by letters, digits or `-`, anything else is refused before any file changes
- Given a pre-release `X.Y.Z-<id>` or `X.Y.Z-<id>.<n>` and `xaden project release pre`, then the same id continues (`alpha` gives `alpha.2`, `rc.1` gives `rc.2`); with `--pre <other>` the id changes (`alpha.2` gives `beta`)
- Given a pre-release and `xaden project release final`, then the suffix is dropped (`0.2.0-rc.2` gives `0.2.0`)
- Given a result that does not sort higher than the current version under SemVer 2.0 precedence (`beta` to `alpha`, `final` on a stable version, `pre` on a stable version), then the release is refused before any file changes; `major|minor|patch` without `--pre` on a pre-release is refused and names `final`
- Given any pre-release, then it runs the same checks, stamps `VERSION` and `CHANGELOG.md`, commits and tags as a stable release, and a failure restores the files (REQ-024)
- Given the changelog, then each pre-release turns `Unreleased` into its own `## [<version>] - <date>` section and the final version stamps what is left; `xaden doc rules-git` says so
- Given the smoke tests, then they cover the bumps (`alpha`, `alpha.2`, `beta`, `rc.1`, `rc.2`, final), the refusals and the precedence order `alpha < alpha.2 < beta < rc.1 < 0.2.0`
- Given a pre-release in `VERSION`, then the checks that pin, fetch, install or sign Xaden itself still accept only `X.Y.Z`

`xaden doc rules-git` and `xaden prompt release` name the pre-release options.
