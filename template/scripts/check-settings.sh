#!/usr/bin/env bash
# Fails when a pull request changes how the project is checked, unless the team accepted it (REQ-137).
# The settings of the merge base are the reference: mode, missing-tools, hook-checks, expect, check.*, findings-status.*,
# require-signature, version, checksum, the baselines and the Xaden workflow. A pull request must not judge itself.
# SETTINGS_ACCEPTED=true (the workflow sets it from the label xaden-settings-accepted) accepts the changes.
# Outside a pull request, or in a repository that was not adopted at the merge base, nothing is compared.
# Usage: scripts/check-settings.sh
set -euo pipefail

# SCRIPTS: where the tooling lives. ROOT: the repository it works on; PROJECT_ROOT lets
# another repository (e.g. the scaffold itself) reuse these scripts.
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(cd "$SCRIPTS/.." && pwd)}"
# shellcheck source=SCRIPTDIR/lib.sh
source "$SCRIPTS/lib.sh"
layout_init "$ROOT"

CONTROLLED_KEYS='^(mode|missing-tools|hook-checks|expect|check\.[a-z0-9-]+|findings-status\.[a-z0-9-]+|require-signature|version|checksum)[[:space:]]*='
WORKFLOW_PATH=".github/workflows/xaden.yml"

# controlled_lines: the settings that decide how the project is checked, from a conf on stdin.
controlled_lines() { grep -E "$CONTROLLED_KEYS" || true; }

# at_base <path>: the file as the merge base had it; fails when it did not exist.
at_base() { git -C "$ROOT" show "$BASE:$1" 2>/dev/null; }

# settings_changes: one line per difference, nothing when the settings are the same.
settings_changes() {
  local before after path was now
  before="$(at_base "$TEAM_DIR_NAME/$CONF_NAME" | controlled_lines)"
  after="$(controlled_lines <"$ROOT/$TEAM_DIR_NAME/$CONF_NAME")"
  diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed -n -e 's/^< /  was: /p' -e 's/^> /  now: /p' || true
  for path in "$ROOT/$TEAM_DIR_NAME/$BASELINE_DIR_NAME"/*.txt; do
    [ -f "$path" ] || continue
    now="$(wc -l <"$path" | tr -d ' ')"
    was="$(at_base "$TEAM_DIR_NAME/$BASELINE_DIR_NAME/$(basename "$path")" | wc -l | tr -d ' ')"
    [ "$now" -le "$was" ] || printf '  baseline %s grew from %s to %s line(s)\n' "$(basename "$path" .txt)" "$was" "$now"
  done
  if ! cmp -s <(at_base "$WORKFLOW_PATH") "$ROOT/$WORKFLOW_PATH" 2>/dev/null; then printf '  %s differs from the merge base\n' "$WORKFLOW_PATH"; fi
}

[ "${EVENT_NAME:-}" = "pull_request" ] || exit 0
BASE="$(change_base "$ROOT")" || exit 0
[ -n "$BASE" ] && at_base "$TEAM_DIR_NAME/$CONF_NAME" >/dev/null || exit 0
[ -f "$ROOT/$TEAM_DIR_NAME/$CONF_NAME" ] || exit 0

changes="$(settings_changes)"
[ -n "$changes" ] || exit 0
warn "check settings changed in this pull request, compared with ${BASE:0:12}:"
printf '%s\n' "$changes" >&2
if [ "${SETTINGS_ACCEPTED:-}" = "true" ]; then
  info "accepted by the label xaden-settings-accepted; the commands above run as changed"
  exit 0
fi
warn "no mapped command ran. A person who may merge reads the lines above and adds the label xaden-settings-accepted to accept them."
exit 1
