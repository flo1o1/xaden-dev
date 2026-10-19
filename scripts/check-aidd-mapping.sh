#!/usr/bin/env bash
# Checks the page that maps the AIDD Manifesto to Xaden's rules (REQ-116): one row for each of the 4 values
# and 12 principles with a valid status, every REQ-nnn and path it cites exists, the attribution is there,
# and it claims no certification or endorsement.
# Usage: scripts/check-aidd-mapping.sh [scaffold-root]
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=SCRIPTDIR/../template/scripts/lib.sh
source "$ROOT/template/scripts/lib.sh"
PAGE="$ROOT/docs/guide/developer/xaden-and-the-aidd-manifesto.md"

[ -f "$PAGE" ] || die "the AIDD mapping page is missing: ${PAGE#"$ROOT"/}"
bad=0
fail() { warn "AIDD mapping: $1"; bad=1; }

for key in V1 V2 V3 V4 P01 P02 P03 P04 P05 P06 P07 P08 P09 P10 P11 P12; do
  row="$(grep -E "^\| $key \|" "$PAGE" || true)"
  if [ "$(printf '%s' "$row" | grep -c .)" -ne 1 ]; then fail "needs exactly one row for $key"; continue; fi
  status="$(printf '%s' "$row" | awk -F'|' '{gsub(/^ +| +$/, "", $4); print $4}')"
  case "$status" in met | partly | "not met") ;; *) fail "$key has the status '$status', not met, partly or not met" ;; esac
done

while IFS= read -r id; do
  ls "$ROOT"/docs/requirements/*/"$id"-*.md >/dev/null 2>&1 || fail "$id is cited but does not exist"
done < <(grep -oE 'REQ-[0-9]+' "$PAGE" | sort -u)
tick=$(printf '\140') # the backtick that wraps a path in the page
while IFS= read -r path; do
  [ -e "$ROOT/$path" ] || fail "$path is cited but does not exist"
done < <(grep -oE "$tick(template|docs|scripts)/[^$tick ]+$tick" "$PAGE" | tr -d "$tick" | sort -u)

grep -qE 'v1\.1\.1' "$PAGE" || fail "the manifesto version is not named"
grep -qF 'https://creativecommons.org/licenses/by/4.0/' "$PAGE" || fail "the CC BY 4.0 license link is missing"
grep -qF 'https://ai-driven-development.org' "$PAGE" || fail "the source link is missing"
grep -qiE 'certified|endorsed|official' "$PAGE" && fail "the page must not say certified, endorsed or official"
grep -qF 'ai-driven-development.org' "$ROOT/THIRD-PARTY.md" || fail "THIRD-PARTY.md does not list the manifesto"
[ "$bad" -eq 0 ] || exit 1
info "AIDD mapping: 16 rows, every cited rule exists, attribution present"
