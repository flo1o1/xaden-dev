#!/usr/bin/env bash
# Modes and baselines of the checks (REQ-068). Sourced by lib.sh; do not execute it.
# In an adopted project (xaden/xaden.conf) a check that finds violations is judged by the mode:
#   advisory       warns, passes
#   changed-files  fails only for violations in files the change touches
#   strict         fails for violations in any file
# Violations that existed at adoption are recorded in xaden/baselines/<check>.txt and never fail
# a check. The baseline only shrinks: fixed violations are removed from it, new ones never added.
# A violation is a line of tool output that names a file and a line ("path:12:3: message", or a
# GitHub annotation "::warning file=path,line=12::message"); it is
# recorded without the numbers, so moving code does not make it new. A failure without such lines
# cannot be baselined (a failing test, for example): advisory warns, the other modes fail.
# Only the exit statuses a check declares as "violations found" (REQ-101) go through that filtering:
# a built-in check declares its own, a mapped one declares them as "findings-status.<name> = 1" in
# xaden/xaden.conf (adoption records them). Any other non-zero status is a tool that did not run to
# the end, whatever it printed, and fails like a failure without violation lines. The check named
# "test" declares none: failing assertions are never baselined.

BASELINE_DIR_NAME="baselines"

# violation_keys: filter; "path: message" for each violation line of tool output on stdin.
violation_keys() {
  sed -n -E -e "s#^$PWD/##" -e 's#^\./##' \
    -e 's#^([^[:space:]:]+):[0-9]+(:[0-9]+)?:?[[:space:]]*(.+)$#\1: \3#p' \
    -e 's#^::(warning|error|notice) file=([^,]+),line=[0-9]+[^:]*::([A-Za-z0-9._-]+\.ya?ml:[0-9]+: )?(.*)$#\2: \4#p' | LC_ALL=C sort
}

# usable_commit <sha> [repo]: true for a full, non-zero commit id that exists in the checkout. The
# previous tip of a push (BEFORE_SHA) is all zeros on a first push and may be missing after a
# rewrite or in a shallow clone (REQ-102).
usable_commit() {
  printf '%s' "$1" | grep -Eq '^[0-9a-f]{40}$' && printf '%s' "$1" | grep -vq '^0*$' &&
    git -C "${2:-.}" rev-parse -q --verify "$1^{commit}" >/dev/null 2>&1
}

# change_base [repo]: prints the commit the change is measured from (nothing when the change is
# only the uncommitted edits). Returns 1 when the scope is unknown: a missing event, a previous
# tip or target branch that is not in the checkout, or history that was rewritten. Unknown never
# means empty (REQ-102).
change_base() {
  local repo="${1:-.}" candidate base
  case "${EVENT_NAME:-}" in
    pull_request) # compare with the actual target branch, which may be a release branch
      printf '%s' "${BASE_REF:-}" | grep -Eq '^[A-Za-z0-9._/-]+$' || return 1
      git -C "$repo" merge-base HEAD "origin/$BASE_REF" 2>/dev/null
      return $? ;;
    push)
      if ! usable_commit "${BEFORE_SHA:-}" "$repo"; then return 1; fi
      if ! git -C "$repo" merge-base --is-ancestor "$BEFORE_SHA" HEAD 2>/dev/null; then return 1; fi
      printf '%s' "$BEFORE_SHA"
      return 0 ;;
  esac
  [ -z "${CI:-}" ] || return 1 # CI without an event: nothing says what this run brought
  for candidate in origin/HEAD origin/main origin/master main master; do
    git -C "$repo" rev-parse -q --verify "$candidate" >/dev/null || continue
    base="$(git -C "$repo" merge-base HEAD "$candidate" 2>/dev/null)" || return 1
    [ "$base" != "$(git -C "$repo" rev-parse HEAD)" ] || continue # on the default branch: try the next
    printf '%s' "$base"
    return 0
  done
  # a default branch exists and HEAD is on it: only uncommitted edits differ. No branch at all: unknown.
  for candidate in origin/HEAD origin/main origin/master main master; do
    ! git -C "$repo" rev-parse -q --verify "$candidate" >/dev/null || return 0
  done
  return 1
}

# changed_files: files the change touches, one per line. Pre-commit: the staged files. Otherwise:
# files that differ from change_base, plus uncommitted edits. Returns 1 when the scope is unknown.
changed_files() {
  local repo="${GIT_REPO:-.}" base files
  if [ -n "${STAGED_LIST:-}" ] && [ -f "$STAGED_LIST" ]; then tr '\0' '\n' <"$STAGED_LIST"; return 0; fi
  base="$(change_base "$repo")" || return 1
  files="$({
    [ -z "$base" ] || git -C "$repo" diff --name-only "$base" HEAD
    git -C "$repo" diff --name-only HEAD
  })" || return 1
  [ -z "$files" ] || printf '%s\n' "$files" | LC_ALL=C sort -u
}

# gate_findings_status <name>: the exit statuses meaning "violations found", comma separated, or
# nothing. The project's declaration wins over the built-in one.
gate_findings_status() {
  local declared
  [ "$1" != "test" ] || return 0
  declared="$(conf_get "$TEAM_DIR/$CONF_NAME" "findings-status.$1")"
  if [ -n "$declared" ]; then printf '%s' "$declared"; return 0; fi
  case "$1" in
    shellcheck | semgrep | actionlint) printf '1' ;;
    zizmor) printf '10,11,12,13,14' ;;
  esac
}

# gate_is_findings_status <status> <name>: whether the check declares that exit status.
gate_is_findings_status() { printf ',%s,' "$(gate_findings_status "$2")" | grep -q ",$1,"; }

