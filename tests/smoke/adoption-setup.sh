# shellcheck shell=bash
# shellcheck disable=SC2016 # bash -c programs are single-quoted on purpose
# Smoke test area "adoption-setup" (REQ-121, part of REQ-066 to REQ-076: adopting, assistant commands, reuse of existing tooling, the layout xaden project create writes).
# Sourced by tests/smoke.sh, which defines the helpers and creates the demo project first.
# shellcheck source=SCRIPTDIR/adoption-lib.sh
source "$SMOKE_DIR/adoption-lib.sh"

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

# REQ-067 the scan reports and changes nothing; the plan shows the exact diff and writes nothing
test_scan_and_plan() {
  local repo="$WORKDIR/repos/scan-shop" before
  make_repo "$repo" shop
  before="$(git -C "$repo" status --porcelain; git -C "$repo" branch --list | wc -l)"
  x_in "$repo" project adopt --scan
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

  x_in "$repo" project adopt --plan
  assert "plan succeeds" test "$XRC" -eq 0
  assert "plan lists the created files" grep -q 'A.xaden/xaden.conf' "$XOUT"
  assert "plan lists the touched file" grep -q 'M.AGENTS.md' "$XOUT"
  assert "plan prints the exact diff" grep -q '^+++ b/xaden/xaden.conf' "$XOUT"
  assert "plan changes nothing" test "$(git -C "$repo" status --porcelain; git -C "$repo" branch --list | wc -l)" = "$before"
  assert "plan creates no worktree" test "$(git -C "$repo" worktree list | wc -l | tr -d ' ')" = "1"

  x_in "$repo" project adopt
  assert "without a terminal nothing is applied" test ! -e "$repo-adopt-xaden"
  assert "without a terminal the apply command is named" grep -q 'xaden project adopt --yes' "$XOUT"

  local unknown="$WORKDIR/repos/unknown"
  make_repo "$unknown" empty
  printf 'int main(void) { return 0; }\n' >"$unknown/main.c"
  git -C "$unknown" add -A && git -C "$unknown" commit -q -m "initial"
  x_in "$unknown" project adopt --scan
  assert "an unrecognised build is said, not guessed" grep -q 'not recognised.*no build system recognised' "$XOUT"
  assert "no command is guessed" bash -c '! grep -q "test runner .*[a-z]" "$1" || grep -q "test runner .*none" "$1"' _ "$XOUT"
}

