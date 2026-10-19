#!/usr/bin/env bash
# Adds Xaden to an existing repository, or takes it out again (REQ-066, REQ-067, REQ-069, REQ-070, REQ-073).
# Usage: xaden project adopt [--scan | --plan] [--yes] [--assistants <list>] [--mode <mode>]
#                    [--check <kind>=<command>]... [--preset | --no-preset] [--worktrees | --no-worktrees] [--skip-hooks] [--skip-ci]
#                    [--commit-convention <conventional|other>]
#        xaden project remove [--yes]
#   --scan        read the repository and report what it has; changes nothing
#   --plan        print the exact diff and the files a run would create or change; changes nothing
#   (default)     scan, plan, then ask once whether to apply the plan on a new branch and worktree
#   --yes         apply without the question (a script or CI job); nothing downloads either way
#   --assistants  claude,copilot,vibe,codex  default: what the scan finds, confirmed by you
#   --mode        advisory | changed-files | strict   default: changed-files
#   --check       name a command the scan could not find, for example --check test="make verify"
#   --commit-convention  conventional | other   default: what the scan finds in the history
# The repository's own build, tests, docs and workflows are never changed: Xaden adds the folder
# xaden/, a marked block in AGENTS.md, and for Claude Code users the line @AGENTS.md in CLAUDE.md
# and one slash command file in .claude/commands/ for each prompt (existing files stay).
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

# The tooling that renders rules and prompts is this installed Xaden.
# shellcheck disable=SC2034 # read by render_rules and resolve_prompt in layout.sh
TOOLS_DIR="$SCAFFOLD_ROOT/template"
ADOPT_REPO=""
STOP_AFTER=""          # scan or plan
ASSUME_YES=0
CLASSIC=0              # a project created by `xaden project create`, with a copy of the tooling
PRESET_CHOICE=ask      # ask, yes, no
WORKTREES_CHOICE=ask   # ask, yes, no
EXIT_UNSUPPORTED=4     # an unsupported hook manager or CI system (a manual step is printed)

usage() {
  sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# parse_arguments <args...>: sets the choices.
parse_arguments() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --scan) STOP_AFTER=scan ;;
      --plan | --dry-run) STOP_AFTER=plan ;;
      --yes) ASSUME_YES=1 ;;
      --preset) PRESET_CHOICE=yes ;;
      --no-preset) PRESET_CHOICE=no ;;
      --worktrees) WORKTREES_CHOICE=yes ;;
      --no-worktrees) WORKTREES_CHOICE=no ;;
      --skip-hooks) ADOPT_HOOKS=0 ;;
      --skip-ci) ADOPT_CI=0 ;;
      --mode)
        shift
        case " $CHECK_MODES " in *" ${1:-} "*) ADOPT_MODE=$1 ;; *) die "--mode must be one of: $CHECK_MODES" ;; esac ;;
      --commit-convention)
        shift
        case "${1:-}" in conventional | other) ADOPT_CONVENTION=$1 ;; *) die "--commit-convention must be conventional or other" ;; esac ;;
      --assistants)
        shift
        printf '%s' "${1:-}" | grep -Eq '^[a-z0-9]+(,[a-z0-9]+)*$' || die "--assistants takes a comma separated list such as claude,codex"
        ADOPT_ASSISTANTS=$1 ;;
      --check)
        shift
        printf '%s' "${1:-}" | grep -Eq '^[a-z][a-z0-9-]*=.+$' || die "--check takes <kind>=<command>, for example --check test=\"make verify\""
        ADOPT_CHECKS="$ADOPT_CHECKS${ADOPT_CHECKS:+$'\n'}$1" ;;
      -h | --help) usage; exit 0 ;;
      *) die "unknown option: $1 (xaden project adopt --help)" ;;
    esac
    shift
  done
}

# unsupported_stop <what> <manual step>: stops with a clear error; Xaden does not guess (REQ-069).
unsupported_stop() {
  warn "$1 is not supported, so Xaden does not touch it."
  printf '%s\n' "$2" >&2
  exit "$EXIT_UNSUPPORTED"
}

