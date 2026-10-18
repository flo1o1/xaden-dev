#!/usr/bin/env bash
# What a repository already has, found by reading it (REQ-067). Source it; do not execute it.
# Requires template/scripts/lib.sh. Nothing here writes a file or runs the repository's code.
# A tool or setup that is not recognised is reported as such; no command is ever guessed.

# Scan results, set by scan_repository.
SCAN_STACKS=""        # node python go rust java make, space separated
SCAN_TEST=""          # command that runs the tests, or empty
SCAN_LINT=""          # command that runs the linters, or empty
SCAN_TYPECHECK=""     # command that runs the type checker, or empty
SCAN_FOUND_TOOLS=""   # tools found without a command to run them: "eslint (no lint script)"
SCAN_GAPS=""          # kinds that are missing: test lint typecheck
SCAN_HOOKS=""         # husky pre-commit lefthook plain, or "unsupported: <name>"
SCAN_CI=""            # github-actions none, or "unsupported: <name>"
SCAN_CONVENTION=""    # conventional or other
SCAN_CONVENTION_EVIDENCE=""  # why: "3 of 3 subjects", "no history" or "chosen with --commit-convention"
SCAN_AGENTS=0
SCAN_CLAUDE=0
SCAN_CLAUDE_DIR=0
SCAN_COPILOT=0
SCAN_VIBE=0
SCAN_CODEX=0
SCAN_UNRECOGNISED=""  # what could not be recognised, one line each (newline separated)

# conventional commit subject (the same rule the commit-msg hook enforces)
CONVENTIONAL_PATTERN='^(feat|fix|refactor|docs|test|chore|perf|build|ci|style|revert)(\([a-z0-9._-]+\))?!?: .+'

# repo_has <repo> <path>: true if the path exists in the repository's working tree.
repo_has() { [ -e "$1/$2" ]; }

# repo_grep <repo> <regex> <files...>: true if one of the files exists and matches.
repo_grep() {
  local repo=$1 pattern=$2 file
  shift 2
  for file in "$@"; do
    if [ -f "$repo/$file" ] && grep -Eq -- "$pattern" "$repo/$file"; then return 0; fi
  done
  return 1
}

# package_script <repo> <name>: true if package.json defines the npm script. A key whose value is
# a version range (a dependency of that name) does not count, nor does the placeholder npm init
# writes for "test". Works for package.json written on one line or many.
package_script() {
  [ -f "$1/package.json" ] || return 1
  grep -E "\"$2\"[[:space:]]*:[[:space:]]*\"[^0-9^~*<>=\"]" "$1/package.json" | grep -qv 'no test specified'
}

# make_target <repo> <name>: true if the Makefile defines the target.
make_target() {
  [ -f "$1/Makefile" ] && grep -Eq "^$2[[:space:]]*:" "$1/Makefile"
}

# set_command <kind> <command>: records the first command found for a kind.
set_command() {
  case "$1" in
    test) [ -n "$SCAN_TEST" ] || SCAN_TEST=$2 ;;
    lint) [ -n "$SCAN_LINT" ] || SCAN_LINT=$2 ;;
    typecheck) [ -n "$SCAN_TYPECHECK" ] || SCAN_TYPECHECK=$2 ;;
  esac
}

# found_tool <text>: a tool the repository configures but that has no command to run it.
found_tool() { SCAN_FOUND_TOOLS="$SCAN_FOUND_TOOLS${SCAN_FOUND_TOOLS:+$'\n'}$1"; }

scan_node() {
  local repo=$1
  repo_has "$repo" package.json || return 0
  SCAN_STACKS="$SCAN_STACKS node"
  package_script "$repo" test && set_command test "npm test"
  package_script "$repo" lint && set_command lint "npm run lint"
  if package_script "$repo" typecheck; then set_command typecheck "npm run typecheck"; fi
  if [ -z "$SCAN_LINT" ] && { repo_has "$repo" eslint.config.js || repo_has "$repo" eslint.config.mjs || repo_has "$repo" .eslintrc.json || repo_has "$repo" .eslintrc.js; }; then
    found_tool "eslint (configured, but package.json has no lint script)"
  fi
  if [ -z "$SCAN_TYPECHECK" ] && repo_has "$repo" tsconfig.json; then
    found_tool "TypeScript (tsconfig.json, but package.json has no typecheck script)"
  fi
}