# REQ-066 REQ-070 REQ-073 adopting: own branch and worktree, nothing of the team's changes, small footprint
test_adopt_and_remove() {
  local repo="$WORKDIR/repos/adopt-shop" worktree changed
  make_repo "$repo" shop
  x_in "$repo" project adopt --yes --assistants claude
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
  assert "REQ-127 adopt adds no scoped AGENTS.md in a folder" test -z "$(cd "$worktree" && find . -name AGENTS.md -not -path './AGENTS.md' -not -path './.git/*' | head -n 1)"
  assert "AGENTS.md gets one marked block" test "$(grep -c 'xaden:begin' "$worktree/AGENTS.md")" = "1"
  assert "team content is plain Markdown plus one settings file (REQ-070)" test -f "$worktree/xaden/xaden.conf" -a -f "$worktree/xaden/requirements/INDEX.md" -a -d "$worktree/xaden/personas" -a -d "$worktree/xaden/security-reviews"
  assert "no editor specific files" test -z "$(find "$worktree/xaden" -name '.obsidian' -o -name '.vscode')"
  assert "tooling is not copied into the repository" test ! -e "$worktree/scripts/check.sh" -a ! -e "$worktree/prompts" -a ! -e "$worktree/xaden/scripts"
  assert "RULES.md says it is generated" grep -q 'Generated, do not edit' "$worktree/xaden/RULES.md"
  assert "RULES.md has no path of the copied layout" bash -c '! grep -nE "scripts/[a-z-]+\.sh|docs/(requirements|personas|threat-model|security)" "$1"' _ "$worktree/xaden/RULES.md"
  assert "RULES.md makes a mode change an approval point" grep -q 'Approval point' "$worktree/xaden/RULES.md"
  assert "REQ-110 RULES.md says the assistant never merges its own pull request" bash -c 'tr "\n" " " <"$1" | grep -q "never merges it"' _ "$worktree/xaden/RULES.md"
  assert "REQ-111 RULES.md holds the judgment section" grep -q '^### Judgment stays with the human' "$worktree/xaden/RULES.md"
  assert "REQ-122 RULES.md asks for epic, title and ID" bash -c 'tr -s "[:space:]" " " <"$1" | grep -q "Name a requirement with its epic, title and ID"' _ "$worktree/xaden/RULES.md"
  x_in "$worktree" doc rules-git
  assert "REQ-126 xaden doc rules-git prints the git rules for the adopted layout" test "$XRC" -eq 0
  assert "RULES.md starts a change sparse on the team's requirements only (REQ-082, REQ-126)" \
    grep -qF 'sparse-checkout set --cone xaden/requirements`' "$XOUT"
  assert "REQ-126 RULES.md names the command of each moved topic, not a file the project lacks" bash -c \
    'grep -q "xaden doc rules-git" "$1" && grep -q "xaden doc rules-requirements" "$1" && ! grep -q "docs/rules/" "$1" "$2"' _ "$worktree/xaden/RULES.md" "$XOUT"
  assert "REQ-126 RULES.md stays under the 10240 byte budget" test "$(wc -c <"$worktree/xaden/RULES.md")" -le 10240
  x_in "$worktree" doc rules-nonsense
  assert "REQ-126 an unknown rules topic is refused" test "$XRC" -ne 0
  assert "the version and checksum are pinned" grep -Eq '^checksum = [0-9a-f]{64}$' "$worktree/xaden/xaden.conf"
  assert "the build's commands are mapped" grep -q '^check.test = npm test$' "$worktree/xaden/xaden.conf"
  assert "git hooks of the clone are chained, not replaced" grep -q 'xaden hook pre-commit' "$repo/.git/hooks/pre-commit"
  assert "core.hooksPath is not set" test -z "$(git -C "$repo" config --get core.hooksPath || true)"
  assert "violations that exist are recorded" test -f "$worktree/xaden/baselines/shellcheck.txt"
  assert "adopting twice is refused" bash -c 'cd "$1" && ! "$2" adopt --yes' _ "$worktree" "$XADEN"

  printf '%s\n' 'text added by the team' >>"$worktree/AGENTS.md"
  git -C "$worktree" -c core.hooksPath=/dev/null commit -q -n -am "docs: team text"
  x_in "$worktree" project remove --yes
  assert "remove succeeds" test "$XRC" -eq 0
  assert "remove deletes the xaden folder" test ! -e "$worktree/xaden"
  assert "remove deletes the workflow and CLAUDE.md" test ! -e "$worktree/.github/workflows/xaden.yml" -a ! -e "$worktree/CLAUDE.md"
  assert "remove keeps the team's text in AGENTS.md" grep -q 'text added by the team' "$worktree/AGENTS.md"
  assert "remove takes the block out" bash -c '! grep -q xaden "$1"' _ "$worktree/AGENTS.md"
  assert "remove leaves nothing but the adoption's own paths in git status" test -z "$(git -C "$worktree" status --porcelain | grep -Ev ' (xaden/|AGENTS\.md|CLAUDE\.md|\.claude/commands/[a-z-]+\.md|\.github/workflows/xaden\.yml)' || true)"
  assert "remove unchains the git hooks" bash -c '! test -e "$1/.git/hooks/pre-commit"' _ "$repo"

  local no_ci="$WORKDIR/repos/no-ci" plain
  make_repo "$no_ci" shop
  x_in "$no_ci" project adopt --yes --skip-ci
  assert "--skip-ci adds no workflow" test ! -e "$no_ci-adopt-xaden/.github/workflows/xaden.yml"
  assert "without Claude users there is no CLAUDE.md" test ! -e "$no_ci-adopt-xaden/CLAUDE.md"
  plain="$(git -C "$no_ci-adopt-xaden" diff --name-only main HEAD | grep -Ev '^(xaden/|AGENTS\.md$)' || true)"
  assert "the footprint without the workflow is xaden/ and AGENTS.md" test -z "$plain"

  local claude="$WORKDIR/repos/claude" 
  make_repo "$claude" shop
  printf '# Claude\n@AGENTS.md\n' >"$claude/CLAUDE.md"
  git -C "$claude" add -A && git -C "$claude" commit -q -m "docs: claude"
  x_in "$claude" project adopt --yes --assistants claude --skip-ci
  assert "an existing CLAUDE.md that has the line stays as it is" cmp -s "$claude/CLAUDE.md" "$claude-adopt-xaden/CLAUDE.md"
  local claude2="$WORKDIR/repos/claude2"
  make_repo "$claude2" shop
  printf '# Claude\nown rules\n' >"$claude2/CLAUDE.md"
  git -C "$claude2" add -A && git -C "$claude2" commit -q -m "docs: claude"
  x_in "$claude2" project adopt --yes --assistants claude --skip-ci
  assert "an existing CLAUDE.md gains the line" test "$(tail -n 1 "$claude2-adopt-xaden/CLAUDE.md")" = "@AGENTS.md"
  assert "an existing CLAUDE.md keeps its text" grep -q 'own rules' "$claude2-adopt-xaden/CLAUDE.md"

  local empty="$WORKDIR/repos/empty"
  make_repo "$empty" empty
  x_in "$empty" project adopt --yes --skip-ci
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

  x_in "$repo" project adopt --plan
  assert "the plan lists a command file" grep -Eq 'A[[:space:]]+\.claude/commands/xaden-bugfix\.md' "$XOUT"
  assert "the plan names the file it skips" grep -q 'skipped .claude/commands/xaden-feature.md' "$XOUT"
  assert "the plan writes nothing" test ! -e "$wt"

  x_in "$repo" project adopt --yes --assistants claude
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
  assert "adopt creates exactly the new command files" test "$(git -C "$wt" diff --name-only main HEAD | grep -c '^\.claude/commands/')" -eq 10

  x_in "$wt" project remove --yes
  assert "remove deletes the files Xaden created" test ! -e "$wt/.claude/commands/xaden-bugfix.md" -a ! -e "$wt/.claude/commands/xaden-release.md"
  assert "remove keeps the team's own command" test "$(cat "$wt/.claude/commands/xaden-feature.md")" = "my own feature command"
  assert "remove leaves no stray file" test -z "$(git -C "$wt" status --porcelain | grep -Ev ' (xaden/|AGENTS\.md|CLAUDE\.md|\.claude/commands/[a-z-]+\.md|\.github/workflows/xaden\.yml)' || true)"

  local plain="$WORKDIR/repos/commands-plain"
  make_repo "$plain" shop
  x_in "$plain" project adopt --yes --skip-ci
  assert "without Claude there are no command files" test ! -e "$plain-adopt-xaden/.claude"
}

