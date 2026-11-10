#!/usr/bin/env bash
# Shared helpers for scripts in this repo. Source it; do not execute it.
# Portable on Linux and macOS (bash >= 3.2, POSIX sed/awk/tar only).

# shellcheck source=SCRIPTDIR/layout.sh
source "$(dirname "${BASH_SOURCE[0]}")/layout.sh"
# shellcheck source=SCRIPTDIR/gate.sh
source "$(dirname "${BASH_SOURCE[0]}")/gate.sh"

# Check results (REQ-019): every check is passed, failed or skipped; finish_checks reports them.
FAILURES=0
CHECKS_PASSED=0
SKIPPED_CHECKS=""
# "1" makes a missing tool a failure instead of a skipped check.
STRICT="${STRICT:-0}"

# --- messages (REQ-074) --------------------------------------------------------------
# Four kinds, each marked the same way: question 🐉, warning ⚠️ (stderr), error 🔥 (stderr,
# exit 1), success ✅. Plain text ([?], WARNING:, ERROR:, OK:) when XADEN_PLAIN=1, CI is set,
# the stream is not a terminal or the locale is not UTF-8. Scripts print messages only through
# these helpers; a smoke test fails on a hand-written sign or prompt. Facts in a message
# (versions, URLs, checksums, commands) are never rephrased; security and data-loss messages
# carry no jokes.

# plain_messages <fd>: true when messages on that stream use plain text.
plain_messages() {
  if [ "${XADEN_PLAIN:-0}" = "1" ] || [ -n "${CI:-}" ] || [ ! -t "$1" ]; then return 0; fi
  case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in *[Uu][Tt][Ff]-8* | *[Uu][Tt][Ff]8*) return 1 ;; esac
  return 0
}

info() { printf '==> %s\n' "$*"; }
# tip <text>: names an optional tool that fits this project (REQ-051); never changes a result.
tip() { printf 'TIP: %s\n' "$*"; }
warn() { if plain_messages 2; then printf 'WARNING: %s\n' "$*" >&2; else printf '⚠️  %s\n' "$*" >&2; fi; }
die() { if plain_messages 2; then printf 'ERROR: %s\n' "$*" >&2; else printf '🔥 %s\n' "$*" >&2; fi; exit 1; }
# ok <text>: a verified success. Never after a run with skipped checks (AGENTS.md §5).
ok() { if plain_messages 1; then printf 'OK: %s\n' "$*"; else printf '✅ %s\n' "$*"; fi; }

# has_terminal: true when a person can answer a question. XADEN_TEST_MODE=1 (tests only) lets a
# test answer on stdin; no other variable or flag answers for a person.
has_terminal() {
  { [ "${XADEN_TEST_MODE:-0}" = "1" ] && [ -n "${XADEN_TEST_ANSWER+x}" ]; } || { [ -t 0 ] && [ -t 1 ]; }
}

# ask <question> [y|n]: a question that waits for an answer: separator line, then the question
# as the last line with the default (n unless told otherwise). Returns 0 only for an explicit
# yes; anything else, including no answer, is no. Without a terminal it returns 2 and asks nothing.
ask() {
  local question=$1 default=${2:-n} hint answer=""
  has_terminal || return 2
  if [ "$default" = "y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
  printf -- '----------------------------------------\n'
  if plain_messages 1; then printf '[?] %s %s ' "$question" "$hint"; else printf '🐉 %s %s ' "$question" "$hint"; fi
  if [ "${XADEN_TEST_MODE:-0}" = "1" ] && [ -n "${XADEN_TEST_ANSWER+x}" ]; then
    answer=$XADEN_TEST_ANSWER
    printf '%s\n' "$answer"
  else
    read -r answer || answer=""
  fi
  case "$answer" in
    [Yy] | [Yy][Ee][Ss]) return 0 ;;
    "") [ "$default" = "y" ] ;;
    *) return 1 ;;
  esac
}