# check_supported: the hook manager and the CI system must be known, or the person skips them.
check_supported() {
  case "$SCAN_HOOKS" in
    unsupported*)
      if [ "$ADOPT_HOOKS" = 1 ]; then
        unsupported_stop "The hook setup (${SCAN_HOOKS#unsupported: })" \
          "Manual step: call 'xaden hook pre-commit' from your pre-commit hook and 'xaden hook commit-msg \"\$1\"' from your commit-msg hook, or run 'xaden project adopt --skip-hooks' to adopt without them."
      fi ;;
  esac
  case "$SCAN_CI" in
    unsupported*)
      if [ "$ADOPT_CI" = 1 ]; then
        unsupported_stop "The CI system (${SCAN_CI#unsupported: })" \
          "Manual step: install Xaden at the pinned version in a CI job (xaden/README.md) and run 'xaden check --strict', or run 'xaden project adopt --skip-ci' to adopt without a workflow."
      fi ;;
  esac
}

# default_branch: the branch the adoption branches from and the pull request targets.
default_branch() {
  local name
  name="$(git -C "$ADOPT_REPO" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
  if [ -z "$name" ]; then
    for name in main master; do
      git -C "$ADOPT_REPO" rev-parse -q --verify "refs/heads/$name" >/dev/null && break
      name=""
    done
  fi
  printf '%s' "${name:-$(git -C "$ADOPT_REPO" symbolic-ref -q --short HEAD 2>/dev/null || echo main)}"
}

has_commits() { git -C "$ADOPT_REPO" rev-parse -q --verify HEAD >/dev/null; }

# choose_assistants: from --assistants, else what the scan finds, confirmed when a person can answer.
# Without a finding, only Claude Code is asked about (REQ-066); the others are offered when detected (REQ-081).
choose_assistants() {
  [ -z "$ADOPT_ASSISTANTS" ] || return 0
  local detected="" name question
  if [ "$SCAN_CLAUDE" = 1 ] || [ "$SCAN_CLAUDE_DIR" = 1 ]; then detected=claude; fi
  if [ "$SCAN_COPILOT" = 1 ]; then detected="$detected${detected:+,}copilot"; fi
  if [ "$SCAN_VIBE" = 1 ]; then detected="$detected${detected:+,}vibe"; fi
  if [ "$SCAN_CODEX" = 1 ]; then detected="$detected${detected:+,}codex"; fi
  if [ "$ASSUME_YES" = 1 ] || ! has_terminal; then
    ADOPT_ASSISTANTS=$detected
    return 0
  fi
  if [ -z "$detected" ]; then
    if ask "Does your team use Claude Code? Xaden then adds CLAUDE.md with the line @AGENTS.md and the slash commands (/xaden-feature, /xaden-bugfix, ...)."; then
      ADOPT_ASSISTANTS=claude
    fi
    return 0
  fi
  for name in $(printf '%s' "$detected" | tr ',' ' '); do
    case "$name" in
      claude) question="Claude Code is used here. Add CLAUDE.md with the line @AGENTS.md and the slash commands (/xaden-feature, /xaden-bugfix, ...)?" ;;
      copilot) question="GitHub Copilot is used here. Add the slash commands (/xaden-feature, /xaden-bugfix, ...) as prompt files in .github/prompts/?" ;;
      vibe) question="Mistral Vibe is used here. Add the slash commands (/xaden-feature, /xaden-bugfix, ...) as skills in .agents/skills/?" ;;
      codex) question="Codex CLI is used here. Add the commands (\$xaden-feature, \$xaden-bugfix, ...) as skills in .agents/skills/?" ;;
    esac
    if ask "$question" y; then ADOPT_ASSISTANTS="$ADOPT_ASSISTANTS${ADOPT_ASSISTANTS:+,}$name"; fi
  done
}

