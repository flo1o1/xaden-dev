#!/usr/bin/env bash
# Checks for every project, whatever its language, for scripts/check.sh. Sourced, not executed.
# All optional (REQ-051): workflow linters run when installed; jscpd runs once .jscpd.json exists.

WORKFLOW_PATTERN='^\.github/workflows/[^/]+\.ya?ml$'

# has_project_file <regex>: true if a tracked file matches. grep reads all input (no -q):
# stopping early would kill the listing with SIGPIPE, which pipefail reports as "no match".
has_project_file() { list_project_files | tr '\0' '\n' | grep -E "$1" >/dev/null; }

# run_workflow_check <name> <binary> [args...]: with JUDGE_BY_MODE=1 (check.sh) the existing workflows are judged
# by the mode and the baseline of the project (REQ-068); otherwise any finding fails.
run_workflow_check() {
  local name=$1
  shift
  if [ "${JUDGE_BY_MODE:-0}" = "1" ]; then run_gated "$name" "workflows: $name" "$@"; else run_tool "workflows: $name" "$@"; fi
}

# stack_check <mode>: lints staged or all workflow files; full mode also checks duplication.
stack_check() {
  collect_files "$1" "$WORKFLOW_PATTERN"
  if [ ${#TARGETS[@]} -gt 0 ]; then
    if has_command actionlint; then run_workflow_check actionlint actionlint "${TARGETS[@]}"; fi
    if has_command zizmor; then
      if [ "${JUDGE_BY_MODE:-0}" = "1" ]; then # annotations name file and line, so the gate can judge them
        run_workflow_check zizmor zizmor --offline --format github "${TARGETS[@]}"
      else
        run_workflow_check zizmor zizmor --offline "${TARGETS[@]}"
      fi
    fi
  fi
  [ "$1" = "full" ] || return 0
  if [ -f .jscpd.json ]; then
    PATH="$PWD/node_modules/.bin:$PATH" run_tool "duplication: jscpd" jscpd .
  fi
}

# stack_tips: optional tools that fit this project and are not used yet.
stack_tips() {
  if has_project_file "$WORKFLOW_PATTERN"; then
    has_command actionlint ||
      tip "workflows: actionlint finds errors in GitHub Actions workflows before they run. Install it; scripts/check.sh then runs it"
    has_command zizmor ||
      tip "workflows: zizmor finds security problems in GitHub Actions workflows (injection, leaked credentials). Install it; scripts/check.sh then runs it offline"
  fi
  if has_project_file "$SOURCE_FILE_PATTERN" && [ ! -f .jscpd.json ]; then
    tip "duplication: jscpd finds copy-pasted code. Add .jscpd.json (see docs/optional-tools.md) and install jscpd"
  fi
  return 0
}
