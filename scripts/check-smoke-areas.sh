#!/usr/bin/env bash
# Checks that AGENTS.md has a row for every smoke area (REQ-092), so the list of what each area
# covers cannot go stale. An area is a file tests/smoke/<area>.sh; its row starts with | `<area>` |.
# The paths in that row must be those of the area in docs/smoke-areas.txt, which CI uses (REQ-114).
# Usage: scripts/check-smoke-areas.sh [scaffold-root]
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=SCRIPTDIR/../template/scripts/lib.sh
source "$ROOT/template/scripts/lib.sh"

missing=0
count=0
for file in "$ROOT"/tests/smoke/*.sh; do
  area="$(basename "$file" .sh)"
  [ "$area" = lib ] && continue
  count=$((count + 1))
  grep -qF "| \`$area\` |" "$ROOT/AGENTS.md" || { warn "smoke area $area has no row in AGENTS.md"; missing=1; }
done
# paths_in_table <area>: the paths of the area's row in AGENTS.md, sorted, one per line
# shellcheck disable=SC2016 # the backticks are literal Markdown
paths_in_table() {
  grep -F "| \`$1\` |" "$ROOT/AGENTS.md" | awk -F'|' '{print $4}' | grep -o '`[^`]*`' | tr -d '`' | LC_ALL=C sort
}
while IFS='|' read -r area paths; do
  case "$area" in '' | '#'*) continue ;; esac
  [ -f "$ROOT/tests/smoke/$area.sh" ] || [ "$area" = '*all*' ] || { warn "docs/smoke-areas.txt names $area, which has no tests/smoke/$area.sh"; missing=1; }
  [ "$area" = '*all*' ] && continue
  [ "$(paths_in_table "$area")" = "$(tr ' ' '\n' <<<"$paths" | LC_ALL=C sort)" ] ||
    { warn "the paths of area $area differ between AGENTS.md and docs/smoke-areas.txt"; missing=1; }
done <"$ROOT/docs/smoke-areas.txt"
[ "$missing" -eq 0 ] || exit 1
info "smoke areas: $count, each with a row in AGENTS.md"
