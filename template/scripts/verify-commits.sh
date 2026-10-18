#!/usr/bin/env bash
# Runs the commit-msg checks (Conventional Commits + REQ/CC references) on existing commits.
# Used by CI so contributors without local hooks are checked too.
# Usage: scripts/verify-commits.sh <git-revision-range>   e.g. origin/main..HEAD
#        scripts/verify-commits.sh --ci                    range derived from CI variables:
#   EVENT_NAME (push|pull_request), BASE_REF (PR target branch), BEFORE_SHA (previous tip
#   of the pushed branch), DEFAULT_BRANCH (default: main).
# Merge commits are not checked themselves; every commit they bring in is.
set -euo pipefail

# SCRIPTS: where the tooling lives. ROOT: the repository it works on; PROJECT_ROOT lets
# another repository (e.g. the scaffold itself) reuse these scripts.
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(cd "$SCRIPTS/.." && pwd)}"
# shellcheck source=SCRIPTDIR/lib.sh
source "$SCRIPTS/lib.sh"

# is_commit <revision>: true if the revision names an existing commit.
is_commit() { git -C "$ROOT" rev-parse -q --verify "$1^{commit}" >/dev/null 2>&1; }

# ci_range: the commits a CI run introduces (REQ-022). A first push (no previous tip)
# covers everything not yet on the default branch, or the whole history including the
# root commit when the default branch itself is pushed for the first time.
ci_range() {
  local default_branch="${DEFAULT_BRANCH:-main}" base
  if [ "${EVENT_NAME:-}" = "pull_request" ]; then
    printf '%s' "${BASE_REF:-}" | grep -Eq '^[A-Za-z0-9._/-]+$' || die "invalid BASE_REF: ${BASE_REF:-<empty>}"
    printf 'origin/%s..HEAD' "$BASE_REF"
    return 0
  fi
  if usable_commit "${BEFORE_SHA:-}" "$ROOT"; then
    printf '%s..HEAD' "$BEFORE_SHA"
    return 0
  fi
  if is_commit "origin/$default_branch"; then
    base="$(git -C "$ROOT" merge-base "origin/$default_branch" HEAD)"
    if [ "$base" != "$(git -C "$ROOT" rev-parse HEAD)" ]; then
      printf '%s..HEAD' "$base"
      return 0
    fi
  fi
  printf 'HEAD' # whole history
}

# Temporary file holding one commit message at a time (global: the EXIT trap needs it).
MESSAGE_FILE=""

# verify_range <range>: checks every non-merge commit in the range; dies on any failure.
verify_range() {
  local commit failed=0
  MESSAGE_FILE="$(mktemp)"
  trap 'rm -f "$MESSAGE_FILE"' EXIT
  for commit in $(git -C "$ROOT" rev-list --no-merges "$1"); do
    git -C "$ROOT" log -1 --format=%B "$commit" >"$MESSAGE_FILE"
    if ! "$SCRIPTS/hooks/commit-msg" "$MESSAGE_FILE"; then
      warn "commit $(git -C "$ROOT" log -1 --format='%h %s' "$commit") failed the message checks"
      failed=$((failed + 1))
    fi
  done
  [ "$failed" -eq 0 ] || die "$failed commit(s) failed the message checks"
  info "commit messages OK ($1)"
}

case "${1:-}" in
  "") die "usage: scripts/verify-commits.sh <revision-range> | --ci" ;;
  --ci)
    range="$(ci_range)" # assignment first: a failing ci_range aborts the script (set -e)
    verify_range "$range"
    ;;
  *) verify_range "$1" ;;
esac