# choose_preset: offers Xaden's preset for the first stack with a gap, as a separate step.
choose_preset() {
  local stack=""
  [ -n "$SCAN_GAPS" ] && [ "$PRESET_CHOICE" != no ] || return 0
  case " $SCAN_STACKS " in *" python "*) stack=python ;; *" node "*) stack=node ;; esac
  [ -n "$stack" ] || return 0
  if [ "$PRESET_CHOICE" = yes ]; then ADOPT_PRESET=$stack; return 0; fi
  if [ "$ASSUME_YES" = 1 ] || ! has_terminal; then return 0; fi
  if ask "No check for: $SCAN_GAPS. Add Xaden's $stack preset as a separate commit? You install its tools yourself."; then
    ADOPT_PRESET=$stack
  fi
}

# choose_worktrees: offers a git-ignored worktrees/ folder for change worktrees (REQ-090), as a separate step.
choose_worktrees() {
  case "$WORKTREES_CHOICE" in
    yes) ADOPT_WORKTREES=1; return 0 ;;
    no) return 0 ;;
  esac
  if [ "$ASSUME_YES" = 1 ] || ! has_terminal; then return 0; fi
  if ask "Add a worktrees/ folder where change worktrees live? Git ignores everything in it; one small file."; then ADOPT_WORKTREES=1; fi
}

# run_steps <dir> <record>: the steps, one commit each. record=1 also records the baselines.
run_steps() {
  local dir=$1 record=$2
  if [ "$CLASSIC" = 1 ]; then
    apply_migration "$dir"
    commit_step "$dir" "chore: move the team content into xaden/ and drop the copied tooling"
  fi
  apply_core "$dir"
  if [ "$record" = 1 ]; then record_baselines "$dir"; fi
  commit_step "$dir" "chore: adopt Xaden $(running_version)"
  if [ "$SCAN_HOOKS" = husky ] && [ "$ADOPT_HOOKS" = 1 ]; then
    apply_hooks_tracked "$dir"
    commit_step "$dir" "chore: run Xaden's checks from the husky hooks"
  fi
  case "$SCAN_CI" in
    github-actions | none)
      if [ "$ADOPT_CI" = 1 ]; then
        apply_ci "$dir"
        commit_step "$dir" "ci: run Xaden's checks in a separate workflow"
      fi ;;
  esac
  if [ "$ADOPT_WORKTREES" = 1 ]; then
    apply_worktrees "$dir"
    commit_step "$dir" "chore: add worktrees/ for Xaden change worktrees"
  fi
  if [ -n "$ADOPT_PRESET" ]; then
    apply_preset "$dir" "$ADOPT_PRESET"
    commit_step "$dir" "chore: add Xaden's $ADOPT_PRESET preset for the missing checks"
  fi
}

# record_baselines <dir>: records the violations that exist today as the baselines (REQ-068). Runs
# the repository's own check commands, so its installed dependencies are linked in for the run.
record_baselines() {
  local dir=$1 dependency linked=""
  for dependency in node_modules .venv; do
    if [ -d "$ADOPT_REPO/$dependency" ] && [ ! -e "$dir/$dependency" ]; then
      ln -s "$ADOPT_REPO/$dependency" "$dir/$dependency"
      linked="$linked $dependency"
    fi
  done
  info "recording the violations that exist today (xaden/baselines/)"
  (cd "$dir" && PROJECT_ROOT="$dir" "$SCAFFOLD_ROOT/template/scripts/check.sh" --record-baseline) ||
    warn "recording the baselines failed; the checks will report everything that exists today"
  for dependency in $linked; do delete_file "${dir:?}/$dependency"; done
}

# scratch_copy <dir>: a copy of the repository as it is committed (or, with no commit yet, its
# working tree) with its own git history, for the plan.
scratch_copy() {
  local dir=$1
  if has_commits; then
    git -C "$ADOPT_REPO" archive HEAD | tar -x -C "$dir"
  else
    (cd "$ADOPT_REPO" && tar --exclude=./.git -cf - .) | tar -x -C "$dir"
  fi
  git -C "$dir" init -q -b scratch
  # no background gc: it can still write into .git/objects when the plan deletes the copy (Linux)
  git -C "$dir" config gc.auto 0
  git -C "$dir" config maintenance.auto false
  git -C "$dir" add -A
  git -C "$dir" -c core.hooksPath=/dev/null commit -q -n --allow-empty -m "scratch: before adoption"
}

