# Release a version

Cut a version when you decide to: checked, stamped in the changelog and tagged locally. Xaden never pushes.

## Before you start

- The work is committed and the working tree is clean.
- The project has a `VERSION` file and a `CHANGELOG.md` with an `Unreleased` section. New projects have both. An adopted repository that has neither cannot use `xaden project release`; release it with your own process.

## Release

```bash
xaden project release minor
```

- `xaden project release minor`: checks everything in strict mode, stamps `VERSION` and the changelog section, commits and tags locally. Use `major` for a breaking change, `minor` for a backwards-compatible feature and `patch` for a bug fix.

It refuses to continue while a check fails, a required tool is missing, or a requirement, `SECURITY.md` or `xaden/threat-model.md` still contains an unfilled `TODO` marker. A failed step restores the files, so a failed release leaves nothing half-done.

Push when you want:

```bash
git push --follow-tags
```

- `git push --follow-tags`: sends the release commit and its tag. Pushing sends code out, so it is your decision.

In Claude Code, type `/xaden-release` for the checklist the assistant follows, including the security review before every release. In any
other assistant, tell it to run `xaden prompt release`.

## Next

[Join a project that uses Xaden](join-a-project.md).
