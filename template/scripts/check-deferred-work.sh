#!/usr/bin/env bash
# Fails when a row of docs/deferred-work.md lacks a source, a summary or evidence, or cites a REQ-nnn that
# does not exist (REQ-125). Rows inside <!-- comments --> are ignored. Columns: Source | Summary | Evidence.
# Usage: scripts/check-deferred-work.sh
set -euo pipefail

# SCRIPTS: where the tooling lives. ROOT: the repository it works on; PROJECT_ROOT lets
# another repository (e.g. the scaffold itself) reuse these scripts.
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(cd "$SCRIPTS/.." && pwd)}"
# shellcheck source=SCRIPTDIR/lib.sh
source "$SCRIPTS/lib.sh"
layout_init "$ROOT"

# deferred_problems <file> <known-ids>: one line per invalid row, nothing when all are fine.
# shellcheck disable=SC2016 # single-quoted awk program, not shell
deferred_problems() {
  awk -F'|' -v known="$2" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    BEGIN { count = split(known, list, " "); for (i = 1; i <= count; i++) exists[list[i]] = 1 }
    /<!--/ { in_comment = 1 }
    in_comment { if (/-->/) in_comment = 0; next }
    !/^\|/ || /^\|[ \t]*-+[ \t]*\|/ { next }
    {
      source = trim($2); summary = trim($3); evidence = trim($4)
      if (source == "Source") next
      label = (source == "" ? "row without source" : source) ": " (summary == "" ? "(no summary)" : summary)
      if (source == "") { print label ": no source"; next }
      if (summary == "") { print label ": no summary"; next }
      if (evidence == "") { print label ": no evidence"; next }
      rest = source " " summary " " evidence
      while (match(rest, /REQ-[0-9]+/)) {
        id = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
        if (!(id in exists)) print label ": " id " is not a requirement of this project"
      }
    }' "$1"
}

if [ ! -f "$DEFERRED_FILE" ]; then # created with the first deferral in an adopted project
  echo "no ${DEFERRED_FILE#"$ROOT"/}; nothing to check"
  exit 0
fi
known_ids="$(PROJECT_ROOT="$ROOT" "$SCRIPTS/req.sh" list | awk '{ printf "%s ", $1 }')"
problems="$(deferred_problems "$DEFERRED_FILE" "$known_ids")"
if [ -n "$problems" ]; then
  printf '%s\n' "$problems" | while IFS= read -r problem; do warn "${DEFERRED_FILE#"$ROOT"/}: $problem"; done
  exit 1
fi
echo "deferred work OK"
