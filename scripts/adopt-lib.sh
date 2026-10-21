#!/usr/bin/env bash
# Putting Xaden beneath an existing repository, and taking it out again (REQ-066, REQ-069,
# REQ-070, REQ-073). Source it; do not execute it. Requires template/scripts/lib.sh,
# scripts/scaffold-lib.sh and scripts/adopt-scan.sh.
#
# Every step is a function that changes files below one directory and nothing else. The plan is
# the same functions run on a scratch copy of the repository: what the plan shows is what applying
# does. Effects outside the working tree (git hooks, .git/info/exclude) are not part of a step
# and happen only when the plan is applied.

# shellcheck disable=SC2034 # the settings below are read by adopt.sh and create.sh
BLOCK_BEGIN='<!-- xaden:begin -->'
BLOCK_END='<!-- xaden:end -->'
HOOK_BEGIN='# >>> xaden >>>'
HOOK_END='# <<< xaden <<<'
ADOPT_BRANCH="chore/adopt-xaden"

# Choices, set by adopt.sh from the command line, the scan and the answers.
ADOPT_MODE="changed-files"
ADOPT_CONVENTION=""    # --commit-convention: overrides what the scan finds (REQ-108)
ADOPT_ASSISTANTS=""
ADOPT_CHECKS=""        # newline separated "kind=command" the person named (--check)
ADOPT_PRESET=""        # stack whose preset the person accepted, or empty
ADOPT_WORKTREES=0      # 1 when the person wants a worktrees/ folder
ADOPT_CODEOWNER=""     # --codeowner: who reviews the control files (REQ-141), or empty: no candidate
ADOPT_HOOKS=1          # 0 = --skip-hooks
ADOPT_CI=1             # 0 = --skip-ci
ADOPT_DEFAULT_BRANCH="main"
ADOPT_UPDATE_CHECK=""  # the interval the person chose for the update check (REQ-084), or empty: not asked

# choose_update_check: asks once how often Xaden may look for updates. Off is the default answer;
# nothing is asked or set without a terminal, and an unreadable answer becomes off.
choose_update_check() {
  ask_text "How often may Xaden look for newer versions and dependencies? ($UPDATE_CHECK_FORMS; it only reports)" off || return 0
  if update_check_seconds "$ASK_TEXT_ANSWER" >/dev/null; then
    ADOPT_UPDATE_CHECK=$ASK_TEXT_ANSWER
  else
    warn "'$ASK_TEXT_ANSWER' is not valid. Use $UPDATE_CHECK_FORMS. The update check stays off."
    ADOPT_UPDATE_CHECK=off
  fi
}

# the version and checksum of the Xaden that runs
running_version() { tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION"; }
running_checksum() { tree_checksum "$SCAFFOLD_ROOT" "$(signed_like "$(running_version)")"; }

# --- text files with a marked block ---------------------------------------------------

# agents_block: the text Xaden owns inside AGENTS.md.
agents_block() {
  cat <<'TEXT'
<!-- xaden:begin -->
This repository uses Xaden. Read `xaden/RULES.md` (generated, do not edit) before you change
anything, and follow it. Look up requirements with `xaden req show REQ-nnn`, print a task prompt
with `xaden prompt <name>`, and run `xaden check` before you call work done.
<!-- xaden:end -->
TEXT
}

# set_block <file> <begin> <end> <block-text>: puts the block into the file, replacing an older
# one; text outside the markers is never touched. Creates the file when it is missing.
set_block() {
  local file=$1 begin=$2 end=$3 block=$4 tmp
  tmp="$(mktemp)"
  if [ -f "$file" ] && grep -qxF "$begin" "$file"; then
    awk -v begin="$begin" -v end="$end" -v block="$block" '
      $0 == begin { print block; skipping = 1; next }
      skipping { if ($0 == end) skipping = 0; next }
      { print }' "$file" >"$tmp"
  else
    { [ ! -s "$file" ] || { cat "$file"; [ -z "$(tail -c 1 "$file")" ] || printf '\n'; printf '\n'; }
      printf '%s\n' "$block"; } >"$tmp"
  fi
  mkdir -p "$(dirname "$file")"
  cat "$tmp" >"$file"
  rm -f "$tmp"
}

# delete_file <path>: removes one file; refuses an empty or root path.
delete_file() {
  rm -f "${1:?delete_file needs a path}"
}

# remove_block <file> <begin> <end>: takes the block out together with the blank line set_block
# put before it; deletes the file when nothing else is left.
remove_block() {
  local file=$1 begin=$2 end=$3 tmp
  [ -f "$file" ] || return 0
  tmp="$(mktemp)"
  awk -v begin="$begin" -v end="$end" '
    $0 == begin { held = ""; skipping = 1; next }
    skipping { if ($0 == end) skipping = 0; next }
    { if (held != "") { printf "%s", held; held = "" }
      if ($0 == "") { held = "\n" } else { print } }
    END { if (held != "") printf "%s", held }' "$file" >"$tmp"
  # nothing left but blank lines or a shebang line that Xaden added: the file was Xaden's
  if [ -z "$(grep -v '^#!' "$tmp" | tr -d '[:space:]')" ]; then delete_file "$file"; else cat "$tmp" >"$file"; fi
  rm -f "$tmp"
}

# --- the footprint: everything a step puts outside xaden/ (REQ-073) -------------------

# --- step 1: the xaden folder and the pointers ----------------------------------------

# expected_kinds: the kinds of checks a repository of the scanned stack should have.
expected_kinds() {
  [ -n "$SCAN_STACKS" ] || return 0
  printf 'test lint'
  case " $SCAN_STACKS " in
    *" python "*) printf ' typecheck' ;;
    *" node "*) [ ! -f "${ADOPT_REPO:-.}/tsconfig.json" ] || printf ' typecheck' ;;
  esac
  # REQ-106: a new adoption expects the audits too; an adoption from before is not changed on upgrade
  case " $SCAN_STACKS " in *" python "* | *" node "*) printf ' audit' ;; esac
  case " $SCAN_STACKS " in *" python "*) printf ' security' ;; esac
  return 0
}

