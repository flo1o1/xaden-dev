#!/usr/bin/env bash
# Validates the requirement files under docs/requirements/ (REQ-021, REQ-046, REQ-047).
# Every epic folder has an EPIC.md with a title and a goal. Every REQ-nnn-<slug>.md has:
# front matter with a unique id matching the file name, type job|quality, epic equal to its
# folder, a known priority and status, and a YYYY-MM-DD date; a "# " title; a "## Job" job
# story (When …, I want to …, so I can …) or a "## Quality goal"; and at least one
# acceptance criterion. INDEX.md must match the files. "TODO:" markers are a warning, and an
# error with --release, as are template placeholders. The date placeholder is accepted only with
# ALLOW_TEMPLATE_PLACEHOLDERS=1 (the scaffold's own template check).
# Usage: scripts/check-requirements.sh [--release] [requirements-dir]
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

RELEASE_MODE=0
if [ "${1:-}" = "--release" ]; then
  RELEASE_MODE=1
  shift
fi
DIR="${1:-$REQ_DIR}"
# The date placeholder, assembled from two parts so project generation (which fills every
# literal occurrence in the template) does not rewrite it here.
DATE_PLACEHOLDER="{{""DATE}}"

[ -d "$DIR" ] || die "$DIR not found"
[ -f "$DIR/REQUIREMENTS.md" ] && die "$DIR/REQUIREMENTS.md uses the old table format; run scripts/migrate-requirements.sh"

# check_epics: every epic folder has EPIC.md with a title and a non-empty "## Goal".
check_epics() {
  local epic
  while IFS= read -r epic; do
    if [ ! -f "$epic/$EPIC_FILE" ]; then
      warn "${epic#"$DIR"/}: missing $EPIC_FILE"
      FAILURES=$((FAILURES + 1))
    elif ! awk '/^# ./ { title = 1 } /^## / { in_goal = ($0 == "## Goal") ; next }
                in_goal && NF { goal = 1 } END { exit !(title && goal) }' "$epic/$EPIC_FILE"; then
      warn "${epic#"$DIR"/}/$EPIC_FILE: needs a \"# \" title and a non-empty \"## Goal\""
      FAILURES=$((FAILURES + 1))
    elif grep -q 'TODO:' "$epic/$EPIC_FILE"; then
      warn "${epic#"$DIR"/}/$EPIC_FILE: contains TODO text"
    fi
  done < <(epic_dirs "$DIR")
}