# ask_text <question> <default>: like ask, for a free answer. The answer lands in ASK_TEXT_ANSWER
# (empty means the default). Without a terminal it returns 2, asks nothing and leaves it empty.
ASK_TEXT_ANSWER=""
# shellcheck disable=SC2034 # read by the scripts that call ask_text
ask_text() {
  local question=$1 default=$2 answer=""
  ASK_TEXT_ANSWER=""
  has_terminal || return 2
  printf -- '----------------------------------------\n'
  if plain_messages 1; then printf '[?] %s [%s] ' "$question" "$default"; else printf '🐉 %s [%s] ' "$question" "$default"; fi
  if [ "${XADEN_TEST_MODE:-0}" = "1" ] && [ -n "${XADEN_TEST_ANSWER+x}" ]; then
    answer=$XADEN_TEST_ANSWER
    printf '%s\n' "$answer"
  else
    read -r answer || answer=""
  fi
  ASK_TEXT_ANSWER=${answer:-$default}
}

# has_command <name>: true if <name> is on PATH.
# refuse_nested_run <name>: dies when <name> already runs in this process tree, so a check that
# starts itself fails at once instead of spawning processes without end (REQ-086).
# XADEN_ALLOW_NESTED=1 lets a test start one on purpose.
refuse_nested_run() {
  case ":${XADEN_RUNNING:-}:" in
    *":$1:"*) [ "${XADEN_ALLOW_NESTED:-}" = 1 ] || die "$1 is already running in this process tree (recursion?); XADEN_ALLOW_NESTED=1 allows it on purpose" ;;
  esac
  export XADEN_RUNNING="${XADEN_RUNNING:+$XADEN_RUNNING:}$1"
}

has_command() { command -v "$1" >/dev/null 2>&1; }

# record_missing_tool <label> <binary>: a check whose tool is missing is skipped (reported
# as INCOMPLETE), or failed when STRICT=1.
record_missing_tool() {
  if [ "$STRICT" = "1" ]; then
    warn "required tool missing: $2 ($1)"
    FAILURES=$((FAILURES + 1))
  else
    warn "SKIPPED $1: '$2' not installed"
    SKIPPED_CHECKS="$SKIPPED_CHECKS${SKIPPED_CHECKS:+, }$1"
  fi
}

# run_tool <label> <binary> [args...]: runs one check and records passed or failed;
# a missing binary is recorded by record_missing_tool.
run_tool() {
  local label=$1 binary=$2
  shift 2
  if ! has_command "$binary"; then
    record_missing_tool "$label" "$binary"
    return 0
  fi
  info "$label"
  if "$binary" "$@"; then
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    warn "$label failed"
    FAILURES=$((FAILURES + 1))
  fi
}

# finish_checks: prints the summary and exits. Failures exit 1. Skipped checks never count
# as passed: the run is reported INCOMPLETE (exit 0 locally; --strict turns skips into failures).
finish_checks() {
  printf '==> summary: %d passed, %d failed, skipped: %s\n' \
    "$CHECKS_PASSED" "$FAILURES" "${SKIPPED_CHECKS:-none}"
  [ "$FAILURES" -eq 0 ] || die "$FAILURES check(s) failed"
  if [ -n "$SKIPPED_CHECKS" ]; then
    warn "INCOMPLETE: not all checks ran. Install the missing tools, or require them with --strict or missing-tools = fail in xaden/xaden.conf."
    exit 0
  fi
  ok "all checks passed"
}

# --- check helpers shared by check.sh and the scaffold's check-scaffold.sh -------------
# Modes: "staged" = pre-commit (staged files only, offline, seconds);
#        "full"   = everything (CI, release, before declaring work done).