# signature_policy_line: a new project accepts only releases the maintainer signed (REQ-136), when this
# Xaden knows a key to verify them with; without a key the line would lock the project out.
signature_policy_line() {
  local signers="$SCAFFOLD_ROOT/release-signers"
  # tests have no key unless they bring their own
  if [ "${XADEN_TEST_MODE:-0}" = "1" ]; then signers="${XADEN_SIGNERS_FILE:-/dev/null}"; fi
  grep -Ev '^[[:space:]]*(#|$)' "$signers" >/dev/null 2>&1 || return 0
  printf '# Only releases signed by the maintainer (release-signers) may be installed. Set false to allow unsigned ones.\nrequire-signature = true'
}

# render_conf <expect>: the content of xaden/xaden.conf.
render_conf() {
  local line
  cat <<EOF
# Xaden settings of this repository. Reviewed like code: a new version or a looser mode needs a pull request.
# The tooling is not copied here; this version and checksum select it (see xaden/README.md).
version = $(running_version)
checksum = $(running_checksum)
$(signature_policy_line)
# advisory: warn only. changed-files: fail for files the change touches. strict: fail for all.
mode = $ADOPT_MODE
commit-convention = $SCAN_CONVENTION
assistants = ${ADOPT_ASSISTANTS:-none}
# Checks that run in the pre-commit hook; the full run (xaden check, CI) runs all of them.
hook-checks = lint
# Kinds of checks this repository should have. One without a check.<kind> command is reported as a gap.
# Without this line Xaden looks at the project (package.json, pyproject.toml) when it checks.
${1:+expect = $(printf '%s' "$1" | tr ' ' ',')}
EOF
  [ -z "$ADOPT_UPDATE_CHECK" ] || printf '# Look for a newer Xaden and outdated dependencies: off, or an interval such as 12h, 1d, 7d. It only reports.\nupdate-check = %s\n' "$ADOPT_UPDATE_CHECK"
  [ -z "$SCAN_TEST" ] || printf 'check.test = %s\n' "$SCAN_TEST"
  [ -z "$SCAN_LINT" ] || printf 'check.lint = %s\n' "$SCAN_LINT"
  [ -z "$SCAN_TYPECHECK" ] || printf 'check.typecheck = %s\n' "$SCAN_TYPECHECK"
  [ -z "$SCAN_AUDIT" ] || printf 'check.audit = %s\n' "$SCAN_AUDIT"
  [ -z "$SCAN_SECURITY" ] || printf 'check.security = %s\n' "$SCAN_SECURITY"
  if [ -n "$ADOPT_CHECKS" ]; then
    printf '%s\n' "$ADOPT_CHECKS" | while IFS= read -r line; do printf 'check.%s = %s\n' "${line%%=*}" "${line#*=}"; done
  fi
  return 0
}

