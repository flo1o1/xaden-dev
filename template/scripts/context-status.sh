#!/usr/bin/env bash
# Prints rule IDs, requirement counts (IDs of those not done) and a fingerprint of the rule/requirement files. The
# assistant quotes the CONTEXT CHECK line in its first reply; the user compares it with their
# own run to spot stale or missing context. A consistency aid only: a matching fingerprint
# does not prove that the files were read or followed.
# Usage: scripts/context-status.sh
set -euo pipefail

# SCRIPTS: where the tooling lives. ROOT: the repository it works on; PROJECT_ROOT lets
# another repository (e.g. the scaffold itself) reuse these scripts.
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(cd "$SCRIPTS/.." && pwd)}"
# shellcheck source=SCRIPTDIR/lib.sh
source "$SCRIPTS/lib.sh"
# shellcheck source=SCRIPTDIR/update-check-lib.sh
source "$SCRIPTS/update-check-lib.sh"
# Where the CC-nn rules are defined (RULES_FILE) and the clean-code guide (CLEAN_CODE_FILE).
layout_init "$ROOT"

# rule_and_requirement_files: the rule files (REQ-126: the files of docs/rules/ too) plus every
# Markdown file of the requirements, in a fixed order so the fingerprint is the same on every machine.
rule_and_requirement_files() {
  printf '%s\n' "$RULES_FILE" "$CLEAN_CODE_FILE"
  [ ! -d "$RULES_DIR" ] || find "$RULES_DIR" -type f -name '*.md' | LC_ALL=C sort
  find "$REQ_DIR" -type f -name '*.md' | LC_ALL=C sort
}

# fingerprint: CRC of all rule and requirement files (POSIX cksum, same on Linux and macOS).
fingerprint() { rule_and_requirement_files | tr '\n' '\0' | xargs -0 cat | cksum | cut -d' ' -f1; }

# rule_ids: defined rule IDs, e.g. "CC-01 CC-02 ...".
rule_ids() { grep -oE '^- \*\*CC-[0-9]{2}\*\*' "$RULES_FILE" | grep -oE 'CC-[0-9]{2}' | tr '\n' ' '; }

# requirement_summary: "63 (62 done, 1 draft); not done: REQ-063(draft)". Done IDs are only
# counted, so the line stays short however many requirements a project has.
requirement_summary() {
  "$SCRIPTS/req.sh" list | awk '
    { id = $1; status = $2; sub(/^\[/, "", status); sub(/,$/, "", status) }
    !(status in count) { order[++kinds] = status }
    { count[status]++; total++ }
    status != "done" { open = open " " id "(" status ")" }
    END {
      for (i = 1; i <= kinds; i++) counts = counts (i > 1 ? ", " : "") count[order[i]] " " order[i]
      printf "%d (%s); not done:%s\n", total, counts, (open == "" ? " none" : open)
    }'
}

echo "CONTEXT CHECK $(fingerprint)"
echo "rules: $(rule_ids)"
echo "requirements: $(requirement_summary)"
# REQ-084 the cached result of the update check, if the person turned it on; never the network
update_check_print_cached "$ROOT"
