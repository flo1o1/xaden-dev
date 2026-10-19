#!/usr/bin/env bash
# Looks up and creates requirements so nobody has to quote them from memory (REQ-047).
# Usage: scripts/req.sh list [--epic <epic>] [--status <status>]   one line per requirement
#        scripts/req.sh show REQ-nnn [--brief]        the requirement file; --brief: goal and criteria only
#        scripts/req.sh for <path>...                 the requirements whose "paths:" line matches a file or folder
#        scripts/req.sh find <word>...                the requirements whose title or text holds every word
#        scripts/req.sh new <epic> <job|quality> "<title>"   creates the next REQ-nnn as draft
#        scripts/req.sh index                         rewrites docs/requirements/INDEX.md and INDEX-full.md
set -euo pipefail

# SCRIPTS: where the tooling lives. ROOT: the repository it works on; PROJECT_ROOT lets
# another repository (e.g. the scaffold itself) reuse these scripts.
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(cd "$SCRIPTS/.." && pwd)}"
# shellcheck source=SCRIPTDIR/lib.sh
source "$SCRIPTS/lib.sh"
# shellcheck source=SCRIPTDIR/requirements-lib.sh
source "$SCRIPTS/requirements-lib.sh"
layout_init "$ROOT"
DIR="$REQ_DIR"
# Text the new file starts with; check-requirements.sh warns until it is replaced.
TODO_JOB="TODO: When <situation>, I want to <motivation>, so I can <expected outcome>."
TODO_QUALITY="TODO: <measurable quality goal, e.g. \"95 % of searches answer within 1 s\">."
TODO_CRITERION="TODO: Given <context>, when <action>, then <observable result>."

# list_requirements [--epic <epic>] [--status <status>]: prints "ID [status, priority] title",
# sorted by ID; the filters narrow the list (REQ-126).
list_requirements() {
  local epic="" status=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --epic) epic="${2:-}"; [ -n "$epic" ] || die "--epic needs an epic name"; shift 2 ;;
      --status) status="${2:-}"; [ -n "$status" ] || die "--status needs a status"; shift 2 ;;
      *) die "usage: scripts/req.sh list [--epic <epic>] [--status <status>]" ;;
    esac
  done
  [ -z "$status" ] || case " $REQUIREMENT_STATUSES " in *" $status "*) ;; *) die "status must be one of: $REQUIREMENT_STATUSES" ;; esac
  requirement_records "$DIR" | LC_ALL=C sort | awk -F'\t' -v epic="$epic" -v status="$status" \
    '(epic == "" || $5 == epic) && (status == "" || $2 == status) { printf "%s [%s, %s] %s\n", $1, $2, $3, $6 }'
}

