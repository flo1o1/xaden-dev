#!/usr/bin/env bash
# Checks the documentation Xaden cares about. A project keeps its own documentation and Xaden requires no guides
# (REQ-070); with --release no unfilled "<!-- TODO" marker may remain in SECURITY.md and the threat model (REQ-058).
# Usage: scripts/check-docs.sh [--release]
set -euo pipefail

# SCRIPTS: where the tooling lives. ROOT: the repository it works on; PROJECT_ROOT lets
# another repository (e.g. the scaffold itself) reuse these scripts.
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(cd "$SCRIPTS/.." && pwd)}"
# shellcheck source=SCRIPTDIR/lib.sh
source "$SCRIPTS/lib.sh"

RELEASE_MODE=0
[ "${1:-}" = "--release" ] && RELEASE_MODE=1

# check_filled <file>: counts a failure if "<!-- TODO" markers remain; the word TODO in prose is fine.
check_filled() {
  local count
  [ -f "$1" ] || return 0 # projects generated before the security documents existed
  count=$(grep -c '<!-- TODO' "$1" || true)
  if [ "$count" -gt 0 ]; then
    warn "$1: $count unfilled TODO marker(s)"
    FAILURES=$((FAILURES + 1))
  fi
}

layout_init "$ROOT"
if [ "$RELEASE_MODE" = "1" ]; then
  check_filled "$ROOT/SECURITY.md"
  check_filled "$THREAT_MODEL_FILE"
  [ "$FAILURES" -eq 0 ] || exit 1
fi
echo "docs OK (a project has no guides to check)"