# readme_text: xaden/README.md, for the people who find the folder.
readme_text() {
  cat <<'TEXT'
# Xaden in this repository

This folder holds what the team decides and Xaden checks: requirements, personas, security reviews
and the settings. Everything is plain Markdown plus one settings file.

| Path | What it is |
|------|------------|
| `xaden.conf` | The pinned Xaden version and checksum, the mode of the checks, the commands Xaden runs |
| `RULES.md` | The rules for AI assistants. Generated from the pinned version: do not edit |
| `requirements/` | One file per requirement, grouped in epics |
| `personas/` | The users the team builds for |
| `security-reviews/` | Recorded security reviews |
| `baselines/` | Violations that existed before adoption; the lists only shrink |
| `prompts/` | Optional: a prompt of the same name as a default prompt replaces it |
| `footprint.txt` | The few paths outside this folder that Xaden touched, so `xaden project remove` can undo them |

The Xaden tooling is not copied into the repository. Install Xaden once per machine
(https://xaden.dev), then use `xaden check`, `xaden req`, `xaden prompt` and the rest. A newer
Xaden on your machine changes nothing here; `xaden core doctor` compares the installed version with
the pinned one, and `xaden project pin` moves the whole team in one pull request.
TEXT
}

# apply_core <dir>: step 1, the folder xaden/ and the pointer files.
apply_core() {
  local dir=$1 expect
  expect="$(expected_kinds)"
  mkdir -p "$dir/xaden/requirements" "$dir/xaden/personas" "$dir/xaden/security-reviews" "$dir/xaden/baselines"
  : >"$dir/xaden/personas/.gitkeep"
  : >"$dir/xaden/security-reviews/.gitkeep"
  : >"$dir/xaden/baselines/.gitkeep"
  render_conf "$expect" >"$dir/xaden/xaden.conf"
  readme_text >"$dir/xaden/README.md"
  render_rules >"$dir/xaden/RULES.md"
  render_index "$dir/xaden/requirements" >"$dir/xaden/requirements/INDEX.md"
  render_index "$dir/xaden/requirements" full >"$dir/xaden/requirements/INDEX-full.md"
  if [ -f "$dir/AGENTS.md" ]; then note_footprint "$dir" block AGENTS.md; else note_footprint "$dir" created-block AGENTS.md; fi
  set_block "$dir/AGENTS.md" "$BLOCK_BEGIN" "$BLOCK_END" "$(agents_block)"
  case ",$ADOPT_ASSISTANTS," in
    *,claude,*)
      if [ -f "$dir/CLAUDE.md" ]; then note_footprint "$dir" line CLAUDE.md; else note_footprint "$dir" created-line CLAUDE.md; fi
      if ! grep -qx '@AGENTS.md' "$dir/CLAUDE.md" 2>/dev/null; then
        { [ ! -s "$dir/CLAUDE.md" ] || { cat "$dir/CLAUDE.md"; [ -z "$(tail -c 1 "$dir/CLAUDE.md")" ] || printf '\n'; }
          printf '@AGENTS.md\n'; } >"$dir/CLAUDE.md.new" && mv "$dir/CLAUDE.md.new" "$dir/CLAUDE.md"
      fi ;;
  esac
  [ -z "$(command_kinds "$ADOPT_ASSISTANTS")" ] || sync_commands "$dir" "$TOOLS_DIR" "$ADOPT_ASSISTANTS"
}

# --- step 2: hooks that live in the repository (husky) --------------------------------

# hook_block <hook-name>: what Xaden adds to a hook file.
hook_block() {
  cat <<EOF
$HOOK_BEGIN
if command -v xaden >/dev/null 2>&1; then xaden hook $1 "\$@" || exit \$?; else echo "xaden not found: Xaden's checks are skipped (see xaden/README.md)" >&2; fi
$HOOK_END
EOF
}

# add_hook_block <hook-file> <hook-name>: chains Xaden into one hook file, keeping what is there.
add_hook_block() {
  local file=$1 name=$2 first
  if [ -f "$file" ]; then
    first="$(head -n 1 "$file")"
    case "$first" in
      '#!'*sh* | '') ;;
      *) die "the hook $file is not a shell script ($first). Add this to it by hand:
$(hook_block "$name")" ;;
    esac
  else
    mkdir -p "$(dirname "$file")"
    printf '#!/usr/bin/env sh\n' >"$file"
  fi
  set_block "$file" "$HOOK_BEGIN" "$HOOK_END" "$(hook_block "$name")"
  chmod +x "$file"
}

