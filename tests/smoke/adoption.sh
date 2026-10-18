# shellcheck shell=bash
# shellcheck disable=SC2016 # bash -c programs are single-quoted on purpose
# Smoke test area "adoption" (REQ-066 to REQ-076: adopting Xaden in existing repositories).
# Sourced by tests/smoke.sh, which defines the helpers and creates the demo project first.

# message_of <function> <args...>: what a lib.sh message helper prints on both streams.
message_of() { bash -c 'source "$1"; shift; "$@"' _ "$SCAFFOLD_ROOT/template/scripts/lib.sh" "$@" 2>&1 || true; }

# REQ-074 four kinds of messages, plain fallbacks, no hand-made signs
test_messages() {
  assert "plain error when not a terminal" test "$(message_of die boom)" = "ERROR: boom"
  assert "plain warning when not a terminal" test "$(message_of warn careful)" = "WARNING: careful"
  assert "plain success when not a terminal" test "$(message_of ok fine)" = "OK: fine"
  assert "CI forces plain text" test "$(CI=1 message_of ok fine)" = "OK: fine"
  assert "warnings go to stderr" test -z "$(bash -c 'source "$1"; warn x' _ "$SCAFFOLD_ROOT/template/scripts/lib.sh" 2>/dev/null)"
  assert "errors exit non-zero" bash -c '! bash -c '\''source "$1"; die x'\'' _ "$1" 2>/dev/null' _ "$SCAFFOLD_ROOT/template/scripts/lib.sh"

  local asked
  asked="$(XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=y message_of ask "Go on?")"
  assert "question is marked, last line, shows the default" test "$(printf '%s\n' "$asked" | tail -n 1)" = "[?] Go on? [y/N] y"
  assert "separator line comes before the question" test "$(printf '%s\n' "$asked" | head -n 1)" = "----------------------------------------"
  assert "yes answers a question" env XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=yes bash -c 'source "$1"; ask "Go on?" >/dev/null' _ "$SCAFFOLD_ROOT/template/scripts/lib.sh"
  assert_fails "empty answer is no" env XADEN_TEST_MODE=1 XADEN_TEST_ANSWER= bash -c 'source "$1"; ask "Go on?" >/dev/null' _ "$SCAFFOLD_ROOT/template/scripts/lib.sh"
  assert_fails "other answers are no" env XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=maybe bash -c 'source "$1"; ask "Go on?" >/dev/null' _ "$SCAFFOLD_ROOT/template/scripts/lib.sh"
  assert_fails "no terminal and no test mode: nothing is asked" bash -c 'source "$1"; ask "Go on?" </dev/null' _ "$SCAFFOLD_ROOT/template/scripts/lib.sh"
  assert_fails "the test answer is ignored without test mode" env XADEN_TEST_ANSWER=y bash -c 'source "$1"; ask "Go on?" </dev/null >/dev/null' _ "$SCAFFOLD_ROOT/template/scripts/lib.sh"

  assert "no script prints a sign by hand" bash -c \
    '! grep -rIl -e "🐉" -e "⚠" -e "🔥" -e "✅" "$1/scripts" "$1/template/scripts" | grep -v "template/scripts/lib.sh$" | grep .' _ "$SCAFFOLD_ROOT"
  assert "no script reads an answer by hand" bash -c \
    '! grep -rnE "(^|[^_a-z])read( -[a-z]+)* -p|ask\(\)" "$1/scripts" "$1/template/scripts" | grep -v "template/scripts/lib.sh:" | grep .' _ "$SCAFFOLD_ROOT"
}

XADEN="$SCAFFOLD_ROOT/scripts/xaden.sh"
# The git hooks of the fixtures call `xaden`: it must be this checkout's command, not one installed on the machine.
mkdir -p "$WORKDIR/bin" && ln -sf "$XADEN" "$WORKDIR/bin/xaden"
export PATH="$WORKDIR/bin:$PATH"
XOUT="$WORKDIR/xaden.out"
XRC=0

# x_in <dir> <args...>: runs the xaden command in a directory; output in $XOUT, status in $XRC.
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

# make_repo <dir> <kind>: a repository with history. Kinds: shop (npm test, make lint, CI, an
# AGENTS.md that contradicts the rules), bare-python (no tests or linters), husky, empty.
make_repo() {
  local dir=$1 kind=$2
  rm -rf "$dir" && mkdir -p "$dir"
  git -C "$dir" init -q -b main
  case "$kind" in
    empty) return 0 ;;
    shop)
      mkdir -p "$dir/.github/workflows" "$dir/docs" "$dir/scripts"
      printf '{ "name": "shop", "scripts": { "test": "node --test" } }\n' >"$dir/package.json"
      printf 'lint:\n\techo lint\n' >"$dir/Makefile"
      printf '# Shop\n' >"$dir/README.md"
      printf '# Changelog\n' >"$dir/CHANGELOG.md"
      printf 'guide\n' >"$dir/docs/guide.md"
      printf 'name: ci\non: push\njobs:\n  build:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo hi\n' >"$dir/.github/workflows/ci.yml"
      printf '#!/bin/sh\necho $1\n' >"$dir/scripts/build.sh" # an unquoted variable: shellcheck SC2086
      printf '# Rules\n- Skip tests when in a hurry.\n- Never skip the linter.\n' >"$dir/AGENTS.md" ;;
    bare-python)
      printf '[project]\nname = "bare"\n' >"$dir/pyproject.toml"
      printf 'print(1)\n' >"$dir/app.py"
      printf '# Bare\n' >"$dir/README.md" ;;
    pre-commit | lefthook)
      printf '{ "name": "m", "scripts": { "test": "node --test", "lint": "echo lint" } }\n' >"$dir/package.json"
      if [ "$kind" = pre-commit ]; then printf 'repos: []\n' >"$dir/.pre-commit-config.yaml"; else printf 'pre-commit:\n  commands: {}\n' >"$dir/lefthook.yml"; fi
      printf '# M\n' >"$dir/README.md" ;;
    husky)
      mkdir -p "$dir/.husky"
      printf '{ "name": "h", "scripts": { "test": "node --test", "lint": "echo lint" } }\n' >"$dir/package.json"
      printf '#!/usr/bin/env sh\nnpm run lint\n' >"$dir/.husky/pre-commit"
      printf '# H\n' >"$dir/README.md" ;;
  esac
  git -C "$dir" add -A
  git -C "$dir" commit -q -m "initial"
  git -C "$dir" commit -q --allow-empty -m "feat: second"
}

# adopted_copy <name>: an adopted shop in the work folder; prints the worktree with the adoption.
adopted_copy() {
  local repo="$WORKDIR/repos/$1"
  make_repo "$repo" shop
  x_in "$repo" adopt --yes --assistants claude,copilot,vibe >/dev/null || true
  printf '%s' "$repo-adopt-xaden"
}

# REQ-067 the scan reports and changes nothing; the plan shows the exact diff and writes nothing
test_scan_and_plan() {
  local repo="$WORKDIR/repos/scan-shop" before
  make_repo "$repo" shop
  before="$(git -C "$repo" status --porcelain; git -C "$repo" branch --list | wc -l)"
  x_in "$repo" adopt --scan
  assert "scan succeeds" test "$XRC" -eq 0
  assert "scan names the stack" grep -q 'stack .*node' "$XOUT"
  assert "scan finds the test runner" grep -q 'test runner .*npm test' "$XOUT"
  assert "scan finds the linters" grep -q 'linters .*make lint' "$XOUT"
  assert "scan finds the CI system" grep -q 'CI .*github-actions' "$XOUT"
  assert "scan finds the hook manager" grep -q 'hook manager .*plain' "$XOUT"
  assert "scan finds the commit convention" grep -q 'commit convention .*other' "$XOUT"
  assert "scan finds AGENTS.md" grep -q 'assistant files .*AGENTS.md' "$XOUT"
  assert "scan lists a contradicting rule with file and line" grep -q 'AGENTS.md:2: .*Skip tests' "$XOUT"
  assert "a rule that forbids skipping is no contradiction" bash -c '! grep -q "AGENTS.md:3" "$1"' _ "$XOUT"
  assert "scan changes nothing" test "$(git -C "$repo" status --porcelain; git -C "$repo" branch --list | wc -l)" = "$before"
  assert "scan wrote no xaden folder" test ! -e "$repo/xaden"

  x_in "$repo" adopt --plan
  assert "plan succeeds" test "$XRC" -eq 0
  assert "plan lists the created files" grep -q 'A.xaden/xaden.conf' "$XOUT"
  assert "plan lists the touched file" grep -q 'M.AGENTS.md' "$XOUT"
  assert "plan prints the exact diff" grep -q '^+++ b/xaden/xaden.conf' "$XOUT"
  assert "plan changes nothing" test "$(git -C "$repo" status --porcelain; git -C "$repo" branch --list | wc -l)" = "$before"
  assert "plan creates no worktree" test "$(git -C "$repo" worktree list | wc -l | tr -d ' ')" = "1"

  x_in "$repo" adopt
  assert "without a terminal nothing is applied" test ! -e "$repo-adopt-xaden"
  assert "without a terminal the apply command is named" grep -q 'xaden adopt --yes' "$XOUT"

  local unknown="$WORKDIR/repos/unknown"
  make_repo "$unknown" empty
  printf 'int main(void) { return 0; }\n' >"$unknown/main.c"
  git -C "$unknown" add -A && git -C "$unknown" commit -q -m "initial"
  x_in "$unknown" adopt --scan
  assert "an unrecognised build is said, not guessed" grep -q 'not recognised.*no build system recognised' "$XOUT"
  assert "no command is guessed" bash -c '! grep -q "test runner .*[a-z]" "$1" || grep -q "test runner .*none" "$1"' _ "$XOUT"
}

