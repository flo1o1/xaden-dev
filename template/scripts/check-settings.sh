#!/usr/bin/env bash
# Fails when a pull request changes how the project is checked, unless the team accepted it (REQ-137).
# The settings of the merge base are the reference: mode, missing-tools, the pin of the optional AIDD add-on (aidd-*), hook-checks, expect, check.*, findings-status.*,
# require-signature, version, checksum, the baselines and the Xaden workflow. A pull request must not judge itself.
# SETTINGS_ACCEPTED=true (the workflow sets it from the label xaden-settings-accepted) accepts the changes.
# Outside a pull request, or in a repository that was not adopted at the merge base, nothing is compared.
# HEAD_REF=<ref> (REQ-160) is the trusted run: the checkout is the base branch, the pull request is a ref that was fetched as
# data, and nothing of it is executed or checked out. Both sides are read with git, and a scope that cannot be determined
# fails the run instead of passing it. The workflow .github/workflows/xaden-settings.yml runs it that way.
# Usage: scripts/check-settings.sh
set -euo pipefail

# SCRIPTS: where the tooling lives. ROOT: the repository it works on; PROJECT_ROOT lets
# another repository (e.g. the scaffold itself) reuse these scripts.
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(cd "$SCRIPTS/.." && pwd)}"
# shellcheck source=SCRIPTDIR/lib.sh
source "$SCRIPTS/lib.sh"
layout_init "$ROOT"

CONTROLLED_KEYS='^(mode|missing-tools|hook-checks|expect|check\.[a-z0-9-]+|findings-status\.[a-z0-9-]+|require-signature|version|checksum|aidd-[a-z]+)[[:space:]]*='
WORKFLOW_PATHS=".github/workflows/xaden.yml .github/workflows/xaden-settings.yml"
BASELINE_FILE_PATTERN='^[a-z0-9-]+\.txt$' # a name from a pull request reaches the log: only plain names do

# controlled_lines: the settings that decide how the project is checked, from a conf on stdin.
# Leading whitespace goes first: the conf parser (conf_get, conf_keys) ignores it, so an indented key counts (REQ-157).
controlled_lines() { sed -E 's/^[[:space:]]+//' | grep -E "$CONTROLLED_KEYS" || true; }

# at_base <path>: the file as the merge base had it; fails when it did not exist.
at_base() { git -C "$ROOT" show "$BASE:$1" 2>/dev/null; }

# after_show <path>: the file as the pull request has it; fails when it has none.
after_show() {
  if [ -n "${HEAD_REF:-}" ]; then git -C "$ROOT" show "$HEAD_REF:$1" 2>/dev/null; else cat "$ROOT/$1" 2>/dev/null; fi
}

# after_baselines: the names of the baseline files the pull request has, plain names only.
after_baselines() {
  if [ -n "${HEAD_REF:-}" ]; then
    git -C "$ROOT" ls-tree --name-only "$HEAD_REF" "$TEAM_DIR_NAME/$BASELINE_DIR_NAME/" 2>/dev/null | sed 's#.*/##'
  else
    ls "$ROOT/$TEAM_DIR_NAME/$BASELINE_DIR_NAME" 2>/dev/null
  fi | grep -E "$BASELINE_FILE_PATTERN" || true
}

# blob_ids <path>: "<base blob> <pull request blob>", empty for a file that side does not have.
blob_ids() {
  local base_blob after_blob
  base_blob="$(git -C "$ROOT" rev-parse -q --verify "$BASE:$1" 2>/dev/null || true)"
  if [ -n "${HEAD_REF:-}" ]; then
    after_blob="$(git -C "$ROOT" rev-parse -q --verify "$HEAD_REF:$1" 2>/dev/null || true)"
  elif [ -f "$ROOT/$1" ]; then
    after_blob="$(git -C "$ROOT" hash-object -- "$ROOT/$1")"
  else
    after_blob=""
  fi
  printf '%s %s' "$base_blob" "$after_blob"
}

# settings_changes: one line per difference, nothing when the settings are the same.
settings_changes() {
  local before after name path was now
  before="$(at_base "$TEAM_DIR_NAME/$CONF_NAME" | controlled_lines)"
  after="$(after_show "$TEAM_DIR_NAME/$CONF_NAME" | controlled_lines)"
  diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed -n -e 's/^< /  was: /p' -e 's/^> /  now: /p' || true
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    path="$TEAM_DIR_NAME/$BASELINE_DIR_NAME/$name"
    now="$(after_show "$path" | wc -l | tr -d ' ')"
    was="$(at_base "$path" | wc -l | tr -d ' ')"
    [ "$now" -le "$was" ] || printf '  baseline %s grew from %s to %s line(s)\n' "${name%.txt}" "$was" "$now"
  done < <(after_baselines)
  for path in $WORKFLOW_PATHS; do
    [ "$(blob_ids "$path")" = "$(blob_ids "$path" | awk '{ print $1 " " $1 }')" ] || printf '  %s differs from the merge base\n' "$path"
  done
}

[ "${EVENT_NAME:-}" = "pull_request" ] || exit 0
if [ -n "${HEAD_REF:-}" ]; then
  # the trusted run: the scope must be known, because unknown must not mean unchanged (REQ-102, REQ-160)
  printf '%s' "$HEAD_REF" | grep -Eq '^[A-Za-z0-9._/-]+$' || die "HEAD_REF is not a plain ref name"
  printf '%s' "${BASE_REF:-}" | grep -Eq '^[A-Za-z0-9._/-]+$' || die "BASE_REF is not a plain branch name"
  git -C "$ROOT" rev-parse -q --verify "$HEAD_REF^{commit}" >/dev/null || die "HEAD_REF $HEAD_REF is not a commit in this checkout"
  BASE="$(git -C "$ROOT" merge-base "$HEAD_REF" "origin/$BASE_REF" 2>/dev/null)" || die "no merge base of $HEAD_REF and origin/$BASE_REF; fetch both with their history"
else
  BASE="$(change_base "$ROOT")" || exit 0
  [ -f "$ROOT/$TEAM_DIR_NAME/$CONF_NAME" ] || exit 0
fi
[ -n "$BASE" ] && at_base "$TEAM_DIR_NAME/$CONF_NAME" >/dev/null || exit 0

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
