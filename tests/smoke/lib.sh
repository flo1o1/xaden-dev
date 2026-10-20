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
DEMO="$WORKDIR/demo app/demo-app" # the demo project; a space in the path on purpose
mkdir -p "$(dirname "$DEMO")"
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

# fail_assertion <message>: ends the run with the message; with SMOKE_KEEP_GOING=1 it counts the failure and goes on,
# so a rewrite of an area lists every assertion that fails in one run (the run still fails in the end).
FAILED_ASSERTIONS=0
fail_assertion() {
  if [ "${SMOKE_KEEP_GOING:-0}" = "1" ]; then
    FAILED_ASSERTIONS=$((FAILED_ASSERTIONS + 1))
    printf 'FAIL %s\n' "$1" >&2
    return 0
  fi
  die "$1"
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
    fail_assertion "FAILED: $description"
  fi
}

# assert_fails <description> <command...>: command must exit non-zero.
assert_fails() {
  local description=$1
  shift
  if ("$@") >"$OUTPUT" 2>&1; then
    show_output
    fail_assertion "FAILED (expected failure): $description"
    return 0
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
    fail_assertion "FAILED (expected failure): $description"
    return 0
  fi
  if ! grep -q -- "$expected" "$OUTPUT"; then
    show_output
    fail_assertion "FAILED (wrong reason, expected '$expected'): $description"
    return 0
  fi
  pass "$description"
}

# requirements_dir <root>: where a project keeps its requirements.
requirements_dir() { printf '%s' "$1/xaden/requirements"; }

# req_file <root> <REQ-nnn>: path of a requirement file of a project.
req_file() {
  find "$(requirements_dir "$1")" -name "$2-*.md" | head -n 1
}

# edit_file <file> <sed-expression>: edits a file in place (portable, no sed -i).
edit_file() {
  sed "$2" "$1" >"$1.edit" && mv "$1.edit" "$1"
}

# set_status <REQ-nnn> <status> [root]: changes a requirement's status in a project (default: the
# demo project) and regenerates the index.
set_status() {
  local root="${3:-$DEMO}"
  edit_file "$(req_file "$root" "$1")" "s/^status: .*/status: $2/"
  PROJECT_ROOT="$root" "$SCAFFOLD_ROOT/template/scripts/req.sh" index >/dev/null
}


# requirements_variant <name> <sed-expression> [source]: a copy of a project's requirements (default: the
# demo project) with REQ-001 edited and the index regenerated; prints the requirements directory.
requirements_variant() {
  local root="$WORKDIR/variants/$1" source="${3:-$DEMO}"
  rm -rf "$root" && mkdir -p "$root/xaden"
  cp -R "$source/xaden/requirements" "$root/xaden/" && cp "$source/xaden/xaden.conf" "$root/xaden/"
  edit_file "$(req_file "$root" REQ-001)" "$2"
  PROJECT_ROOT="$root" "$SCAFFOLD_ROOT/template/scripts/req.sh" index >/dev/null
  printf '%s' "$(requirements_dir "$root")"
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

XADEN="$SCAFFOLD_ROOT/scripts/xaden.sh"
# The git hooks of the fixtures call `xaden`: it must be this checkout's command, not one installed on the machine.
mkdir -p "$WORKDIR/bin" && ln -sf "$XADEN" "$WORKDIR/bin/xaden"
export PATH="$WORKDIR/bin:$PATH"
XOUT="$WORKDIR/xaden.out"
XRC=0

# x_in <dir> <args...>: runs the xaden command in a directory; output in $XOUT, status in $XRC.
# shellcheck disable=SC2034 # XRC is read by the areas
x_in() {
  local dir=$1
  shift
  XRC=0
  (cd "$dir" && env -u CI "$XADEN" "$@") >"$XOUT" 2>&1 || XRC=$? # CI=true would make the scope of a check unknown (REQ-102)
}

# x_answers <answer> <dir> <args...>: like x_in, with a test answer for every question.
x_answers() {
  local answer=$1
  shift
  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=$answer x_in "$@"
}

# REQ-001 project creation: the demo project every area runs against, made by xaden itself (REQ-133)
test_new_project() {
  assert_fails "reject bad project name" "$XADEN" project create "Bad Name" "$WORKDIR/x"
  x_in "$(dirname "$DEMO")" project create demo-app "$DEMO"
  assert "create the demo project (first commit on main allowed)" test "$XRC" -eq 0
  assert "the demo project has its team folder" test -f "$DEMO/xaden/xaden.conf" -a -d "$DEMO/xaden/requirements"
  assert "the demo project has a first commit" git -C "$DEMO" log --oneline -1
  x_in "$DEMO" req new first-epic job "Describe the first job"
  assert "the demo project has a placeholder requirement" test -f "$DEMO/xaden/requirements/first-epic/REQ-001-describe-the-first-job.md"
  git -C "$DEMO" add -A && git -C "$DEMO" commit -q --no-verify -m "docs: placeholder requirement"
  make_demo_tools
}

# make_demo_tools: $DEMO_TOOLS holds one executable per script of template/scripts that runs it on the adopted demo project
# (PROJECT_ROOT, unless the caller sets another), so an area calls "$DEMO_TOOLS/check-requirements.sh" like a script of the project.
# shellcheck disable=SC2016 # the wrapper's ${PROJECT_ROOT:-...} must stay literal in the generated script
make_demo_tools() {
  local script name
  DEMO_TOOLS="$WORKDIR/demo-tools"
  mkdir -p "$DEMO_TOOLS"
  for script in "$SCAFFOLD_ROOT"/template/scripts/*.sh; do
    name="$(basename "$script")"
    printf '#!/usr/bin/env bash\nexec env PROJECT_ROOT="${PROJECT_ROOT:-%s}" "%s" "$@"\n' "$DEMO" "$script" >"$DEMO_TOOLS/$name"
    chmod +x "$DEMO_TOOLS/$name"
  done
  mkdir -p "$DEMO_TOOLS/hooks"
  for script in "$SCAFFOLD_ROOT"/template/scripts/hooks/*; do
    name="$(basename "$script")"
    printf '#!/usr/bin/env bash\nexec env PROJECT_ROOT="${PROJECT_ROOT:-%s}" "%s" "$@"\n' "$DEMO" "$script" >"$DEMO_TOOLS/hooks/$name"
    chmod +x "$DEMO_TOOLS/hooks/$name"
  done
}

# git needs an identity inside the sandbox project.
export GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=smoke@example.invalid
export GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=smoke@example.invalid