# REQ-066 REQ-070 REQ-073 adopting: own branch and worktree, nothing of the team's changes, small footprint
test_adopt_and_remove() {
  local repo="$WORKDIR/repos/adopt-shop" worktree changed
  make_repo "$repo" shop
  x_in "$repo" adopt --yes --assistants claude
  worktree="$repo-adopt-xaden"
  assert "adopt succeeds" test "$XRC" -eq 0
  assert "adopt works on its own branch and worktree" test "$(git -C "$worktree" branch --show-current)" = "chore/adopt-xaden"
  assert "the default branch is untouched" test "$(git -C "$repo" rev-parse main)" = "$(git -C "$repo" rev-parse HEAD)"
  assert "the first commit message names Xaden" git -C "$worktree" log -1 --format=%s main..HEAD
  changed="$(git -C "$worktree" diff --name-only main HEAD | grep -Ev '^(xaden/|AGENTS\.md$|CLAUDE\.md$|\.claude/commands/[a-z-]+\.md$|\.github/prompts/[a-z-]+\.prompt\.md$|\.agents/skills/[a-z-]+/SKILL\.md$|\.github/workflows/xaden\.yml$)' || true)"
  assert "only xaden/, AGENTS.md, CLAUDE.md, the command files and the documented workflow change (REQ-073)" test -z "$changed"
  assert "README, docs, scripts and CHANGELOG are untouched (REQ-066)" test -z "$(git -C "$worktree" diff --name-only main HEAD -- README.md docs scripts CHANGELOG.md package.json Makefile .github/workflows/ci.yml)"
  assert "the existing workflow is untouched" cmp -s "$repo/.github/workflows/ci.yml" "$worktree/.github/workflows/ci.yml"
  assert "CLAUDE.md is one line for Claude users" test "$(cat "$worktree/CLAUDE.md")" = "@AGENTS.md"
  assert "AGENTS.md keeps the team's own text" grep -q 'Skip tests when in a hurry' "$worktree/AGENTS.md"
  assert "AGENTS.md gets one marked block" test "$(grep -c 'xaden:begin' "$worktree/AGENTS.md")" = "1"
  assert "team content is plain Markdown plus one settings file (REQ-070)" test -f "$worktree/xaden/xaden.conf" -a -f "$worktree/xaden/requirements/INDEX.md" -a -d "$worktree/xaden/personas" -a -d "$worktree/xaden/security-reviews"
  assert "no editor specific files" test -z "$(find "$worktree/xaden" -name '.obsidian' -o -name '.vscode')"
  assert "tooling is not copied into the repository" test ! -e "$worktree/scripts/check.sh" -a ! -e "$worktree/prompts" -a ! -e "$worktree/xaden/scripts"
  assert "RULES.md says it is generated" grep -q 'Generated, do not edit' "$worktree/xaden/RULES.md"
  assert "RULES.md has no path of the copied layout" bash -c '! grep -nE "scripts/[a-z-]+\.sh|docs/(requirements|personas|threat-model|security)" "$1"' _ "$worktree/xaden/RULES.md"
  assert "RULES.md makes a mode change an approval point" grep -q 'Approval point' "$worktree/xaden/RULES.md"
  assert "REQ-110 RULES.md says the assistant never merges its own pull request" bash -c 'tr "\n" " " <"$1" | grep -q "never merges it"' _ "$worktree/xaden/RULES.md"
  assert "RULES.md starts a change sparse on the team's requirements only (REQ-082)" \
    grep -qF 'sparse-checkout set --cone xaden/requirements`' "$worktree/xaden/RULES.md"
  assert "the version and checksum are pinned" grep -Eq '^checksum = [0-9a-f]{64}$' "$worktree/xaden/xaden.conf"
  assert "the build's commands are mapped" grep -q '^check.test = npm test$' "$worktree/xaden/xaden.conf"
  assert "git hooks of the clone are chained, not replaced" grep -q 'xaden hook pre-commit' "$repo/.git/hooks/pre-commit"
  assert "core.hooksPath is not set" test -z "$(git -C "$repo" config --get core.hooksPath || true)"
  assert "violations that exist are recorded" test -f "$worktree/xaden/baselines/shellcheck.txt"
  assert "adopting twice is refused" bash -c 'cd "$1" && ! "$2" adopt --yes' _ "$worktree" "$XADEN"

  printf '%s\n' 'text added by the team' >>"$worktree/AGENTS.md"
  git -C "$worktree" -c core.hooksPath=/dev/null commit -q -n -am "docs: team text"
  x_in "$worktree" remove --yes
  assert "remove succeeds" test "$XRC" -eq 0
  assert "remove deletes the xaden folder" test ! -e "$worktree/xaden"
  assert "remove deletes the workflow and CLAUDE.md" test ! -e "$worktree/.github/workflows/xaden.yml" -a ! -e "$worktree/CLAUDE.md"
  assert "remove keeps the team's text in AGENTS.md" grep -q 'text added by the team' "$worktree/AGENTS.md"
  assert "remove takes the block out" bash -c '! grep -q xaden "$1"' _ "$worktree/AGENTS.md"
  assert "remove leaves nothing but the adoption's own paths in git status" test -z "$(git -C "$worktree" status --porcelain | grep -Ev ' (xaden/|AGENTS\.md|CLAUDE\.md|\.claude/commands/[a-z-]+\.md|\.github/workflows/xaden\.yml)' || true)"
  assert "remove unchains the git hooks" bash -c '! test -e "$1/.git/hooks/pre-commit"' _ "$repo"

  local no_ci="$WORKDIR/repos/no-ci" plain
  make_repo "$no_ci" shop
  x_in "$no_ci" adopt --yes --skip-ci
  assert "--skip-ci adds no workflow" test ! -e "$no_ci-adopt-xaden/.github/workflows/xaden.yml"
  assert "without Claude users there is no CLAUDE.md" test ! -e "$no_ci-adopt-xaden/CLAUDE.md"
  plain="$(git -C "$no_ci-adopt-xaden" diff --name-only main HEAD | grep -Ev '^(xaden/|AGENTS\.md$)' || true)"
  assert "the footprint without the workflow is xaden/ and AGENTS.md" test -z "$plain"

  local claude="$WORKDIR/repos/claude" 
  make_repo "$claude" shop
  printf '# Claude\n@AGENTS.md\n' >"$claude/CLAUDE.md"
  git -C "$claude" add -A && git -C "$claude" commit -q -m "docs: claude"
  x_in "$claude" adopt --yes --assistants claude --skip-ci
  assert "an existing CLAUDE.md that has the line stays as it is" cmp -s "$claude/CLAUDE.md" "$claude-adopt-xaden/CLAUDE.md"
  local claude2="$WORKDIR/repos/claude2"
  make_repo "$claude2" shop
  printf '# Claude\nown rules\n' >"$claude2/CLAUDE.md"
  git -C "$claude2" add -A && git -C "$claude2" commit -q -m "docs: claude"
  x_in "$claude2" adopt --yes --assistants claude --skip-ci
  assert "an existing CLAUDE.md gains the line" test "$(tail -n 1 "$claude2-adopt-xaden/CLAUDE.md")" = "@AGENTS.md"
  assert "an existing CLAUDE.md keeps its text" grep -q 'own rules' "$claude2-adopt-xaden/CLAUDE.md"

  local empty="$WORKDIR/repos/empty"
  make_repo "$empty" empty
  x_in "$empty" adopt --yes --skip-ci
  assert "an empty repository gets the same layout" test -f "$empty/xaden/xaden.conf" -a -f "$empty/xaden/RULES.md" -a -f "$empty/AGENTS.md"
  assert "an empty repository gets a commit on the adoption branch" test "$(git -C "$empty" branch --show-current)" = "chore/adopt-xaden"
}

