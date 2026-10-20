#!/usr/bin/env bash
# Creates a new project in the adopted layout (REQ-066: one code path for new and existing projects),
# or, with --autopilot, in the recommended setup for a stack after one confirmation (REQ-076).
# Usage: xaden project create [--autopilot [--stack python|node]] [--assistants <list>] <name> [dir]
# Plain: the xaden/ folder, the marked AGENTS.md block, hooks, a CI workflow, mode strict, a first
# commit on main. Autopilot adds the stack's preset and prints one plan with everything it will do;
# it asks once. A yes applies the plan; anything else changes nothing. Neither pushes, publishes or
# downloads: the commands that install the development tools are printed for you to run. A folder
# that already holds code, a build file or history is a job for `xaden project adopt`: both stop there and
# change nothing.
# shellcheck disable=SC2034 # TOOLS_DIR is read by layout.sh, ADOPT_PRESET by the steps in adopt-lib.sh
set -euo pipefail

SCAFFOLD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=SCRIPTDIR/../template/scripts/lib.sh
source "$SCAFFOLD_ROOT/template/scripts/lib.sh"
# shellcheck source=SCRIPTDIR/../template/scripts/requirements-lib.sh
source "$SCAFFOLD_ROOT/template/scripts/requirements-lib.sh"
# shellcheck source=SCRIPTDIR/scaffold-lib.sh
source "$SCAFFOLD_ROOT/scripts/scaffold-lib.sh"
# shellcheck source=SCRIPTDIR/../template/scripts/update-check-lib.sh
source "$SCAFFOLD_ROOT/template/scripts/update-check-lib.sh"
# shellcheck source=SCRIPTDIR/adopt-scan.sh
source "$SCAFFOLD_ROOT/scripts/adopt-scan.sh"
# shellcheck source=SCRIPTDIR/adopt-lib.sh
source "$SCAFFOLD_ROOT/scripts/adopt-lib.sh"

TOOLS_DIR="$SCAFFOLD_ROOT/template"
STACK=""
CREATED_FOLDER=0
COMPLETED=0
AUTOPILOT=0
ADOPT_PRESET=""
NAME=""
TARGET=""

# cleanup_on_failure: removes the folder this run created when the run did not finish.
cleanup_on_failure() {
  if [ "$CREATED_FOLDER" = 1 ] && [ "$COMPLETED" != 1 ] && [ -n "$TARGET" ]; then
    rm -rf "${TARGET:?}"
    warn "creating the project failed; removed the partial folder $TARGET"
  fi
}
trap cleanup_on_failure EXIT

parse_arguments() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --autopilot) AUTOPILOT=1 ;;
      --stack)
        shift
        case "${1:-}" in python | node) STACK=$1 ;; *) die "--stack must be python or node" ;; esac ;;
      --assistants)
        shift
        printf '%s' "${1:-}" | grep -Eq '^[a-z0-9]+(,[a-z0-9]+)*$' || die "--assistants takes a comma separated list such as claude,codex"
        ADOPT_ASSISTANTS=$1 ;;
      -*) die "unknown option: $1" ;;
      *) if [ -z "$NAME" ]; then NAME=$1; elif [ -z "$TARGET" ]; then TARGET=$1; else die "too many arguments"; fi ;;
    esac
    shift
  done
  [ -n "$NAME" ] || die "usage: xaden project create [--autopilot [--stack python|node]] <name> [dir]"
  [ "$AUTOPILOT" = 1 ] || [ -z "$STACK" ] || die "--stack belongs to --autopilot"
  is_project_name "$NAME" || die "invalid project name '$NAME' (use lowercase letters, digits, hyphens)"
  TARGET="${TARGET:-$PWD/$NAME}"
}

# refuse_existing_work: a folder with code, a build file or history is for `xaden project adopt`.
refuse_existing_work() {
  [ -e "$TARGET" ] || return 0
  [ -d "$TARGET" ] || die "$TARGET exists and is not a folder"
  if [ -n "$(find "$TARGET" -mindepth 1 -maxdepth 1 ! -name .git | head -n 1)" ] ||
    git -C "$TARGET" rev-parse -q --verify HEAD >/dev/null 2>&1; then
    warn "$TARGET already contains code, a build file or history. Nothing was changed."
    echo "Use 'cd $TARGET && xaden project adopt' to add Xaden to it, or choose another name." >&2
    exit 2
  fi
}

# choose_stack: from --stack, else one question per stack.
choose_stack() {
  [ -z "$STACK" ] || return 0
  has_terminal || die "name the stack: xaden project create --autopilot --stack python|node $NAME"
  if ask "Is this a Python project?"; then STACK=python
  elif ask "Is this a Node (JavaScript or TypeScript) project?"; then STACK=node
  else die "autopilot knows python and node; for other stacks use: xaden project create $NAME"
  fi
}

