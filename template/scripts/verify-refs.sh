#!/usr/bin/env bash
# Rejects commit messages that cite rules/requirements which do not exist.
# Usage: scripts/verify-refs.sh <commit-message-file>
# - Every REQ-nnn must be a requirement file in the requirements folder; every CC-nn a rule in AGENTS.md.
# - `feat` needs a "Refs: REQ-nnn" trailer; `fix` needs one or "Refs: none".
set -euo pipefail

# SCRIPTS: where the tooling lives. ROOT: the repository it works on; PROJECT_ROOT lets
# another repository (e.g. the scaffold itself) reuse these scripts.
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(cd "$SCRIPTS/.." && pwd)}"
# shellcheck source=SCRIPTDIR/lib.sh
source "$SCRIPTS/lib.sh"
layout_init "$ROOT"
REQUIREMENTS_RELATIVE="${REQ_DIR#"$ROOT"/}" # docs/requirements, or xaden/requirements

MESSAGE_FILE=${1:-}
[ -f "$MESSAGE_FILE" ] || die "usage: scripts/verify-refs.sh <commit-message-file>"

# read_committed_version <path>: the file as it will be committed (git index) when tracked,
# otherwise the working-tree file. Unstaged edits must not validate a commit (REQ-020).
# git exports GIT_DIR to hooks, which would make `-C <dir>` treat <dir> as the top of the work
# tree and read a file of the same name from the repository top; the subshell drops GIT_DIR and
# GIT_WORK_TREE and keeps the index git commits from, made absolute before -C changes directory.
read_committed_version() {
  (
    unset GIT_DIR GIT_WORK_TREE
    case "${GIT_INDEX_FILE:-/}" in /*) ;; *) GIT_INDEX_FILE="$PWD/$GIT_INDEX_FILE" ;; esac
    git -C "$(dirname "$1")" show ":./$(basename "$1")"
  ) 2>/dev/null || cat "$1"
}

# Temporary export of the git index; removed on exit.
SNAPSHOT=""

# committed_requirements_root: a directory whose docs/requirements holds the requirement files
# as they will be committed (git index). Outside git, the working tree itself.
committed_requirements_root() {
  local prefix
  if ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    printf '%s' "$ROOT"
    return 0
  fi
  prefix="$(git -C "$ROOT" rev-parse --show-prefix)" # checkout-index writes repository paths
  mkdir -p "$SNAPSHOT/${prefix}$REQUIREMENTS_RELATIVE"
  # The settings file is exported too: its presence selects the adopted layout (REQ-070).
  git -C "$ROOT" ls-files -z -- "$REQUIREMENTS_RELATIVE" "$TEAM_DIR_NAME/$CONF_NAME" |
    git -C "$ROOT" checkout-index -z --stdin --prefix="$SNAPSHOT/"
  printf '%s' "$SNAPSHOT/$prefix"
}

SNAPSHOT="$(mktemp -d)"
# The message as git stores it: no comment lines, no diff below the `git commit -v` scissors line.
CLEAN_MESSAGE_FILE="$(mktemp)"
trap 'rm -rf "$SNAPSHOT" "$CLEAN_MESSAGE_FILE"' EXIT
sed '/^. -\{24\} >8 -\{24\}$/,$d' "$MESSAGE_FILE" | git stripspace --strip-comments >"$CLEAN_MESSAGE_FILE"
REQUIREMENTS_ROOT="$(committed_requirements_root)"
# "ID [status, priority] title" per committed requirement.
REQUIREMENTS_LIST="$(PROJECT_ROOT="$REQUIREMENTS_ROOT" "$SCRIPTS/req.sh" list)"
RULES_TEXT="$(read_committed_version "$RULES_FILE")"

# check_cited_ids: every cited ID must exist in the source of truth.
check_cited_ids() {
  local id
  while IFS= read -r id; do
    case "$id" in
      REQ-*) grep -q "^$id " <<<"$REQUIREMENTS_LIST" || die "commit cites unknown requirement $id (rule: $(rule_file_hint git))" ;;
      CC-*) printf '%s\n' "$RULES_TEXT" | grep -Eq "^- \*\*$id\*\*" || die "commit cites unknown rule $id" ;;
    esac
  done < <(grep -oE 'REQ-[0-9]{3,}|CC-[0-9]{2}' "$CLEAN_MESSAGE_FILE" | sort -u)
}

# requirement_status <REQ-nnn>: status of the requirement as committed.
requirement_status() {
  printf '%s\n' "$REQUIREMENTS_LIST" | sed -n "s/^$1 \[\([^,]*\),.*/\1/p"
}

# check_referenced_status <refs-text>: feat/fix may only implement approved, in-progress or
# done requirements; drafts must be approved first, dropped ones are gone (REQ-021).
check_referenced_status() {
  local id status
  for id in $(printf '%s' "$1" | grep -oE 'REQ-[0-9]{3,}' | sort -u); do
    status="$(requirement_status "$id")"
    case "$status" in
      approved | in-progress | done) ;;
      *) die "$id has status '$status'; feat/fix may only reference approved, in-progress or done requirements (rule: $(rule_file_hint git))" ;;
    esac
  done
}

# check_required_trailer: feat/fix must say which requirement they serve.
check_required_trailer() {
  local type refs
  type=$(head -n 1 "$CLEAN_MESSAGE_FILE" | sed -E 's/^([a-z]+).*/\1/')
  # Only real git trailers count (last paragraph), not "Refs:" lines in prose (REQ-022).
  refs=$(git interpret-trailers --parse <"$CLEAN_MESSAGE_FILE" | grep -E '^Refs:' || true)
  case "$type" in
    feat) printf '%s' "$refs" | grep -Eq 'REQ-[0-9]{3,}' || die "feat commits need a 'Refs: REQ-nnn' trailer (rule: $(rule_file_hint git))" ;;
    fix) printf '%s' "$refs" | grep -Eq 'REQ-[0-9]{3,}|^Refs:[[:space:]]*none[[:space:]]*$' || die "fix commits need 'Refs: REQ-nnn' or 'Refs: none' (rule: $(rule_file_hint git))" ;;
  esac
  case "$type" in feat | fix) check_referenced_status "$refs" ;; esac
}

check_cited_ids
check_required_trailer