# REQ-080 Claude Code users get one slash command for each default prompt, and nobody else does
test_claude_commands() {
  local repo="$WORKDIR/repos/commands" wt="$WORKDIR/repos/commands-adopt-xaden" name prompt file
  make_repo "$repo" shop
  mkdir -p "$repo/.claude/commands"
  printf 'my own feature command\n' >"$repo/.claude/commands/xaden-feature.md"
  git -C "$repo" add -A && git -C "$repo" commit -q -m "docs: own feature command"

  x_in "$repo" adopt --plan
  assert "the plan lists a command file" grep -Eq 'A[[:space:]]+\.claude/commands/xaden-bugfix\.md' "$XOUT"
  assert "the plan names the file it skips" grep -q 'skipped .claude/commands/xaden-feature.md' "$XOUT"
  assert "the plan writes nothing" test ! -e "$wt"

  x_in "$repo" adopt --yes --assistants claude
  assert "adopt succeeds" test "$XRC" -eq 0
  for name in kickoff feature bugfix refactor review security requirements docs persona release; do
    assert "command $name exists" test -f "$wt/.claude/commands/xaden-$name.md"
  done
  # feature is the team's own file here, so it has no command of Xaden's
  for prompt in "$SCAFFOLD_ROOT"/template/prompts/*.md; do
    name="$(basename "$prompt" .md)"
    [ "$name" = 00-index ] || [ "$name" = feature ] || assert "prompt $name is reachable by a command" grep -rlq "xaden prompt $name\`" "$wt/.claude/commands"
  done
  file="$wt/.claude/commands/xaden-review.md"
  assert "a command asks the assistant to run xaden prompt" grep -Fq 'Run `xaden prompt code-review` and follow it. Task input: $ARGUMENTS' "$file"
  assert "a command has a description" grep -q '^description: .' "$file"
  assert "a command never holds the prompt text" test "$(wc -l <"$file")" -le 6
  assert "an existing command file is not overwritten" test "$(cat "$wt/.claude/commands/xaden-feature.md")" = "my own feature command"
  assert "a skipped file is not in the footprint" bash -c '! grep -q "commands/xaden-feature.md" "$1"' _ "$wt/xaden/footprint.txt"
  assert "the footprint lists a created file" grep -qx 'file .claude/commands/xaden-bugfix.md' "$wt/xaden/footprint.txt"
  assert "adopt creates exactly the new command files" test "$(git -C "$wt" diff --name-only main HEAD | grep -c '^\.claude/commands/')" -eq 9

  x_in "$wt" remove --yes
  assert "remove deletes the files Xaden created" test ! -e "$wt/.claude/commands/xaden-bugfix.md" -a ! -e "$wt/.claude/commands/xaden-release.md"
  assert "remove keeps the team's own command" test "$(cat "$wt/.claude/commands/xaden-feature.md")" = "my own feature command"
  assert "remove leaves no stray file" test -z "$(git -C "$wt" status --porcelain | grep -Ev ' (xaden/|AGENTS\.md|CLAUDE\.md|\.claude/commands/[a-z-]+\.md|\.github/workflows/xaden\.yml)' || true)"

  local plain="$WORKDIR/repos/commands-plain"
  make_repo "$plain" shop
  x_in "$plain" adopt --yes --skip-ci
  assert "without Claude there are no command files" test ! -e "$plain-adopt-xaden/.claude"
}

# REQ-081 Copilot, Mistral Vibe and Codex CLI users get command files in their own layout
test_other_assistant_commands() {
  local repo="$WORKDIR/repos/others" wt="$WORKDIR/repos/others-adopt-xaden" name file
  make_repo "$repo" shop
  mkdir -p "$repo/.github/prompts"
  printf 'my own feature prompt\n' >"$repo/.github/prompts/xaden-feature.prompt.md"
  git -C "$repo" add -A && git -C "$repo" commit -q -m "docs: own feature prompt"

  x_in "$repo" adopt --plan --assistants copilot,vibe,codex
  assert "the plan lists a Copilot prompt file" grep -Eq 'A[[:space:]]+\.github/prompts/xaden-bugfix\.prompt\.md' "$XOUT"
  assert "the plan lists a skill" grep -Eq 'A[[:space:]]+\.agents/skills/xaden-bugfix/SKILL\.md' "$XOUT"
  assert "the plan names the file it skips" grep -q 'skipped .github/prompts/xaden-feature.prompt.md' "$XOUT"

  x_in "$repo" adopt --yes --assistants copilot,vibe,codex
  assert "adopt succeeds" test "$XRC" -eq 0
  for name in kickoff feature bugfix refactor review security requirements docs persona release; do
    assert "skill $name exists" test -f "$wt/.agents/skills/xaden-$name/SKILL.md"
    [ "$name" = feature ] || assert "Copilot prompt $name exists" test -f "$wt/.github/prompts/xaden-$name.prompt.md"
  done
  file="$wt/.github/prompts/xaden-review.prompt.md"
  assert "a Copilot prompt asks the assistant to run xaden prompt" grep -Fq 'Run `xaden prompt code-review` and follow it. Task input: ${input:task:describe the task}' "$file"
  assert "a Copilot prompt has a description" grep -q '^description: .' "$file"
  file="$wt/.agents/skills/xaden-review/SKILL.md"
  assert "a skill is named like its command" grep -qx 'name: xaden-review' "$file"
  assert "a skill asks the assistant to run xaden prompt" grep -Fq 'Run `xaden prompt code-review` and follow it.' "$file"
  assert "a skill is explicit-use only by its description" grep -q '^description: .*Use only when the user asks for it by name (xaden-review)' "$file"
  assert "no file holds the prompt text" test "$(cat "$wt"/.agents/skills/*/SKILL.md "$wt"/.github/prompts/*.prompt.md | wc -l)" -le 200
  assert "an existing Copilot prompt is not overwritten" test "$(cat "$wt/.github/prompts/xaden-feature.prompt.md")" = "my own feature prompt"
  assert "a skipped file is not in the footprint" bash -c '! grep -q "prompts/xaden-feature.prompt.md" "$1"' _ "$wt/xaden/footprint.txt"
  assert "the footprint lists a created skill once, although Vibe and Codex share it" test "$(grep -cx 'file .agents/skills/xaden-bugfix/SKILL.md' "$wt/xaden/footprint.txt")" -eq 1
  assert "adopt creates exactly the new Copilot prompts" test "$(git -C "$wt" diff --name-only main HEAD | grep -c '^\.github/prompts/')" -eq 9
  assert "adopt creates one skill for each prompt" test "$(git -C "$wt" diff --name-only main HEAD | grep -c '^\.agents/skills/')" -eq 10
  assert "without Claude there are no Claude files" test ! -e "$wt/CLAUDE.md" -a ! -e "$wt/.claude"

  x_in "$wt" remove --yes
  assert "remove deletes the Copilot prompts and skills Xaden created" test ! -e "$wt/.github/prompts/xaden-bugfix.prompt.md" -a ! -e "$wt/.agents"
  assert "remove keeps the team's own prompt" test "$(cat "$wt/.github/prompts/xaden-feature.prompt.md")" = "my own feature prompt"
  assert "remove leaves no stray file" test -z "$(git -C "$wt" status --porcelain | grep -Ev ' (xaden/|AGENTS\.md|\.github/prompts/[a-z-]+\.prompt\.md|\.agents/skills/[a-z-]+/SKILL\.md|\.github/workflows/xaden\.yml)' || true)"

  # a file or folder of the assistant's own is what makes adopt offer it; .agents/ names neither Vibe nor Codex
  local vibe="$WORKDIR/repos/detect-vibe" copilot="$WORKDIR/repos/detect-copilot" codex="$WORKDIR/repos/detect-codex"
  make_repo "$vibe" shop
  mkdir -p "$vibe/.vibe" && printf 'x = 1\n' >"$vibe/.vibe/config.toml"
  git -C "$vibe" add -A && git -C "$vibe" commit -q -m "chore: vibe"
  x_in "$vibe" adopt --yes --skip-ci
  assert "Vibe is detected and gets skills" test -f "$vibe-adopt-xaden/.agents/skills/xaden-feature/SKILL.md"
  assert "only the detected assistant gets files" test ! -e "$vibe-adopt-xaden/.github/prompts" -a ! -e "$vibe-adopt-xaden/.claude"
  make_repo "$copilot" shop
  printf 'Be kind.\n' >"$copilot/.github/copilot-instructions.md"
  git -C "$copilot" add -A && git -C "$copilot" commit -q -m "chore: copilot"
  x_in "$copilot" adopt --yes --skip-ci
  assert "Copilot is detected and gets prompt files" test -f "$copilot-adopt-xaden/.github/prompts/xaden-feature.prompt.md"
  assert "Copilot alone gets no skills" test ! -e "$copilot-adopt-xaden/.agents"
  make_repo "$codex" shop
  mkdir -p "$codex/.codex" && printf 'x = 1\n' >"$codex/.codex/config.toml"
  git -C "$codex" add -A && git -C "$codex" commit -q -m "chore: codex"
  x_in "$codex" adopt --yes --skip-ci
  assert "Codex is detected and gets skills" test -f "$codex-adopt-xaden/.agents/skills/xaden-feature/SKILL.md"
  assert "Codex alone gets no Copilot files" test ! -e "$codex-adopt-xaden/.github/prompts"
}

# REQ-069 existing hooks, CI and tools are chained, reused and never replaced
test_reuse_of_existing_tooling() {
  local repo="$WORKDIR/repos/hook-plain" husky="$WORKDIR/repos/hook-husky" worktree out
  make_repo "$repo" shop
  printf '#!/bin/sh\necho team hook\n' >"$repo/.git/hooks/pre-commit" && chmod +x "$repo/.git/hooks/pre-commit"
  x_in "$repo" adopt --yes --skip-ci
  assert "an existing plain git hook keeps its content" grep -q 'echo team hook' "$repo/.git/hooks/pre-commit"
  assert "Xaden is chained into the existing hook" grep -q 'xaden hook pre-commit' "$repo/.git/hooks/pre-commit"
  assert "a commit-msg hook is added" grep -q 'xaden hook commit-msg' "$repo/.git/hooks/commit-msg"

  make_repo "$husky" husky
  x_in "$husky" adopt --yes --skip-ci
  worktree="$husky-adopt-xaden"
  assert "husky: the existing hook keeps its command" grep -q 'npm run lint' "$worktree/.husky/pre-commit"
  assert "husky: Xaden is chained into the tracked hook" grep -q 'xaden hook pre-commit' "$worktree/.husky/pre-commit"
  assert "husky: core.hooksPath is not set over the manager" test -z "$(git -C "$husky" config --get core.hooksPath || true)"
  assert "husky: the hook step is its own commit" bash -c 'git -C "$1" log --format=%s main..HEAD | grep -q "husky hooks"' _ "$worktree"
  assert "husky: a mapped test and lint command are used" grep -q '^check.lint = npm run lint$' "$worktree/xaden/xaden.conf"

  local manager
  for manager in pre-commit lefthook; do
    make_repo "$WORKDIR/repos/$manager" $manager
    printf '#!/usr/bin/env bash\n# File generated by %s\necho %s ran\n' "$manager" "$manager" >"$WORKDIR/repos/$manager/.git/hooks/pre-commit" && chmod +x "$WORKDIR/repos/$manager/.git/hooks/pre-commit"
    x_in "$WORKDIR/repos/$manager" adopt --scan
    assert "$manager: the hook manager is recognised" grep -q "hook manager .*$manager" "$XOUT"
    x_in "$WORKDIR/repos/$manager" adopt --yes --skip-ci
    assert "$manager: adoption succeeds" test "$XRC" -eq 0
    assert "$manager: the generated hook keeps its content" grep -q "$manager ran" "$WORKDIR/repos/$manager/.git/hooks/pre-commit"
    assert "$manager: Xaden is chained into it" grep -q 'xaden hook pre-commit' "$WORKDIR/repos/$manager/.git/hooks/pre-commit"
    assert "$manager: no tracked file changes for the hook" test -z "$(git -C "$WORKDIR/repos/$manager-adopt-xaden" diff --name-only main HEAD | grep -E 'lefthook|pre-commit-config|husky' || true)"
    x_in "$WORKDIR/repos/$manager-adopt-xaden" setup
    assert "$manager: xaden setup is idempotent" test "$(grep -c 'xaden hook pre-commit' "$WORKDIR/repos/$manager/.git/hooks/pre-commit")" = "1"
  done

  make_repo "$WORKDIR/repos/overcommit" shop
  : >"$WORKDIR/repos/overcommit/.overcommit.yml"
  x_in "$WORKDIR/repos/overcommit" adopt --yes
  assert "an unsupported hook manager stops with a manual step" test "$XRC" -eq 4
  assert "the manual step is named" grep -q 'Manual step' "$XOUT"
  assert "nothing was created for the unsupported hook manager" test ! -e "$WORKDIR/repos/overcommit-adopt-xaden"
  make_repo "$WORKDIR/repos/gitlab" shop
  : >"$WORKDIR/repos/gitlab/.gitlab-ci.yml" && rm -rf "$WORKDIR/repos/gitlab/.github"
  x_in "$WORKDIR/repos/gitlab" adopt --yes
  assert "an unsupported CI system stops with a manual step" test "$XRC" -eq 4
  x_in "$WORKDIR/repos/gitlab" adopt --yes --skip-ci
  assert "--skip-ci adopts without the unsupported CI system" test "$XRC" -eq 0

  out="$WORKDIR/repos/hook-plain-adopt-xaden"
  x_in "$out" check
  assert "the mapped test command runs" grep -q '^==> check: test' "$XOUT"
  assert "the mapped lint command runs" grep -q '^==> check: lint' "$XOUT"
  assert "Xaden's own language presets stay unused" bash -c '! grep -q "python:\|node:" "$1"' _ "$XOUT"

  # gaps and presets
  local bare="$WORKDIR/repos/bare"
  make_repo "$bare" bare-python
  x_in "$bare" adopt --scan
  assert "the scan lists each gap" grep -q 'gaps .*test lint typecheck' "$XOUT"
  x_in "$bare" adopt --yes --skip-ci --mode strict
  assert "without the preset no configuration file is added" test ! -e "$bare-adopt-xaden/ruff.toml"
  x_in "$bare-adopt-xaden" check
  assert "strict: a gap is an error" test "$XRC" -ne 0
  assert "the gap is named" grep -q "gap: no 'lint' check is configured" "$XOUT"
  git -C "$bare" worktree remove --force "$bare-adopt-xaden" && git -C "$bare" branch -D chore/adopt-xaden >/dev/null
  x_in "$bare" adopt --yes --skip-ci --mode advisory
  x_in "$bare-adopt-xaden" check
  assert "advisory: a gap is a warning" grep -q "WARNING: gap: no 'lint' check" "$XOUT"
  git -C "$bare" worktree remove --force "$bare-adopt-xaden" && git -C "$bare" branch -D chore/adopt-xaden >/dev/null
  printf '[lint]\nselect = ["E"]\n' >"$bare/ruff.toml"
  git -C "$bare" add -A && git -C "$bare" commit -q -m "build: own ruff configuration"
  x_in "$bare" adopt --yes --skip-ci --preset
  worktree="$bare-adopt-xaden"
  assert "the preset is its own commit" bash -c 'git -C "$1" log --format=%s main..HEAD | grep -q "python preset"' _ "$worktree"
  assert "the preset writes its configuration at the root" test -f "$worktree/mypy.ini" -a -f "$worktree/requirements-dev.txt"
  assert "an existing partial configuration is never overwritten" grep -q 'select = \["E"\]' "$worktree/ruff.toml"
  assert "the difference is shown" grep -q 'ruff.toml exists and differs' "$XOUT"
  assert "the install command is printed, not run" grep -q 'pip install -r requirements-dev.txt' "$XOUT"
  assert "the preset maps its commands" grep -q '^check.typecheck = mypy \.$' "$worktree/xaden/xaden.conf"
  assert "the preset's commit has only preset files and the mapping" test -z "$(git -C "$worktree" show --name-only --format= HEAD | grep -Ev '^(mypy\.ini|requirements-dev\.txt|xaden/xaden\.conf|xaden/footprint\.txt)$' || true)"

  # REQ-090 the worktrees/ folder is its own question and its own commit
  local plain="$WORKDIR/repos/plain-worktrees"
  make_repo "$plain" bare-python
  x_in "$plain" adopt --yes --skip-ci
  assert "without the option no worktrees folder is added" test ! -e "$plain-adopt-xaden/worktrees"
  git -C "$plain" worktree remove --force "$plain-adopt-xaden" && git -C "$plain" branch -D chore/adopt-xaden >/dev/null
  x_in "$plain" adopt --yes --skip-ci --worktrees
  worktree="$plain-adopt-xaden"
  assert "the worktrees folder is its own commit" bash -c 'git -C "$1" log --format=%s main..HEAD | grep -q "worktrees/"' _ "$worktree"
  assert "the folder ignores its contents" bash -c 'mkdir -p "$1/worktrees/x" && : >"$1/worktrees/x/f" && git -C "$1" check-ignore -q worktrees/x/f' _ "$worktree"
  assert "the footprint lists the file" grep -qx 'file worktrees/.gitignore' "$worktree/xaden/footprint.txt"
  rm -rf "$worktree/worktrees/x"
  x_in "$worktree" remove --yes
  assert "remove takes the folder away again" test ! -e "$worktree/worktrees"
}

# fake_release <dir> <version>: a release folder with v<version>.tar.gz, built from this working tree.
fake_release() {
  local dir=$1 version=$2 tree="$1/build/xaden-$2"
  rm -rf "$dir" && mkdir -p "$tree"
  git -C "$SCAFFOLD_ROOT" ls-files -z | (cd "$SCAFFOLD_ROOT" && xargs -0 tar cf - 2>/dev/null) | tar xf - -C "$tree"
  # REQ-080 this version has a prompt more and a prompt less than the one under test
  rm -f "$tree/template/prompts/release.md"
  printf -- '---\ntitle: A new prompt\n---\n' >"$tree/template/prompts/newthing.md"
  printf '%s\n' "$version" >"$tree/VERSION"
  printf '## [%s] - 2099-01-01\n\n### Added\n- Something new in %s.\n\n' "$version" "$version" >"$WORKDIR/entry.md"
  { sed -n '1,/^## \[Unreleased\]/p' "$tree/CHANGELOG.md"; printf '\n'; cat "$WORKDIR/entry.md"; sed '1,/^## \[Unreleased\]/d' "$tree/CHANGELOG.md"; } >"$tree/CHANGELOG.md.new"
  mv "$tree/CHANGELOG.md.new" "$tree/CHANGELOG.md"
  tar czf "$dir/v$version.tar.gz" -C "$dir/build" "xaden-$version"
}

# REQ-071 REQ-072 pinned versions, upgrades and downloads only with a yes
test_versions_and_downloads() {
  local current repo worktree hint releases="$WORKDIR/releases" home="$WORKDIR/xaden-home" upgraded
  current="$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")" # not hardcoded: a release bumps it
  fake_release "$releases" 9.9.9
  export XADEN_RELEASES_URL="file://$releases" XADEN_HOME="$home"
  worktree="$(adopted_copy versions)"
  repo="${worktree%-adopt-xaden}"

  x_in "$worktree" doctor
  assert "doctor reports installed and pinned version" grep -q "installed $current, project pinned $current" "$XOUT"
  PATH="$(path_without curl)" x_in "$worktree" doctor
  assert "doctor works without curl, so it uses no network" grep -q "installed $current" "$XOUT"
  x_in "$worktree" upgrade --check
  assert "looking for newer releases needs a terminal and a yes" test "$XRC" -eq 3
  assert "nothing was looked up without a terminal" grep -q 'did not look for a newer release' "$XOUT"

  x_in "$worktree" pin --check
  assert "pin --check needs a terminal and a yes as well (REQ-099)" test "$XRC" -eq 3
  x_in "$worktree" upgrade 9.9.9
  assert "upgrade <version> in a project names xaden pin (REQ-099)" grep -q 'xaden pin 9.9.9' "$XOUT"
  hint="$(adopted_copy hint)"
  mkdir -p "$home/versions/0.0.1/scripts" && printf '#!/bin/sh\n' >"$home/versions/0.0.1/scripts/xaden.sh" && chmod +x "$home/versions/0.0.1/scripts/xaden.sh"
  edit_file "$hint/xaden/xaden.conf" 's/^version = .*/version = 0.0.1/'
  x_in "$hint" doctor
  assert "doctor names xaden pin when a newer Xaden is installed (REQ-099)" grep -q "xaden pin $current" "$XOUT"
  rm -rf "${home:?}"

  x_answers n "$worktree" upgrade 9.9.9
  assert "no answer but yes downloads nothing" test ! -e "$home/versions/9.9.9"
  assert "a no leaves no upgrade branch" test -z "$(git -C "$repo" branch --list 'chore/upgrade-xaden-*')"
  x_in "$worktree" upgrade 9.9.9
  assert "without a terminal nothing downloads, exit code 3" test "$XRC" -eq 3
  assert "without a terminal the exact command is named" grep -q 'xaden fetch 9.9.9' "$XOUT"
  assert "without a terminal nothing is installed" test ! -e "$home/versions"

  # REQ-107 a workflow from before the commit check lacks its step
  awk '/- name: Commit messages \(the hooks can be skipped/ { skip = 1 } !skip { print }' "$worktree/.github/workflows/xaden.yml" >"$WORKDIR/older-workflow.yml"
  cp "$WORKDIR/older-workflow.yml" "$worktree/.github/workflows/xaden.yml"
  git -C "$worktree" -c core.hooksPath=/dev/null commit -q -am "test: older workflow"
  x_answers y "$worktree" pin 9.9.9
  upgraded="$worktree-upgrade-xaden-9.9.9"
  assert "REQ-107 upgrade adds the commit check to an older workflow, once" test "$(grep -c 'xaden.sh verify-commits --ci' "$upgraded/.github/workflows/xaden.yml")" -eq 1
  assert "REQ-107 the branch the person is on keeps its workflow" bash -c '! grep -q verify-commits "$1"' _ "$worktree/.github/workflows/xaden.yml"
  assert "upgrade works on a branch for a pull request" test "$(git -C "$upgraded" branch --show-current)" = "chore/upgrade-xaden-9.9.9"
  assert "upgrade bumps the version" grep -q '^version = 9.9.9$' "$upgraded/xaden/xaden.conf"
  assert "upgrade bumps the checksum" test "$(grep '^checksum' "$upgraded/xaden/xaden.conf")" != "$(grep '^checksum' "$worktree/xaden/xaden.conf")"
  assert "upgrade regenerates RULES.md for the new version" grep -q 'Generated from Xaden 9.9.9' "$upgraded/xaden/RULES.md"
  assert "upgrade shows the changelog entries" grep -q 'Something new in 9.9.9' "$XOUT"
  assert "upgrade shows the diff" grep -q 'xaden/xaden.conf' "$XOUT"
  assert "upgrade adds a command for a new prompt (REQ-080)" grep -q 'xaden prompt newthing' "$upgraded/.claude/commands/xaden-newthing.md"
  assert "upgrade removes the command of a dropped prompt (REQ-080)" test ! -e "$upgraded/.claude/commands/xaden-release.md"
  assert "upgrade drops that file from the footprint (REQ-080)" bash -c '! grep -q "commands/xaden-release.md" "$1"' _ "$upgraded/xaden/footprint.txt"
  assert "upgrade adds a Copilot prompt file for a new prompt (REQ-081)" grep -q 'xaden prompt newthing' "$upgraded/.github/prompts/xaden-newthing.prompt.md"
  assert "upgrade adds a skill for a new prompt (REQ-081)" grep -q 'xaden prompt newthing' "$upgraded/.agents/skills/xaden-newthing/SKILL.md"
  assert "upgrade removes the Copilot file and the skill of a dropped prompt (REQ-081)" test ! -e "$upgraded/.github/prompts/xaden-release.prompt.md" -a ! -e "$upgraded/.agents/skills/xaden-release"
  assert "upgrade updates the pinned workflow" grep -q 'XADEN_VERSION: "9.9.9"' "$upgraded/.github/workflows/xaden.yml"
  assert "the project on the old branch is unchanged" grep -q "^version = $current\$" "$worktree/xaden/xaden.conf"
  assert "the downloaded version is installed once" test -x "$home/versions/9.9.9/scripts/xaden.sh"

  # a newer Xaden installed on one machine changes no repository file; the pinned one is used
  x_in "$worktree" doctor
  assert "an installed newer version changes nothing in the project" test -z "$(git -C "$worktree" status --porcelain)"

  # a pinned version that is missing
  rm -rf "$home"
  x_in "$upgraded" check
  assert "a missing pinned version without a terminal exits with 3" test "$XRC" -eq 3
  assert "the exact fetch command is printed" grep -q 'xaden fetch 9.9.9' "$XOUT"
  assert "the source and the checksum are shown" grep -q 'checksum:' "$XOUT"
  assert "nothing was installed" test ! -e "$home"
  x_answers n "$upgraded" check
  assert "the answer no downloads nothing" test ! -e "$home"
  x_answers "" "$upgraded" check
  assert "no answer is no" test ! -e "$home"
  x_answers y "$upgraded" check
  assert "a yes installs the pinned version after the checksum matched" test -x "$home/versions/9.9.9/scripts/xaden.sh"
  x_in "$upgraded" check
  assert "the yes is not remembered, the next run uses the installed copy without asking" test -x "$home/versions/9.9.9/scripts/xaden.sh"
  assert "the project check runs with the pinned version" grep -q 'check mode: full' "$XOUT"
  rm -rf "$home"
  edit_file "$upgraded/xaden/xaden.conf" 's/^checksum = .*/checksum = 0000000000000000000000000000000000000000000000000000000000000000/'
  x_answers y "$upgraded" fetch 9.9.9
  assert "a checksum mismatch exits non-zero" test "$XRC" -eq 5
  assert "a checksum mismatch installs nothing" test ! -e "$home/versions/9.9.9"
  assert "a checksum mismatch is a plain error without jokes" grep -q 'does not match the checksum' "$XOUT"

  # rules that do not match the pinned version fail the check and name the fix
  edit_file "$worktree/xaden/RULES.md" 's/Generated, do not edit/Edited by hand/'
  x_in "$worktree" check
  assert "RULES.md that does not match the pinned version fails" test "$XRC" -ne 0
  assert "the fix is named" grep -q 'run: xaden rules' "$XOUT"
  x_in "$worktree" rules
  x_in "$worktree" check
  assert "xaden rules repairs it" test "$XRC" -eq 0

  # an archive from the network that is not safe to extract
  if need_tool python3 "unsafe archive tests"; then
    local bad="$WORKDIR/bad-releases" worktree2
    mkdir -p "$bad"
    python3 - "$bad" <<'PY'
import io, sys, tarfile
out = sys.argv[1]
def archive(name, members):
    with tarfile.open(f"{out}/{name}", "w:gz") as tar:
        for member, data, kind in members:
            info = tarfile.TarInfo(member)
            if kind == "link":
                info.type = tarfile.SYMTYPE
                info.linkname = "/etc"
                tar.addfile(info)
            else:
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
archive("v8.8.8.tar.gz", [("xaden-8.8.8/VERSION", b"8.8.8\n", "file"), ("xaden-8.8.8/../evil", b"x", "file")])
archive("v8.8.7.tar.gz", [("xaden-8.8.7/VERSION", b"8.8.7\n", "file"), ("xaden-8.8.7/link", b"", "link")])
PY
    worktree2="$(adopted_copy unsafe)"
    for version in 8.8.8 8.8.7; do
      XADEN_RELEASES_URL="file://$bad" x_answers y "$worktree2" upgrade "$version"
      assert "an unsafe archive ($version) is refused" test "$XRC" -ne 0
      assert "an unsafe archive ($version) installs nothing" test ! -e "$home/versions/$version"
    done
    assert "an unsafe archive writes nothing outside its folder" test ! -e "$WORKDIR/evil"
  fi

  # REQ-077 signed releases: the pinned checksum comes from the maintainer, not from the download
  if need_tool ssh-keygen "signature tests"; then
    local sign="$WORKDIR/sign" assets="$WORKDIR/assets/v9.9.9" extracted signed_worktree
    mkdir -p "$sign" "$assets" "$sign/tree"
    ssh-keygen -q -t ed25519 -N '' -C test -f "$sign/key" && ssh-keygen -q -t ed25519 -N '' -C other -f "$sign/other"
    printf 'release@xaden.dev namespaces="xaden-release" %s\n' "$(cat "$sign/key.pub")" >"$sign/signers"
    tar xzf "$releases/v9.9.9.tar.gz" -C "$sign/tree" --strip-components=1
    extracted="$(tree_checksum "$sign/tree")"
    printf '%s  xaden-9.9.9\n' "$extracted" >"$assets/xaden-9.9.9.checksum"
    ssh-keygen -q -Y sign -f "$sign/key" -n xaden-release "$assets/xaden-9.9.9.checksum"
    export XADEN_ASSETS_URL="file://$WORKDIR/assets" XADEN_SIGNERS_FILE="$sign/signers"
    signed_worktree="$(adopted_copy signed)"

    rm -rf "$home"
    x_answers y "$signed_worktree" upgrade 9.9.9
    assert "a signed release upgrades" test "$XRC" -eq 0
    assert "the signature is reported as verified" grep -q 'signature verified' "$XOUT"
    assert "the pinned checksum is the signed one" grep -q "^checksum = $extracted\$" "$signed_worktree-upgrade-xaden-9.9.9/xaden/xaden.conf"

    rm -rf "$home" "$signed_worktree-upgrade-xaden-9.9.9" && git -C "${signed_worktree%-adopt-xaden}" worktree prune && git -C "${signed_worktree%-adopt-xaden}" branch -D chore/upgrade-xaden-9.9.9 >/dev/null
    printf '%s  xaden-9.9.9\n' "0000000000000000000000000000000000000000000000000000000000000000" >"$assets/xaden-9.9.9.checksum.tampered"
    cp "$assets/xaden-9.9.9.checksum" "$assets/original.checksum" && cp "$assets/xaden-9.9.9.checksum.tampered" "$assets/xaden-9.9.9.checksum"
    x_answers y "$signed_worktree" upgrade 9.9.9
    assert "a changed checksum file fails with exit code 6" test "$XRC" -eq 6
    assert "nothing is installed after a bad signature" test ! -e "$home/versions/9.9.9"

    cp "$assets/original.checksum" "$assets/xaden-9.9.9.checksum" && rm -f "$assets/xaden-9.9.9.checksum.sig"
    ssh-keygen -q -Y sign -f "$sign/other" -n xaden-release "$assets/xaden-9.9.9.checksum"
    x_answers y "$signed_worktree" upgrade 9.9.9
    assert "a signature by an unknown key fails with exit code 6" test "$XRC" -eq 6

    rm -rf "${assets:?}"/* "$home"
    x_answers y "$signed_worktree" upgrade 9.9.9
    assert "a release without a signature is installed with a warning" test "$XRC" -eq 0
    assert "the warning names trust on first use" grep -q 'trust on first use' "$XOUT"
    # REQ-103 require-signature = true: only releases the maintainer signed, on every path
    local policy_worktree policy_pinned
    policy_worktree="$(adopted_copy policy)"
    printf 'require-signature = true\n' >>"$policy_worktree/xaden/xaden.conf"
    git -C "$policy_worktree" add -A && git -C "$policy_worktree" -c core.hooksPath=/dev/null commit -q -n -m "chore: require signed releases"
    policy_pinned="$policy_worktree-upgrade-xaden-9.9.9"
    rm -rf "$home"
    x_answers y "$policy_worktree" upgrade 9.9.9
    assert "policy: a release without a published signature is refused with exit code 6" test "$XRC" -eq 6
    assert "policy: the refusal names the setting" grep -q 'require-signature = true' "$XOUT"
    assert "policy: nothing is installed without a signature" test ! -e "$home/versions/9.9.9"
    printf '%s  xaden-9.9.9\n' "$extracted" >"$assets/xaden-9.9.9.checksum"
    ssh-keygen -q -Y sign -f "$sign/other" -n xaden-release "$assets/xaden-9.9.9.checksum"
    x_answers y "$policy_worktree" upgrade 9.9.9
    assert "policy: a signature by an unknown key still fails with exit code 6" test "$XRC" -eq 6
    rm -f "$assets/xaden-9.9.9.checksum.sig" && ssh-keygen -q -Y sign -f "$sign/key" -n xaden-release "$assets/xaden-9.9.9.checksum"
    x_answers y "$policy_worktree" upgrade 9.9.9
    assert "policy: the first download with a valid signature is installed" test "$XRC" -eq 0
    assert "policy: the signed checksum is what gets pinned" grep -q "^checksum = $extracted\$" "$policy_pinned/xaden/xaden.conf"
    assert "policy: the signed checksum is recorded outside the installed folder" test "$(tr -d '[:space:]' <"$home/versions/9.9.9.signed")" = "$extracted"
    x_in "$policy_pinned" check
    assert "policy: the authenticated copy runs for the project" grep -q 'check mode: full' "$XOUT"
    rm -f "$home/versions/9.9.9.signed"
    x_in "$policy_pinned" check
    assert "policy: a copy with no signature on record is not run" test "$XRC" -ne 0
    assert "policy: the message names the fix" grep -q 'xaden fetch 9.9.9' "$XOUT"
    x_answers y "$policy_pinned" fetch 9.9.9
    assert "policy: fetch re-verifies the installed copy against the signed checksum" test "$XRC" -eq 0
    assert "policy: and records the result" test -f "$home/versions/9.9.9.signed"
    git init -q "$home/versions/9.9.9"
    x_in "$policy_pinned" check
    assert "policy: a git checkout is never accepted" test "$XRC" -ne 0
    rm -rf "$home/versions/9.9.9/.git"
    x_in "$policy_pinned" check
    assert "policy: the same files without .git run again" test "$XRC" -eq 0
    printf 'changed\n' >>"$home/versions/9.9.9/README.md"
    x_in "$policy_pinned" check
    assert "policy: files that no longer match the signed checksum are not run" test "$XRC" -ne 0
    x_answers y "$policy_pinned" fetch 9.9.9
    assert "policy: fetch does not bless a changed copy" test "$XRC" -eq 6
    rm -rf "$home"
    x_answers n "$policy_worktree" upgrade 9.9.9
    assert "policy: the download still needs a yes" test ! -e "$home/versions/9.9.9"
    edit_file "$policy_pinned/xaden/xaden.conf" 's/^require-signature = true/require-signature = yes/'
    for command in check doctor "fetch 9.9.9"; do
      # shellcheck disable=SC2086 # "fetch 9.9.9" is two words on purpose
      x_in "$policy_pinned" $command
      assert "policy: an invalid value stops '$command'" grep -q 'require-signature must be true or false (got: yes)' "$XOUT"
    done
    edit_file "$policy_pinned/xaden/xaden.conf" 's/^require-signature = .*/require-signature =/'
    x_in "$policy_pinned" check
    assert "policy: an empty value is refused, not read as false" grep -q 'require-signature must be true or false (got: )' "$XOUT"
    assert "policy: CI installs only the pinned checksum" grep -q 'XADEN_CHECKSUM' "$SCAFFOLD_ROOT/scripts/adopt/ci.yml"
    unset XADEN_ASSETS_URL XADEN_SIGNERS_FILE
  fi

  assert "only fetch.sh and the installer get-xaden.sh reach the network" bash -c \
    '! grep -rnE "^[^#]*(curl|wget)[[:space:]]|^[^#]*git (clone|fetch|pull|ls-remote)" "$1/scripts" "$1/template/scripts" --include="*.sh" | grep -v -e "scripts/fetch.sh:" -e "scripts/get-xaden.sh:" | grep .' _ "$SCAFFOLD_ROOT"
  unset XADEN_RELEASES_URL XADEN_HOME
}