# REQ-081 Copilot, Mistral Vibe and Codex CLI users get command files in their own layout
test_other_assistant_commands() {
  local repo="$WORKDIR/repos/others" wt="$WORKDIR/repos/others-adopt-xaden" name file
  make_repo "$repo" shop
  mkdir -p "$repo/.github/prompts"
  printf 'my own feature prompt\n' >"$repo/.github/prompts/xaden-feature.prompt.md"
  git -C "$repo" add -A && git -C "$repo" commit -q -m "docs: own feature prompt"

  x_in "$repo" project adopt --plan --assistants copilot,vibe,codex
  assert "the plan lists a Copilot prompt file" grep -Eq 'A[[:space:]]+\.github/prompts/xaden-bugfix\.prompt\.md' "$XOUT"
  assert "the plan lists a skill" grep -Eq 'A[[:space:]]+\.agents/skills/xaden-bugfix/SKILL\.md' "$XOUT"
  assert "the plan names the file it skips" grep -q 'skipped .github/prompts/xaden-feature.prompt.md' "$XOUT"

  x_in "$repo" project adopt --yes --assistants copilot,vibe,codex
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
  assert "adopt creates exactly the new Copilot prompts" test "$(git -C "$wt" diff --name-only main HEAD | grep -c '^\.github/prompts/')" -eq 10
  assert "adopt creates one skill for each prompt" test "$(git -C "$wt" diff --name-only main HEAD | grep -c '^\.agents/skills/')" -eq 11
  assert "without Claude there are no Claude files" test ! -e "$wt/CLAUDE.md" -a ! -e "$wt/.claude"

  x_in "$wt" project remove --yes
  assert "remove deletes the Copilot prompts and skills Xaden created" test ! -e "$wt/.github/prompts/xaden-bugfix.prompt.md" -a ! -e "$wt/.agents"
  assert "remove keeps the team's own prompt" test "$(cat "$wt/.github/prompts/xaden-feature.prompt.md")" = "my own feature prompt"
  assert "remove leaves no stray file" test -z "$(git -C "$wt" status --porcelain | grep -Ev ' (xaden/|AGENTS\.md|\.github/prompts/[a-z-]+\.prompt\.md|\.agents/skills/[a-z-]+/SKILL\.md|\.github/workflows/xaden\.yml)' || true)"

  # a file or folder of the assistant's own is what makes adopt offer it; .agents/ names neither Vibe nor Codex
  local vibe="$WORKDIR/repos/detect-vibe" copilot="$WORKDIR/repos/detect-copilot" codex="$WORKDIR/repos/detect-codex"
  make_repo "$vibe" shop
  mkdir -p "$vibe/.vibe" && printf 'x = 1\n' >"$vibe/.vibe/config.toml"
  git -C "$vibe" add -A && git -C "$vibe" commit -q -m "chore: vibe"
  x_in "$vibe" project adopt --yes --skip-ci
  assert "Vibe is detected and gets skills" test -f "$vibe-adopt-xaden/.agents/skills/xaden-feature/SKILL.md"
  assert "only the detected assistant gets files" test ! -e "$vibe-adopt-xaden/.github/prompts" -a ! -e "$vibe-adopt-xaden/.claude"
  make_repo "$copilot" shop
  printf 'Be kind.\n' >"$copilot/.github/copilot-instructions.md"
  git -C "$copilot" add -A && git -C "$copilot" commit -q -m "chore: copilot"
  x_in "$copilot" project adopt --yes --skip-ci
  assert "Copilot is detected and gets prompt files" test -f "$copilot-adopt-xaden/.github/prompts/xaden-feature.prompt.md"
  assert "Copilot alone gets no skills" test ! -e "$copilot-adopt-xaden/.agents"
  make_repo "$codex" shop
  mkdir -p "$codex/.codex" && printf 'x = 1\n' >"$codex/.codex/config.toml"
  git -C "$codex" add -A && git -C "$codex" commit -q -m "chore: codex"
  x_in "$codex" project adopt --yes --skip-ci
  assert "Codex is detected and gets skills" test -f "$codex-adopt-xaden/.agents/skills/xaden-feature/SKILL.md"
  assert "Codex alone gets no Copilot files" test ! -e "$codex-adopt-xaden/.github/prompts"
}