# path_matches <entry> <path>: true when a "paths:" entry covers a repository path. An entry that ends
# in / or names a folder covers everything below it; an entry with * ? [ is a glob over the whole path
# (a * also crosses /); anything else is one file (REQ-127).
path_matches() {
  local entry=$1 path=$2
  entry="${entry#./}"
  path="${path#./}"
  path="${path#"$ROOT"/}"
  [ -n "$entry" ] || return 1
  case "$entry" in
    *[\*\?\[]*)
      # shellcheck disable=SC2254 # the entry is a glob on purpose
      case "$path" in $entry) return 0 ;; esac
      return 1 ;;
  esac
  entry="${entry%/}"
  case "$path" in "$entry" | "$entry"/*) return 0 ;; esac
  return 1
}

# requirements_for <path>...: "ID [status, priority] title" of each requirement whose "paths:" line
# matches one of the paths; a requirement without "paths:" never matches (REQ-127).
requirements_for() {
  [ $# -gt 0 ] || die "usage: scripts/req.sh for <path>..."
  local id status priority title paths entry path rest
  requirement_records "$DIR" | LC_ALL=C sort | while IFS=$'\t' read -r id status priority _ _ title _ paths; do
    [ -n "$paths" ] || continue
    rest="$paths,"
    while [ -n "$rest" ]; do
      entry="${rest%%,*}"
      rest="${rest#*,}"
      entry="$(printf '%s' "$entry" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      for path in "$@"; do
        if path_matches "$entry" "$path"; then printf '%s [%s, %s] %s\n' "$id" "$status" "$priority" "$title"; rest=""; break; fi
      done
    done
  done
}

# find_requirements <word>...: "ID [status, priority] title" of each requirement whose file holds every
# word, ignoring case; it never prints a whole file (REQ-127).
find_requirements() {
  [ $# -gt 0 ] || die "usage: scripts/req.sh find <word>..."
  local id status priority title path word hit
  requirement_records "$DIR" | LC_ALL=C sort | while IFS=$'\t' read -r id status priority _ _ title path _; do
    hit=1
    for word in "$@"; do grep -qiF -- "$word" "$path" || { hit=0; break; }; done
    if [ "$hit" = 1 ]; then printf '%s [%s, %s] %s\n' "$id" "$status" "$priority" "$title"; fi
  done
}

# show_requirement <REQ-nnn> [--brief]: prints the path and the content of one requirement; with
# --brief only status, title, the job or quality goal and the acceptance criteria (REQ-126).
show_requirement() {
  local path brief=""
  path="$(requirement_path "$DIR" "$1")"
  case "${2:-}" in "") ;; --brief) brief=1 ;; *) die "usage: scripts/req.sh show REQ-nnn [--brief]" ;; esac
  printf 'File: %s\n\n' "${path#"$ROOT"/}"
  if [ -z "$brief" ]; then cat "$path"; return 0; fi
  awk '
    FNR == 1 && $0 == "---" { front = 1; next }
    front && $0 == "---" { front = 0; next }
    front { if ($0 ~ /^(id|status):/) print; next }
    /^## / { keep = ($0 == "## Job" || $0 == "## Quality goal" || $0 == "## Acceptance criteria") }
    /^# / || keep { print }' "$path"
}

# new_requirement <epic> <type> <title>: creates the next requirement as a draft and
# refreshes the index. Prints the new file's path.
new_requirement() {
  local epic=$1 type=$2 title=$3 id path statement="$TODO_JOB"
  is_epic_name "$epic" || die "epic must be lowercase words with dashes: $epic"
  case " $REQUIREMENT_TYPES " in *" $type "*) ;; *) die "type must be one of: $REQUIREMENT_TYPES" ;; esac
  [ -n "$title" ] || die "title is empty"
  [ "$type" = "quality" ] && statement="$TODO_QUALITY"
  write_epic "$DIR/$epic" "$epic" "TODO: The big job this epic serves (When …, I want to …, so I can …)."
  id="$(next_requirement_id "$DIR")"
  path="$DIR/$epic/$id-$(slugify "$title").md"
  write_requirement "$path" "$id" "$type" "$epic" "should" "draft" "$(date +%Y-%m-%d)" \
    "$title" "$statement" "$TODO_CRITERION"
  write_index
  printf '%s\n' "${path#"$ROOT"/}"
}

# write_index: regenerates INDEX.md and INDEX-full.md from the requirement files.
write_index() {
  render_index "$DIR" >"$DIR/$INDEX_FILE"
  render_index "$DIR" full >"$DIR/$INDEX_FULL_FILE"
}

[ -d "$DIR" ] || die "${DIR#"$ROOT"/} not found (old table format? run scripts/migrate-requirements.sh)"
case "${1:-}" in
  list) shift; list_requirements "$@" ;;
  show) show_requirement "${2:-}" "${3:-}" ;;
  for) shift; requirements_for "$@" ;;
  find) shift; find_requirements "$@" ;;
  new) new_requirement "${2:-}" "${3:-}" "${4:-}" ;;
  index) write_index && info "wrote ${DIR#"$ROOT"/}/$INDEX_FILE" ;;
  *) die "usage: scripts/req.sh list [--epic <epic>] [--status <status>] | show REQ-nnn [--brief] | for <path>... | find <word>... | new <epic> <job|quality> \"<title>\" | index" ;;
esac
