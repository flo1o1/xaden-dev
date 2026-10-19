# Rules: versioning and git

Moved from `AGENTS.md` (REQ-126), rule IDs and wording unchanged. `AGENTS.md` says when to read this file.

## 7. Versioning and git

- Semantic Versioning in `VERSION` (`MAJOR.MINOR.PATCH`). Do not edit it by hand;
  `scripts/release.sh <major|minor|patch>` does it — only run when the user asks.
- Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`; `!` or
  `BREAKING CHANGE:` for breaking changes. Enforced by the commit-msg hook.
- `Refs:` must be a git trailer: in the last paragraph of the message, next to other trailers.
  Merge/Revert/fixup!/squash! messages skip only the format check; IDs are always verified,
  and CI re-checks every commit a push or pull request introduces.
- Add a user-visible bullet to `CHANGELOG.md` → `Unreleased` for every `feat`/`fix`.
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
