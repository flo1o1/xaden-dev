# shellcheck shell=bash
# Smoke test area "assistant-guidance" (docs/requirements/assistant-guidance). Sourced by tests/smoke.sh, which
# defines the helpers and creates the demo project first.

# read_denied <file-name>: true if a Read(./...) deny pattern in .claude/settings.json matches
# the name. Shell globs stand in for Claude Code's gitignore-style matching of plain names.
read_denied() {
  local pattern
  while IFS= read -r pattern; do
    # shellcheck disable=SC2254 # the pattern is meant to glob
    case "$1" in $pattern) return 0 ;; esac
  done < <(sed -n 's/^ *"Read(\.\/\(.*\))",*$/\1/p' "$PROJECT/.claude/settings.json")
  return 1
}

# rule_ids <file>: prints the sorted, unique CC-nn IDs a file mentions.
rule_ids() {
  grep -o 'CC-[0-9][0-9]' "$1" | sort -u
}

# REQ-002 tool-agnostic rules, REQ-005 security review, REQ-008 Obsidian vault
test_template_contents() {
  local pointer
  for pointer in CLAUDE.md .clinerules .continue/rules/project.md .github/copilot-instructions.md .aider.conf.yml; do
    assert "$pointer points to AGENTS.md" grep -q 'AGENTS.md' "$PROJECT/$pointer"
  done
  assert "/xaden-security runs the tool-agnostic review prompt" grep -q '@prompts/security-review.md' "$PROJECT/.claude/commands/xaden-security.md"
  # REQ-045 no personal skills, plugins or private tools: the generated project names none
  # optional-tools.md names a public plugin catalogue whose repository is called "skills" (REQ-053)
  assert_fails "generated project references no skills" grep -rli 'skill' "$PROJECT" --exclude-dir=.git --exclude=optional-tools.md
  assert "tool-agnostic security prompt present" grep -q 'OWASP' "$PROJECT/prompts/security-review.md"
  assert "Obsidian vault configured" test -f "$PROJECT/.obsidian/app.json"
  assert "shared Obsidian config stays tracked" bash -c "! git -C '$PROJECT' check-ignore -q .obsidian/app.json"
  assert "per-user Obsidian state is ignored" bash -c "git -C '$PROJECT' check-ignore -q .obsidian/workspace.json && git -C '$PROJECT' check-ignore -q .obsidian/appearance.json && git -C '$PROJECT' check-ignore -q .obsidian/plugins/x/data.json"
  assert "every prompt has frontmatter" bash -c "cd '$PROJECT/prompts' && for f in *.md; do head -1 \"\$f\" | grep -qx -- '---' || exit 1; done"
}

# REQ-027 proportional, consistent clean-code guidance
test_clean_code_guidance() {
  assert "every CC rule is explained in clean-code.md and none is invented there" \
    test "$(rule_ids "$PROJECT/AGENTS.md")" = "$(rule_ids "$PROJECT/docs/clean-code.md")"
  assert "CC-06 scope agrees in AGENTS.md and clean-code.md" \
    bash -c "grep -q 'CC-06.* Document public APIs' '$PROJECT/AGENTS.md' && grep -q '^- Document public' '$PROJECT/docs/clean-code.md'"
  assert "CC-05 accepts result and option types" grep -q 'exceptions, result or option types' "$PROJECT/AGENTS.md"
  assert "CC-09 forbids unrelated refactoring" grep -q 'No unrelated refactoring' "$PROJECT/AGENTS.md"
  # REQ-041 design, test and refactoring practices
  local practice
  for practice in 'Composition root' 'does work (an algorithm) or coordinates' 'polymorphic objects' \
    'hidden temporal coupling' 'Law of Demeter' 'Size heuristics' 'Name length follows scope' \
    'positive' 'A wrong comment is worse than none' 'English unless' 'Parallel implementation' \
    'characterization' 'check results and state' 'a test that cannot fail' 'Flaky tests' \
    'Test doubles replace' 'Pyramid' 'Given / When / Then'; do
    assert "clean-code guide covers: $practice" grep -q "$practice" "$PROJECT/docs/clean-code.md"
  done
  # REQ-044 linter configuration only gets stricter without approval
  assert "loosening linters is an approval point" grep -q 'raising a threshold, or adding an ignore or suppression is an \*\*Approval point' "$(rules_text "$PROJECT")"
  assert "linter baselines may only shrink" grep -q 'it may only shrink' "$(rules_text "$PROJECT")"
  assert "presets require approval to relax" bash -c "grep -q \"user's approval\" '$PROJECT/presets/node/eslint.config.mjs' && grep -q \"user's approval\" '$PROJECT/presets/python/ruff.toml'"
  assert "ESLint preset forbids var" grep -q '"no-var": "error"' "$PROJECT/presets/node/eslint.config.mjs"
}

