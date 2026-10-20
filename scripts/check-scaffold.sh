#!/usr/bin/env bash
# Checks the scaffold repository itself: its own requirements, the template's integrity,
# shell lint, secret scan, SAST (local rules + rule tests) and the end-to-end smoke test.
# Usage: [STRICT=1] [SMOKE=skip] scripts/check-scaffold.sh [--staged]   (STRICT=1: missing tools fail, as in CI)
#   SMOKE=skip leaves out tests/smoke.sh (CI runs it area by area, REQ-114); everything else runs as usual
#   (default)  full run incl. semgrep rule tests and tests/smoke.sh
#   --staged   pre-commit run: staged files only, offline, no smoke test
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_SCRIPTS="$ROOT/template/scripts"
# shellcheck source=SCRIPTDIR/../template/scripts/lib.sh
source "$TEMPLATE_SCRIPTS/lib.sh"
cd "$ROOT"

MODE=full
case "${1:-}" in
  "") ;;
  --staged) MODE=staged ;;
  *) die "usage: scripts/check-scaffold.sh [--staged]" ;;
esac

# The hook's --staged run is meant to nest (commits inside tests); only a full run must not.
if [ "$MODE" = "full" ]; then refuse_nested_run check-scaffold.sh; fi

# test_semgrep_rules: proves every local rule fires on its fixtures in tests/semgrep/.
test_semgrep_rules() {
  local workdir status=0
  workdir="$(mktemp -d)"
  cp "$ROOT"/template/.semgrep/*.yml "$ROOT"/tests/semgrep/* "$workdir/"
  semgrep --test --metrics=off --disable-version-check "$workdir" || status=$?
  rm -rf "$workdir"
  return "$status"
}

# warn_shellcheck_version: CI pins the version in .github/shellcheck.version; others may flag different things.
warn_shellcheck_version() {
  local pinned local_version
  has_command shellcheck || return 0
  pinned="$(sed -n 's/^SHELLCHECK_VERSION=//p' "$ROOT/.github/shellcheck.version")"
  local_version="$(shellcheck --version | sed -n 's/^version: //p')"
  [ "$pinned" = "$local_version" ] ||
    warn "shellcheck $local_version here, CI pins $pinned (.github/shellcheck.version): CI may flag findings this run does not"
}

# check_version_pin: the version pinned in xaden/xaden.conf is the one in VERSION; the release script stamps both (REQ-134).
check_version_pin() {
  local pinned version
  pinned="$(conf_get "$ROOT/xaden/xaden.conf" version)"
  version="$(tr -d '[:space:]' <"$ROOT/VERSION")"
  [ "$pinned" = "$version" ] || { warn "xaden/xaden.conf pins $pinned, VERSION is $version"; return 1; }
  info "xaden/xaden.conf pins $version"
}

REAL_ROOT="$ROOT" # the staged snapshot has no .git
if [ "$MODE" = "staged" ]; then
  enter_staged_snapshot "$ROOT" # checks see exactly the staged content (REQ-020)
  ROOT="$SNAPSHOT"
fi

info "check mode: $MODE"
run_tool "scaffold requirements" "$TEMPLATE_SCRIPTS/check-requirements.sh" --release "$ROOT/xaden/requirements" # REQ-049: no TODO: left
run_tool "version pin" check_version_pin # REQ-134
run_tool "scaffold traceability" env PROJECT_ROOT="$ROOT" "$TEMPLATE_SCRIPTS/check-traceability.sh"
run_tool "site pages" "$ROOT/scripts/check-site-pages.sh" "$ROOT" # REQ-064
run_tool "third-party credits" "$ROOT/scripts/check-third-party.sh" "$ROOT" # REQ-113
run_tool "AIDD mapping" "$ROOT/scripts/check-aidd-mapping.sh" "$ROOT" # REQ-116
run_tool "release archive" "$ROOT/scripts/check-release-archive.sh" "$REAL_ROOT" # REQ-094
run_tool "smoke areas" "$ROOT/scripts/check-smoke-areas.sh" "$ROOT" # REQ-092
run_tool "git hooks path" "$ROOT/scripts/check-hooks-path.sh" "$REAL_ROOT"
warn_shellcheck_version
lint_shell "$MODE"
scan_secrets "$MODE"
# tests/semgrep holds deliberately vulnerable fixtures; scan everything else.
scan_sast "$MODE" "$ROOT/template/.semgrep" '^tests/semgrep/'

if [ "$MODE" = "full" ]; then
  if has_command semgrep; then
    run_tool "semgrep rule tests" test_semgrep_rules
  else
    record_missing_tool "semgrep rule tests" semgrep
  fi
  if [ "${SMOKE:-}" = "skip" ]; then
    info "smoke test skipped (SMOKE=skip)"
  else
    run_tool "smoke test" "$ROOT/tests/smoke.sh"
  fi
fi

finish_checks