# REQ-069 existing hooks, CI and tools are chained, reused and never replaced
test_reuse_of_existing_tooling() {
  local repo="$WORKDIR/repos/hook-plain" husky="$WORKDIR/repos/hook-husky" worktree out
  make_repo "$repo" shop
  printf '#!/bin/sh\necho team hook\n' >"$repo/.git/hooks/pre-commit" && chmod +x "$repo/.git/hooks/pre-commit"
  x_in "$repo" project adopt --yes --skip-ci
  assert "an existing plain git hook keeps its content" grep -q 'echo team hook' "$repo/.git/hooks/pre-commit"
  assert "Xaden is chained into the existing hook" grep -q 'xaden hook pre-commit' "$repo/.git/hooks/pre-commit"
  assert "a commit-msg hook is added" grep -q 'xaden hook commit-msg' "$repo/.git/hooks/commit-msg"

  make_repo "$husky" husky
  x_in "$husky" project adopt --yes --skip-ci
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
    x_in "$WORKDIR/repos/$manager" project adopt --scan
    assert "$manager: the hook manager is recognised" grep -q "hook manager .*$manager" "$XOUT"
    x_in "$WORKDIR/repos/$manager" project adopt --yes --skip-ci
    assert "$manager: adoption succeeds" test "$XRC" -eq 0
    assert "$manager: the generated hook keeps its content" grep -q "$manager ran" "$WORKDIR/repos/$manager/.git/hooks/pre-commit"
    assert "$manager: Xaden is chained into it" grep -q 'xaden hook pre-commit' "$WORKDIR/repos/$manager/.git/hooks/pre-commit"
    assert "$manager: no tracked file changes for the hook" test -z "$(git -C "$WORKDIR/repos/$manager-adopt-xaden" diff --name-only main HEAD | grep -E 'lefthook|pre-commit-config|husky' || true)"
    x_in "$WORKDIR/repos/$manager-adopt-xaden" project setup
    assert "$manager: xaden project setup is idempotent" test "$(grep -c 'xaden hook pre-commit' "$WORKDIR/repos/$manager/.git/hooks/pre-commit")" = "1"
  done

  make_repo "$WORKDIR/repos/overcommit" shop
  : >"$WORKDIR/repos/overcommit/.overcommit.yml"
  x_in "$WORKDIR/repos/overcommit" project adopt --yes
  assert "an unsupported hook manager stops with a manual step" test "$XRC" -eq 4
  assert "the manual step is named" grep -q 'Manual step' "$XOUT"
  assert "nothing was created for the unsupported hook manager" test ! -e "$WORKDIR/repos/overcommit-adopt-xaden"
  make_repo "$WORKDIR/repos/gitlab" shop
  : >"$WORKDIR/repos/gitlab/.gitlab-ci.yml" && rm -rf "$WORKDIR/repos/gitlab/.github"
  x_in "$WORKDIR/repos/gitlab" project adopt --yes
  assert "an unsupported CI system stops with a manual step" test "$XRC" -eq 4
  x_in "$WORKDIR/repos/gitlab" project adopt --yes --skip-ci
  assert "--skip-ci adopts without the unsupported CI system" test "$XRC" -eq 0

  out="$WORKDIR/repos/hook-plain-adopt-xaden"
  x_in "$out" check
  assert "the mapped test command runs" grep -q '^==> check: test' "$XOUT"
  assert "the mapped lint command runs" grep -q '^==> check: lint' "$XOUT"
  assert "Xaden's own language presets stay unused" bash -c '! grep -q "python:\|node:" "$1"' _ "$XOUT"

  # gaps and presets
  local bare="$WORKDIR/repos/bare"
  make_repo "$bare" bare-python
  x_in "$bare" project adopt --scan
  assert "the scan lists each gap" grep -q 'gaps .*test lint typecheck' "$XOUT"
  x_in "$bare" project adopt --yes --skip-ci --mode strict
  assert "without the preset no configuration file is added" test ! -e "$bare-adopt-xaden/ruff.toml"
  x_in "$bare-adopt-xaden" check
  assert "strict: a gap is an error" test "$XRC" -ne 0
  assert "the gap is named" grep -q "gap: no 'lint' check is configured" "$XOUT"
  git -C "$bare" worktree remove --force "$bare-adopt-xaden" && git -C "$bare" branch -D chore/adopt-xaden >/dev/null
  x_in "$bare" project adopt --yes --skip-ci --mode advisory
  x_in "$bare-adopt-xaden" check
  assert "advisory: a gap is a warning" grep -q "WARNING: gap: no 'lint' check" "$XOUT"
  git -C "$bare" worktree remove --force "$bare-adopt-xaden" && git -C "$bare" branch -D chore/adopt-xaden >/dev/null
  printf '[lint]\nselect = ["E"]\n' >"$bare/ruff.toml"
  git -C "$bare" add -A && git -C "$bare" commit -q -m "build: own ruff configuration"
  x_in "$bare" project adopt --yes --skip-ci --preset
  worktree="$bare-adopt-xaden"
  assert "the preset is its own commit" bash -c 'git -C "$1" log --format=%s main..HEAD | grep -q "python preset"' _ "$worktree"
  assert "the preset writes its configuration at the root" test -f "$worktree/mypy.ini" -a -f "$worktree/requirements-dev.txt"
  assert "an existing partial configuration is never overwritten" grep -q 'select = \["E"\]' "$worktree/ruff.toml"
  assert "the difference is shown" grep -q 'ruff.toml exists and differs' "$XOUT"
  assert "the install command is printed, not run" grep -q 'pip install -r requirements-dev.txt' "$XOUT"
  assert "the preset maps its commands" grep -q '^check.typecheck = mypy \.$' "$worktree/xaden/xaden.conf"
  assert "the preset's commit has only preset files and the mapping" test -z "$(git -C "$worktree" show --name-only --format= HEAD | grep -Ev '^(mypy\.ini|requirements-dev\.txt|xaden/xaden\.conf|xaden/footprint\.txt)$' || true)"

  # the scan finds unittest, conservatively: pytest wins, and the command runs from the root
  local ut="$WORKDIR/repos/unittest"
  make_repo "$ut" unittest-python
  x_in "$ut" project adopt --scan
  assert "the scan finds unittest" grep -q 'test runner .*python3 -m unittest discover -s tests' "$XOUT"
  assert "the found command runs the tests from the repository root" bash -c 'cd "$1" && python3 -m unittest discover -s tests >/dev/null 2>&1' _ "$ut"
  printf '[pytest]\n' >"$ut/pytest.ini"
  x_in "$ut" project adopt --scan
  assert "pytest wins over unittest" grep -q 'test runner  *pytest$' "$XOUT"
  rm "$ut/pytest.ini" && printf 'print(1)\n' >"$ut/tests/test_app.py"
  x_in "$ut" project adopt --scan
  assert "a test file without unittest is no unittest evidence" grep -q 'test runner  *none$' "$XOUT"

  # REQ-090 the worktrees/ folder is its own question and its own commit
  local plain="$WORKDIR/repos/plain-worktrees"
  make_repo "$plain" bare-python
  x_in "$plain" project adopt --yes --skip-ci
  assert "without the option no worktrees folder is added" test ! -e "$plain-adopt-xaden/worktrees"
  git -C "$plain" worktree remove --force "$plain-adopt-xaden" && git -C "$plain" branch -D chore/adopt-xaden >/dev/null
  x_in "$plain" project adopt --yes --skip-ci --worktrees
  worktree="$plain-adopt-xaden"
  assert "the worktrees folder is its own commit" bash -c 'git -C "$1" log --format=%s main..HEAD | grep -q "worktrees/"' _ "$worktree"
  assert "the folder ignores its contents" bash -c 'mkdir -p "$1/worktrees/x" && : >"$1/worktrees/x/f" && git -C "$1" check-ignore -q worktrees/x/f' _ "$worktree"
  assert "the footprint lists the file" grep -qx 'file worktrees/.gitignore' "$worktree/xaden/footprint.txt"
  rm -rf "$worktree/worktrees/x"
  x_in "$worktree" project remove --yes
  assert "remove takes the folder away again" test ! -e "$worktree/worktrees"
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
  x_in "$worktree" project ignore-list
  assert "the ignore list names the Xaden paths" test "$(cat "$XOUT")" = "$(printf 'xaden/\nAGENTS.md\nCLAUDE.md')"
  assert "the ignore list changes no file" test "$(git -C "$worktree" status --porcelain)" = "$before"
  rm "$worktree/CLAUDE.md"
  x_in "$worktree" project ignore-list
  assert "CLAUDE.md is listed only when present" test "$(cat "$XOUT")" = "$(printf 'xaden/\nAGENTS.md')"
}

