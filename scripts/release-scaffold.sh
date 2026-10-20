#!/usr/bin/env bash
# Releases the scaffold: SemVer bump of the root VERSION, changelog stamp, release commit, tag.
# The full check is opt-in (--check, REQ-089): CI checks the release pull request anyway.
# Never pushes. Usage: scripts/release-scaffold.sh [--check] <major|minor|patch>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=SCRIPTDIR/../template/scripts/lib.sh
source "$ROOT/template/scripts/lib.sh"
cd "$ROOT"

# stamp_release <version>: writes the version into CHANGELOG.md, VERSION and the pin in xaden/xaden.conf (REQ-134).
stamp_release() {
  stamp_changelog CHANGELOG.md "$1" && printf '%s\n' "$1" >VERSION && conf_set xaden/xaden.conf version "$1"
}

main() {
  local run_check=0 part next
  if [ "${1:-}" = "--check" ]; then run_check=1; shift; fi
  part=${1:-}
  [ -n "$part" ] || die "usage: scripts/release-scaffold.sh [--check] <major|minor|patch>"
  [ -z "$(git status --porcelain)" ] || die "working tree not clean; commit or stash first"
  next="$(bump_version "$(tr -d '[:space:]' <VERSION)" "$part")"
  ensure_tag_absent "v$next"

  if [ "$run_check" = "1" ]; then
    STRICT=1 "$ROOT/scripts/check-scaffold.sh"
  else
    info "full check skipped: CI checks the release pull request (run with --check to check first)"
  fi
  stamp_release_or_restore stamp_release "$next" VERSION CHANGELOG.md xaden/xaden.conf
  commit_release_or_restore "chore(release): scaffold v$next" VERSION CHANGELOG.md xaden/xaden.conf
  tag_release_or_report "v$next"
  info "released scaffold v$next (not pushed; see AGENTS.md \"Landing a change on main\")"
}

main "$@"
