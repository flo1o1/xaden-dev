#!/usr/bin/env bash
# Maintainers' test fixture, not reachable through `xaden` (REQ-001): creates a project from template/ that keeps
# its own copy of the tooling, the layout the smoke suite runs against.
# Usage: scripts/new-project.sh <project-name> [target-dir]
#   project-name: lowercase letters, digits, hyphens (2-51 chars), starts with a letter
#   target-dir:   defaults to ../<project-name>; must not exist yet
set -euo pipefail

# The project's own tooling runs below (setup, first commit hooks); it must act on the new
# project, never on a repository the caller's environment names.
unset PROJECT_ROOT

SCAFFOLD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$SCAFFOLD_ROOT/template"
# shellcheck source=SCRIPTDIR/../template/scripts/lib.sh
source "$TEMPLATE/scripts/lib.sh"
# shellcheck source=SCRIPTDIR/scaffold-lib.sh
source "$SCAFFOLD_ROOT/scripts/scaffold-lib.sh"

# Set while generating; cleanup_on_failure removes them unless generation completed.
STAGING=""
TARGET_CREATED=""
COMPLETED=0

# cleanup_on_failure: removes temporary files, and the half-created project on failure.
cleanup_on_failure() {
  [ -n "$STAGING" ] && rm -rf "$STAGING"
  if [ "$COMPLETED" != "1" ] && [ -n "$TARGET_CREATED" ]; then
    rm -rf "$TARGET_CREATED"
    warn "generation failed; removed partial project $TARGET_CREATED"
  fi
}

# fill_text_placeholders <name> <date>: filter; replaces {{PROJECT_NAME}} and {{DATE}} on stdin.
fill_text_placeholders() { fill_project_name "$1" | sed -e "s/{{DATE}}/$2/g"; }

# fill_placeholders <dir> <name>: replaces {{PROJECT_NAME}} and {{DATE}} in text files.
fill_placeholders() {
  local dir=$1 name=$2 today file
  today="$(date +%F)"
  grep -rlE '\{\{(PROJECT_NAME|DATE)\}\}' "$dir" | while IFS= read -r file; do
    rewrite_file "$file" fill_text_placeholders "$name" "$today"
  done
}

# init_repository <dir>: git init, activate hooks, first commit.
init_repository() {
  local dir=$1
  git -C "$dir" init -q -b main
  "$dir/scripts/setup.sh" >/dev/null
  git -C "$dir" add -A
  # The first commit has no branch to come from (REQ-060).
  ALLOW_MAIN_COMMIT=1 git -C "$dir" commit -q -m "chore: initialize project from the Xaden scaffold"
}

main() {
  local name=${1:-} target
  [ -n "$name" ] || die "usage: scripts/new-project.sh <project-name> [target-dir]"
  is_project_name "$name" || die "invalid project name '$name' (use lowercase letters, digits, hyphens)"
  target="${2:-$SCAFFOLD_ROOT/../$name}"
  [ ! -e "$target" ] || die "target already exists: $target"
  has_command git || die "git is required"

  trap cleanup_on_failure EXIT
  STAGING="$(mktemp -d)"
  export_template "$TEMPLATE" "$STAGING"
  mkdir -p "$target"
  target="$(cd "$target" && pwd)"
  TARGET_CREATED="$target"
  (cd "$STAGING" && tar cf - .) | (cd "$target" && tar xf -)
  fill_placeholders "$target" "$name"
  write_manifest "$target" "$STAGING" "$name" "$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")"
  init_repository "$target"
  COMPLETED=1

  info "created $name at $target"
  echo "Next: open the folder in your LLM tool, then run the 'kickoff' prompt (prompts/kickoff.md)."
  echo "Obsidian: open the folder as a vault to review prompts."
}

main "$@"