# REQ-076 autopilot
test_autopilot() {
  local base="$WORKDIR/autopilot" project
  rm -rf "$base" && mkdir -p "$base"
  x_in "$base" project create --autopilot --stack python demo
  assert "without a terminal autopilot prints the plan and changes nothing" test ! -e "$base/demo"
  assert "the plan names the install commands" grep -q 'pip install -r requirements-dev.txt' "$XOUT"
  x_answers n "$base" project create --autopilot --stack python demo
  assert "anything but yes changes nothing" test ! -e "$base/demo"

  mkdir -p "$base/existing" && printf 'print(1)\n' >"$base/existing/app.py"
  x_answers y "$base" project create --autopilot --stack python existing
  assert "a folder with code stops and points to adopt" test "$XRC" -eq 2
  assert "it points to xaden project adopt" grep -q 'xaden project adopt' "$XOUT"
  assert "it changes nothing" test "$(ls -A "$base/existing")" = "app.py"

  PATH="$(path_without curl)" x_answers y "$base" project create --autopilot --stack python demo
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

  x_answers y "$base" project create --autopilot --stack node webapp
  assert "the node stack prints exact package versions" grep -q 'npm install --save-dev --save-exact eslint@10.12.0' "$XOUT"
  x_answers y "$base" project create --autopilot --stack python demo
  assert "an existing project is not touched again" test "$XRC" -eq 2
}