# REQ-033 trusted instructions versus untrusted content, explicit approvals
test_assistant_trust_rules() {
  local item
  for item in 'issue and pull-request text' 'output of tools and dependencies' 'files in .inbox/.' \
    'authorise running commands' 'destructive or irreversible' 'adding, removing or upgrading dependencies' \
    'affecting production' 'sending code or data outside' 'reading, printing or changing secrets'; do
    assert "AGENTS.md trust rules cover: $item" grep -q -- "$item" "$PROJECT/AGENTS.md"
  done
}

# REQ-050 optional add-on rule sets: documented, never installed, never above AGENTS.md
test_add_on_rule_sets() {
  local guide="$SCAFFOLD_ROOT/docs/guide/admin/requirements-and-platforms.md" tools="$PROJECT/docs/optional-tools.md" add_on
  for add_on in Ponytail Caveman 'Token Optimizer' claude-mem obsidian-skills impeccable; do
    assert "guide lists $add_on as optional" grep -q "^| Optional: \\[$add_on\\]" "$guide"
  done
  assert "guide points to optional-tools.md for add-on details" grep -q 'risks to know before installing are in .template/docs/optional-tools.md.' "$guide"
  assert_fails "guide does not repeat add-on install commands" grep -q 'plugin install' "$guide"
  assert "Ponytail Claude Code install is documented" grep -q 'plugin install ponytail@ponytail' "$tools"
  assert "Ponytail names the AGENTS.md route for other tools" grep -q "can use its .AGENTS.md." "$tools"
  assert "Caveman install is documented" grep -q 'plugin install caveman@caveman' "$tools"
  assert "project files stay out of Caveman compression" grep -q 'Keep project files in normal prose' "$tools"
  assert "Token Optimizer install is documented" grep -q 'plugin install token-optimizer@alexgreensh-token-optimizer' "$tools"
  assert "Token Optimizer license is stated" grep -q 'PolyForm Noncommercial' "$tools"
  assert "compressed output never replaces verbatim failures" grep -q 'quote failing lines from the full output' "$tools"
  assert "the on-disk archive of tool output is disclosed" grep -q 'credentials removed by pattern' "$tools"
  assert "claude-mem install is documented" grep -q 'plugin install claude-mem' "$tools"
  assert "claude-mem session store is disclosed" grep -q '/\.claude-mem`' "$tools"
  assert "claude-mem hosted service is disclosed" grep -q 'receives session content' "$tools"
  assert "obsidian-skills install is documented" grep -q 'plugin install obsidian@obsidian-skills' "$tools"
  assert "Obsidian syntax is limited to prompts/" grep -q 'stay plain Markdown, because other assistants' "$tools"
  assert "impeccable install is documented" grep -q 'plugin install impeccable@impeccable' "$tools"
  assert "impeccable network calls and telemetry opt-out are disclosed" grep -q '"telemetry": false' "$tools"
  assert "impeccable edit hook and how to skip it are disclosed" grep -q -- '--no-hooks' "$tools"
  assert_fails "new projects enable no plugin" grep -qi 'plugin' "$PROJECT/.claude/settings.json"
  assert "AGENTS.md ranks add-on rule sets below itself" grep -q 'they never override this file' "$PROJECT/AGENTS.md"
}