# Source files the duplication tip looks at.
# shellcheck disable=SC2034 # read by stacks/common.sh
SOURCE_FILE_PATTERN='\.(py|js|jsx|mjs|cjs|ts|tsx)$'
# SAST_FILE_PATTERN (REQ-144): the files the local semgrep rules scan; one rules file per language in .semgrep/.
# A language without a rules file in .semgrep/ finds nothing, so listing it here is harmless.
SAST_FILE_PATTERN='\.(py|js|jsx|mjs|cjs|ts|tsx|go|java|php|rb|rs)$'
# Files selected by the last collect_files call (bash array).
TARGETS=()
# Staged mode (REQ-020): the real repository, a temporary export of its index (exactly what
# will be committed) and the NUL-separated list of staged paths.
GIT_REPO=""
SNAPSHOT=""
STAGED_LIST=""
# Files the commit does not change are left out of the snapshot above this size (1 MiB):
# copying large tracked assets on every commit would make the hook slow (REQ-014).
SNAPSHOT_MAX_UNCHANGED_FILE_BYTES=1048576

# snapshot_paths: index paths to export, one per line: every staged file, plus every other
# file up to SNAPSHOT_MAX_UNCHANGED_FILE_BYTES. Names containing newlines are unsupported.
snapshot_paths() {
  {
    tr '\0' '\n' <"$STAGED_LIST"
    git -C "$GIT_REPO" ls-files -s -z | tr '\0' '\n' |
      awk '{ path = $0; sub(/^[^\t]*\t/, "", path); print $2 " " path }' |
      git -C "$GIT_REPO" cat-file --batch-check='%(objecttype) %(objectsize) %(rest)' |
      awk -v limit="$SNAPSHOT_MAX_UNCHANGED_FILE_BYTES" '$1 == "blob" && $2 <= limit { sub(/^[^ ]* [^ ]* /, ""); print }'
  } | LC_ALL=C sort -u
}

# enter_staged_snapshot <repo-root>: exports the git index (see snapshot_paths) to a temporary
# directory and changes into it, so checks see the staged content, not unstaged edits.
# Untracked dependency folders are linked so linters resolve. The working tree is never modified.
enter_staged_snapshot() {
  local dependency_dir
  GIT_REPO=$1
  SNAPSHOT="$(mktemp -d)"
  STAGED_LIST="$(mktemp)"
  trap 'rm -rf "$SNAPSHOT" "$STAGED_LIST"' EXIT
  git -C "$GIT_REPO" diff --cached --name-only -z --diff-filter=ACMR >"$STAGED_LIST"
  snapshot_paths | git -C "$GIT_REPO" checkout-index --stdin --prefix="$SNAPSHOT/"
  for dependency_dir in node_modules .venv; do
    if [ -d "$GIT_REPO/$dependency_dir" ]; then ln -s "$GIT_REPO/$dependency_dir" "$SNAPSHOT/$dependency_dir"; fi
  done
  export PROJECT_ROOT="$SNAPSHOT"
  cd "$SNAPSHOT" || die "cannot enter staged snapshot $SNAPSHOT"
  # REQ-172: use the real index for tracking and the snapshot for ignore rules and requirement content.
  if [ -d "$SNAPSHOT/$TEAM_DIR_NAME/requirements" ]; then
    (
      # shellcheck source=SCRIPTDIR/requirements-lib.sh
      source "$TOOLS_DIR/scripts/requirements-lib.sh"
      GIT_DIR="$(git -C "$GIT_REPO" rev-parse --absolute-git-dir)" GIT_WORK_TREE="$SNAPSHOT" \
        refresh_local_requirement_indexes "$SNAPSHOT/$TEAM_DIR_NAME/requirements"
    )
  fi
}

# list_project_files: NUL-separated paths of the project's files (git-tracked files, or every
# regular file inside a staged snapshot, which only contains tracked files).
list_project_files() {
  if git rev-parse --git-dir >/dev/null 2>&1; then
    git ls-files -z
  else
    find . -type f | sed 's|^\./||' | tr '\n' '\0' # POSIX; names with newlines are unsupported
  fi
}

