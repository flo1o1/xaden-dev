# Join a project that uses Xaden

Start contributing to a repository whose team already uses Xaden.

## Before you start

- Xaden is installed ([Install Xaden](../admin/install-xaden.md)). The repository may pin a Xaden version you do not have yet; Xaden then asks before it downloads anything ([Pin one Xaden version per project](../admin/pin-one-version-per-project.md)).

## Join

```bash
git clone <project-url> && cd <project>
xaden project setup
```

- `git clone ...`: gets the project. Git does not clone hooks.
- `xaden project setup`: chains Xaden's checks into the git hooks of this clone and reports missing tools. Run it once per clone.

Check that it worked: `xaden project doctor` prints `installed X, project pinned Y` for the same version, and `xaden check` ends with a summary.

CI re-runs the static analysis and the commit-message checks, so a skipped hook is caught there.

## Work as the team does

Read `xaden/RULES.md` and the requirements in `xaden/requirements/`. Start your assistant in the folder. In Claude Code, type
`/xaden-feature <what users can do afterwards>`; in any other assistant, tell it to run `xaden prompt feature`. Both are described in
[Build features](build-features.md).