scan_python() {
  local repo=$1 project_files="pyproject.toml setup.py setup.cfg"
  if ! { repo_has "$repo" pyproject.toml || repo_has "$repo" setup.py || repo_has "$repo" setup.cfg ||
    ls "$repo"/requirements*.txt >/dev/null 2>&1; }; then return 0; fi
  SCAN_STACKS="$SCAN_STACKS python"
  # shellcheck disable=SC2086 # the file list is words on purpose
  if repo_has "$repo" pytest.ini || repo_grep "$repo" '^\[tool\.pytest|^\[tool:pytest\]|^\[pytest\]' $project_files tox.ini; then
    set_command test "pytest"
  fi
  # shellcheck disable=SC2086
  if repo_has "$repo" ruff.toml || repo_has "$repo" .ruff.toml || repo_grep "$repo" '^\[tool\.ruff' $project_files; then
    set_command lint "ruff check ."
  elif repo_has "$repo" .flake8 || repo_grep "$repo" '^\[flake8\]' setup.cfg tox.ini; then
    set_command lint "flake8"
  fi
  # shellcheck disable=SC2086
  if repo_has "$repo" mypy.ini || repo_grep "$repo" '^\[tool\.mypy\]|^\[mypy\]' $project_files; then
    set_command typecheck "mypy ."
  elif repo_has "$repo" pyrightconfig.json; then
    set_command typecheck "pyright"
  fi
}

scan_go() {
  repo_has "$1" go.mod || return 0
  SCAN_STACKS="$SCAN_STACKS go"
  set_command test "go test ./..."
  if repo_has "$1" .golangci.yml || repo_has "$1" .golangci.yaml; then set_command lint "golangci-lint run"; fi
}

scan_rust() {
  repo_has "$1" Cargo.toml || return 0
  SCAN_STACKS="$SCAN_STACKS rust"
  set_command test "cargo test"
  if repo_has "$1" clippy.toml || repo_has "$1" .clippy.toml; then set_command lint "cargo clippy"; fi
}

scan_jvm_and_others() {
  local repo=$1
  if repo_has "$repo" pom.xml || repo_has "$repo" build.gradle || repo_has "$repo" build.gradle.kts; then
    SCAN_STACKS="$SCAN_STACKS java"
    if repo_has "$repo" gradlew; then set_command test "./gradlew test"; elif repo_has "$repo" pom.xml; then set_command test "mvn test"; fi
  fi
  if repo_has "$repo" Gemfile || repo_has "$repo" composer.json; then
    SCAN_UNRECOGNISED="$SCAN_UNRECOGNISED${SCAN_UNRECOGNISED:+$'\n'}Ruby or PHP project: no test or lint command is known for it"
  fi
}

# scan_make: a Makefile fills the kinds the language did not.
scan_make() {
  local repo=$1
  [ -f "$repo/Makefile" ] || return 0
  SCAN_STACKS="$SCAN_STACKS make"
  make_target "$repo" test && set_command test "make test"
  make_target "$repo" lint && set_command lint "make lint"
  make_target "$repo" typecheck && set_command typecheck "make typecheck"
  return 0
}

# scan_gaps: the kinds this repository should have a check for and does not.
scan_gaps() {
  [ -n "$SCAN_STACKS" ] || return 0
  [ -n "$SCAN_TEST" ] || SCAN_GAPS="$SCAN_GAPS test"
  [ -n "$SCAN_LINT" ] || SCAN_GAPS="$SCAN_GAPS lint"
  case " $SCAN_STACKS " in
    *" python "*) [ -n "$SCAN_TYPECHECK" ] || SCAN_GAPS="$SCAN_GAPS typecheck" ;;
    *" node "*) if [ -z "$SCAN_TYPECHECK" ] && repo_has "$1" tsconfig.json; then SCAN_GAPS="$SCAN_GAPS typecheck"; fi ;;
  esac
  SCAN_GAPS="${SCAN_GAPS# }"
}

# scan_hooks <repo>: the hook manager, or "unsupported: <name>".
scan_hooks() {
  local repo=$1 path
  if repo_has "$repo" .husky; then SCAN_HOOKS=husky
  elif repo_has "$repo" .pre-commit-config.yaml; then SCAN_HOOKS=pre-commit
  elif repo_has "$repo" lefthook.yml || repo_has "$repo" .lefthook.yml || repo_has "$repo" lefthook.yaml; then SCAN_HOOKS=lefthook
  elif repo_has "$repo" .overcommit.yml; then SCAN_HOOKS="unsupported: overcommit"
  elif repo_grep "$repo" '"simple-git-hooks"' package.json; then SCAN_HOOKS="unsupported: simple-git-hooks"
  else
    path="$(git -C "$repo" config --get core.hooksPath 2>/dev/null || true)"
    if [ -n "$path" ]; then SCAN_HOOKS="unsupported: core.hooksPath = $path"; else SCAN_HOOKS=plain; fi
  fi
}

