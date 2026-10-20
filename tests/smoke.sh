#!/usr/bin/env bash
# Smoke test for the scaffold: generates a project and exercises its tooling.
# Usage: tests/smoke.sh [area ...]   all areas, or only the named ones (needs git)
#        tests/smoke.sh --list       the areas in run order: tests/smoke/<area>.sh, one per epic, plus the three adoption-* areas
# Every run first creates the demo project (test_new_project); an area then runs alone.
# REQ-009: .github/workflows/scaffold-ci.yml runs this file on ubuntu-latest and macos-latest.
set -euo pipefail

# A PROJECT_ROOT in the caller's environment would point the project scripts at another repository.
unset PROJECT_ROOT

SMOKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/smoke"
# shellcheck source=SCRIPTDIR/smoke/lib.sh
source "$SMOKE_DIR/lib.sh"

# Run order of the areas. release-and-docs runs last: its release fills the demo project's
# placeholder requirement and stamps a version, which earlier areas still need unchanged.
AREAS="adoption-setup adoption-versions adoption-checks assistant-guidance project-setup quality-gates requirements security release-and-docs"

# areas: the areas in run order; dies when a file in tests/smoke/ is missing from AREAS.
areas() {
  local on_disk
  on_disk="$(find "$SMOKE_DIR" -name '*.sh' ! -name lib.sh ! -name adoption-lib.sh | sed -e 's|.*/||' -e 's|\.sh$||' | LC_ALL=C sort)"
  [ "$on_disk" = "$(tr ' ' '\n' <<<"$AREAS" | LC_ALL=C sort)" ] || die "tests/smoke/*.sh and AREAS in tests/smoke.sh differ"
  tr ' ' '\n' <<<"$AREAS"
}

main() {
  local area known chosen=()
  known="$(areas)"
  if [ "${1:-}" = "--list" ]; then printf '%s\n' "$known"; return 0; fi
  for area in "$@"; do
    grep -qx -- "$area" <<<"$known" || die "unknown area: $area (see tests/smoke.sh --list)"
  done
  # Named areas run in AREAS order, whatever order they were given in.
  while IFS= read -r area; do
    if [ "$#" -eq 0 ] || grep -qx -- "$area" <<<"$(printf '%s\n' "$@")"; then chosen+=("$area"); fi
  done <<<"$known"
  refuse_nested_run smoke.sh # checks above only print or fail, so they may nest
  test_new_project
  for area in "${chosen[@]}"; do
    # shellcheck source=/dev/null # the area is chosen at run time
    source "$SMOKE_DIR/$area.sh"
  done
  [ "$FAILED_ASSERTIONS" -eq 0 ] || die "smoke test FAILED: $FAILED_ASSERTIONS assertion(s) failed (SMOKE_KEEP_GOING=1)"
  if [ "$SKIPPED" -gt 0 ]; then
    warn "smoke test INCOMPLETE: $PASSED assertions passed, $SKIPPED fixture(s) skipped"
  else
    info "smoke test passed ($PASSED assertions${1:+, areas: ${chosen[*]}})"
  fi
}

main "$@"
