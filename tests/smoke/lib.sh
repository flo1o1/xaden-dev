# shellcheck shell=bash
# Shared setup, assertion helpers and the demo project fixture for the smoke test areas.
# Sourced by tests/smoke.sh; not run on its own.

SCAFFOLD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=SCRIPTDIR/../../template/scripts/lib.sh
source "$SCAFFOLD_ROOT/template/scripts/lib.sh"
# shellcheck source=SCRIPTDIR/../../scripts/scaffold-lib.sh
source "$SCAFFOLD_ROOT/scripts/scaffold-lib.sh"

# REQ-025: isolated from the user's git configuration; failures show the command output;
# SMOKE_REQUIRE_TOOLS=1 (set in CI) turns tool-dependent skips into failures.
# SMOKE_VERBOSE=1 prints a line per passed assertion; by default only failures and the total
# appear, so an assistant reading the output spends no tokens on hundreds of "ok" lines.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
# Strictness is chosen per test call; an inherited STRICT=1 (CI) must not leak into fixtures.
unset STRICT
# Fixtures commit on main; test_branch_rule (REQ-060) and the generation and release asserts
# run with ALLOW_MAIN_COMMIT=0 to prove the rule and its built-in exceptions.
export ALLOW_MAIN_COMMIT=1
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
PROJECT="$WORKDIR/demo app/demo-app" # space in the path on purpose (REQ-018)
mkdir -p "$(dirname "$PROJECT")"
OUTPUT="$WORKDIR/last-command.log"
PASSED=0
SKIPPED=0

# rules_text <dir>: a file holding AGENTS.md and the files of docs/rules/ of a project or of the
# template (REQ-126 moved most rule sections there); tests grep it for a rule wherever it lives.
rules_text() {
  local file
  file="$(mktemp "$WORKDIR/rules-text.XXXXXX")"
  cat "$1/AGENTS.md" "$1"/docs/rules/*.md >"$file"
  printf '%s' "$file"
}

# show_output: prints the tail of the last command's output (diagnostics on failure).
show_output() {
  echo "----- output of the failed command (last 40 lines) -----" >&2
  tail -n 40 "$OUTPUT" >&2
  echo "--------------------------------------------------------" >&2
}

# pass <description>: counts a passed assertion; prints it only with SMOKE_VERBOSE=1.
pass() {
  PASSED=$((PASSED + 1))
  if [ "${SMOKE_VERBOSE:-0}" = "1" ]; then printf 'ok   %s\n' "$1"; fi
  return 0
}

# assert <description> <command...>: runs the command, dies with its output if it fails.
assert() {
  local description=$1
  shift
  if ("$@") >"$OUTPUT" 2>&1; then
    pass "$description"
  else
    show_output
    die "FAILED: $description"
  fi
}

# assert_fails <description> <command...>: command must exit non-zero.
assert_fails() {
  local description=$1
  shift
  if ("$@") >"$OUTPUT" 2>&1; then
    show_output
    die "FAILED (expected failure): $description"
  fi
  pass "$description"
}

# need_tool <tool> <what>: true if available; otherwise skip visibly, or fail in CI.
need_tool() {
  has_command "$1" && return 0
  [ "${SMOKE_REQUIRE_TOOLS:-0}" = "1" ] && die "required tool missing in CI: $1 ($2)"
  SKIPPED=$((SKIPPED + 1))
  printf 'SKIP %s (%s not installed)\n' "$2" "$1"
  return 1
}

# assert_fails_with <description> <expected-text> <command...>: command must exit non-zero and
# its output must contain the expected text, so it fails for the right reason.
assert_fails_with() {
  local description=$1 expected=$2
  shift 2
  if ("$@") >"$OUTPUT" 2>&1; then
    show_output
    die "FAILED (expected failure): $description"
  fi
  if ! grep -q -- "$expected" "$OUTPUT"; then
    show_output
    die "FAILED (wrong reason, expected '$expected'): $description"
  fi
  pass "$description"
}

# req_file <root> <REQ-nnn>: path of a requirement file below <root>/docs/requirements.
req_file() {
  find "$1/docs/requirements" -name "$2-*.md" | head -n 1
}

# edit_file <file> <sed-expression>: edits a file in place (portable, no sed -i).
edit_file() {
  sed "$2" "$1" >"$1.edit" && mv "$1.edit" "$1"
}

# set_status <REQ-nnn> <status>: changes a requirement's status in the demo project and
# regenerates the index.
set_status() {
  edit_file "$(req_file "$PROJECT" "$1")" "s/^status: .*/status: $2/"
  "$PROJECT/scripts/req.sh" index >/dev/null
}


# requirements_variant <name> <sed-expression>: a copy of the demo project's requirements with
# REQ-001 edited and the index regenerated; prints the requirements directory.
requirements_variant() {
  local root="$WORKDIR/variants/$1"
  rm -rf "$root" && mkdir -p "$root/docs"
  cp -R "$PROJECT/docs/requirements" "$root/docs/"
  edit_file "$(req_file "$root" REQ-001)" "$2"
  PROJECT_ROOT="$root" "$PROJECT/scripts/req.sh" index >/dev/null
  printf '%s' "$root/docs/requirements"
}

# path_without <tool>: prints a PATH where every command except <tool> is available.
path_without() {
  local bin="$WORKDIR/path-without-$1" dir file
  mkdir -p "$bin"
  local IFS=:
  for dir in $PATH; do
    for file in "$dir"/*; do
      [ -x "$file" ] && [ ! -e "$bin/${file##*/}" ] && [ "${file##*/}" != "$1" ] && ln -s "$file" "$bin/${file##*/}"
    done
  done
  printf '%s' "$bin"
}

# REQ-001 project creation, REQ-013 template separation
test_new_project() {
  assert_fails "reject bad project name" "$SCAFFOLD_ROOT/scripts/new-project.sh" "Bad Name" "$WORKDIR/x"
  assert "create project (first commit on main allowed)" env ALLOW_MAIN_COMMIT=0 "$SCAFFOLD_ROOT/scripts/new-project.sh" demo-app "$PROJECT"
  assert "no placeholders left" test -z "$(grep -rl '{{PROJECT_NAME}}' "$PROJECT" --exclude-dir=.git || true)"
  assert "scaffold-only files not copied" test ! -e "$PROJECT/tests" -a ! -e "$PROJECT/template" -a ! -e "$PROJECT/scripts/new-project.sh"
  assert "project gets template rules" grep -q 'CC-09' "$PROJECT/AGENTS.md"
  assert "own git repo with first commit" git -C "$PROJECT" log --oneline -1
  assert "hooks path configured" test "$(git -C "$PROJECT" config core.hooksPath)" = "scripts/hooks"
}

# git needs an identity inside the sandbox project.
export GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=smoke@example.invalid
export GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=smoke@example.invalid