# REQ-097 xaden upgrade updates Xaden itself
test_self_upgrade() {
  local releases="$WORKDIR/self-releases" home="$WORKDIR/self-home" source="$WORKDIR/self-source" bin="$WORKDIR/self-bin" current
  current="$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")"
  fake_release "$releases" 9.9.9
  export XADEN_RELEASES_URL="file://$releases" XADEN_HOME="$home"
  mkdir -p "$source" && git -C "$SCAFFOLD_ROOT" archive "$(git -C "$SCAFFOLD_ROOT" write-tree)" | tar -x -C "$source"
  "$source/scripts/install.sh" "$bin" >/dev/null
  rm -rf "$source"
  run_installed() { XRC=0; (cd "$WORKDIR" && "$bin/xaden" "$@") >"$XOUT" 2>&1 || XRC=$?; }

  run_installed upgrade 9.9.9
  assert "without a terminal nothing downloads, exit code 3" test "$XRC" -eq 3
  assert "without a terminal current stays" test "$(readlink "$home/current")" = "versions/$current"
  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=n run_installed upgrade 9.9.9
  assert "a no downloads nothing" test ! -e "$home/versions/9.9.9"
  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=y run_installed upgrade 7.7.7
  assert "a failed download fails" test "$XRC" -ne 0
  assert "a failed download leaves current on the old version" test "$(readlink "$home/current")" = "versions/$current"
  assert "a failed download leaves no folder behind" test ! -e "$home/versions/7.7.7"

  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=y run_installed upgrade 9.9.9
  assert "upgrade succeeds" test "$XRC" -eq 0
  assert "current points to the new version" test "$(readlink "$home/current")" = "versions/9.9.9"
  assert "the same command now runs the new version" test "$("$bin/xaden" version)" = "9.9.9"
  assert "the old version stays installed" test -x "$home/versions/$current/scripts/xaden.sh"
  assert "the changelog entries are shown" grep -q 'Something new in 9.9.9' "$XOUT"
  assert "the command link did not change" test "$(readlink "$bin/xaden")" = "$home/current/scripts/xaden.sh"
  run_installed upgrade 9.9.9
  assert "upgrading to the installed version says so" grep -q 'installed already' "$XOUT"

  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=y x_in "$WORKDIR" upgrade 9.9.9
  assert "a git clone is not upgraded, it is pulled" grep -q 'git -C .* pull' "$XOUT"
  assert "a git clone changed nothing" test "$(readlink "$home/current")" = "versions/9.9.9"
  unset XADEN_RELEASES_URL XADEN_HOME
}