# check_files: validates every requirement file; prints "requirements OK (n)" when all pass.
# shellcheck disable=SC2016 # single-quoted awk program, not shell
check_files() {
  local files
  files="$(requirement_files "$DIR")"
  if [ -z "$files" ] && [ "$LAYOUT" = "adopted" ]; then # a freshly adopted project starts without requirements
    echo "no requirements yet (write them with: xaden prompt kickoff)"
    return 0
  fi
  [ -n "$files" ] || { warn "no requirement files found in $DIR"; FAILURES=$((FAILURES + 1)); return 0; }
  printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 awk \
    -v types="$REQUIREMENT_TYPES" -v priorities="$REQUIREMENT_PRIORITIES" \
    -v statuses="$REQUIREMENT_STATUSES" -v allow_placeholders="${ALLOW_TEMPLATE_PLACEHOLDERS:-0}" \
    -v date_placeholder="$DATE_PLACEHOLDER" '
    function fail(msg) { printf "ERROR: %s: %s\n", short, msg > "/dev/stderr"; errors++ }
    # allowed: exact match against a space-separated list (a regex would let "d.*e" pass).
    function allowed(value, list,   names, count, i) {
      count = split(list, names, " ")
      for (i = 1; i <= count; i++) if (names[i] == value) return 1
      return 0
    }
    function valid_date(d) { return d ~ /^[0-9][0-9][0-9][0-9]-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$/ }
    function finish() {
      if (path == "") return
      id = field["id"]; type = field["type"]
      if (!front_closed) fail("missing front matter (--- … ---)")
      if (id !~ /^REQ-[0-9][0-9][0-9]+$/) fail("bad id \"" id "\"")
      else if (index(base, id "-") != 1 && base != id ".md") fail("file name must start with " id "-")
      if (id in seen) fail("duplicate id " id " (also " seen[id] ")")
      seen[id] = short
      if (!allowed(type, types)) fail("type must be one of: " types)
      if (field["epic"] != folder) fail("epic \"" field["epic"] "\" does not match folder \"" folder "\"")
      if (!allowed(field["priority"], priorities)) fail("unknown priority \"" field["priority"] "\"")
      if (!allowed(field["status"], statuses)) fail("unknown status \"" field["status"] "\"")
      if (field["updated"] == date_placeholder) {
        if (allow_placeholders != "1") fail("unfilled " date_placeholder " placeholder")
      } else if (!valid_date(field["updated"])) fail("invalid date \"" field["updated"] "\" (expected YYYY-MM-DD)")
      if (title == "") fail("missing \"# \" title")
      if (type == "job") {
        if (section_lines["Job"] == 0) fail("empty \"## Job\" section")
        else if (!has_todo["Job"] && !(tolower(job) ~ /when .*i want .*so i can/))
          fail("job must read \"When …, I want to …, so I can …\"")
      }
      if (type == "quality" && section_lines["Quality goal"] == 0) fail("empty \"## Quality goal\" section")
      if (criteria == 0) fail("\"## Acceptance criteria\" needs at least one \"- \" item")
      if (todo) printf "WARN: %s: contains TODO text\n", short > "/dev/stderr"
      files++
    }
    FNR == 1 {
      finish()
      path = FILENAME; n = split(path, parts, "/"); base = parts[n]; folder = parts[n - 1]
      short = folder "/" base
      split("", field); split("", section_lines); split("", has_todo)
      title = ""; section = ""; job = ""; criteria = 0; todo = 0; in_front = 0; front_closed = 0
      if ($0 == "---") { in_front = 1; next }
    }
    in_front && $0 == "---" { in_front = 0; front_closed = 1; next }
    in_front {
      key = $0; sub(/:.*/, "", key)
      value = $0; sub(/^[^:]*:[ \t]*/, "", value); sub(/[ \t]+$/, "", value)
      field[key] = value; next
    }
    /TODO:/ { todo = 1; if (section != "") has_todo[section] = 1 }
    /^# / && title == "" { title = substr($0, 3); next }
    /^## / { section = substr($0, 4); next }
    NF && section != "" { section_lines[section]++ }
    section == "Job" && NF { job = job " " $0 }
    section == "Acceptance criteria" && /^- ./ { criteria++ }
    END {
      finish()
      if (errors > 0) exit 1
      printf "requirements OK (%d)\n", files
    }'
}

# check_release_blockers: TODO text and template placeholders block a release.
check_release_blockers() {
  local found
  found="$( (grep -rl -e 'TODO:' -e '{{' "$DIR" --include='*.md' || true) | sed "s|^$DIR/||")"
  if [ -n "$found" ]; then
    warn "replace TODO text and placeholders before a release:"
    printf '%s\n' "$found" | sed 's/^/  /' >&2
    FAILURES=$((FAILURES + 1))
  fi
}

# check_index: INDEX.md and INDEX-full.md must equal what req.sh index would write.
check_index() {
  # compared as text, not through a pipe: cmp stops at the first difference and would break the pipe
  if [ "$(render_index "$DIR")" != "$(cat "$DIR/$INDEX_FILE" 2>/dev/null)" ] ||
    [ "$(render_index "$DIR" full)" != "$(cat "$DIR/$INDEX_FULL_FILE" 2>/dev/null)" ]; then
    warn "$INDEX_FILE or $INDEX_FULL_FILE is missing or stale; run scripts/req.sh index"
    FAILURES=$((FAILURES + 1))
  fi
}

# check_paths: a "paths:" entry that matches no file or folder of the repository hides its requirement
# from `scripts/req.sh for`, so each one is named as a warning (REQ-127); it never fails the check.
check_paths() {
  local id paths rest entry
  while IFS=$'\t' read -r id _ _ _ _ _ _ paths; do
    rest="$paths,"
    while [ -n "$paths" ] && [ -n "$rest" ]; do
      entry="${rest%%,*}"
      rest="${rest#*,}"
      entry="$(printf '%s' "$entry" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's#^\./##')"
      [ -n "$entry" ] || continue
      case "$entry" in
        *[\*\?\[]*) compgen -G "$ROOT/$entry" >/dev/null || warn "$id: paths entry \"$entry\" matches no file or folder" ;;
        *) [ -e "$ROOT/${entry%/}" ] || warn "$id: paths entry \"$entry\" matches no file or folder" ;;
      esac
    done
  done < <(requirement_records "$DIR")
}

check_epics
check_files || FAILURES=$((FAILURES + 1))
check_index
check_paths
[ "$RELEASE_MODE" = "1" ] && check_release_blockers
[ "$FAILURES" -eq 0 ] || exit 1
