#!/usr/bin/env bash
# Checks what a release archive holds (REQ-094): only the paths on the list below, so no maintainer
# file reaches a person who installs Xaden. The archive is the one `git archive` makes of the staged
# files; .gitattributes (export-ignore) keeps maintainer files out of it, and the GitHub release page
# and scripts/sign-release.sh use the same rules. A new path in the repository fails this check until
# it is export-ignored or added here, so the list cannot drift.
# Usage: scripts/check-release-archive.sh [scaffold-root]
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=SCRIPTDIR/../template/scripts/lib.sh
source "$ROOT/template/scripts/lib.sh"

# Every file of an archive matches one of these (extended regular expressions on the full path).
SHIPPED_PATHS='^(CHANGELOG\.md|GETTING-STARTED\.md|LICENSE|README\.md|VERSION|release-signers)$
^docs/assets/[^/]+$
^docs/guide/(admin|developer)/[^/]+\.md$
^template/
^scripts/(adopt-lib|adopt-scan|adopt|create|fetch|get-xaden|install|new-project|scaffold-lib|update-scaffold|xaden)\.sh$
^scripts/adopt/ci\.yml$'
# These must be in it, or Xaden does not run.
REQUIRED_PATHS="VERSION CHANGELOG.md release-signers scripts/xaden.sh scripts/install.sh scripts/fetch.sh template/AGENTS.md"

main() {
  local files stray missing path
  files="$(git -C "$ROOT" archive "$(git -C "$ROOT" write-tree)" | tar -t | grep -v '/$')" || die "cannot make an archive of $ROOT (is it a git repository?)"
  stray="$(printf '%s\n' "$files" | grep -Ev "$(printf '%s' "$SHIPPED_PATHS" | paste -sd'|' -)" || true)"
  if [ -n "$stray" ]; then
    printf '%s\n' "$stray" | sed 's/^/  /' >&2
    die "these files would reach the release archive: add them to export-ignore in .gitattributes, or to SHIPPED_PATHS in scripts/check-release-archive.sh"
  fi
  missing=""
  for path in $REQUIRED_PATHS; do
    printf '%s\n' "$files" | grep -qxF "$path" || missing="$missing $path"
  done
  [ -z "$missing" ] || die "the release archive lacks:$missing"
  info "release archive: $(printf '%s\n' "$files" | wc -l | tr -d ' ') files, no maintainer file"
}

main