# apply_hooks_tracked <dir>: step 2, only for husky, whose hooks are files of the repository.
apply_hooks_tracked() {
  add_hook_block "$1/.husky/pre-commit" pre-commit
  add_hook_block "$1/.husky/commit-msg" commit-msg
  note_footprint "$1" hook-block .husky/pre-commit
  note_footprint "$1" hook-block .husky/commit-msg
}

# git_hooks_dir <repo>: absolute path of the directory git runs hooks from.
git_hooks_dir() {
  local hooks_dir
  hooks_dir="$(cd "$1" && git rev-parse --git-path hooks)"
  case "$hooks_dir" in /*) printf '%s' "$hooks_dir" ;; *) printf '%s/%s' "$1" "$hooks_dir" ;; esac
}

# install_local_hooks <repo>: the hooks of plain git, pre-commit and lefthook live in .git, not
# in the repository: chain Xaden into them. `xaden project setup` does the same for every teammate.
install_local_hooks() {
  local hooks_dir
  hooks_dir="$(git_hooks_dir "$1")"
  mkdir -p "$hooks_dir"
  add_hook_block "$hooks_dir/pre-commit" pre-commit
  add_hook_block "$hooks_dir/commit-msg" commit-msg
}

# --- step 3: the CI workflow ------------------------------------------------------------

apply_ci() {
  local dir=$1 file=".github/workflows/xaden.yml"
  mkdir -p "$dir/.github/workflows"
  sed -e "s/@VERSION@/$(running_version)/g" -e "s/@CHECKSUM@/$(running_checksum)/g" \
    -e "s/@DEFAULT_BRANCH@/$ADOPT_DEFAULT_BRANCH/g" "$SCAFFOLD_ROOT/scripts/adopt/ci.yml" >"$dir/$file"
  cat "$SCAFFOLD_ROOT/scripts/adopt/ci-commit-step.yml" >>"$dir/$file" # REQ-107: the step `xaden project pin` adds to older workflows
  note_footprint "$dir" file "$file"
}

# apply_codeowners <dir> (REQ-141): a candidate CODEOWNERS file, never over the project's own; the team merges it.
apply_codeowners() {
  local dir=$1 file=".github/CODEOWNERS-dist" path
  mkdir -p "$dir/.github"
  {
    printf '# Candidate from Xaden: merge into .github/CODEOWNERS, then turn on "Require review from Code Owners" for the default branch.\n'
    for path in /xaden/xaden.conf /xaden/baselines/ /AGENTS.md /.github/workflows/; do printf '%s %s\n' "$path" "$ADOPT_CODEOWNER"; done
  } >"$dir/$file"
  note_footprint "$dir" file "$file"
}

# --- step 4: the worktrees/ folder (REQ-090) ---------------------------------------------

# apply_worktrees <dir>: one tracked file; it ignores everything else in the folder, itself excepted.
apply_worktrees() {
  local dir=$1 file="worktrees/.gitignore"
  mkdir -p "$dir/worktrees"
  printf '*\n!.gitignore\n' >"$dir/$file"
  note_footprint "$dir" file "$file"
}

# --- step 5: a preset for the gaps ------------------------------------------------------

# preset_files <stack>: the files of Xaden's preset for a stack, relative to the preset folder.
preset_files() {
  case "$1" in
    python) printf 'ruff.toml\nmypy.ini\nrequirements-dev.txt\n' ;;
    node) printf 'eslint.config.mjs\n' ;;
  esac
}

# preset_commands <stack>: "kind=command" for what the preset's tools run.
preset_commands() {
  case "$1" in
    python) printf 'lint=ruff check .\ntypecheck=mypy .\ntest=pytest -q\naudit=pip-audit\nsecurity=bandit -q -r . -x ./.venv,./node_modules,./tests\n' ;;
    node) printf 'lint=npx eslint .\ntest=node --test\ntypecheck=npx tsc --noEmit\naudit=npm audit --audit-level=high\n' ;;
  esac
}

# preset_findings_status <stack> <kind>: the exit statuses the preset's tool uses for "violations
# found" (REQ-101); the test runner declares none.
preset_findings_status() {
  case "$1/$2" in
    node/typecheck) printf '1,2' ;; # tsc --noEmit: 1 or 2 depending on the version
    */lint | */typecheck | */audit | */security) printf '1' ;; # pip-audit, npm audit and bandit exit 1 on findings
  esac
}

