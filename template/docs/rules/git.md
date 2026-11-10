# Rules: versioning and git

Moved from `AGENTS.md` (REQ-126), rule IDs and wording unchanged. `AGENTS.md` says when to read this file.

## 7. Versioning and git

- Semantic Versioning in `VERSION` (`MAJOR.MINOR.PATCH`). Do not edit it by hand;
  `scripts/release.sh <major|minor|patch>` does it — only run when the user asks.
- Pre-releases (REQ-166): `scripts/release.sh minor --pre alpha` makes `0.1.0-alpha` from `0.0.x`; `scripts/release.sh pre` makes the next
  (`alpha`, `alpha.2`, `alpha.3`), `pre --pre beta` changes the id (`alpha.2`, `beta`, `rc`) and `final` drops the suffix. A result that
  does not sort higher under SemVer 2.0 is refused. Each pre-release stamps its own `CHANGELOG.md` section from `Unreleased`; the final stamps what is
  left, so read the pre-release sections above it for the whole story. Checks, commit and tag are the same as for a stable release.
- The release gate (REQ-167): `scripts/check.sh --release` is the full run plus the TODO markers in `SECURITY.md` and `docs/threat-model.md` and the
  requirement placeholders; run it before you ask for the release.
- Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`; `!` or
  `BREAKING CHANGE:` for breaking changes. Enforced by the commit-msg hook.
- `Refs:` must be a git trailer: in the last paragraph of the message, next to other trailers.
  Merge/Revert/fixup!/squash! messages skip only the format check; IDs are always verified,
  and CI re-checks every commit a push or pull request introduces.
- Add a user-visible bullet to `CHANGELOG.md` → `Unreleased` for every `feat`/`fix`. Exception (REQ-171): a project with a `changelog.d/` folder
  writes one fragment instead and never edits `CHANGELOG.md`, so parallel branches cannot conflict. A fragment is `changelog.d/<unique-name>.md`
  (name it by the `Refs:` ID, for example `REQ-171-docs.md`): first line one heading `### Added|Changed|Deprecated|Removed|Fixed|Security`, then
  `- ` bullets. `scripts/release.sh` moves fragments and existing `Unreleased` bullets under the new version once and deletes only the fragments it
  used; `scripts/check.sh` fails on a malformed one and a release stops before changing anything. `changelog.d/README.md` is never consumed.
  Without the folder nothing changes; create it to opt in.
- A change starts with an approved requirement, not with a branch (REQ-082). Draft the requirement
  in the chat and wait for the user's OK; until then create no branch, worktree, commit or file in
  the tree. A rejected draft leaves nothing behind.
- After the OK: one branch per change, in its own folder, so parallel changes never touch each other.
  Worktrees live in `worktrees/` at the project root (git-ignored, skipped by the checks).
  Take the next free requirement number `nnn` and start sparse, so a large repository is not checked
  out in full for the requirement commit (`<type>` as in the commit types):
  `git worktree add --no-checkout -b <type>/req-nnn-<slug> worktrees/req-nnn-<slug> main`,
  `git -C worktrees/req-nnn-<slug> sparse-checkout set --cone docs/requirements scripts`, then
  `git -C worktrees/req-nnn-<slug> checkout`. Create the requirement there with status `approved` and
  commit it first. When implementation starts, run `git sparse-checkout disable` in that folder.
  A change without a requirement (`Refs: none`) skips the draft: `git worktree add worktrees/<slug> -b <type>/<slug> main`.
- Work, commit and run the checks in that folder. Never commit on `main` or `master`: the pre-commit hook
  refuses it (`ALLOW_MAIN_COMMIT=1` only when the user tells you to; releases and the first
  commit are allowed automatically).
- Finish a change with the full `scripts/check.sh`, then push the branch and open a pull request
  (both send code out: **Approval point**). CI runs on the pull request; the user merges.
  After the merge: `git worktree remove worktrees/<slug>` and `git branch -d <type>/<slug>`.
- Commit each coherent step. Never force-push, never rewrite published history.
- Parallel work (REQ-170): once the first commit is testable, push the branch (**Approval point**) and open a
  draft pull request from the first testable commit, so CI and any test environment start early; mark it ready when
  the full `scripts/check.sh` passes. A resource that exists once per machine (a local container stack, a fixed port,
  a shared database file) is changed only through a lock that names its owner (branch or session), for example a lock
  file in a folder every worktree shares. Read the owner before you start, stop or recreate the resource; when
  another owner holds it, ask the user.