# REQ-068 modes and baselines
test_modes_and_baselines() {
  need_tool shellcheck "mode and baseline tests" || return 0
  local worktree="$WORKDIR/repos/modes-adopt-xaden" repo="$WORKDIR/repos/modes" baseline
  make_repo "$repo" shop
  x_in "$repo" adopt --yes --skip-ci
  baseline="$worktree/xaden/baselines/shellcheck.txt"
  assert "existing violations are recorded" test -s "$baseline"
  x_in "$worktree" check
  assert "recorded violations do not fail the checks" test "$XRC" -eq 0

  printf 'echo $2\n' >>"$worktree/scripts/build.sh"
  git -C "$worktree" add -A && git -C "$worktree" -c core.hooksPath=/dev/null commit -q -n -m "fix: add a violation"
  x_in "$worktree" check
  assert "changed-files: a new violation in a changed file fails" test "$XRC" -ne 0
  assert "the violation is named" grep -q 'build.sh: note: Double quote' "$XOUT"
  edit_file "$worktree/xaden/xaden.conf" 's/^mode = .*/mode = advisory/'
  x_in "$worktree" check
  assert "advisory: the same violation only warns" test "$XRC" -eq 0
  assert "advisory says it is not blocking" grep -q 'advisory mode: not blocking' "$XOUT"
  edit_file "$worktree/xaden/xaden.conf" 's/^mode = .*/mode = strict/'
  x_in "$worktree" check
  assert "strict: it fails" test "$XRC" -ne 0

  # a violation in a file the change does not touch
  git -C "$worktree" reset -q --hard HEAD~1
  edit_file "$worktree/xaden/xaden.conf" 's/^mode = .*/mode = changed-files/'
  : >"$baseline"
  x_in "$worktree" check
  assert "changed-files: a violation in an untouched file does not fail" test "$XRC" -eq 0
  edit_file "$worktree/xaden/xaden.conf" 's/^mode = .*/mode = strict/'
  x_in "$worktree" check
  assert "strict: a violation in any file fails" test "$XRC" -ne 0
  git -C "$worktree" checkout -q -- xaden/baselines

  # the baseline shrinks when a violation is fixed, and never grows
  printf '#!/bin/sh\necho "$1"\n' >"$worktree/scripts/build.sh"
  (cd "$worktree" && env -u CI "$XADEN" check) >"$XOUT" 2>&1 || true
  assert "a fixed violation leaves the baseline" test ! -s "$baseline"
  assert "the baseline says it shrank" grep -q 'shrank by 1' "$XOUT"
  printf 'echo $3\n' >>"$worktree/scripts/build.sh"
  (cd "$worktree" && env -u CI "$XADEN" check) >"$XOUT" 2>&1 || true
  assert "the baseline never grows" test ! -s "$baseline"
  git -C "$worktree" checkout -q -- scripts/build.sh

  # another commit convention: references only advise
  printf 'wip stuff\n' >"$WORKDIR/message.txt"
  x_in "$worktree" hook commit-msg "$WORKDIR/message.txt"
  assert "another convention: the commit message hook passes" test "$XRC" -eq 0
  edit_file "$worktree/xaden/xaden.conf" 's/^commit-convention = .*/commit-convention = conventional/'
  x_in "$worktree" hook commit-msg "$WORKDIR/message.txt"
  assert "Conventional Commits: the hook rejects a bad message" test "$XRC" -ne 0
  assert "the rule file makes a mode change an approval point (REQ-044)" bash -c 'tr "\n" " " <"$1" | grep -q "mode. in .xaden/xaden.conf.*is an .*Approval point"' _ "$SCAFFOLD_ROOT/template/AGENTS.md"

  # a real commit goes through the chained hook
  git -C "$worktree" checkout -q -- xaden/xaden.conf
  printf 'echo $4\n' >>"$worktree/scripts/build.sh"
  git -C "$worktree" add scripts/build.sh
  assert_fails "the pre-commit hook blocks a new violation in a changed file" git -C "$worktree" commit -q -m "fix: bad script"
  git -C "$worktree" checkout -q HEAD -- scripts/build.sh
  printf '# note\n' >>"$worktree/README.md"
  git -C "$worktree" add README.md
  assert "the pre-commit hook lets a clean commit through" git -C "$worktree" commit -q -m "docs: note"
}

# REQ-070 prompts, REQ-075 ignore list
test_prompts_and_ignore_list() {
  local worktree
  worktree="$(adopted_copy prompts)"
  x_in "$worktree" prompt kickoff
  assert "a default prompt is printed for the adopted layout" grep -q 'xaden req' "$XOUT"
  assert "the printed prompt names no path of the copied layout" bash -c '! grep -nE "scripts/(req|check|persona)\.sh|docs/requirements" "$1"' _ "$XOUT"
  mkdir -p "$worktree/xaden/prompts" && printf 'The team kickoff.\n' >"$worktree/xaden/prompts/kickoff.md"
  x_in "$worktree" prompt kickoff
  assert "a team prompt of the same name overrides the default" grep -q 'The team kickoff' "$XOUT"
  x_in "$worktree" prompt no-such-prompt
  assert "an unknown prompt is an error" test "$XRC" -ne 0

  local before
  before="$(git -C "$worktree" status --porcelain)"
  x_in "$worktree" ignore-list
  assert "the ignore list names the Xaden paths" test "$(cat "$XOUT")" = "$(printf 'xaden/\nAGENTS.md\nCLAUDE.md')"
  assert "the ignore list changes no file" test "$(git -C "$worktree" status --porcelain)" = "$before"
  rm "$worktree/CLAUDE.md"
  x_in "$worktree" ignore-list
  assert "CLAUDE.md is listed only when present" test "$(cat "$XOUT")" = "$(printf 'xaden/\nAGENTS.md')"
}

# REQ-076 autopilot
test_autopilot() {
  local base="$WORKDIR/autopilot" project
  rm -rf "$base" && mkdir -p "$base"
  x_in "$base" create --autopilot --stack python demo
  assert "without a terminal autopilot prints the plan and changes nothing" test ! -e "$base/demo"
  assert "the plan names the install commands" grep -q 'pip install -r requirements-dev.txt' "$XOUT"
  x_answers n "$base" create --autopilot --stack python demo
  assert "anything but yes changes nothing" test ! -e "$base/demo"

  mkdir -p "$base/existing" && printf 'print(1)\n' >"$base/existing/app.py"
  x_answers y "$base" create --autopilot --stack python existing
  assert "a folder with code stops and points to adopt" test "$XRC" -eq 2
  assert "it points to xaden adopt" grep -q 'xaden adopt' "$XOUT"
  assert "it changes nothing" test "$(ls -A "$base/existing")" = "app.py"

  PATH="$(path_without curl)" x_answers y "$base" create --autopilot --stack python demo
  project="$base/demo"
  assert "autopilot succeeds without curl, so it downloads nothing" test "$XRC" -eq 0
  assert "the project is a git repository with the first commit on main" test "$(git -C "$project" branch --show-current)" = "main"
  assert "the layout is the xaden folder" test -f "$project/xaden/xaden.conf" -a -f "$project/xaden/RULES.md" -a -f "$project/AGENTS.md"
  assert "the mode is strict" grep -q '^mode = strict$' "$project/xaden/xaden.conf"
  assert "the stack's preset is written" test -f "$project/ruff.toml" -a -f "$project/mypy.ini"
  assert "a CI workflow is added" test -f "$project/.github/workflows/xaden.yml"
  assert "hooks are active" grep -q 'xaden hook pre-commit' "$project/.git/hooks/pre-commit"
  assert "the install commands are printed" grep -q 'pip install -r requirements-dev.txt' "$XOUT"
  assert "nothing is pushed: no remote" test -z "$(git -C "$project" remote)"
  assert "skipped checks end with a warning, never a success sign" bash -c 'tail -n 3 "$1" | grep -q "^WARNING:" && ! grep -q "^OK: all checks passed" "$1"' _ "$XOUT"

  x_answers y "$base" create --autopilot --stack node webapp
  assert "the node stack prints exact package versions" grep -q 'npm install --save-dev --save-exact eslint@10.12.0' "$XOUT"
  x_answers y "$base" create --autopilot --stack python demo
  assert "an existing project is not touched again" test "$XRC" -eq 2
}