# print_plan: everything the autopilot run will do.
print_plan() {
  info "autopilot plan for $NAME ($STACK) in $TARGET"
  cat <<PLAN
  1. git init (branch main) and a first commit with the layout below
  2. xaden/: requirements, personas, security reviews, baselines, xaden.conf (Xaden $(running_version) pinned with its checksum), RULES.md
  3. AGENTS.md with the Xaden block${ADOPT_ASSISTANTS:+, and the assistant files and slash commands for: $ADOPT_ASSISTANTS}
  4. README.md, SECURITY.md, .gitignore, VERSION and CHANGELOG.md of the new project
  5. the $STACK preset: $(preset_files "$STACK" | tr '\n' ' ')
  6. checks mapped in xaden.conf: $(preset_commands "$STACK" | sed 's/^/check./;s/=/ = /' | tr '\n' ';')
  7. mode strict: every violation fails; no baseline is needed in a new project
  8. git hooks of this clone (pre-commit, commit-msg) that run the checks
  9. a CI workflow, .github/workflows/xaden.yml, pinned to Xaden $(running_version) and its checksum
  Install commands (printed at the end; you run them, Xaden does not):
    $(preset_install_command "$STACK")
  Packages and versions: only those above; a package added later needs its own approval.
  Nothing is pushed, published or downloaded.
PLAN
}

# shellcheck disable=SC2016 # backticks are Markdown, not command substitution
# write_project_files: the few files every project needs and that are the project's own, not Xaden's.
write_project_files() {
  local dir=$1
  printf '# %s\n\nBuilt with [Xaden](https://xaden.dev). Start with `xaden prompt kickoff`; run the checks with `xaden check`.\n' "$NAME" >"$dir/README.md"
  printf '.env\n.env.*\n!.env.example\nnode_modules/\n.venv/\n__pycache__/\n.DS_Store\n' >"$dir/.gitignore"
  # The security policy and the threat model start from Xaden's templates, with TODO markers that block a release.
  sed "s/{{PROJECT_NAME}}/$NAME/g" "$SCAFFOLD_ROOT/template/SECURITY.md" >"$dir/SECURITY.md"
  sed "s/{{PROJECT_NAME}}/$NAME/g" "$SCAFFOLD_ROOT/template/docs/threat-model.md" >"$dir/xaden/threat-model.md"
  printf '0.0.0\n' >"$dir/VERSION"
  printf '# Changelog\n\nFormat: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) · Versioning: [SemVer](https://semver.org/).\n\n## [Unreleased]\n' >"$dir/CHANGELOG.md"
}

# choose_assistants: Claude Code users get CLAUDE.md and the slash commands. Asked only in a plain run with a terminal.
choose_assistants() {
  [ -z "$ADOPT_ASSISTANTS" ] || return 0
  if [ "$AUTOPILOT" = 1 ] || ! has_terminal; then return 0; fi
  if ask "Does your team use Claude Code? Xaden then adds CLAUDE.md with the line @AGENTS.md and the slash commands (/xaden-feature, /xaden-bugfix, ...)." y; then ADOPT_ASSISTANTS=claude; fi
}

# apply_new: creates the project, in the adopted layout; with a stack, the stack's preset too.
apply_new() {
  # A failed run leaves nothing behind: the folder is removed when this run created it.
  if [ ! -d "$TARGET" ]; then CREATED_FOLDER=1; fi
  mkdir -p "$TARGET"
  TARGET="$(cd "$TARGET" && pwd)"
  git -C "$TARGET" init -q -b main
  ADOPT_REPO="$TARGET"
  ADOPT_MODE=strict
  ADOPT_DEFAULT_BRANCH=main
  SCAN_STACKS=$STACK SCAN_CONVENTION=conventional SCAN_TEST="" SCAN_LINT="" SCAN_TYPECHECK="" SCAN_AUDIT="" SCAN_SECURITY=""
  SCAN_GAPS="$(expected_kinds)"
  ADOPT_PRESET=$STACK
  apply_core "$TARGET"
  write_project_files "$TARGET"
  commit_step "$TARGET" "chore: initialize project with Xaden $(running_version)"
  apply_ci "$TARGET"
  commit_step "$TARGET" "ci: run Xaden's checks in a workflow"
  if [ -n "$STACK" ]; then
    apply_preset "$TARGET" "$STACK"
    commit_step "$TARGET" "chore: add Xaden's $STACK preset"
  fi
  install_local_hooks "$TARGET"
  COMPLETED=1
}

# summary: what exists, and an honest result of the checks (skipped checks end with a warning).
summary() {
  local result
  info "created in $TARGET"
  git -C "$TARGET" ls-files | sed 's/^/  /'
  if [ -z "$STACK" ]; then
    ok "$NAME is ready. Next: open $TARGET in your assistant and run: xaden prompt kickoff"
    return 0
  fi
  info "install the development tools (run this yourself):"
  echo "  cd $TARGET && $(preset_install_command "$STACK")"
  info "checks now"
  result="$(cd "$TARGET" && PROJECT_ROOT="$TARGET" "$SCAFFOLD_ROOT/template/scripts/check.sh" 2>&1)" || true
  printf '%s\n' "$result" | grep -E '^==> summary|SKIPPED|INCOMPLETE|failed|gap:' || true
  if printf '%s' "$result" | grep -Eq 'INCOMPLETE|SKIPPED|, [1-9][0-9]* failed|[1-9][0-9]* check\(s\) failed'; then
    warn "not all checks pass or ran yet: install the tools above, write the first test (xaden prompt kickoff), then run: xaden check"
  else
    ok "all checks passed"
  fi
}

main() {
  parse_arguments "$@"
  has_command git || die "git is required"
  refuse_existing_work
  if [ "$AUTOPILOT" = 1 ]; then
    choose_stack
    print_plan
    if ! has_terminal; then
      echo "No terminal, so nothing was changed. Run it in a terminal to confirm the plan."
      return 0
    fi
    ask "Create $NAME with this setup?" || { echo "Nothing was changed."; return 0; }
  fi
  choose_assistants
  choose_update_check
  apply_new
  summary
}

main "$@"