# collect_files <mode> <include-regex> [exclude-regex]: fills TARGETS with matching staged
# (staged mode) or tracked (full mode) files, relative to the current directory.
# One grep pass over the whole list: a process per file took ~12 s for 5,000 files.
# Names containing newlines are unsupported.
collect_files() {
  local mode=$1 pattern=$2 exclude=${3:-^$} file
  TARGETS=()
  while IFS= read -r file; do
    if [ -f "$file" ]; then TARGETS+=("$file"); fi
  done < <(if [ "$mode" = "staged" ]; then cat "$STAGED_LIST"; else list_project_files; fi |
    tr '\0' '\n' | grep -E "$pattern" | grep -Ev "$exclude")
}

# lint_shell <mode>: shellcheck on shell scripts and extension-less git hooks. With JUDGE_BY_MODE=1 (set by check.sh)
# the findings are judged by the mode and the baseline of the project (REQ-068); otherwise any finding fails.
lint_shell() {
  collect_files "$1" '(\.sh$|(^|/)hooks/[^/.]+$|^\.githooks/)'
  [ ${#TARGETS[@]} -eq 0 ] && return 0
  if [ "${JUDGE_BY_MODE:-0}" = "1" ]; then
    run_gated shellcheck "shellcheck" shellcheck -x -f gcc "${TARGETS[@]}"
  else
    run_tool "shellcheck" shellcheck -x "${TARGETS[@]}" # -x: follow sourced lib.sh even if unstaged
  fi
}

# scan_secrets <mode>: gitleaks on the staged diff, or on the whole git history. Always runs
# against the real repository (GIT_REPO in staged mode), never the snapshot.
scan_secrets() {
  local repo="${GIT_REPO:-.}" scope=()
  [ "$1" = "staged" ] && scope=(--staged)
  if has_command gitleaks && gitleaks git --help >/dev/null 2>&1; then
    run_tool "secret scan (gitleaks)" gitleaks git --no-banner --redact --log-level warn ${scope[@]+"${scope[@]}"} "$repo"
  elif [ "$1" = "staged" ]; then # gitleaks < 8.19
    run_tool "secret scan (gitleaks)" gitleaks protect --staged --no-banner --redact --source "$repo"
  else
    run_tool "secret scan (gitleaks)" gitleaks detect --no-banner --redact --source "$repo"
  fi
}

# scan_sast <mode> <rules-dir> [exclude-regex]: semgrep with versioned local rules only (no network).
scan_sast() {
  collect_files "$1" "$SAST_FILE_PATTERN" "${3:-^$}"
  [ ${#TARGETS[@]} -eq 0 ] && return 0
  if [ "${JUDGE_BY_MODE:-0}" = "1" ]; then
    SEMGREP_ENABLE_VERSION_CHECK=0 run_gated semgrep "SAST (semgrep, local rules)" \
      semgrep scan --config "$2" --metrics=off --disable-version-check --error --quiet --emacs "${TARGETS[@]}"
  else
    SEMGREP_ENABLE_VERSION_CHECK=0 run_tool "SAST (semgrep, local rules)" \
      semgrep scan --config "$2" --metrics=off --disable-version-check --error --quiet "${TARGETS[@]}"
  fi
}

# run_required_tool <label> <binary> [args...]: like run_tool, but a missing binary always
# fails. Used for tools a detected stack depends on, so "not installed" never looks green.
run_required_tool() {
  local saved_strict=$STRICT
  STRICT=1
  run_tool "$@"
  STRICT=$saved_strict
}

# require <condition-description> <command...>: counts a failure unless the command succeeds.
require() {
  local description=$1
  shift
  if ! "$@" >/dev/null 2>&1; then
    warn "missing: $description"
    FAILURES=$((FAILURES + 1))
  fi
}

# is_semver <string>: true for MAJOR.MINOR.PATCH with plain digits.
is_semver() { printf '%s' "$1" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'; }

# rewrite_file <file> <command...>: replaces the file with the command's output (the command
# reads the file on stdin). The file keeps its mode. When the command fails, the file stays
# unchanged; when writing fails, it may be partly written and the status is non-zero.
rewrite_file() {
  local file=$1 tmp status=0
  shift
  tmp="$(mktemp)"
  "$@" <"$file" >"$tmp" || status=$?
  [ "$status" -eq 0 ] && { cat "$tmp" >"$file" || status=$?; }
  rm -f "$tmp"
  return "$status"
}

# changelog_fragments <root>: validates and lists fragment paths; no folder keeps the legacy workflow (REQ-171).
# A fragment has one Keep a Changelog heading and bullet entries; README.md is documentation, never consumed.
changelog_fragments() (
  local directory="${1:-.}/changelog.d" file
  [ ! -L "$directory" ] || die "changelog fragment directory must not be a symlink: $directory"
  [ ! -e "$directory" ] || [ -d "$directory" ] || die "changelog fragments need a directory: $directory"
  [ -d "$directory" ] || return 0
  export LC_ALL=C
  for file in "$directory"/*; do
    [ "${file##*/}" != README.md ] || continue
    [ -e "$file" ] || [ -L "$file" ] || continue
    printf '%s\n' "${file##*/}" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*\.md$' && [ -f "$file" ] && [ ! -L "$file" ] ||
      die "invalid changelog fragment path: $file (use a plain <unique-name>.md file)"
    awk '
      NR == 1 { if ($0 !~ /^### (Added|Changed|Deprecated|Removed|Fixed|Security)$/) exit 1; next }
      /^- [^[:space:]]/ { entries++; next }
      /^[[:space:]]*$/ { next }
      /^  / { if (entries) next }
      { exit 1 }
      END { if (!entries) exit 1 }' "$file" ||
      die "invalid changelog fragment: $file (one ### Added|Changed|Deprecated|Removed|Fixed|Security heading, then bullet entries)"
    printf '%s\n' "$file"
  done
)

# check_changelog_fragments <root>: validates without printing paths or exiting the calling check.
check_changelog_fragments() ( changelog_fragments "$1" >/dev/null )

# render_changelog_fragments <paths>: groups validated fragments by heading, preserving their text.
render_changelog_fragments() {
  local paths=$1 heading file found
  for heading in Added Changed Deprecated Removed Fixed Security; do
    found=0
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      [ "$(head -n 1 "$file")" = "### $heading" ] || continue
      if [ "$found" = 0 ]; then printf '\n### %s\n' "$heading"; found=1; fi
      awk 'NR > 1 { print }' "$file"
      printf '\n'
    done <<<"$paths"
  done
}

# stamp_changelog <file> <version>: stamps Unreleased plus fragments, then consumes only validated files.
# Release callers include the fragments in their rollback and commit file lists (REQ-024, REQ-171).
stamp_changelog() {
  local fragments rendered status=0 file
  grep -q '^## \[Unreleased\]' "$1" || die "$1 has no [Unreleased] section; nothing was changed"
  fragments="$(changelog_fragments "$(dirname "$1")")" || return 1
  rendered="$(mktemp)"
  render_changelog_fragments "$fragments" >"$rendered" || status=$?
  if [ "$status" = 0 ]; then
    # shellcheck disable=SC2016
    rewrite_file "$1" awk -v v="$2" -v d="$(date +%F)" -v fragments="$rendered" '
      function remaining( i, heading) {
        for (i = 1; i <= 6; i++) {
          heading = "### " categories[i]
          if (additions[heading] != "") print "\n" heading "\n" additions[heading]
        }
      }
      BEGIN {
        split("Added Changed Deprecated Removed Fixed Security", categories, " ")
        while ((getline line < fragments) > 0) {
          if (line ~ /^### /) heading = line
          else if (heading != "") additions[heading] = additions[heading] line "\n"
        }
        close(fragments)
      }
      /^## \[Unreleased\]/ { print; print ""; print "## [" v "] - " d; active = 1; next }
      active && /^## / { remaining(); active = 0 }
      active && /^### / {
        print
        if (additions[$0] != "") { printf "%s", additions[$0]; delete additions[$0] }
        next
      }
      { print }
      END { if (active) remaining() }' || status=$?
  fi
  rm -f "$rendered"
  [ "$status" = 0 ] || return "$status"
  while IFS= read -r file; do
    [ -z "$file" ] || rm -- "$file" || return 1
  done <<<"$fragments"
}

# --- branch rule (REQ-060): changes reach main through pull requests -------------------

# Branches that receive changes only through pull requests.
PROTECTED_BRANCHES="main master"

# refuse_commit_on_protected_branch: dies when HEAD is a protected branch. Allowed anyway with
# ALLOW_MAIN_COMMIT=1 (project generation, releases, explicit overrides), while concluding a
# merge, and on a detached HEAD (rebases, CI). Used by the pre-commit hooks.
refuse_commit_on_protected_branch() {
  local branch
  [ "${ALLOW_MAIN_COMMIT:-0}" = "1" ] && return 0
  git rev-parse -q --verify MERGE_HEAD >/dev/null && return 0
  branch="$(git symbolic-ref -q --short HEAD)" || return 0
  case " $PROTECTED_BRANCHES " in *" $branch "*) ;; *) return 0 ;; esac
  die "commits on $branch go through a pull request (AGENTS.md §7). Start the change in its own folder:
  git worktree add worktrees/<slug> -b <type>/<slug> $branch
Override only when told to commit on $branch: ALLOW_MAIN_COMMIT=1 git commit ..."
}

# --- release helpers (REQ-024): never leave a partial release behind -----------------

# ensure_tag_absent <tag>: dies before anything changes if the release tag already exists.
ensure_tag_absent() {
  if git rev-parse -q --verify "refs/tags/$1" >/dev/null; then
    die "tag $1 already exists; nothing was changed"
  fi
}

# stamp_release_or_restore <stamp-command> <version> <files...>: runs the command, which writes
# the new version into the files; if it fails, restores them to HEAD (the release checked for a
# clean tree first), then dies. The command runs in a subshell, so its own die is caught too.
stamp_release_or_restore() {
  local stamp=$1 version=$2
  shift 2
  if ! ("$stamp" "$version"); then
    git checkout -q -- "$@"
    die "stamping the release files failed; they were restored, nothing was changed"
  fi
}

# commit_release_or_restore <message> <files...>: commits the release files; if the commit
# fails, restores them to HEAD so the working tree is exactly as before, then dies.
commit_release_or_restore() {
  local message=$1
  shift
  git add -- "$@"
  # Releases are cut on main after the branches are merged (REQ-060).
  if ! ALLOW_MAIN_COMMIT=1 git commit -q -m "$message"; then
    git reset -q -- "$@"
    git checkout -q -- "$@"
    die "release commit failed; release files restored, nothing was changed"
  fi
}

# tag_release_or_report <tag>: tags HEAD; on failure explains the partial state and the
# two ways out, then dies.
tag_release_or_report() {
  if ! git tag -a "$1" -m "Release $1"; then
    warn "PARTIAL RELEASE: commit $(git rev-parse --short HEAD) exists, but tag $1 could not be created."
    warn "Either retry: git tag -a $1 -m \"Release $1\""
    warn "or undo the release commit: git reset --hard HEAD~1"
    die "tagging failed"
  fi
}

# semver_compare <a> <b>: prints -1, 0 or 1 by SemVer 2.0 precedence (section 11): the core
# numerically, a version without a pre-release above the same core with one, pre-release
# identifiers left to right (numbers below words, words in ASCII order, fewer fields lower).
semver_compare() {
  LC_ALL=C awk -v a="$1" -v b="$2" '
    function isnum(s) { return s ~ /^[0-9]+$/ }
    function cmp(x, y) { return x < y ? -1 : (x > y ? 1 : 0) }
    function core(v, i) { i = index(v, "-"); return i ? substr(v, 1, i - 1) : v }
    function pre(v, i) { i = index(v, "-"); return i ? substr(v, i + 1) : "" }
    BEGIN {
      split(core(a), x, "."); split(core(b), y, ".")
      for (i = 1; i <= 3; i++) { c = cmp(x[i] + 0, y[i] + 0); if (c) { print c; exit } }
      if (pre(a) == "" && pre(b) == "") { print 0; exit }
      if (pre(a) == "") { print 1; exit }
      if (pre(b) == "") { print -1; exit }
      na = split(pre(a), p, "."); nb = split(pre(b), q, ".")
      for (i = 1; i <= na && i <= nb; i++) {
        if (isnum(p[i]) && isnum(q[i])) c = cmp(p[i] + 0, q[i] + 0)
        else if (isnum(p[i])) c = -1
        else if (isnum(q[i])) c = 1
        else c = cmp(p[i], q[i])
        if (c) { print c; exit }
      }
      print cmp(na, nb)
    }'
}

# is_prerelease_semver <string>: true for the pre-releases Xaden makes: X.Y.Z-<id> or X.Y.Z-<id>.<n>, n from 1 (REQ-166).
is_prerelease_semver() {
  printf '%s' "$1" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-[A-Za-z][0-9A-Za-z-]*(\.[1-9][0-9]*)?$'
}

# bump_version <current> <major|minor|patch|pre|final> [<pre-release id>]: prints the next SemVer (REQ-166).
#   major|minor|patch  bump a stable version; with an id the result is a pre-release (0.0.0 minor alpha: 0.1.0-alpha)
#   pre                next pre-release: same id counts up (alpha, alpha.2), another id starts it (beta)
#   final              drops the pre-release suffix
# Dies unless the result sorts after <current> (semver_compare).
bump_version() {
  local current=$1 part=$2 id=${3:-} base suffix current_id="" number=1 major minor patch next
  if is_prerelease_semver "$current"; then
    base=${current%%-*} suffix=${current#*-} current_id=${suffix%%.*}
    case "$suffix" in *.*) number=${suffix#*.} ;; esac
  else
    is_semver "$current" || die "not a valid SemVer: $current (Xaden bumps X.Y.Z, X.Y.Z-<id> and X.Y.Z-<id>.<n>)"
    base=$current
  fi
  [ -z "$id" ] || printf '%s' "$id" | grep -Eq '^[A-Za-z][0-9A-Za-z-]*$' ||
    die "pre-release id must start with a letter and hold only letters, digits and - (got: $id)"
  case "$part" in
    major | minor | patch)
      [ -z "$current_id" ] || die "$current is a pre-release: 'pre' makes the next one, 'final' releases $base"
      IFS=. read -r major minor patch <<EOF
$base
EOF
      case "$part" in
        major) next="$((major + 1)).0.0" ;;
        minor) next="$major.$((minor + 1)).0" ;;
        patch) next="$major.$minor.$((patch + 1))" ;;
      esac
      [ -z "$id" ] || next="$next-$id"
      ;;
    pre)
      [ -n "$current_id" ] || die "$current is not a pre-release: start one with major, minor or patch and --pre <id>"
      id=${id:-$current_id}
      if [ "$id" = "$current_id" ]; then next="$base-$id.$((number + 1))"; else next="$base-$id"; fi
      ;;
    final)
      [ -n "$current_id" ] || die "$current is not a pre-release; nothing to finalize"
      [ -z "$id" ] || die "--pre does not go with final"
      next=$base
      ;;
    *) die "release part must be major, minor, patch, pre or final (got: $part)" ;;
  esac
  [ "$(semver_compare "$next" "$current")" = 1 ] || die "$next does not sort after $current (SemVer 2.0 precedence); nothing was changed"
  printf '%s\n' "$next"
}