# preset_install_command <stack>: what the person runs to install the preset's tools.
preset_install_command() {
  case "$1" in
    python) printf 'python3 -m pip install -r requirements-dev.txt' ;;
    node) printf 'npm install --save-dev --save-exact %s' "$(grep -v '^#' "$SCAFFOLD_ROOT/template/presets/node/devDependencies.txt" | tr '\n' ' ' | sed 's/ $//')" ;;
  esac
}

# apply_preset <dir> <stack>: step 4. Writes the preset's configuration at the repository root,
# where its tools expect it. A file that exists is never overwritten; when it differs, the
# difference is shown and the preset's version goes next to it as <file>.xaden-new if the person
# says yes (REQ-069). Commands are mapped in xaden.conf for the gaps only.
apply_preset() {
  local dir=$1 stack=$2 file kind line conf="$1/xaden/xaden.conf"
  for file in $(preset_files "$stack"); do
    if [ -e "$dir/$file" ]; then
      if ! cmp -s "$SCAFFOLD_ROOT/template/presets/$stack/$file" "$dir/$file"; then
        warn "$file exists and differs from Xaden's preset; it is left unchanged. The difference:"
        diff -u "$dir/$file" "$SCAFFOLD_ROOT/template/presets/$stack/$file" | sed 's/^/    /' >&2 || true
        if ask "Save the preset's version next to it as $file.xaden-new?"; then
          cp "$SCAFFOLD_ROOT/template/presets/$stack/$file" "$dir/$file.xaden-new"
          note_footprint "$dir" file "$file.xaden-new"
        fi
      fi
    else
      cp "$SCAFFOLD_ROOT/template/presets/$stack/$file" "$dir/$file"
      note_footprint "$dir" preset-file "$file"
    fi
  done
  for kind in $SCAN_GAPS; do
    [ -z "$(conf_get "$conf" "check.$kind")" ] || continue
    line="$(preset_commands "$stack" | grep "^$kind=" || true)"
    [ -z "$line" ] || conf_set "$conf" "check.$kind" "${line#*=}"
    [ -z "$line" ] || [ -z "$(preset_findings_status "$stack" "$kind")" ] || conf_set "$conf" "findings-status.$kind" "$(preset_findings_status "$stack" "$kind")"
  done
}

# --- committing a step ------------------------------------------------------------------

# commit_step <dir> <message>: commits whatever the step changed. No hooks: the repository's own
# hooks must not decide whether Xaden's files may be committed.
commit_step() {
  git -C "$1" add -A
  git -C "$1" -c core.hooksPath=/dev/null commit -q -n -m "$2" -m "Adopted with Xaden $(running_version) (https://xaden.dev)."
}

# --- taking Xaden out again -------------------------------------------------------------

# remove_adoption <repo>: undoes exactly what xaden/footprint.txt lists, then deletes xaden/.
remove_adoption() {
  local repo=${1:?remove_adoption needs a repository} kind path hooks_dir
  [ -f "$repo/$FOOTPRINT_FILE" ] || die "$repo/$FOOTPRINT_FILE not found: Xaden was not adopted here, or the footprint was deleted"
  while read -r kind path; do
    case "$path" in /* | *..* | "") die "unsafe path in $FOOTPRINT_FILE: $path" ;; esac
    case "$kind" in
      block | created-block) remove_block "$repo/$path" "$BLOCK_BEGIN" "$BLOCK_END" ;;
      line | created-line)
        grep -vx '@AGENTS.md' "$repo/$path" >"$repo/$path.new" 2>/dev/null || true
        if [ -z "$(tr -d '[:space:]' <"$repo/$path.new")" ]; then delete_file "$repo/$path"; else cat "$repo/$path.new" >"$repo/$path"; fi
        delete_file "$repo/$path.new" ;;
      hook-block) remove_block "$repo/$path" "$HOOK_BEGIN" "$HOOK_END" ;;
      file | preset-file)
        delete_file "$repo/$path"
        (cd "$repo" && rmdir -p "$(dirname "$path")" 2>/dev/null) || true ;;
    esac
  done <"$repo/$FOOTPRINT_FILE"
  hooks_dir="$(git_hooks_dir "$repo")"
  for path in pre-commit commit-msg; do
    if [ -f "$hooks_dir/$path" ] && grep -qxF "$HOOK_BEGIN" "$hooks_dir/$path"; then remove_block "$hooks_dir/$path" "$HOOK_BEGIN" "$HOOK_END"; fi
  done
  rm -rf "${repo:?}/$TEAM_DIR_NAME"
}