# REQ-071 a project with a copy of the tooling moves to the pinned layout with `xaden adopt`
test_migration() {
  local repo="$WORKDIR/repos/classic" worktree
  rm -rf "$repo"
  env ALLOW_MAIN_COMMIT=0 "$SCAFFOLD_ROOT/scripts/new-project.sh" classic-app "$repo" >/dev/null 2>&1
  printf '\nOur own twist.\n' >>"$repo/prompts/feature.md"
  git -C "$repo" commit -q -n -am "docs: our feature prompt"
  x_in "$repo" adopt --yes --skip-ci
  worktree="$repo-adopt-xaden"
  assert "migration succeeds" test "$XRC" -eq 0
  assert "requirements move into xaden/" test -f "$worktree/xaden/requirements/INDEX.md" -a -d "$worktree/xaden/requirements/first-epic"
  assert "the copied tooling is removed" test ! -e "$worktree/scripts/check.sh" -a ! -e "$worktree/prompts/bugfix.md" -a ! -e "$worktree/.scaffold"
  assert "a prompt the team edited stays" grep -q 'Our own twist' "$worktree/prompts/feature.md"
  assert "the edited file is listed" grep -q 'prompts/feature.md' "$XOUT"
  assert "the project's own README and guides stay" test -f "$worktree/README.md" -a -f "$worktree/docs/user-guide.md"
  assert "AGENTS.md is now the short block" bash -c '[ "$(wc -l <"$1")" -lt 12 ] && grep -q "xaden/RULES.md" "$1"' _ "$worktree/AGENTS.md"
  assert "the copied hooks path is gone and Xaden is chained" bash -c 'test -z "$(git -C "$1" config --get core.hooksPath || true)" && grep -q "xaden hook pre-commit" "$1/.git/hooks/pre-commit"' _ "$repo"
  x_in "$worktree" check
  assert "the migrated project passes the checks" test "$XRC" -eq 0
}

# REQ-066 `xaden create` creates the same layout `xaden adopt` gives an empty repository
test_new_project_layout() {
  local base="$WORKDIR/new-layout" project
  rm -rf "$base" && mkdir -p "$base"
  x_in "$base" create demo
  project="$base/demo"
  assert "xaden create succeeds" test "$XRC" -eq 0
  assert "the layout is the xaden folder, as adopt writes it" test -f "$project/xaden/xaden.conf" -a -f "$project/xaden/RULES.md" -a -f "$project/AGENTS.md" -a -d "$project/xaden/baselines"
  assert "the project's own files exist" test -f "$project/README.md" -a -f "$project/.gitignore" -a -f "$project/VERSION" -a -f "$project/CHANGELOG.md" -a -f "$project/SECURITY.md" -a -f "$project/xaden/threat-model.md"
  assert "no copy of the tooling" test ! -e "$project/scripts" -a ! -e "$project/prompts" -a ! -e "$project/.scaffold"
  assert "mode strict, workflow and first commit on main" bash -c 'grep -q "^mode = strict$" "$1/xaden/xaden.conf" && test -f "$1/.github/workflows/xaden.yml" && test "$(git -C "$1" branch --show-current)" = main' _ "$project"
  assert "hooks are chained" grep -q 'xaden hook pre-commit' "$project/.git/hooks/pre-commit"
  assert "without Claude users there is no CLAUDE.md" test ! -e "$project/CLAUDE.md"
  assert "the tree is clean after creation" test -z "$(git -C "$project" status --porcelain)"
  x_in "$project" check
  assert "a new project passes its checks" test "$XRC" -eq 0
  x_in "$project" req new core job "First job"
  assert "requirements are created in xaden/requirements" test -f "$project/xaden/requirements/core/REQ-001-first-job.md"
  git -C "$project" checkout -q -- . && git -C "$project" clean -qfd

  x_in "$base" create demo
  assert "an existing project is not created again" test "$XRC" -eq 2
  x_in "$base" create --assistants claude with-claude
  assert "--assistants claude adds CLAUDE.md with one line" test "$(cat "$base/with-claude/CLAUDE.md")" = "@AGENTS.md"
  x_in "$base" create "Bad Name"
  assert "a bad project name is refused" test "$XRC" -ne 0
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.useConfigOnly GIT_CONFIG_VALUE_0=true x_in "$base" env -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL "$XADEN" create fails
  assert "a failed creation fails" test "$XRC" -ne 0
  assert "a failed creation leaves no partial folder" test ! -e "$base/fails"
  x_in "$base" create --classic classic
  assert "--classic keeps the copied layout" test -f "$base/classic/scripts/check.sh" -a ! -e "$base/classic/xaden"

  # a stack that appears later is noticed, and the preset can be added
  printf '{ "name": "demo" }\n' >"$project/package.json"
  x_in "$project" check
  assert "strict: a stack without checks is an error" test "$XRC" -ne 0
  assert "the gap is named" grep -q "gap: no 'test' check is configured" "$XOUT"
  x_in "$project" preset node
  assert "xaden preset adds the preset's configuration" test -f "$project/eslint.config.mjs"
  assert "xaden preset maps the checks" grep -q '^check.lint = npx eslint \.$' "$project/xaden/xaden.conf"
  assert "xaden preset prints the install command" grep -q 'npm install --save-dev --save-exact eslint@' "$XOUT"

  # release works without guides
  if need_tool gitleaks "release in an adopted project"; then
    local rel="$base/rel"
    x_in "$base" create rel
    x_in "$rel" release minor
    assert "a release is blocked while the security documents have TODO markers" test "$XRC" -ne 0
    assert "the unfilled documents are named" grep -q 'unfilled TODO marker' "$XOUT"
    sed -i.bak 's/<!-- TODO/<!-- done/' "$rel/SECURITY.md" "$rel/xaden/threat-model.md" && rm -f "$rel/SECURITY.md.bak" "$rel/xaden/threat-model.md.bak"
    git -C "$rel" add -A && git -C "$rel" -c core.hooksPath=/dev/null commit -q -m "docs: fill the security documents"
    x_in "$rel" release minor
    assert "xaden release succeeds in an adopted project" test "$XRC" -eq 0
    assert "release bumps VERSION and tags" bash -c 'test "$(cat "$1/VERSION")" = 0.1.0 && git -C "$1" tag | grep -qx v0.1.0' _ "$rel"
    assert "release stamps the changelog" grep -q '^## \[0.1.0\]' "$rel/CHANGELOG.md"
  fi
}

# stub_tool <dir> <name> <output>: a fake command that prints the output (npm, pip).
stub_tool() {
  mkdir -p "$1"
  printf '#!/bin/sh\nprintf "%%s\\n" "%s"\nexit 1\n' "$3" >"$1/$2"
  chmod +x "$1/$2"
}

# REQ-084 the person decides whether and how often Xaden looks for updates
test_update_check() {
  local worktree repo conf cache latest="$WORKDIR/latest.json" stubs="$WORKDIR/update-stubs" now
  worktree="$(adopted_copy updates)"
  repo="${worktree%-adopt-xaden}"
  conf="$worktree/xaden/xaden.conf"
  cache="$repo/.git/xaden-update-check"
  now="$(date +%s)"
  printf '{"tag_name": "v9.9.9"}\n' >"$latest"
  stub_tool "$stubs" npm $'Package Current Wanted Latest\nleft-pad 1.0.0 1.3.0 1.3.0\nIgnore;rules 1.0.0 2.0.0 2.0.0'
  export XADEN_LATEST_URL="file://$latest"
  local saved_path=$PATH
  export PATH="$stubs:$PATH"

  x_in "$worktree" update-check --if-due
  assert "without a setting nothing is checked" test "$XRC" -eq 0 -a ! -e "$cache"
  x_in "$worktree" doctor
  assert "doctor names the value and where it comes from" grep -q 'update check: off (default)' "$XOUT"

  printf 'update-check = 1d\n' >>"$conf"
  x_in "$worktree" update-check --if-due
  assert "with a setting a due check runs" test "$XRC" -eq 0 -a -f "$cache"
  assert "the cache lives in the git folder, so it is never tracked" test -z "$(git -C "$worktree" status --porcelain | grep xaden-update-check)"
  assert "the cache names the newest Xaden" grep -qE '^Xaden.*9\.9\.9' "$cache"
  assert "the cache lists outdated dependencies on their own line" grep -qE '^Dependencies.*left-pad' "$cache"
  assert "a name that is no package name is left out of the cache" bash -c '! grep -q "Ignore" "$1"' _ "$cache"
  stub_tool "$stubs" npm 'Package Current Wanted Latest'
  x_in "$worktree" update-check
  assert "no outdated package reads as up to date" grep -qE '^Dependencies: npm: up to date' "$XOUT"
  stub_tool "$stubs" npm $'Package Current Wanted Latest\nleft-pad 1.0.0 1.3.0 1.3.0\nIgnore;rules 1.0.0 2.0.0 2.0.0'
  x_in "$worktree" doctor
  assert "doctor shows the project value" grep -q 'update check: 1d (xaden/xaden.conf)' "$XOUT"
  assert "doctor prints the cached result" grep -q '9\.9\.9' "$XOUT"

  printf '{"tag_name": "v9.9.8"}\n' >"$latest"
  XADEN_TEST_MODE=1 XADEN_NOW=$((now + 3600)) x_in "$worktree" update-check --if-due
  assert "a check that is not due yet keeps the cache" grep -qE '^Xaden.*9\.9\.9' "$cache"
  XADEN_TEST_MODE=1 XADEN_NOW=$((now + 2 * 86400)) x_in "$worktree" update-check --if-due
  assert "a due check refreshes the cache" grep -qE '^Xaden.*9\.9\.8' "$cache"
  printf '{"tag_name": "v9.9.7"}\n' >"$latest"
  x_in "$worktree" update-check
  assert "update-check by hand ignores the interval" grep -qE '^Xaden.*9\.9\.7' "$cache"

  cp "$cache" "$WORKDIR/cache.before"
  XADEN_LATEST_URL="file://$WORKDIR/does-not-exist" XADEN_TEST_MODE=1 XADEN_NOW=$((now + 9 * 86400)) x_in "$worktree" update-check --if-due
  assert "no network: the check is silent and exits 0" test "$XRC" -eq 0 -a ! -s "$XOUT"
  assert "no network: the old cache stays" cmp -s "$cache" "$WORKDIR/cache.before"

  local value
  for value in 30m 0h abc 1.5d 1w; do
    conf_set "$conf" update-check "$value"
    rm -f "$cache"
    x_in "$worktree" update-check
    assert "the value '$value' is refused" test "$XRC" -ne 0
    assert "the refusal names the allowed forms" grep -q "off, or a number with h or d" "$XOUT"
    assert "nothing is checked for '$value'" test ! -e "$cache"
  done

  conf_set "$conf" update-check off
  x_in "$worktree" update-check
  assert "by hand with the value off refuses" test "$XRC" -ne 0 -a ! -e "$cache"
  x_in "$worktree" update-check --now
  assert "--now checks although the value is off" test "$XRC" -eq 0 -a -f "$cache"
  rm -f "$cache"
  XADEN_UPDATE_CHECK=12h x_in "$worktree" update-check --if-due
  assert "the environment variable overrides the project value for one person" test -f "$cache"
  XADEN_UPDATE_CHECK=12h x_in "$worktree" doctor
  assert "doctor names the environment as the source" grep -q 'update check: 12h (XADEN_UPDATE_CHECK)' "$XOUT"
  assert "the override leaves the project file alone" grep -q '^update-check = off$' "$conf"
  XADEN_UPDATE_CHECK=often x_in "$worktree" update-check --if-due
  assert "a bad environment value is refused too" test "$XRC" -ne 0

  # offline readers never touch the network
  conf_set "$conf" update-check 1d
  rm -f "$cache"
  x_in "$worktree" update-check --now >/dev/null
  PATH="$(path_without curl)" x_in "$worktree" doctor
  assert "doctor prints the cache without curl" grep -q '9\.9\.7' "$XOUT"
  assert "context-status prints the cached result" bash -c 'PROJECT_ROOT="$1" "$2/template/scripts/context-status.sh" | grep -q "9\.9\.7"' _ "$worktree" "$SCAFFOLD_ROOT"
  rm -f "$cache"
  git -C "$worktree" commit -q --allow-empty -m "chore: hooks stay offline"
  assert "the commit hooks started no check" test ! -e "$cache"
  PATH="$(path_without curl)" XADEN_LATEST_URL="file://$latest" x_in "$worktree" doctor
  assert "doctor started no check" test ! -e "$cache"

  # the update is reported, never applied; user-owned files stay
  local releases="$WORKDIR/update-releases" base_commit
  fake_release "$releases" 9.9.9
  export XADEN_RELEASES_URL="file://$releases" XADEN_HOME="$WORKDIR/update-home"
  printf '{}\n' >"$worktree/package-lock.json"
  printf 'pytest\n' >"$worktree/requirements-dev.txt"
  git -C "$worktree" add -A && git -C "$worktree" -c core.hooksPath=/dev/null commit -q -m "chore: lockfiles"
  base_commit="$(git -C "$worktree" rev-parse HEAD)"
  x_answers y "$worktree" upgrade 9.9.9
  assert "upgrade succeeds" test "$XRC" -eq 0
  assert "upgrade leaves package.json, lockfile and requirements-dev.txt alone" bash -c \
    '! git -C "$1" diff --name-only "$2" "chore/upgrade-xaden-9.9.9" | grep -E "^(package(-lock)?\.json|requirements-dev\.txt)$"' _ "$worktree" "$base_commit"
  unset XADEN_RELEASES_URL XADEN_HOME

  # create and adopt ask once, off is the default answer
  local asked="$WORKDIR/repos/asked"
  make_repo "$asked" shop
  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=7d x_in "$asked" adopt --yes --skip-ci
  assert "adopt asks for the interval and records the answer" grep -q '^update-check = 7d$' "$asked-adopt-xaden/xaden/xaden.conf"
  make_repo "$asked" shop
  rm -rf "$asked-adopt-xaden"
  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER='' x_in "$asked" adopt --yes --skip-ci
  assert "an empty answer records off" grep -q '^update-check = off$' "$asked-adopt-xaden/xaden/xaden.conf"
  make_repo "$asked" shop
  rm -rf "$asked-adopt-xaden"
  x_in "$asked" adopt --yes --skip-ci
  assert "without a terminal adopt sets nothing" bash -c '! grep -q "^update-check" "$1/xaden/xaden.conf"' _ "$asked-adopt-xaden"
  rm -rf "$WORKDIR/asked-create" && mkdir -p "$WORKDIR/asked-create"
  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=12h x_in "$WORKDIR/asked-create" create demo
  assert "create asks for the interval and records the answer" grep -q '^update-check = 12h$' "$WORKDIR/asked-create/demo/xaden/xaden.conf"
  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=banana x_in "$WORKDIR/asked-create" create demo2
  assert "an unreadable answer names the allowed forms and records off" bash -c 'grep -q "off, or a number with h or d" "$1" && grep -q "^update-check = off$" "$2"' _ "$XOUT" "$WORKDIR/asked-create/demo2/xaden/xaden.conf"

  export PATH=$saved_path
  unset XADEN_LATEST_URL
}

