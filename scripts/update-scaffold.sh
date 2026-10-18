#!/usr/bin/env bash
# Brings an existing project up to this scaffold version. Only files the scaffold manages
# (see MANAGED_PATHS in scripts/scaffold-lib.sh) are considered; project files are never touched.
# Usage: scripts/update-scaffold.sh <project-dir> [--apply]
#   without --apply: dry run, prints the plan
#   with --apply:    applies it and stages the result (review with `git diff --cached`, then commit)
#
# Per file, three versions are compared: BASE (from the project's .scaffold/manifest),
# CURRENT (in the project) and NEW (this template):
#   current == new                    up-to-date   nothing to do
#   current == base, new differs      update       overwrite with new
#   missing in project, not in base   add          copy new
#   missing in project, in base       skip         project deleted it on purpose
#   not in template, current == base  remove       delete
#   modified locally, new == base     keep         local change, nothing upstream
#   modified locally, new differs     conflict     keep current, write <file>-dist
set -euo pipefail

SCAFFOLD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="" # exported template snapshot, see export_template (REQ-018)
# shellcheck source=SCRIPTDIR/../template/scripts/lib.sh
source "$SCAFFOLD_ROOT/template/scripts/lib.sh"
# shellcheck source=SCRIPTDIR/scaffold-lib.sh
source "$SCAFFOLD_ROOT/scripts/scaffold-lib.sh"

PROJECT=""
APPLY=0
PROJECT_NAME=""
CONFLICTS=0
CHANGES=0

# parse_arguments <args...>: sets PROJECT and APPLY.
parse_arguments() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --apply) APPLY=1 ;;
      -*) die "unknown option: $arg" ;;
      *) PROJECT=$arg ;;
    esac
  done
  [ -n "$PROJECT" ] || die "usage: scripts/update-scaffold.sh <project-dir> [--apply]"
  [ -e "$PROJECT/.git" ] || die "not a git project: $PROJECT" # a file in worktrees and submodules
  PROJECT="$(cd "$PROJECT" && pwd)"
}

# read_project_name: from .scaffold/project-name, or from the AGENTS.md title of older projects.
read_project_name() {
  if [ -f "$PROJECT/$SCAFFOLD_STATE_DIR/project-name" ]; then
    PROJECT_NAME="$(cat "$PROJECT/$SCAFFOLD_STATE_DIR/project-name")"
  else
    PROJECT_NAME="$(sed -n 's/^# AGENTS\.md — //p' "$PROJECT/AGENTS.md" 2>/dev/null | head -n 1)"
    warn "no $SCAFFOLD_STATE_DIR/manifest (project predates update support): local edits cannot be told apart, every difference is a conflict"
  fi
  is_project_name "$PROJECT_NAME" || die "cannot determine project name"
}

# base_sum <path>: checksum recorded at generation/last update, empty if unknown.
base_sum() {
  awk -F'\t' -v path="$1" '$2 == path { print $1 }' "$PROJECT/$SCAFFOLD_STATE_DIR/manifest" 2>/dev/null || true
}

# candidate_paths: managed paths in the new template plus those recorded in the manifest.
# The manifest is project content: paths it lists outside MANAGED_PATHS are ignored.
candidate_paths() {
  {
    managed_template_files "$TEMPLATE"
    { cut -f2 "$PROJECT/$SCAFFOLD_STATE_DIR/manifest" 2>/dev/null || true; } | keep_managed
  } | sort -u
}

# classify <path>: prints the action for one file (see header).
classify() {
  local path=$1 base current="" new=""
  base="$(base_sum "$path")"
  [ -f "$PROJECT/$path" ] && current="$(content_sum <"$PROJECT/$path")"
  [ -f "$TEMPLATE/$path" ] && new="$(render_file "$TEMPLATE/$path" "$PROJECT_NAME" | content_sum)"

  if [ -z "$new" ]; then
    if [ -z "$current" ]; then echo up-to-date
    elif [ "$current" = "$base" ]; then echo remove
    else echo keep
    fi
  elif [ "$current" = "$new" ]; then echo up-to-date
  elif [ -z "$current" ]; then
    if [ -z "$base" ]; then echo add; else echo skip; fi
  elif [ "$current" = "$base" ]; then echo update
  elif [ "$new" = "$base" ]; then echo keep
  else echo conflict
  fi
}

# apply_action <action> <path>: performs one planned action inside the project.
apply_action() {
  local action=$1 path=$2 written=$2
  [ "$action" = conflict ] && written="$path-dist" # conflicts keep the project's file
  refuse_symlink_on_path "$PROJECT" "$written"
  case "$action" in
    add | update)
      mkdir -p "$(dirname "$PROJECT/$path")"
      render_file "$TEMPLATE/$path" "$PROJECT_NAME" >"$PROJECT/$path"
      [ -x "$TEMPLATE/$path" ] && chmod +x "$PROJECT/$path"
      git -C "$PROJECT" add -- "$path"
      ;;
    remove) git -C "$PROJECT" rm -q -- "$path" ;;
    conflict) render_file "$TEMPLATE/$path" "$PROJECT_NAME" >"$PROJECT/$written" ;;
  esac
}

# plan_and_apply: classifies every candidate path, prints the plan, applies it with --apply.
plan_and_apply() {
  local path action
  while IFS= read -r path; do
    action="$(classify "$path")"
    [ "$action" = "up-to-date" ] && continue
    printf '%-10s %s\n' "$action" "$path"
    case "$action" in
      conflict) CONFLICTS=$((CONFLICTS + 1)) ;;
      add | update | remove) CHANGES=$((CHANGES + 1)) ;;
    esac
    [ "$APPLY" = "1" ] && apply_action "$action" "$path"
  done < <(candidate_paths)
  return 0
}

# record_new_state <scaffold-version>: manifest and version now describe this scaffold version.
record_new_state() {
  write_manifest "$PROJECT" "$TEMPLATE" "$PROJECT_NAME" "$1"
  git -C "$PROJECT" add -- "$SCAFFOLD_STATE_DIR"
}

main() {
  local from to
  parse_arguments "$@"
  read_project_name
  TEMPLATE="$(mktemp -d)"
  trap 'rm -rf "$TEMPLATE"' EXIT
  export_template "$SCAFFOLD_ROOT/template" "$TEMPLATE"
  if [ "$APPLY" = "1" ] && [ -n "$(git -C "$PROJECT" status --porcelain)" ]; then
    die "project has uncommitted changes; commit or stash first"
  fi
  from="$(cat "$PROJECT/$SCAFFOLD_STATE_DIR/version" 2>/dev/null || echo unknown)"
  to="$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")"
  info "scaffold $from -> $to for $PROJECT_NAME ($([ "$APPLY" = 1 ] && echo apply || echo dry run))"

  plan_and_apply
  if [ "$APPLY" = "1" ]; then
    record_new_state "$to"
    info "$CHANGES change(s) staged; review: git -C '$PROJECT' diff --cached"
    echo "Commit with: git commit -m \"chore(scaffold): update to v$to\""
  else
    info "$CHANGES change(s) planned; run again with --apply"
  fi
  if [ "$CONFLICTS" -gt 0 ]; then
    warn "$CONFLICTS conflict(s): merge each <file>-dist into <file>, then delete it"
  fi
}

main "$@"
