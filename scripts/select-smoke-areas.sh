#!/usr/bin/env bash
# Picks the smoke areas a pull request has to run (REQ-114). Prints the areas one per line, or `all`;
# the reasons go to stderr. Never prints nothing: whenever the change cannot be mapped for sure, it is `all`.
# Usage: scripts/select-smoke-areas.sh <base-ref> [head-ref]   (head defaults to HEAD)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TABLE="$ROOT/docs/smoke-areas.txt"

all() {
  echo "smoke areas: all, $1" >&2
  echo all
  exit 0
}

# matches <file> <paths>: is the file one of the paths, or below a path that ends in /?
matches() {
  local p
  for p in $2; do
    case "$p" in
      */) case "$1" in "$p"*) return 0 ;; esac ;;
      *) [ "$1" = "$p" ] && return 0 ;;
    esac
  done
  return 1
}

main() {
  local base="${1:-}" head="${2:-HEAD}" files table shared file area paths selected="" areas="" mapped
  [ -n "$base" ] || all "no base ref given"
  [ -r "$TABLE" ] || all "area table docs/smoke-areas.txt unreadable"
  files="$(git -C "$ROOT" diff --name-only "$base...$head" 2>/dev/null)" || all "cannot read the diff $base...$head"
  [ -n "$files" ] || all "the diff $base...$head is empty"
  table="$(grep -v '^#' "$TABLE" | grep -v '^$')"
  shared="$(sed -n 's/^\*all\*|//p' <<<"$table")"
  while IFS='|' read -r area paths; do
    [ "$area" = '*all*' ] || areas="$areas $area"
  done <<<"$table"
  while IFS= read -r file; do
    matches "$file" "$shared" && all "$file is a shared file"
    mapped=0
    while IFS='|' read -r area paths; do
      [ "$area" = '*all*' ] && continue
      if matches "$file" "$paths tests/smoke/$area.sh xaden/requirements/$area/"; then
        mapped=1
        case " $selected " in *" $area "*) ;; *) selected="$selected $area" ;; esac
      fi
    done <<<"$table"
    [ "$mapped" -eq 1 ] || all "$file is in no area"
  done <<<"$files"
  [ -n "$selected" ] || all "no area selected"
  for area in $areas; do
    case " $selected " in
      *" $area "*) echo "$area" ;;
      *) echo "smoke areas: skip $area, no changed path in its row" >&2 ;;
    esac
  done
}

main "$@"
