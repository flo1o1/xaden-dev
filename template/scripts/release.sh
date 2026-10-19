#!/usr/bin/env bash
# Cuts a release: bumps VERSION (SemVer), stamps CHANGELOG and docs, commits, tags. Never pushes.
# Refuses to release while the guides, SECURITY.md or the threat model contain TODO markers.
# Usage: scripts/release.sh <major|minor|patch>
#   major = breaking change, minor = backwards-compatible feature, patch = bug fix
set -euo pipefail

# SCRIPTS: where the tooling lives. ROOT: the repository it works on; PROJECT_ROOT lets
# another repository (e.g. the scaffold itself) reuse these scripts.
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(cd "$SCRIPTS/.." && pwd)}"
# shellcheck source=SCRIPTDIR/lib.sh
source "$SCRIPTS/lib.sh"
cd "$ROOT"
layout_init "$ROOT"

# stamp_docs <version>: sets "Applies to version" in the user and admin guides.
stamp_docs() {
  local file
  for file in docs/user-guide.md docs/admin-guide.md; do
    rewrite_file "$file" awk -v v="$1" '/^\*\*Applies to version:\*\*/ { print "**Applies to version:** " v; next } { print }' ||
      return
  done
}

# stamp_release <version>: writes the version into the changelog, both guides and VERSION.
stamp_release() {
  if [ "$LAYOUT" = "adopted" ]; then # no guides to stamp (REQ-066)
    stamp_changelog CHANGELOG.md "$1" && printf '%s\n' "$1" >VERSION
  else
    stamp_changelog CHANGELOG.md "$1" && stamp_docs "$1" && printf '%s\n' "$1" >VERSION
  fi
}

main() {
  local part=${1:-} current next
  local release_files=(VERSION CHANGELOG.md docs/user-guide.md docs/admin-guide.md)
  if [ "$LAYOUT" = "adopted" ]; then
    release_files=(VERSION CHANGELOG.md)
    if [ ! -f VERSION ] || [ ! -f CHANGELOG.md ]; then
      die "xaden project release stamps VERSION and CHANGELOG.md; this repository has no such pair. Create them (VERSION: 0.0.0, CHANGELOG.md with a '## [Unreleased]' section) or release with your own process"
    fi
  fi
  [ -n "$part" ] || die "usage: scripts/release.sh <major|minor|patch>"
  git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository"
  [ -z "$(git status --porcelain)" ] || die "working tree not clean; commit or stash first"

  current="$(tr -d '[:space:]' <VERSION)"
  next="$(bump_version "$current" "$part")"
  ensure_tag_absent "v$next" # all validation happens before the first change (REQ-024)

  "$SCRIPTS/check.sh" --strict # every required tool must run (REQ-019)
  "$SCRIPTS/check-requirements.sh" --release || die "replace template placeholders in the requirements first"
  "$SCRIPTS/check-docs.sh" --release ||
    die "documentation incomplete (files named above): guides via /xaden-docs; fill SECURITY.md and docs/threat-model.md"
  stamp_release_or_restore stamp_release "$next" "${release_files[@]}"
  commit_release_or_restore "chore(release): v$next" "${release_files[@]}"
  tag_release_or_report "v$next"
  info "released v$next (not pushed; run: git push --follow-tags)"
}

main "$@"