# scan_ci <repo>: the CI system, or "unsupported: <name>".
scan_ci() {
  local repo=$1
  if ls "$repo"/.github/workflows/*.y*ml >/dev/null 2>&1; then SCAN_CI=github-actions
  elif repo_has "$repo" .gitlab-ci.yml; then SCAN_CI="unsupported: GitLab CI"
  elif repo_has "$repo" Jenkinsfile; then SCAN_CI="unsupported: Jenkins"
  elif repo_has "$repo" .circleci; then SCAN_CI="unsupported: CircleCI"
  elif repo_has "$repo" azure-pipelines.yml; then SCAN_CI="unsupported: Azure Pipelines"
  elif repo_has "$repo" bitbucket-pipelines.yml; then SCAN_CI="unsupported: Bitbucket Pipelines"
  else SCAN_CI=none
  fi
}

# scan_convention <repo>: conventional when at least 60 % of the last 30 commit subjects follow
# Conventional Commits; with fewer than 5 subjects the share says too little, so every one of them
# must follow it (REQ-108); with no history at all, conventional.
scan_convention() {
  local total matching
  total="$( (git -C "$1" log -n 30 --format=%s 2>/dev/null || true) | wc -l | tr -d ' ')"
  if [ "$total" -eq 0 ]; then SCAN_CONVENTION=conventional SCAN_CONVENTION_EVIDENCE="no history"; return 0; fi
  matching="$(git -C "$1" log -n 30 --format=%s 2>/dev/null | grep -Ec "$CONVENTIONAL_PATTERN" || true)"
  SCAN_CONVENTION_EVIDENCE="$matching of $total subjects"
  if [ "$total" -ge 5 ] && [ $((matching * 100)) -ge $((total * 60)) ]; then SCAN_CONVENTION=conventional
  elif [ "$total" -lt 5 ] && [ "$matching" -eq "$total" ]; then SCAN_CONVENTION=conventional
  else SCAN_CONVENTION=other
  fi
}

# Rules that an existing AGENTS.md or CLAUDE.md might contradict (REQ-067). Two groups: phrases
# that contradict unless a negation ("never", "do not") is on the same line, and phrases that
# are negative themselves.
CONTRADICTION_POSITIVE='(skip|disable|ignore|bypass|turn off) (the )?(tests?|lint(ing|ers?)?|checks?|hooks?|security|requirements|code review)|--no-verify|(commit|push) (directly )?(to|on) (main|master)|force[- ]push'
CONTRADICTION_NEGATIVE="(don't|do not|never) (write|add) (any )?tests|no need (for|to) (tests?|review|requirements|checks)"
NEGATION='(never|do not|don.t|must not|should not|not allowed|forbidden|avoid)'

# scan_contradictions <repo>: "file:line: text" for each line of AGENTS.md, CLAUDE.md or
# .claude/*.md that contradicts the rules in xaden/RULES.md.
scan_contradictions() {
  local repo=$1 file
  for file in AGENTS.md CLAUDE.md .claude/*.md; do
    [ -f "$repo/$file" ] || continue
    { grep -nEi -- "$CONTRADICTION_POSITIVE" "$repo/$file" | grep -Eiv -- "$NEGATION" || true
      grep -nEi -- "$CONTRADICTION_NEGATIVE" "$repo/$file" || true; } |
      LC_ALL=C sort -t: -k1,1n -u | sed -E "s#^([0-9]+):[[:space:]]*#$file:\1: #"
  done
}

# scan_repository <repo>: fills the SCAN_* variables. Writes nothing.
scan_repository() {
  local repo=$1
  SCAN_STACKS="" SCAN_TEST="" SCAN_LINT="" SCAN_TYPECHECK="" SCAN_FOUND_TOOLS="" SCAN_GAPS="" SCAN_UNRECOGNISED=""
  scan_node "$repo"
  scan_python "$repo"
  scan_go "$repo"
  scan_rust "$repo"
  scan_jvm_and_others "$repo"
  scan_make "$repo"
  SCAN_STACKS="${SCAN_STACKS# }"
  scan_gaps "$repo"
  scan_hooks "$repo"
  scan_ci "$repo"
  scan_convention "$repo"
  SCAN_AGENTS=0 SCAN_CLAUDE=0 SCAN_CLAUDE_DIR=0 SCAN_COPILOT=0 SCAN_VIBE=0 SCAN_CODEX=0
  [ ! -f "$repo/AGENTS.md" ] || SCAN_AGENTS=1
  [ ! -f "$repo/CLAUDE.md" ] || SCAN_CLAUDE=1
  [ ! -d "$repo/.claude" ] || SCAN_CLAUDE_DIR=1
  # REQ-081: a file or folder of the assistant's own; .agents/ is shared by Vibe and Codex, so it names neither
  if [ -f "$repo/.github/copilot-instructions.md" ] || [ -d "$repo/.github/prompts" ]; then SCAN_COPILOT=1; fi
  [ ! -d "$repo/.vibe" ] || SCAN_VIBE=1
  [ ! -d "$repo/.codex" ] || SCAN_CODEX=1
  # source files but no stack recognised
  if [ -z "$SCAN_STACKS" ] && [ -n "$(git -C "$repo" ls-files 2>/dev/null | grep -Ev '^(README|LICENSE|\.|docs/)' | head -n 1)" ]; then
    SCAN_UNRECOGNISED="$SCAN_UNRECOGNISED${SCAN_UNRECOGNISED:+$'\n'}no build system recognised: name your own commands with --check test=\"<command>\""
  fi
}

# show_or_none <text>: the text, or "none".
show_or_none() { printf '%s' "${1:-none}"; }

# print_scan <repo>: the read-only report of --scan.
print_scan() {
  local repo=$1 line mapped
  info "scan of $repo"
  printf '  %-18s %s\n' "stack" "$(show_or_none "$SCAN_STACKS")"
  printf '  %-18s %s\n' "test runner" "$(show_or_none "$SCAN_TEST")"
  printf '  %-18s %s\n' "linters" "$(show_or_none "$SCAN_LINT")"
  printf '  %-18s %s\n' "type checker" "$(show_or_none "$SCAN_TYPECHECK")"
  printf '  %-18s %s\n' "CI" "$(show_or_none "$SCAN_CI")"
  printf '  %-18s %s\n' "hook manager" "$SCAN_HOOKS"
  printf '  %-18s %s\n' "commit convention" "$SCAN_CONVENTION ($SCAN_CONVENTION_EVIDENCE)"
  if [ "$SCAN_CONVENTION" = other ]; then
    printf '  %-18s %s\n' "" "note: the Refs: checks only advise; set commit-convention = conventional in xaden/xaden.conf to enforce them (tightens a gate: an Approval point, REQ-044)"
  fi
  mapped=""
  [ "$SCAN_AGENTS" = 1 ] && mapped="AGENTS.md"
  [ "$SCAN_CLAUDE" = 1 ] && mapped="$mapped${mapped:+, }CLAUDE.md"
  [ "$SCAN_CLAUDE_DIR" = 1 ] && mapped="$mapped${mapped:+, }.claude/"
  [ "$SCAN_COPILOT" = 1 ] && mapped="$mapped${mapped:+, }Copilot (.github/)"
  [ "$SCAN_VIBE" = 1 ] && mapped="$mapped${mapped:+, }.vibe/"
  [ "$SCAN_CODEX" = 1 ] && mapped="$mapped${mapped:+, }.codex/"
  printf '  %-18s %s\n' "assistant files" "$(show_or_none "$mapped")"
  if [ -n "$SCAN_GAPS" ]; then
    printf '  %-18s %s\n' "gaps" "no check for: $SCAN_GAPS"
  fi
  if [ -n "$SCAN_FOUND_TOOLS" ]; then
    printf '%s\n' "$SCAN_FOUND_TOOLS" | while IFS= read -r line; do printf '  %-18s %s\n' "needs a command" "$line"; done
  fi
  if [ -n "$SCAN_UNRECOGNISED" ]; then
    printf '%s\n' "$SCAN_UNRECOGNISED" | while IFS= read -r line; do printf '  %-18s %s\n' "not recognised" "$line"; done
  fi
  local contradictions
  contradictions="$(scan_contradictions "$repo")"
  if [ -n "$contradictions" ]; then
    printf '  rules that contradict xaden/RULES.md (a person decides; nothing is changed):\n'
    printf '%s\n' "$contradictions" | sed 's/^/    /'
  fi
}