# REQ-087 the commands of an older Xaden had no prefix; syncing replaces the ones Xaden created and keeps the rest
test_command_prefix_migration() {
  local dir="$WORKDIR/repos/prefix-migration" lib="$SCAFFOLD_ROOT/template/scripts/lib.sh" scaffold_lib="$SCAFFOLD_ROOT/scripts/scaffold-lib.sh"
  rm -rf "$dir" && mkdir -p "$dir/xaden" "$dir/.claude/commands" "$dir/.agents/skills/feature"
  printf 'old command\n' >"$dir/.claude/commands/feature.md"
  printf 'old skill\n' >"$dir/.agents/skills/feature/SKILL.md"
  printf 'my own review command\n' >"$dir/.claude/commands/review.md"
  printf 'file .claude/commands/feature.md\nfile .agents/skills/feature/SKILL.md\n' >"$dir/xaden/footprint.txt"
  bash -c 'source "$1"; source "$2"; sync_commands "$3" "$4" claude,vibe' _ "$lib" "$scaffold_lib" "$dir" "$SCAFFOLD_ROOT/template" >/dev/null 2>&1
  assert "the old unprefixed command that Xaden created is removed" test ! -e "$dir/.claude/commands/feature.md"
  assert "the old unprefixed skill that Xaden created is removed" test ! -e "$dir/.agents/skills/feature"
  assert "the prefixed command is written" test -f "$dir/.claude/commands/xaden-feature.md"
  assert "the prefixed skill is written" test -f "$dir/.agents/skills/xaden-feature/SKILL.md"
  assert "the footprint lists the new file and not the old one" bash -c 'grep -qx "file .claude/commands/xaden-feature.md" "$1" && ! grep -qx "file .claude/commands/feature.md" "$1"' _ "$dir/xaden/footprint.txt"
  assert "a command of the same old name that Xaden did not create stays" test "$(cat "$dir/.claude/commands/review.md")" = "my own review command"
}

# REQ-101 a check that did not run to the end never counts as passed
test_exit_status_of_checks() {
  local worktree="$WORKDIR/repos/exit-status-adopt-xaden" repo="$WORKDIR/repos/exit-status" conf mode
  make_repo "$repo" shop
  mkdir -p "$repo/tools"
  # prints one violation (baselined below), then exits with the status in tools/status
  printf '#!/bin/sh\necho "scripts/build.sh:3:1: note: old finding"\n[ -z "$STUB_NEW" ] || echo "scripts/build.sh:9:1: note: new finding"\nexit "$(cat "$(dirname "$0")/status")"\n' >"$repo/tools/stub.sh"
  printf '1\n' >"$repo/tools/status"
  git -C "$repo" add -A && git -C "$repo" commit -q -m "chore: stub"
  x_in "$repo" adopt --yes --skip-ci --check "stub=sh tools/stub.sh"
  conf="$worktree/xaden/xaden.conf"
  assert "adoption records the status the check exits with while printing violations" grep -q '^findings-status.stub = 1$' "$conf"

  # a tool that already crashes while adoption records the baseline: its status is not learned
  make_repo "$WORKDIR/repos/exit-status-crash" shop
  mkdir -p "$WORKDIR/repos/exit-status-crash/tools"
  printf '#!/bin/sh\necho "scripts/build.sh:3:1: note: old finding"\necho "FATAL: crashed" >&2\nexit 2\n' >"$WORKDIR/repos/exit-status-crash/tools/stub.sh"
  git -C "$WORKDIR/repos/exit-status-crash" add -A && git -C "$WORKDIR/repos/exit-status-crash" commit -q -m "chore: crashing stub"
  x_in "$WORKDIR/repos/exit-status-crash" adopt --yes --skip-ci --check "stub=sh tools/stub.sh"
  assert "adoption does not learn a crash as the findings status" bash -c '! grep -q "^findings-status.stub" "$1"' _ "$WORKDIR/repos/exit-status-crash-adopt-xaden/xaden/xaden.conf"
  assert "adoption says which line to add" grep -q 'findings-status.stub = 2' "$XOUT"
  x_in "$WORKDIR/repos/exit-status-crash-adopt-xaden" check --strict
  assert "the crashing tool fails afterwards" test "$XRC" -ne 0

  # checks_in <mode>: the check run under that mode, XRC and XOUT as x_in leaves them
  checks_in() {
    edit_file "$conf" "s/^mode = .*/mode = $1/"
    x_in "$worktree" check
  }
  for mode in changed-files strict; do
    checks_in "$mode"
    assert "$mode: the declared status with only baselined violations passes" test "$XRC" -eq 0
  done
  printf '2\n' >"$worktree/tools/status"
  for mode in changed-files strict; do
    checks_in "$mode"
    assert "$mode: a crash after baselined output fails" test "$XRC" -ne 0
    assert "$mode: the failure names the status" grep -q 'check: stub failed (exit status 2)' "$XOUT"
  done
  checks_in advisory
  assert "advisory: a crash only warns" test "$XRC" -eq 0
  assert "advisory says it is not blocking" grep -q 'check: stub failed (advisory mode: not blocking)' "$XOUT"

  # a new violation and a fatal error together: fails, and both lines are shown
  checks_in strict
  (cd "$worktree" && STUB_NEW=1 "$XADEN" check) >"$XOUT" 2>&1 && XRC=0 || XRC=$?
  assert "strict: new violation plus fatal error fails" test "$XRC" -ne 0
  assert "the output is shown" grep -q 'new finding' "$XOUT"

  # an undeclared custom check fails on any non-zero status
  printf '1\n' >"$worktree/tools/status"
  edit_file "$conf" '/^findings-status.stub/d'
  checks_in strict
  assert "undeclared status: the check fails even with only baselined output" test "$XRC" -ne 0

  # failing assertions are never findings
  edit_file "$conf" 's#^check.test = .*#check.test = sh tools/stub.sh#'
  printf 'findings-status.stub = 1\n' >>"$conf"
  checks_in strict
  assert "the test check fails on a failing exit status" grep -q 'check: test failed (exit status 1)' "$XOUT"
  printf 'findings-status.test = 1\n' >>"$conf"
  checks_in strict
  assert "findings-status.test is refused" grep -q 'findings-status.test is not allowed' "$XOUT"
  edit_file "$conf" '/^findings-status.test/d'
  printf 'findings-status.nothing = 1\n' >>"$conf"
  checks_in strict
  assert "a status for an unmapped check is refused" grep -q 'findings-status.nothing names no check' "$XOUT"
  edit_file "$conf" '/^findings-status.nothing/d'
  edit_file "$conf" 's/^findings-status.stub = .*/findings-status.stub = 0,300/'
  checks_in strict
  assert "a status outside 1 to 255 is refused" test "$XRC" -ne 0
  edit_file "$conf" 's/^findings-status.stub = .*/findings-status.stub = one/'
  checks_in strict
  assert "a status that is no number is refused" grep -q 'not a comma separated list' "$XOUT"
}

# REQ-102 an unknown scope of a check is never an empty one
test_scope_of_changed_files() {
  local worktree="$WORKDIR/repos/scope-adopt-xaden" repo="$WORKDIR/repos/scope" conf before_violation tip orphan
  make_repo "$repo" shop
  mkdir -p "$repo/tools"
  # reports a violation in scripts/build.sh once tools/violate exists
  printf '#!/bin/sh\n[ ! -f "$(dirname "$0")/violate" ] || echo "scripts/build.sh:9:1: note: new finding"\n[ ! -f "$(dirname "$0")/violate" ] || exit 1\n' >"$repo/tools/stub.sh"
  git -C "$repo" add -A && git -C "$repo" commit -q -m "chore: stub"
  x_in "$repo" adopt --yes --skip-ci --check "stub=sh tools/stub.sh"
  conf="$worktree/xaden/xaden.conf"
  printf 'findings-status.stub = 1\n' >>"$conf"
  edit_file "$conf" 's/^mode = .*/mode = changed-files/'
  git -C "$worktree" add -A && git -C "$worktree" -c core.hooksPath=/dev/null commit -q -n -m "chore: settings"
  before_violation="$(git -C "$worktree" rev-parse HEAD)"
  : >"$worktree/tools/violate"
  printf '# changed\n' >>"$worktree/scripts/build.sh"
  git -C "$worktree" add -A && git -C "$worktree" -c core.hooksPath=/dev/null commit -q -n -m "fix: the violation"
  printf 'more\n' >>"$worktree/docs/guide.md"
  git -C "$worktree" add -A && git -C "$worktree" -c core.hooksPath=/dev/null commit -q -n -m "docs: unrelated"
  tip="$(git -C "$worktree" rev-parse HEAD)"
  orphan="$(git -C "$worktree" commit-tree -m orphan "$(git -C "$worktree" rev-parse 'HEAD^{tree}')")"
  git -C "$worktree" update-ref refs/remotes/origin/release "$before_violation"

  # scope_run <variable=value>...: the check with exactly these CI variables, XRC and XOUT as x_in leaves them
  scope_run() {
    XRC=0
    (cd "$worktree" && env -u CI -u EVENT_NAME -u BASE_REF -u BEFORE_SHA "$@" "$XADEN" check) >"$XOUT" 2>&1 || XRC=$?
  }
  scope_run EVENT_NAME=push BEFORE_SHA="$before_violation"
  assert "push: a violation in the first commit of the push fails" test "$XRC" -ne 0
  assert "push: the violation is named" grep -q 'build.sh: note: new finding' "$XOUT"
  scope_run EVENT_NAME=push BEFORE_SHA="$(git -C "$worktree" rev-parse HEAD~1)"
  assert "push: a violation outside the pushed commits does not fail" test "$XRC" -eq 0
  scope_run EVENT_NAME=push BEFORE_SHA="$tip"
  assert "push: a verified empty change set passes without fallback" test "$XRC" -eq 0
  ! grep -q 'cannot tell' "$XOUT" || die "FAILED: an empty change set must not fall back"
  scope_run EVENT_NAME=push BEFORE_SHA=0000000000000000000000000000000000000000
  assert "push: a first push (all-zero previous tip) checks everything" test "$XRC" -ne 0
  assert "the fallback is explained" grep -q 'cannot tell which files this run changes' "$XOUT"
  scope_run EVENT_NAME=push BEFORE_SHA="$orphan"
  assert "push: a previous tip that is not an ancestor checks everything" test "$XRC" -ne 0
  scope_run EVENT_NAME=push BEFORE_SHA=1111111111111111111111111111111111111111
  assert "push: a previous tip missing in the checkout checks everything" grep -q 'cannot tell' "$XOUT"
  scope_run EVENT_NAME=pull_request BASE_REF=release
  assert "pull request: the diff to the actual target branch is used" test "$XRC" -ne 0
  ! grep -q 'cannot tell' "$XOUT" || die "FAILED: a known target branch must not fall back"
  scope_run EVENT_NAME=pull_request BASE_REF=gone
  assert "pull request: an unknown target branch checks everything" grep -q 'cannot tell' "$XOUT"
  scope_run EVENT_NAME=pull_request BASE_REF='bad ref;'
  assert "pull request: an invalid BASE_REF checks everything" grep -q 'cannot tell' "$XOUT"
  scope_run CI=true
  assert "CI without an event checks everything" grep -q 'cannot tell' "$XOUT"
  assert "the mode in xaden.conf is untouched by the fallback" grep -q '^mode = changed-files$' "$conf"
  # the step that runs the checks, not another one, receives the event
  assert "the generated workflows hand the event to the check step" bash -c '
    for f in "$1/scripts/adopt/ci.yml" "$1/template/.github/workflows/ci.yml"; do
      awk "/name: (Xaden checks|Static analysis) \\(full run/ { step = 1 } step && /EVENT_NAME:/ { e = 1 } step && /BASE_REF:/ { b = 1 } step && /BEFORE_SHA:/ { s = 1 } step && /run:/ { exit !(e && b && s) }" "$f" || exit 1
    done' _ "$SCAFFOLD_ROOT"
}