# gate_record_findings_status <status> <name>: adoption saw the check exit with <status> while
# printing violations; unless it declares statuses already, that becomes its declaration.
gate_record_findings_status() {
  [ "$2" != "test" ] && [ -z "$(gate_findings_status "$2")" ] && [ -f "$TEAM_DIR/$CONF_NAME" ] || return 0
  conf_set "$TEAM_DIR/$CONF_NAME" "findings-status.$2" "$1"
}

# gate_baseline_file <name>: where the baseline of one check lives.
# GATE_BASELINE_DIR overrides the folder while a baseline is recorded (adoption).
gate_baseline_file() { printf '%s/%s.txt' "${GATE_BASELINE_DIR:-$TEAM_DIR/$BASELINE_DIR_NAME}" "$1"; }

# gate_new_violations <keys-file> <baseline-file>: violations that are not in the baseline.
gate_new_violations() {
  if [ -f "$2" ]; then LC_ALL=C comm -23 "$1" "$2"; else cat "$1"; fi
}

# gate_shrink_baseline <keys-file> <baseline-file>: removes fixed violations from the baseline.
# Not in CI: a run there must not change files; it says what to do instead.
gate_shrink_baseline() {
  local fixed
  [ -f "$2" ] || return 0
  fixed="$(LC_ALL=C comm -13 "$1" "$2" | wc -l | tr -d ' ')"
  [ "$fixed" -gt 0 ] || return 0
  if [ -n "${CI:-}" ] || [ "${MODE:-full}" = "staged" ]; then
    warn "$fixed baselined violation(s) of '$(basename "$2" .txt)' are fixed; run 'xaden check' outside CI and commit the smaller baseline"
    return 0
  fi
  LC_ALL=C comm -12 "$1" "$2" >"$2.tmp" && mv "$2.tmp" "$2"
  info "baseline of '$(basename "$2" .txt)' shrank by $fixed; commit it"
}

# gate_run <name> <label> <command...>: runs one check under the project's mode and baseline.
# The check passes, warns or fails as described at the top of this file.
gate_run() {
  local name=$1 label=$2 mode output keys new scope status=0 count
  shift 2
  mode="$(project_mode "${PROJECT_ROOT:-$PWD}")"
  output="$(mktemp)"
  keys="$(mktemp)"
  info "$label"
  "$@" >"$output" 2>&1 || status=$?
  violation_keys <"$output" >"$keys"
  if [ "${GATE_RECORD:-0}" = "1" ]; then # adoption: what is there now becomes the baseline
    mkdir -p "$(dirname "$(gate_baseline_file "$name")")"
    cat "$keys" >"$(gate_baseline_file "$name")"
    if [ "$status" -ne 0 ] && [ ! -s "$keys" ]; then
      warn "$label fails today without naming files; that cannot be baselined, the mode decides (see xaden/xaden.conf)"
    else
      [ "$status" -eq 0 ] || gate_record_findings_status "$status" "$name"
      info "baseline of '$name': $(wc -l <"$keys" | tr -d ' ') violation(s)"
    fi
    rm -f "$output" "$keys"
    return 0
  fi
  if [ "$status" -eq 0 ]; then
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
    gate_shrink_baseline "$keys" "$(gate_baseline_file "$name")"
    rm -f "$output" "$keys"
    return 0
  fi
  # no violation lines, or an exit status the check does not declare as "violations found" (a crash
  # after some findings, a misconfiguration): nothing to baseline or filter
  if [ ! -s "$keys" ] || ! gate_is_findings_status "$status" "$name"; then
    cat "$output" >&2
    rm -f "$output" "$keys"
    if [ "$mode" = "advisory" ]; then warn "$label failed (advisory mode: not blocking)"; return 0; fi
    warn "$label failed (exit status $status)"
    FAILURES=$((FAILURES + 1))
    return 0
  fi
  new="$(mktemp)"
  gate_new_violations "$keys" "$(gate_baseline_file "$name")" >"$new"
  if [ "$mode" = "changed-files" ]; then
    scope="$(mktemp)"
    if changed_files >"$scope"; then
      # keep violations whose file ("path:" before the first colon) is in the change
      awk -F': ' 'NR == FNR { changed[$0] = 1; next } ($1 in changed)' "$scope" "$new" >"$new.scoped"
      mv "$new.scoped" "$new"
    else # unknown scope is not an empty one: judge every file, as strict mode does, for this run
      mode=strict
      warn "$label: cannot tell which files this run changes; checking all files (strict) for this run"
    fi
    rm -f "$scope"
  fi
  gate_shrink_baseline "$keys" "$(gate_baseline_file "$name")"
  count="$(wc -l <"$new" | tr -d ' ')"
  if [ "$count" -eq 0 ]; then
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  elif [ "$mode" = "advisory" ]; then
    warn "$label: $count violation(s) (advisory mode: not blocking)"
    sed 's/^/  /' "$new" >&2
  else
    warn "$label: $count new violation(s) (mode $mode; the baseline holds the ones from before adoption)"
    sed 's/^/  /' "$new" >&2
    FAILURES=$((FAILURES + 1))
  fi
  rm -f "$output" "$keys" "$new"
}

# run_gated <name> <label> <binary> [args...]: like run_tool, for an adopted project's mode.
# A missing binary is handled as run_tool does.
run_gated() {
  local name=$1 label=$2 binary=$3
  shift 3
  if ! has_command "$binary"; then record_missing_tool "$label" "$binary"; return 0; fi
  gate_run "$name" "$label" "$binary" "$@"
}