# REQ-063 opusplan is a documented option; the template pins no model
test_model_routing_option() {
  local claude_md="$PROJECT/CLAUDE.md"
  assert "CLAUDE.md names opusplan for the session" grep -q '/model opusplan' "$claude_md"
  assert "CLAUDE.md keeps opusplan in local settings" grep -q '"model": "opusplan". in .\.claude/settings\.local\.json' "$claude_md"
  assert "CLAUDE.md names the fallback without Opus" grep -q '/model sonnet., the prompts work unchanged' "$claude_md"
  assert "CLAUDE.md explains per-command model front matter" grep -q 'it applies to the current turn only' "$claude_md"
  assert_fails "project settings pin no model" grep -q '"model"' "$PROJECT/.claude/settings.json"
  assert_fails "no command pins a model" grep -lq '^model:' "$PROJECT"/.claude/commands/*.md
}

# REQ-034 accurate Claude Code permission rules
test_claude_permissions() {
  local secret
  for secret in .env .env.local .env.production.local .env.development .env.test .env.staging .env.production; do
    assert "Read denied for $secret" read_denied "$secret"
  done
  assert_fails "Read allowed for .env.example (documentation prompt needs it)" read_denied .env.example
  assert "force-push variants denied" bash -c "grep -q 'git push -f:' '$PROJECT/.claude/settings.json' && grep -q 'git push --force-with-lease:' '$PROJECT/.claude/settings.json'"
  assert "CLAUDE.md states the limits" grep -q 'not a security boundary' "$PROJECT/CLAUDE.md"
  if need_tool python3 "settings.json syntax"; then
    assert "settings.json is valid JSON" python3 -m json.tool "$PROJECT/.claude/settings.json"
  fi
}

# REQ-110 a human owns and merges every change an assistant prepares
# shellcheck disable=SC2016 # the bash -c scripts read their file as $1
test_human_merges() {
  local rules="$PROJECT/AGENTS.md"
  assert "REQ-110 the rules say the assistant never merges its own pull request" bash -c 'tr "\n" " " <"$1" | grep -q "never merges it"' _ "$rules"
  assert "REQ-110 the rules let the person tell it to merge one named pull request" bash -c 'tr "\n" " " <"$1" | grep -q "tells it to in that session"' _ "$rules"
  assert "REQ-110 an assistant trailer discloses and does not replace the author" bash -c 'tr "\n" " " <"$1" | grep -q "Co-Authored-By.*does not replace the author"' _ "$rules"
  assert "REQ-110 Signed-off-by is optional" bash -c 'tr "\n" " " <"$1" | grep -q "Signed-off-by.* optional"' _ "$rules"
  assert "REQ-110 gh pr merge needs a confirmation in Claude Code" bash -c "tr -d ' \n' <'$PROJECT/.claude/settings.json' | grep -q '\"ask\":\\[\"Bash(ghprmerge:\*)\"\\]'"
  assert "REQ-110 CLAUDE.md says the ask rule is a convenience guard" bash -c 'tr "\n" " " <"$1" | grep -q "ask. rule makes Claude Code ask before .gh pr merge"' _ "$PROJECT/CLAUDE.md"
  if need_tool python3 "settings.json ask rule"; then
    assert "REQ-110 the ask entry is valid JSON" python3 -c 'import json,sys; assert "Bash(gh pr merge:*)" in json.load(open(sys.argv[1]))["permissions"]["ask"]' "$PROJECT/.claude/settings.json"
  fi
  assert "REQ-110 the landing section lets the maintainer merge" bash -c 'tr "\n" " " <"$1" | grep -qi "the maintainer merges"' _ "$SCAFFOLD_ROOT/AGENTS.md"
  assert "REQ-110 the landing section no longer hands the merge to the assistant" bash -c '! grep -q "# when both checks are green" "$1"' _ "$SCAFFOLD_ROOT/AGENTS.md"
  assert "REQ-110 the guide says the person merges" bash -c 'tr "\n" " " <"$1" | grep -q "you review and merge the pull request"' _ "$SCAFFOLD_ROOT/docs/guide/developer/build-features.md"
}

# REQ-112 merge and site-follow-up rules live in the scaffold's own rule file
# shellcheck disable=SC2016 # the bash -c scripts read their file as $1
test_merge_rules_in_repo() {
  local rules="$SCAFFOLD_ROOT/AGENTS.md"
  assert "REQ-112 no merge request before both checks are green" bash -c 'tr "\n" " " <"$1" | grep -q "Never ask for a merge before both CI checks are green"' _ "$rules"
  assert "REQ-112 several pull requests merge in dependency order" bash -c 'tr "\n" " " <"$1" | grep -q "dependency order.*mergeable"' _ "$rules"
  assert "REQ-112 a failed merge never uses --admin" bash -c 'tr "\n" " " <"$1" | grep -q "never use .--admin"' _ "$rules"
  assert "REQ-112 a documentation change needs a site follow-up" bash -c 'tr "\n" " " <"$1" | grep -q "needs a site follow-up"' _ "$rules"
}

# REQ-111 the assistant explains what it did and says what it cannot judge
# shellcheck disable=SC2016 # the bash -c scripts read their file as $1
test_judgment_stays_human() {
  local rules="$PROJECT/AGENTS.md" section name
  section="$(awk '/^### Judgment stays with the human/ { on = 1; print; next } on && /^##/ { exit } on { print }' "$rules")"
  assert "REQ-111 the rules have the section" test -n "$section"
  assert "REQ-111 the section is at most 1 KB" test "$(printf '%s' "$section" | wc -c | tr -d ' ')" -le 1024
  assert "REQ-111 it asks for an explanation and a way to check" bash -c 'tr -s "[:space:]" " " <<<"$1" | grep -q "Explain a non-trivial change.*one way to check it"' _ "$section"
  assert "REQ-111 it names what the assistant cannot evaluate" bash -c 'tr -s "[:space:]" " " <<<"$1" | grep -q "Say what you cannot evaluate"' _ "$section"
  assert "REQ-111 a second failed attempt is a signal" bash -c 'tr -s "[:space:]" " " <<<"$1" | grep -q "second failed attempt.*inspect scope, context, assumptions and tests"' _ "$section"
  assert "REQ-119 a retry names what changes first and says what changed" bash -c 'tr -s "[:space:]" " " <<<"$1" | grep -q "Before you retry, name which of scope, names, tests or context you will change, and say in one line what you changed"' _ "$section"
  assert "REQ-119 the rule is in the scaffold template too" bash -c 'tr -s "[:space:]" " " <"$1" | grep -q "name which of scope, names, tests or context you will change"' _ "$SCAFFOLD_ROOT/template/AGENTS.md"
  assert "REQ-120 a session that lost coherence is named and restarted from the files" bash -c 'tr -s "[:space:]" " " <<<"$1" | grep -q "lost coherence: say so and propose a fresh session.*xaden context.*enough to resume"' _ "$section"
  assert "REQ-120 the rule is in the scaffold template too" bash -c 'tr -s "[:space:]" " " <"$1" | grep -q "lost coherence: say so and propose a fresh session"' _ "$SCAFFOLD_ROOT/template/AGENTS.md"
  assert "REQ-120 the guide explains how to restart a session" grep -q '^## Restart a session' "$SCAFFOLD_ROOT/docs/guide/developer/build-features.md"
  assert "REQ-111 lessons go to docs/decisions after approval" bash -c 'tr -s "[:space:]" " " <<<"$1" | grep -q "docs/decisions/.*only after the user approves"' _ "$section"
  for name in feature bugfix refactor; do
    assert "REQ-111 the $name prompt points to the section" grep -q 'AGENTS.md §9 (Judgment stays with the human)' "$PROJECT/prompts/$name.md"
  done
}

# REQ-123 a small change takes a short path, a large change the full one
# shellcheck disable=SC2016 # the bash -c scripts read their file as $1
test_size_the_task() {
  local rules="$PROJECT/AGENTS.md" section small name
  section="$(awk '/^### Size the task/ { on = 1; print; next } on && /^##/ { exit } on { print }' "$rules")"
  assert "REQ-123 the rules have the size table" test -n "$section"
  assert "REQ-123 the assistant states the size and the user can overrule it" bash -c 'tr -s "[:space:]" " " <<<"$1" | grep -q "say its size and why in one line.*user can overrule it"' _ "$section"
  assert "REQ-123 the size is guidance, not a check" bash -c 'tr -s "[:space:]" " " <<<"$1" | grep -q "not a check; hooks and .scripts/check.sh. run the same for every size"' _ "$section"
  assert "REQ-123 small is at most 2 files and no new surface" bash -c 'tr -s "[:space:]" " " <<<"$1" | grep -q "one approved requirement covers it, at most 2 files, no new dependency, no new input, auth, data, files or network surface"' _ "$section"
  assert "REQ-123 large writes the plan to docs/architecture.md" bash -c 'tr -s "[:space:]" " " <<<"$1" | grep -q "new structure, a new dependency or more than one epic.*docs/architecture.md.*each a normal change"' _ "$section"
  assert "REQ-123 a change that grows switches to the normal flow" bash -c 'tr -s "[:space:]" " " <<<"$1" | grep -q "touches a third file.*size changed and switch to the normal flow"' _ "$section"
  assert "REQ-123 several goals are listed and the user decides" bash -c 'tr -s "[:space:]" " " <<<"$1" | grep -q "two or more independently shippable goals.*the user decides"' _ "$section"
  small="$(grep '^| small ' <<<"$section")"
  for name in "test first" "scripts/check.sh" "Refs:" "changelog bullet" "guide update" "quick review of the diff"; do
    assert "REQ-123 the small path keeps: $name" bash -c 'tr -s "[:space:]" " " <<<"$1" | grep -qF "$2"' _ "$small" "$name"
  done
  for name in feature bugfix refactor; do
    assert "REQ-123 the $name prompt points to the size table" grep -q 'AGENTS.md §9 (Size the task)' "$PROJECT/prompts/$name.md"
  done
}

# REQ-122 assistants cite a requirement with epic, title and ID
# shellcheck disable=SC2016 # the bash -c scripts read their file as $1
test_cite_requirement_in_full() {
  assert "REQ-122 the rules ask for epic, title and ID, never the ID alone" \
    bash -c 'tr -s "[:space:]" " " <"$1" | grep -q "Name a requirement with its epic, title and ID, never the ID alone"' _ "$PROJECT/AGENTS.md"
}

# REQ-035 one workflow and approval model across prompts
test_prompt_workflow() {
  local prompts="$PROJECT/prompts" name
  for name in kickoff feature bugfix refactor requirements-update security-review release; do
    assert "$name prompt marks its approval points" grep -q '\*\*Approval point' "$prompts/$name.md"
  done
  assert "AGENTS.md defines approval points and prior approval" grep -q 'already approved that exact step' "$PROJECT/AGENTS.md"
  assert_fails "no prompt uses an unmarked wait phrase" grep -lE 'Wait for my confirmation|Ask me before installing|wait for my OK' "$prompts"/*.md
  assert_fails "feature prompt does not skip requirement approval" grep -q 'status .in-progress.) and' "$prompts/feature.md"
  assert "bugfix is regression-test first" grep -q 'Do not change production code before the test fails' "$prompts/bugfix.md"
  # REQ-036 truthful completion report
  local rules
  rules="$(rules_text "$PROJECT")"
  assert "AGENTS.md defines the completion report" bash -c "grep -q '^  COMPLETION REPORT' '$rules' && grep -q 'Checks skipped:' '$rules' && grep -q 'Acceptance evidence:' '$rules'"
  assert "skipped checks are never reported as passed" grep -q 'listed as skipped,' "$(rules_text "$PROJECT")"
  for name in kickoff feature bugfix refactor requirements-update security-review release documentation; do
    assert "$name prompt ends with the completion report" grep -q 'Completion report given' "$prompts/$name.md"
  done
  # REQ-037 honest docs checks, operations guidance
  assert "docs check says it verifies structure only" grep -q 'structure only' <("$PROJECT/scripts/check-docs.sh")
  assert "AGENTS.md says docs check is structure only" grep -q 'It checks structure only' "$(rules_text "$PROJECT")"
  for topic in 'timeouts' 'bounded retries' 'graceful shutdown' 'health checks' 'no secrets or personal data' \
    'rollback path' 'actually tested'; do
    assert "documentation prompt asks for: $topic" grep -q "$topic" "$prompts/documentation.md"
  done
  assert "admin guide asks when the restore was tested" grep -q 'restore was last tested' "$PROJECT/docs/admin-guide.md"
  assert "feature refactors first only when needed" grep -q 'refactor first (\[\[refactor\]\]' "$prompts/feature.md"
}

# REQ-060: changes are committed on feature branches; the hooks refuse commits on main.
test_branch_rule() {
  local empty="$WORKDIR/empty-repo"
  printf 'x\n' >>"$PROJECT/notes.txt" && git -C "$PROJECT" add notes.txt
  assert_fails_with "commit on main refused" "git worktree add" \
    env ALLOW_MAIN_COMMIT=0 git -C "$PROJECT" commit -q -m "docs: straight to main"
  assert "ALLOW_MAIN_COMMIT=1 permits a commit on main" \
    env ALLOW_MAIN_COMMIT=1 git -C "$PROJECT" commit -q -m "docs: allowed on main"
  git -C "$PROJECT" reset -q --hard HEAD~1

  git -C "$PROJECT" checkout -q -b docs/notes
  printf 'branch\n' >"$PROJECT/notes.txt" && git -C "$PROJECT" add notes.txt
  assert "commit on a feature branch allowed" env ALLOW_MAIN_COMMIT=0 git -C "$PROJECT" commit -q -m "docs: notes on a branch"
  git -C "$PROJECT" checkout -q main
  printf 'main\n' >"$PROJECT/notes.txt" && git -C "$PROJECT" add notes.txt
  git -C "$PROJECT" commit -q -m "docs: conflicting notes on main"
  git -C "$PROJECT" merge -q docs/notes >/dev/null 2>&1 || true
  printf 'merged\n' >"$PROJECT/notes.txt" && git -C "$PROJECT" add notes.txt
  assert "concluding a merge on main allowed" env ALLOW_MAIN_COMMIT=0 git -C "$PROJECT" commit -q --no-edit
  git -C "$PROJECT" reset -q --hard HEAD~2 && git -C "$PROJECT" branch -q -D docs/notes

  git init -q -b main "$empty"
  assert_fails_with "scaffold hook refuses commits on main" "git worktree add" \
    bash -c "cd '$empty' && ALLOW_MAIN_COMMIT=0 '$SCAFFOLD_ROOT/.githooks/pre-commit'"
  assert "AGENTS.md tells assistants to use a branch and worktree per change" \
    grep -q 'git worktree add worktrees/<slug> -b <type>/<slug> main' "$(rules_text "$PROJECT")"
}

# shellcheck disable=SC2016 # the bash -c scripts read their file as $1
# REQ-082: a requirement is approved before any branch or worktree exists; the worktree starts sparse.
test_approve_before_branch() {
  local rules feature="$SCAFFOLD_ROOT/template/prompts/feature.md"
  local draft add approval creation file repo="$WORKDIR/sparse-repo" tree="$WORKDIR/sparse-repo-req-001-x"
  rules="$(rules_text "$SCAFFOLD_ROOT/template")"
  draft="$(grep -n 'Draft the requirement' "$rules" | head -n1 | cut -d: -f1)"
  add="$(grep -n 'worktree add --no-checkout' "$rules" | head -n1 | cut -d: -f1)"
  assert "the rules draft the requirement before they create the worktree" test -n "$draft" -a "${draft:-9}" -lt "${add:-0}"
  assert "the rules start the worktree sparse and widen it for the implementation" \
    bash -c 'grep -q "sparse-checkout set --cone docs/requirements scripts" "$1" && grep -q "sparse-checkout disable" "$1"' _ "$rules"
  approval="$(grep -n 'Approval point' "$feature" | head -n1 | cut -d: -f1)"
  creation="$(grep -n 'req.sh new' "$feature" | head -n1 | cut -d: -f1)"
  assert "the feature prompt asks for approval before it creates a requirement file" test -n "$approval" -a "${approval:-9}" -lt "${creation:-0}"
  for file in "$SCAFFOLD_ROOT/AGENTS.md" "$rules" "$SCAFFOLD_ROOT"/template/prompts/*.md; do
    assert "no 'branch per change first' rule in ${file#"$SCAFFOLD_ROOT"/}" bash -c '! grep -Eq "^- One branch per change" "$1"' _ "$file"
  done

  mkdir -p "$repo/docs/requirements" "$repo/scripts" "$repo/src"
  git init -q -b main "$repo"
  printf 'r\n' >"$repo/docs/requirements/a.md" && printf 's\n' >"$repo/scripts/a.sh" && printf 'big\n' >"$repo/src/big.txt"
  git -C "$repo" add -A && git -C "$repo" commit -q -m "docs: scratch"
  git -C "$repo" worktree add -q --no-checkout -b feat/req-001-x "$tree" main
  git -C "$tree" sparse-checkout set --cone docs/requirements scripts
  git -C "$tree" checkout -q
  assert "the sparse worktree has the requirements and the scripts" test -f "$tree/docs/requirements/a.md" -a -f "$tree/scripts/a.sh"
  assert "the sparse worktree leaves the rest out" test ! -e "$tree/src/big.txt"
  git -C "$tree" sparse-checkout disable
  assert "sparse-checkout disable restores the full tree" test -f "$tree/src/big.txt"
}

# REQ-053 optional assistant plugins are documented, not installed
test_assistant_plugins() {
  local doc="$PROJECT/docs/optional-tools.md" item
  for item in 'code-review@claude-plugins-official' 'trailofbits/skills' 'ponytail@ponytail' \
    'takes precedence over them' 'Not recommended'; do
    assert "optional tools document covers: $item" grep -q -- "$item" "$doc"
  done
  assert "/xaden-review offers ponytail-review as an optional second pass" \
    grep -q 'Optional second pass: if the Ponytail plugin is installed' "$PROJECT/.claude/commands/xaden-review.md"
}

# REQ-054 look for mature existing solutions before building
test_look_before_build() {
  local item
  for item in 'Look before you build' 'search the web for a mature solution' 'name, one-line summary, license, website' \
    'No web access: say so'; do
    assert "AGENTS.md rule covers: $item" grep -q -- "$item" "$(rules_text "$PROJECT")"
  done
  assert "feature prompt applies the rule" grep -q 'Look before you build (AGENTS.md' "$PROJECT/prompts/feature.md"
}

# REQ-079 Xaden supports only assistants with file access: no context pack is left anywhere.
# The pattern is spelled with brackets so this file does not match itself; the changelog,
# the requirements and the security reviews keep the history and are not searched.
test_no_context_pack() {
  local hits
  hits="$(cd "$SCAFFOLD_ROOT" || exit 1; grep -rIlE 'pack[-]context|context[-]pack|xaden[ ]pack' scripts template tests docs/guide \
    docs/threat-model.md README.md GETTING-STARTED.md .gitignore 2>/dev/null || true)"
  assert "no file mentions the context pack: ${hits:-none}" test -z "$hits"
  assert_fails "xaden has no pack command" "$SCAFFOLD_ROOT/scripts/xaden.sh" pack
  assert "AGENTS.md says Xaden needs file access" grep -q 'Xaden needs an assistant with file access' "$PROJECT/AGENTS.md"
}

# REQ-061 user personas that assistants check solutions against
test_personas() {
  local copy="$WORKDIR/variants/personas" persona name
  rm -rf "$copy" && mkdir -p "$WORKDIR/variants" && cp -R "$PROJECT" "$copy"
  persona="$copy/docs/personas/ada-admin.md"
  assert "persona.sh new creates the persona file" bash -c "'$copy/scripts/persona.sh' new 'Ada Admin' | grep -qx 'docs/personas/ada-admin.md'"
  assert "persona name and date are filled in" bash -c "grep -qx 'name: Ada Admin' '$persona' && grep -Eq '^updated: [0-9]{4}-[0-9]{2}-[0-9]{2}$' '$persona' && ! grep -q '{{' '$persona'"
  assert "persona sections are prefilled" bash -c "grep -q '^## A solution fails this persona when' '$persona' && grep -q '^TODO: ' '$persona'"
  printf 'edited\n' >>"$persona"
  assert_fails_with "an existing persona is not overwritten" 'exists already' "$copy/scripts/persona.sh" new 'Ada Admin'
  assert "the existing persona keeps its content" grep -qx 'edited' "$persona"
  assert_fails_with "a name that breaks the file is rejected" 'without' "$copy/scripts/persona.sh" new 'a/b'
  for name in Ben Cleo Dan Eve; do "$copy/scripts/persona.sh" new "$name" >/dev/null; done
  assert "a sixth persona warns about focus" bash -c "'$copy/scripts/persona.sh' new Finn 2>&1 | grep -q '3 to 5'"
  # REQ-061: a dangling link in docs/personas/ must not make persona.sh write outside the project.
  ln -s "$WORKDIR/outside-persona" "$copy/docs/personas/mallory.md"
  assert_fails_with "persona.sh refuses a dangling symbolic link" 'exists already' "$copy/scripts/persona.sh" new Mallory
  assert_fails "nothing is written through the link" test -e "$WORKDIR/outside-persona"
  rm "$copy/docs/personas/mallory.md"
  assert "AGENTS.md checks solutions against personas" grep -q 'against each one; name the persona it fails' "$(rules_text "$PROJECT")"
  for name in kickoff feature code-review; do
    assert "$name prompt uses the personas" grep -q 'docs/personas\|\[\[persona\]\]' "$PROJECT/prompts/$name.md"
  done
  assert "/xaden-persona runs the persona prompt" grep -qx '@prompts/persona.md' "$PROJECT/.claude/commands/xaden-persona.md"
  assert "the scaffold manages the persona template" is_managed docs/personas/0000-template.md
  assert_fails "the scaffold never manages project personas" is_managed docs/personas/ada-admin.md
}

# REQ-055, REQ-091 maintainers use the project commands on the scaffold itself
test_scaffold_commands() {
  local name prompt
  for name in bugfix refactor review security feature requirements release persona; do
    prompt="$(sed -n 's|^@template/prompts/\(.*\)$|\1|p' "$SCAFFOLD_ROOT/.claude/commands/xaden-$name.md")"
    assert "/$name includes an existing template prompt" test -n "$prompt" -a -f "$SCAFFOLD_ROOT/template/prompts/$prompt"
  done
  for name in kickoff docs; do
    assert_fails "REQ-091 /$name stays out of the scaffold" test -e "$SCAFFOLD_ROOT/.claude/commands/xaden-$name.md"
  done
  assert "AGENTS.md maps the release script" grep -q 'release-scaffold.sh' "$SCAFFOLD_ROOT/AGENTS.md"
  assert "AGENTS.md names the commands left out" grep -q 'xaden-kickoff.*xaden-docs' "$SCAFFOLD_ROOT/AGENTS.md"
  assert "AGENTS.md maps prompt paths for the scaffold" grep -q '^## Using the project commands here' "$SCAFFOLD_ROOT/AGENTS.md"
  assert "scaffold threat model names entry points" grep -q '^## Entry points' "$SCAFFOLD_ROOT/docs/threat-model.md"
  assert_fails "projects get no scaffold commands" grep -rq 'template/prompts' "$PROJECT/.claude/commands"
  assert_fails "projects get no scaffold threat model" grep -q 'Xaden' "$PROJECT/docs/threat-model.md"
}

# REQ-085 xaden runs the project commands on the scaffold itself
test_xaden_in_scaffold() {
  local xaden="$SCAFFOLD_ROOT/scripts/xaden.sh" lookalike
  assert "xaden req shows a scaffold requirement" bash -c "cd '$SCAFFOLD_ROOT' && '$xaden' req show REQ-055 | grep -q '^id: REQ-055'"
  assert "xaden context covers the scaffold rules" bash -c "cd '$SCAFFOLD_ROOT' && '$xaden' context | grep -q '^rules: CC-01 '"
  # a full run would recurse into this test; a bad flag proves the dispatch to check-scaffold.sh
  assert "xaden check runs check-scaffold.sh" bash -c "cd '$SCAFFOLD_ROOT' && '$xaden' check --bogus 2>&1 | grep -q 'check-scaffold.sh'"
  lookalike="$(mktemp -d)"
  git -C "$lookalike" init -q
  mkdir -p "$lookalike/template/scripts"
  : >"$lookalike/template/scripts/req.sh"
  assert "a repository with only a template folder is no scaffold" bash -c "cd '$lookalike' && '$xaden' req list 2>&1 | grep -q 'not a Xaden project'"
  rm -rf "$lookalike"
}

# REQ-126 the rules loaded in every session stay small; the rest is read when a task needs it
test_small_context() {
  local rules="$PROJECT/AGENTS.md" file topic before after message copy
  assert "REQ-126 AGENTS.md stays under 10240 bytes" test "$(wc -c <"$rules")" -le 10240
  for topic in checks docs git requirements security working-style; do
    assert "REQ-126 AGENTS.md names docs/rules/$topic.md with a trigger" grep -Eq "^(- )?Before .*read \`docs/rules/$topic\.md\`" "$rules"
    assert "REQ-126 docs/rules/$topic.md exists" test -s "$PROJECT/docs/rules/$topic.md"
  done
  for file in "$PROJECT"/docs/rules/*.md; do
    assert "REQ-126 ${file##*/} is named in AGENTS.md" grep -q "docs/rules/$(basename "$file")" "$rules"
  done
  assert "REQ-126 the rules that stay in AGENTS.md keep their IDs and wording" bash -c "grep -q '^- \*\*CC-09\*\*' '$rules' \
    && grep -q 'Ask the user first' '$rules' && grep -q '^### Judgment stays with the human' '$rules' && grep -q '^### Size the task' '$rules' \
    && grep -q 'never merges it' '$rules' && grep -q 'is an \*\*Approval point' '$rules'"
  assert "REQ-126 the moved text is wording unchanged" bash -c "grep -q 'Lifecycle: .draft. (idea)' '$PROJECT/docs/rules/requirements.md' \
    && grep -q 'it may only shrink' '$PROJECT/docs/rules/checks.md' && grep -q 'Conventional Commits' '$PROJECT/docs/rules/git.md'"
  copy="$WORKDIR/variants/rules-fingerprint"
  rm -rf "$copy" && mkdir -p "$WORKDIR/variants" && cp -R "$PROJECT" "$copy"
  before="$("$copy/scripts/context-status.sh")"
  before="${before%%$'\n'*}" # the CONTEXT CHECK line; head would break the pipe of the script
  printf '\n' >>"$copy/docs/rules/git.md"
  after="$("$copy/scripts/context-status.sh")"
  after="${after%%$'\n'*}"
  assert "REQ-126 a change in docs/rules/ reaches the context fingerprint" test "$before" != "$after"
  message="$WORKDIR/unknown-ref-message"
  printf 'feat: x\n\nRefs: REQ-%s\n' 999 >"$message" # an ID no requirement has; spelled in parts so traceability does not read it as a citation
  assert_fails_with "REQ-126 a failing commit check names the file that holds the rule" 'docs/rules/git.md' \
    bash -c "cd '$PROJECT' && scripts/verify-refs.sh '$message'"
}

test_template_contents
test_clean_code_guidance
test_assistant_trust_rules
test_add_on_rule_sets
test_model_routing_option
test_claude_permissions
test_human_merges
test_merge_rules_in_repo
test_judgment_stays_human
test_size_the_task
test_cite_requirement_in_full
test_prompt_workflow
test_branch_rule
test_approve_before_branch
test_assistant_plugins
test_look_before_build
test_personas
test_scaffold_commands
test_xaden_in_scaffold
test_no_context_pack
test_small_context