# print_plan <full>: runs the steps on a scratch copy and prints what they did.
print_plan() {
  local full=$1 scratch base
  scratch="$(mktemp -d)"
  scratch_copy "$scratch"
  base="$(git -C "$scratch" rev-parse HEAD)"
  (
    export GIT_AUTHOR_NAME=xaden GIT_AUTHOR_EMAIL=xaden@localhost GIT_COMMITTER_NAME=xaden GIT_COMMITTER_EMAIL=xaden@localhost
    run_steps "$scratch" 0
  )
  info "plan: Xaden $(running_version) on branch $ADOPT_BRANCH, from $ADOPT_DEFAULT_BRANCH"
  git -C "$scratch" log --reverse --format='  commit: %s' "$base"..HEAD
  echo "  files (A = created, M = changed):"
  git -C "$scratch" diff --name-status "$base" HEAD | sed 's/^/    /'
  if [ "$full" = 1 ]; then
    echo
    git -C "$scratch" diff "$base" HEAD
  else
    echo "  Show the exact diff with: xaden project adopt --plan"
  fi
  if [ "$CLASSIC" = 1 ]; then
    echo "  This project keeps a copy of the tooling (.scaffold/). The plan moves its requirements, personas and"
    echo "  reviews into xaden/ and removes the copied files you did not edit; files you edited stay and are listed."
  fi
  echo "  Besides the files:"
  echo "    - the violations that exist today are recorded in xaden/baselines/ when the plan is applied (it runs your check commands)"
  if [ "$SCAN_HOOKS" != husky ] && [ "$ADOPT_HOOKS" = 1 ]; then
    echo "    - Xaden is chained into the git hooks of this clone ($SCAN_HOOKS); not a tracked file, each teammate runs 'xaden project setup'"
  fi
  echo "    - nothing is downloaded, pushed or published"
  [ -z "$ADOPT_PRESET" ] || echo "    - install the preset's tools yourself: $(preset_install_command "$ADOPT_PRESET")"
  rm -rf "${scratch:?}"
}

# apply_plan: creates the branch and worktree, runs the steps, installs local hooks.
apply_plan() {
  local worktree
  if has_commits; then
    worktree="$(dirname "$ADOPT_REPO")/$(basename "$ADOPT_REPO")-adopt-xaden"
    [ ! -e "$worktree" ] || die "$worktree exists already; remove it first (git worktree remove)"
    git -C "$ADOPT_REPO" rev-parse -q --verify "refs/heads/$ADOPT_BRANCH" >/dev/null &&
      die "branch $ADOPT_BRANCH exists already; delete it or finish that adoption first"
    git -C "$ADOPT_REPO" worktree add -q -b "$ADOPT_BRANCH" "$worktree" "$ADOPT_DEFAULT_BRANCH"
  else
    worktree="$ADOPT_REPO" # an empty repository has no branch to start from: the first commit lands on the new branch
    git -C "$ADOPT_REPO" checkout -q -b "$ADOPT_BRANCH"
  fi
  run_steps "$worktree" 1
  if [ "$CLASSIC" = 1 ] && [ "$(git -C "$ADOPT_REPO" config --get core.hooksPath || true)" = "scripts/hooks" ]; then
    git -C "$ADOPT_REPO" config --unset core.hooksPath # the copied hooks are gone after the migration
  fi
  if [ "$SCAN_HOOKS" != husky ] && [ "$ADOPT_HOOKS" = 1 ]; then install_local_hooks "$ADOPT_REPO"; fi
  ok "Xaden $(running_version) is on branch $ADOPT_BRANCH in $worktree"
  echo "Next: review the commits, then push the branch and open a pull request your team reviews:"
  echo "  git -C \"$worktree\" push -u origin $ADOPT_BRANCH"
  offer_pull_request "$worktree"
}

