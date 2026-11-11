#!/usr/bin/env bash
# Prints "true" when the label that accepts changed check settings counts, "false" otherwise (REQ-160).
# It counts only when the latest event of the label on the pull request is "labeled", the person who added it is not the
# pull request's author, and it happened after the last push (the later of the head commit's committer date and the latest
# force-push event of the timeline). Anything that cannot be determined (no jq, unreadable JSON, a bad argument) prints "false":
# unknown must not mean accepted. The workflow xaden-settings.yml fetches the timeline and sets SETTINGS_ACCEPTED from this.
# Usage: scripts/label-accepted.sh <timeline.json | -> <author-login> <head-commit-epoch> [label]
#   timeline.json: the output of `gh api --paginate repos/<owner>/<repo>/issues/<n>/timeline` (one or several JSON arrays)
set -uo pipefail

# label_accepted <timeline file or -> <author> <head epoch> <label>: prints true or false, always returns 0.
label_accepted() {
  local file="$1" author="$2" head_epoch="$3" label="$4" answer
  printf '%s' "$author" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9-]*(\[bot\])?$' || { echo false; return 0; }
  printf '%s' "$head_epoch" | grep -Eq '^[0-9]{1,12}$' || { echo false; return 0; }
  command -v jq >/dev/null 2>&1 || { echo false; return 0; }
  answer="$(jq -rs --arg author "$author" --argjson head "$head_epoch" --arg label "$label" '
      [ .[] | if type == "array" then .[] else . end ] as $events
      | ([ $events[] | select(.event == "head_ref_force_pushed") | .created_at | fromdateiso8601 ] + [$head] | max) as $pushed
      | ([ $events[] | select((.event == "labeled" or .event == "unlabeled") and .label.name == $label) ]
          | sort_by(.created_at) | last) as $last
      | if $last != null and $last.event == "labeled" and ($last.actor.login // "") != ""
           and (($last.actor.login | ascii_downcase) != ($author | ascii_downcase))
           and (($last.created_at | fromdateiso8601) > $pushed)
        then "true" else "false" end' "$file" 2>/dev/null)" || answer=false
  [ "$answer" = "true" ] && echo true || echo false
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  [ $# -ge 3 ] || { echo "usage: scripts/label-accepted.sh <timeline.json | -> <author-login> <head-commit-epoch> [label]" >&2; echo false; exit 0; }
  label_accepted "$1" "$2" "$3" "${4:-xaden-settings-accepted}"
fi