# REQ-066 `xaden project create` creates the same layout `xaden project adopt` gives an empty repository
test_new_project_layout() {
  local base="$WORKDIR/new-layout" project
  rm -rf "$base" && mkdir -p "$base"
  x_in "$base" project create demo
  project="$base/demo"
  assert "xaden project create succeeds" test "$XRC" -eq 0
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

  x_in "$base" project create demo
  assert "an existing project is not created again" test "$XRC" -eq 2
  x_in "$base" project create --assistants claude with-claude
  assert "--assistants claude adds CLAUDE.md with one line" test "$(cat "$base/with-claude/CLAUDE.md")" = "@AGENTS.md"
  x_in "$base" project create "Bad Name"
  assert "a bad project name is refused" test "$XRC" -ne 0
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.useConfigOnly GIT_CONFIG_VALUE_0=true x_in "$base" env -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL "$XADEN" project create fails
  assert "a failed creation fails" test "$XRC" -ne 0
  assert "a failed creation leaves no partial folder" test ! -e "$base/fails"
  x_in "$base" project create --classic classic
  assert "--classic is an unknown option and creates nothing (REQ-001)" test "$XRC" -ne 0 -a ! -e "$base/classic"
  x_in "$base" update
  assert "xaden update is an unknown command (REQ-001)" test "$XRC" -ne 0

  # a stack that appears later is noticed, and the preset can be added
  printf '{ "name": "demo" }\n' >"$project/package.json"
  x_in "$project" check
  assert "strict: a stack without checks is an error" test "$XRC" -ne 0
  assert "the gap is named" grep -q "gap: no 'test' check is configured" "$XOUT"
  x_in "$project" project preset node
  assert "xaden project preset adds the preset's configuration" test -f "$project/eslint.config.mjs"
  assert "xaden project preset maps the checks" grep -q '^check.lint = npx eslint \.$' "$project/xaden/xaden.conf"
  assert "xaden project preset prints the install command" grep -q 'npm install --save-dev --save-exact eslint@' "$XOUT"

  # release works without guides
  if need_tool gitleaks "release in an adopted project"; then
    local rel="$base/rel"
    x_in "$base" project create rel
    x_in "$rel" project release minor
    assert "a release is blocked while the security documents have TODO markers" test "$XRC" -ne 0
    assert "the unfilled documents are named" grep -q 'unfilled TODO marker' "$XOUT"
    sed -i.bak 's/<!-- TODO/<!-- done/' "$rel/SECURITY.md" "$rel/xaden/threat-model.md" && rm -f "$rel/SECURITY.md.bak" "$rel/xaden/threat-model.md.bak"
    git -C "$rel" add -A && git -C "$rel" -c core.hooksPath=/dev/null commit -q -m "docs: fill the security documents"
    x_in "$rel" project release minor
    assert "xaden project release succeeds in an adopted project" test "$XRC" -eq 0
    assert "release bumps VERSION and tags" bash -c 'test "$(cat "$1/VERSION")" = 0.1.0 && git -C "$1" tag | grep -qx v0.1.0' _ "$rel"
    assert "release stamps the changelog" grep -q '^## \[0.1.0\]' "$rel/CHANGELOG.md"
  fi
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

test_messages
test_scan_and_plan
test_adopt_and_remove
test_claude_commands
test_command_prefix_migration
test_other_assistant_commands
test_reuse_of_existing_tooling
test_prompts_and_ignore_list
test_autopilot
test_new_project_layout