# offer_pull_request <worktree>: pushing sends code out, so it is a question, never a default.
offer_pull_request() {
  has_command gh && has_terminal && git -C "$1" remote get-url origin >/dev/null 2>&1 || return 0
  if ask "Push $ADOPT_BRANCH to origin and open a pull request now?"; then
    git -C "$1" push -u origin "$ADOPT_BRANCH"
    (cd "$1" && gh pr create --base "$ADOPT_DEFAULT_BRANCH" --fill)
  fi
}

# adopt_main <args...>
adopt_main() {
  parse_arguments "$@"
  has_command git || die "git is required"
  ADOPT_REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || die "this is not a git repository; run 'git init' first"
  [ ! -f "$ADOPT_REPO/xaden/xaden.conf" ] || die "Xaden is adopted here already (xaden/xaden.conf). Move it with: xaden project pin"
  if [ -d "$ADOPT_REPO/.scaffold" ]; then
    CLASSIC=1
    ADOPT_MODE=strict # that project was strict already
  fi
  ADOPT_DEFAULT_BRANCH="$(default_branch)"
  scan_repository "$ADOPT_REPO"
  if [ -n "$ADOPT_CONVENTION" ]; then
    SCAN_CONVENTION=$ADOPT_CONVENTION SCAN_CONVENTION_EVIDENCE="chosen with --commit-convention"
  fi
  if [ "$CLASSIC" = 1 ]; then
    [ "$SCAN_HOOKS" != "unsupported: core.hooksPath = scripts/hooks" ] || SCAN_HOOKS=plain # the copied hooks go with the copy
    if [ -d "$ADOPT_REPO/.claude" ] || [ -f "$ADOPT_REPO/CLAUDE.md" ]; then SCAN_CLAUDE=1; fi
  fi
  print_scan "$ADOPT_REPO"
  [ "$STOP_AFTER" != scan ] || return 0
  check_supported
  choose_assistants
  choose_preset
  choose_worktrees
  if [ -n "$SCAN_UNRECOGNISED$SCAN_FOUND_TOOLS" ] && [ "$ASSUME_YES" != 1 ] && has_terminal; then
    ask "Some tools were not recognised (listed above) and get no check. Continue anyway? Name their commands with --check <kind>=<command>." ||
      { echo "Nothing was changed."; return 0; }
  fi
  print_plan "$([ "$STOP_AFTER" = plan ] && echo 1 || echo 0)"
  [ "$STOP_AFTER" != plan ] || return 0
  choose_update_check
  if [ "$ASSUME_YES" != 1 ]; then
    if ! has_terminal; then
      echo "No terminal, so nothing was changed. To apply this plan: xaden project adopt --yes (add the options you used)."
      return 0
    fi
    ask "Apply this plan on the new branch $ADOPT_BRANCH?" || { echo "Nothing was changed."; return 0; }
  fi
  apply_plan
}

# remove_main <args...>: undoes the footprint in the working tree; the person commits the result.
remove_main() {
  local repo path kind
  [ "${1:-}" != "--yes" ] || ASSUME_YES=1
  repo="$(git rev-parse --show-toplevel 2>/dev/null)" || die "this is not a git repository"
  [ -f "$repo/$FOOTPRINT_FILE" ] || die "Xaden is not adopted here ($FOOTPRINT_FILE not found)"
  info "xaden project remove would delete xaden/ and undo these changes:"
  while read -r kind path; do printf '  %s %s\n' "$kind" "$path"; done <"$repo/$FOOTPRINT_FILE"
  if [ "$ASSUME_YES" != 1 ]; then
    has_terminal || { echo "No terminal, so nothing was changed. To remove: xaden project remove --yes"; return 0; }
    ask "Remove Xaden from this repository?" || { echo "Nothing was changed."; return 0; }
  fi
  remove_adoption "$repo"
  ok "Xaden is removed from the working tree. Review with git status, then commit."
}

if [ "${1:-}" = "__remove" ]; then
  shift
  remove_main "$@"
else
  adopt_main "$@"
fi