# REQ-103 the generated CI installation under require-signature = true: the workflow's own install
# step, run on a fresh home, then the check command of the workflow
test_signed_only_in_generated_ci() {
  local worktree version checksum ci="$WORKDIR/ci-signed"
  worktree="$(adopted_copy ci-signed)"
  printf 'require-signature = true\n' >>"$worktree/xaden/xaden.conf"
  git -C "$worktree" add -A && git -C "$worktree" -c core.hooksPath=/dev/null commit -q -n -m "chore: require signed releases"
  version="$(conf_get "$worktree/xaden/xaden.conf" version)"
  checksum="$(conf_get "$worktree/xaden/xaden.conf" checksum)"
  rm -rf "$ci" && mkdir -p "$ci/temp" "$ci/home"
  git -C "$SCAFFOLD_ROOT" archive --prefix="xaden-$version/" HEAD | gzip >"$ci/release.tar.gz"
  # the install step of the generated workflow, with the download replaced by the local archive
  awk '/- name: Install Xaden/ { on = 1; next } on && /run: \|/ { run = 1; next } run && /- name:/ { exit } run { sub(/^          /, ""); print }' \
    "$worktree/.github/workflows/xaden.yml" |
    sed 's#^curl -fsSL .* | tar -xz -C "\$RUNNER_TEMP"#tar -xz -C "$RUNNER_TEMP" -f "$CI_ARCHIVE"#' >"$ci/install.sh"
  assert "the install step was found" grep -q 'CI_ARCHIVE' "$ci/install.sh"
  XRC=0
  (cd "$ci" && env -u XADEN_HOME -u XDG_DATA_HOME HOME="$ci/home" RUNNER_TEMP="$ci/temp" GITHUB_PATH="$ci/path" CI_ARCHIVE="$ci/release.tar.gz" \
    XADEN_VERSION="$version" XADEN_CHECKSUM="$checksum" bash "$ci/install.sh") >"$XOUT" 2>&1 || XRC=$?
  assert "CI installs the pinned tree" test "$XRC" -eq 0
  XRC=0
  (cd "$worktree" && env -u CI -u XADEN_HOME -u XDG_DATA_HOME HOME="$ci/home" "$ci/temp/xaden-$version/scripts/xaden.sh" check) >"$XOUT" 2>&1 || XRC=$?
  assert "CI: the signed-only check accepts exactly the pinned tree" bash -c '! grep -q "requires signed releases" "$1"' _ "$XOUT"
  assert "CI: the checks run" grep -q 'check mode: full' "$XOUT"
  printf 'changed\n' >>"$ci/temp/xaden-$version/README.md"
  XRC=0
  (cd "$worktree" && env -u CI -u XADEN_HOME -u XDG_DATA_HOME HOME="$ci/home" "$ci/temp/xaden-$version/scripts/xaden.sh" check) >"$XOUT" 2>&1 || XRC=$?
  assert "CI: a changed tree is refused" grep -q 'requires signed releases' "$XOUT"
}

# REQ-108 the commit convention comes from evidence and is shown with its consequence
test_convention_from_evidence() {
  local repo="$WORKDIR/repos/convention" subject worktree
  history_of() {
    make_repo "$repo" empty
    for subject in "$@"; do git -C "$repo" commit -q --allow-empty -m "$subject"; done
  }
  make_repo "$repo" empty
  x_in "$repo" adopt --scan
  assert "REQ-108 no history: conventional" grep -q 'commit convention .*conventional (no history)' "$XOUT"
  history_of "feat: a" "fix: b" "docs: c"
  x_in "$repo" adopt --scan
  assert "REQ-108 three conventional subjects: conventional, with the evidence" grep -q 'commit convention .*conventional (3 of 3 subjects)' "$XOUT"
  assert "REQ-108 conventional: no advice sentence" bash -c '! grep -q "only advise" "$1"' _ "$XOUT"
  history_of "feat: a" "wip" "fix: b"
  x_in "$repo" adopt --scan
  assert "REQ-108 one subject off the pattern in three: other, with the evidence" grep -q 'commit convention .*other (2 of 3 subjects)' "$XOUT"
  assert "REQ-108 other: the sentence names the setting and the approval point" grep -q "Refs: checks only advise.*commit-convention = conventional.*Approval point" "$XOUT"
  history_of "feat: a" "b" "c" "d" "e" "fix: f"
  x_in "$repo" adopt --scan
  assert "REQ-108 six mixed subjects: other, the 60 percent rule is unchanged" grep -q 'commit convention .*other (2 of 6 subjects)' "$XOUT"
  history_of "feat: a" "fix: b" "c" "docs: d" "test: e" "chore: f"
  x_in "$repo" adopt --scan
  assert "REQ-108 five or more: 60 percent conventional is enough" grep -q 'commit convention .*conventional (5 of 6 subjects)' "$XOUT"

  history_of "feat: a" "wip" "fix: b"
  x_in "$repo" adopt --scan --commit-convention conventional
  assert "REQ-108 the flag overrides the scan and says so" grep -q 'commit convention .*conventional (chosen with --commit-convention)' "$XOUT"
  x_in "$repo" adopt --scan --commit-convention loose
  assert "REQ-108 an unknown value is rejected" test "$XRC" -ne 0
  assert "REQ-108 the error names the allowed values" grep -q 'conventional or other' "$XOUT"
  x_in "$repo" adopt --yes --assistants claude --skip-ci --commit-convention conventional
  worktree="$repo-adopt-xaden"
  assert "REQ-108 the conf holds the value alone, without the evidence" grep -qx 'commit-convention = conventional' "$worktree/xaden/xaden.conf"

  worktree="$(adopted_copy convention-tip)"
  x_in "$worktree" check
  assert "REQ-108 other: the full run prints one TIP naming the setting" test "$(grep -c '^TIP: .*commit-convention' "$XOUT")" -eq 1
  edit_file "$worktree/xaden/xaden.conf" 's/^commit-convention = .*/commit-convention = conventional/'
  x_in "$worktree" check
  assert "REQ-108 conventional: no such TIP" bash -c '! grep -q "^TIP: .*commit-convention" "$1"' _ "$XOUT"
}

# REQ-107 the commit rules hold in CI, where a skipped hook cannot hide a commit
test_commit_check_in_ci() {
  local worktree workflow before ci_uses unknown="REQ-""999" # split: traceability rejects a test that cites an unknown ID
  worktree="$(adopted_copy commit-check)"
  workflow="$worktree/.github/workflows/xaden.yml"
  assert "REQ-107 the generated workflow runs the commit check" grep -q 'run: xaden.sh verify-commits --ci' "$workflow"
  assert "REQ-107 it reads the events the range comes from" bash -c 'grep -A6 "Commit messages" "$1" | grep -q BEFORE_SHA' _ "$workflow"
  ci_uses="$(grep -c 'uses:' "$SCAFFOLD_ROOT/scripts/adopt/ci.yml")"
  assert "REQ-107 the step adds no third-party action" test "$(grep -c 'uses:' "$workflow")" -eq "$ci_uses"
  assert "REQ-107 the step adds no secret" bash -c '! grep -q "secrets\." "$1"' _ "$workflow"

  edit_file "$worktree/xaden/xaden.conf" 's/^commit-convention = .*/commit-convention = conventional/'
  before="$(git -C "$worktree" rev-parse HEAD)"
  git -C "$worktree" -c core.hooksPath=/dev/null commit -q --allow-empty -m "feat: no reference"
  EVENT_NAME=push BEFORE_SHA="$before" x_in "$worktree" verify-commits --ci
  assert "REQ-107 conventional: a feat commit without Refs fails the step" test "$XRC" -ne 0
  assert "REQ-107 the log names the rule" grep -q "feat commits need a 'Refs: REQ-nnn' trailer" "$XOUT"
  assert "REQ-107 the log names the commit" grep -q 'feat: no reference' "$XOUT"
  git -C "$worktree" -c core.hooksPath=/dev/null commit -q --allow-empty -m "fix: unknown reference" -m "Refs: $unknown"
  EVENT_NAME=push BEFORE_SHA="$(git -C "$worktree" rev-parse HEAD~1)" x_in "$worktree" verify-commits --ci
  assert "REQ-107 conventional: an unknown requirement fails the step" bash -c 'test "$1" -ne 0 && grep -q "$3" "$2"' _ "$XRC" "$XOUT" "$unknown"
  git -C "$worktree" -c core.hooksPath=/dev/null commit -q --allow-empty -m "fix: fine" -m "Refs: none"
  EVENT_NAME=push BEFORE_SHA="$(git -C "$worktree" rev-parse HEAD~1)" x_in "$worktree" verify-commits --ci
  assert "REQ-107 conventional: a valid commit passes" test "$XRC" -eq 0
  EVENT_NAME=pull_request BASE_REF='bad ref;' x_in "$worktree" verify-commits --ci
  assert "REQ-107 a range that cannot be derived fails, it is not read as empty" test "$XRC" -ne 0

  edit_file "$worktree/xaden/xaden.conf" 's/^commit-convention = .*/commit-convention = other/'
  EVENT_NAME=push BEFORE_SHA="$before" x_in "$worktree" verify-commits --ci
  assert "REQ-107 another convention: the same findings only warn" test "$XRC" -eq 0
  assert "REQ-107 the warning says why" grep -q "advisory only while commit-convention is 'other'" "$XOUT"
}

# REQ-109 the commit check judges only the commits since the adoption, in a checkout it can read
test_commit_check_range() {
  local worktree clone zero="0000000000000000000000000000000000000000"
  worktree="$(adopted_copy commit-range)"
  edit_file "$worktree/xaden/xaden.conf" 's/^commit-convention = .*/commit-convention = conventional/'
  git -C "$worktree" -c core.hooksPath=/dev/null commit -q -am "chore: enforce the convention"
  # the fixture's first commit, from before the adoption, is not a conventional message
  EVENT_NAME=push BEFORE_SHA="$zero" x_in "$worktree" verify-commits --ci
  assert "REQ-109 a first push passes although a commit from before the adoption is not conventional" test "$XRC" -eq 0
  git -C "$worktree" -c core.hooksPath=/dev/null commit -q --allow-empty -m "wip after the adoption"
  EVENT_NAME=push BEFORE_SHA="$zero" x_in "$worktree" verify-commits --ci
  assert "REQ-109 a bad commit after the adoption fails the first push" test "$XRC" -ne 0
  assert "REQ-109 the log names that commit" grep -q 'wip after the adoption' "$XOUT"
  assert "REQ-109 the log does not name the commit from before the adoption" bash -c '! grep -q " initial" "$1"' _ "$XOUT"
  git -C "$worktree" reset -q --hard HEAD~1

  clone="$WORKDIR/repos/commit-range-shallow"
  rm -rf "$clone" && git clone -q --depth 1 "file://$worktree" "$clone"
  EVENT_NAME=push BEFORE_SHA="$zero" x_in "$clone" verify-commits --ci
  assert "REQ-109 a shallow checkout fails the adopted project's check" test "$XRC" -ne 0
  assert "REQ-109 the log names fetch-depth" grep -q 'fetch-depth: 0' "$XOUT"
  edit_file "$clone/xaden/xaden.conf" 's/^commit-convention = .*/commit-convention = other/'
  EVENT_NAME=push BEFORE_SHA="$zero" x_in "$clone" verify-commits --ci
  assert "REQ-109 a shallow checkout fails under another convention too" test "$XRC" -ne 0
}

test_messages
test_scan_and_plan
test_convention_from_evidence
test_adopt_and_remove
test_claude_commands
test_command_prefix_migration
test_other_assistant_commands
test_reuse_of_existing_tooling
test_versions_and_downloads
test_self_upgrade
test_modes_and_baselines
test_exit_status_of_checks
test_commit_check_in_ci
test_commit_check_range
test_scope_of_changed_files
test_signed_only_in_generated_ci
test_prompts_and_ignore_list
test_autopilot
test_migration
test_new_project_layout
test_update_check
