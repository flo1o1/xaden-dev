#!/usr/bin/env bash
# Keeps THIRD-PARTY.md in step with the code (REQ-113): every tool the stack files, the presets, the
# generated CI workflow and docs/optional-tools.md name needs a line there with a link and a license.
# Usage: scripts/check-third-party.sh [scaffold-root]
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=SCRIPTDIR/../template/scripts/lib.sh
source "$ROOT/template/scripts/lib.sh"
FILE="$ROOT/THIRD-PARTY.md"
LICENSE_WORD='MIT|GPL|Apache|BSD|ISC|MPL|CC[- ]BY|Artistic|PolyForm'

[ -f "$FILE" ] || die "THIRD-PARTY.md is missing"

# tool_names: one name per line. shortcut: greps the call forms the scripts use today; a new form
# needs a line here, and the smoke test (REQ-113) shows when the list stops finding tools.
tool_names() {
  local stacks="$ROOT/template/scripts/stacks" presets="$ROOT/template/presets" ci="$ROOT/scripts/adopt/ci.yml"
  sed -n -E 's/.*run_(required_)?tool "[^"]*" ([a-z][a-z0-9-]*).*/\2/p' "$stacks"/*.sh
  sed -n -E 's/.*has_command ([a-z][a-z0-9-]*).*/\1/p' "$stacks"/*.sh
  sed -n -E 's/.*tip "[a-z]+: ([A-Za-z-]+) .*/\1/p' "$stacks"/*.sh
  grep -hEv '^(#|$)' "$presets"/*/requirements-dev.txt "$presets"/*/devDependencies.txt | sed -E 's/^(@?[^@=]*)[@=].*/\1/'
  sed -n -E 's/.*(pipx|pip) install "([a-z-]+)==.*/\2/p; s/.*apt-get install -y ([a-z-]+).*/\1/p; s/^ *(- )?uses: ([^@ ]+)@.*/\2/p' "$ci"
  sed -n -E 's/^  ([A-Z_]+)_VERSION:.*/\1/p' "$ci" | grep -v '^XADEN$' | tr 'A-Z_' 'a-z-'
  sed -n -E 's/^\| \[([^]]+)\].*/\1/p' "$ROOT/template/docs/optional-tools.md"
}

bad=0
while IFS= read -r tool; do
  # a name alone is not enough: the same line needs a link and a license
  if ! grep -iF -- "$tool" "$FILE" | grep -i 'https://' | grep -Eqi "$LICENSE_WORD"; then
    warn "THIRD-PARTY.md has no line with a link and a license for: $tool"
    bad=1
  fi
done < <(tool_names | sort -u)
[ "$bad" -eq 0 ] || exit 1
info "third party: every tool the code names is credited with a link and a license"
