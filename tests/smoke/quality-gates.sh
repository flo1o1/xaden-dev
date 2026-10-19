# shellcheck shell=bash
# Smoke test area "quality-gates" (docs/requirements/quality-gates). Sourced by tests/smoke.sh, which
# defines the helpers and creates the demo project first.

# msg <text with \n escapes>: writes a commit message file (git passes a regular file to hooks); prints its path.
msg() {
  printf '%b' "$1" >"$WORKDIR/commit-msg.txt"
  printf '%s' "$WORKDIR/commit-msg.txt"
}

# fake_tools <name...>: a directory of stand-in commands that report a finding and fail.
fake_tools() {
  local bin="$WORKDIR/fake-tools" name
  mkdir -p "$bin"
  for name in "$@"; do
    printf '#!/bin/sh\necho "fake finding from %s"\nexit 1\n' "$name" >"$bin/$name"
    chmod +x "$bin/$name"
  done
  printf '%s' "$bin"
}

# REQ-025 passed assertions are silent unless SMOKE_VERBOSE=1; failures always print
test_quiet_output() {
  assert "passed assertions print nothing by default" test -z "$(SMOKE_VERBOSE=0 pass probe)"
  assert "SMOKE_VERBOSE=1 prints passed assertions" test "$(SMOKE_VERBOSE=1 pass probe)" = "ok   probe"
  # one area can run alone: tests/smoke.sh <area>
  assert "smoke test lists its areas" test "$("$SCAFFOLD_ROOT/tests/smoke.sh" --list | tr '\n' ' ')" = \
    "adoption-setup adoption-versions adoption-checks assistant-guidance project-setup quality-gates requirements security release-and-docs "
  # REQ-121 every test function of the adoption library's areas is called in exactly one of them
  local adoption_files="$SCAFFOLD_ROOT/tests/smoke/adoption-setup.sh $SCAFFOLD_ROOT/tests/smoke/adoption-versions.sh $SCAFFOLD_ROOT/tests/smoke/adoption-checks.sh"
  # shellcheck disable=SC2086 # the three file names hold no spaces
  assert "REQ-121 each adoption test function is defined and called in exactly one area" test -z "$(
    {
      grep -h '^test_[a-z_]*() {' $adoption_files | sed 's/() {//' | sort -u
      grep -h '^test_[a-z_]*$' $adoption_files
    } | sort | uniq -c | grep -v '^ *2 ' | grep .
  )"
  assert_fails_with "smoke test rejects an unknown area" 'unknown area' "$SCAFFOLD_ROOT/tests/smoke.sh" no-such-area
}

# REQ-004 static analysis, REQ-006 requirements tracking, REQ-010 docs, REQ-011 grounding
test_generated_project() {
  assert "checks pass" "$PROJECT/scripts/check.sh"
  assert "docs structure valid" "$PROJECT/scripts/check-docs.sh"
  assert_fails "docs check --release flags TODOs" "$PROJECT/scripts/check-docs.sh" --release
  assert_fails "bad commit message rejected" "$PROJECT/scripts/hooks/commit-msg" "$(msg "did stuff\n")"
  assert_fails "feat citing a draft requirement rejected (REQ-021)" "$PROJECT/scripts/hooks/commit-msg" "$(msg 'feat(api): add endpoint\n\nRefs: REQ-001\n')"
  set_status REQ-001 approved
  git -C "$PROJECT" add docs/requirements
  assert "feat citing an approved requirement accepted" "$PROJECT/scripts/hooks/commit-msg" "$(msg 'feat(api): add endpoint\n\nRefs: REQ-001\n')"
  git -C "$PROJECT" reset -q --hard
  assert_fails "feat without Refs rejected" "$PROJECT/scripts/hooks/commit-msg" "$(msg 'feat(api): add endpoint\n')"
  assert_fails "invented requirement ID rejected" "$PROJECT/scripts/hooks/commit-msg" "$(msg 'feat(api): add x\n\nRefs: REQ-042\n')" # traceability: ignore
  assert_fails "invented rule ID rejected" "$PROJECT/scripts/hooks/commit-msg" "$(msg 'refactor: tidy per CC-77\n')"
  assert "fix with Refs none accepted" "$PROJECT/scripts/hooks/commit-msg" "$(msg 'fix: typo\n\nRefs: none\n')"
  assert "req.sh shows known requirement" "$PROJECT/scripts/req.sh" show REQ-001
  assert_fails "req.sh rejects unknown requirement" "$PROJECT/scripts/req.sh" show REQ-999 # traceability: ignore
  assert "context status lists rules" grep -q 'CC-09' <("$PROJECT/scripts/context-status.sh")
  # REQ-011: counts per status, IDs only for requirements not done (the list stays short)
  assert "context status counts requirements per status" grep -qx 'requirements: 1 (1 draft); not done: REQ-001(draft)' <("$PROJECT/scripts/context-status.sh")
  assert "context status leaves out done requirement IDs" bash -c "PROJECT_ROOT='$SCAFFOLD_ROOT' RULES_FILE='$SCAFFOLD_ROOT/template/AGENTS.md' '$SCAFFOLD_ROOT/template/scripts/context-status.sh' | grep -E '^requirements: [0-9]+ \([0-9]+ done' | grep -qv 'REQ-002'"
  # REQ-028 threat model at kickoff
  assert "project has a threat model with an ASVS level" grep -q 'ASVS level' "$PROJECT/docs/threat-model.md"
  assert "kickoff fills the threat model" grep -q 'docs/threat-model.md' "$PROJECT/prompts/kickoff.md"
  assert "security review reads the threat model" grep -q 'docs/threat-model.md' "$PROJECT/prompts/security-review.md"
  # REQ-029 precise security checklist
  local topic
  for topic in 'not a replacement' 'DNS rebinding' 'hard links' 'size limit before reading' \
    'tenant A cannot reach' 'revoke sessions' 'Password reset' 'Rate and resource limits' \
    'Safe parsing' 'Data retention' '## Web applications \*(web)\*'; do
    assert "security checklist covers: $topic" grep -q "$topic" "$PROJECT/docs/security.md"
  done
  # REQ-039 WSTG test areas missing so far, in checklist and review prompt
  for topic in 'open redirect' 'parameter pollution' 'response splitting' 'request smuggling' \
    'LDAP' 'file inclusion' 'vertical privilege escalation' 'user enumeration' 'default or shared accounts' \
    'session tokens in URLs' 'Strict-Transport-Security' '\.git/' 'is public: no secrets there' \
    'at rest' 'separate origin' 'upload frequency' 'Anti-automation' 'LIKE' 'ReDoS' 'audit trail' \
    'Separate duties' 'postMessage' 'localStorage' 'PCI DSS'; do
    assert "security checklist covers: $topic" grep -qi "$topic" "$PROJECT/docs/security.md"
  done
  for topic in 'open redirects' 'privilege escalation' 'user enumeration' 'ReDoS' 'request' \
    'smuggling' 'postMessage' 'segregation of duties'; do
    assert "security review checks: $topic" grep -qi "$topic" "$PROJECT/prompts/security-review.md"
  done
  assert_fails "obsolete technologies left out" grep -Eqi 'flash|silverlight|cvss v2' "$PROJECT/docs/security.md" "$PROJECT/prompts/security-review.md"
  # REQ-030 dependency policy with accountable exceptions
  for topic in '^## Dependencies' 'Lockfiles' 'Licenses' 'install scripts' 'Updates'; do
    assert "dependency policy covers: $topic" grep -q "$topic" "$PROJECT/docs/security.md"
  done
  assert "exceptions need owner and expiry" grep -q '| Owner | Expires (YYYY-MM-DD) |' "$PROJECT/docs/security-exceptions.md"
  assert "release prompt blocks on expired exceptions" grep -q 'security-exceptions.md' "$PROJECT/prompts/release.md"
  # REQ-031 vulnerability reporting and incident policy
  for topic in '^## Reporting a vulnerability' '^## Secret rotation' '^## Incident response basics' 'SBOM'; do
    assert "SECURITY.md covers: $topic" grep -q "$topic" "$PROJECT/SECURITY.md"
  done
  # REQ-032 recorded security review reports
  for topic in '^## Scope' '^## Evidence' '^## Limitations' '^## Findings' '^## Remediation summary'; do
    assert "review report template has: $topic" grep -q "$topic" "$PROJECT/docs/security-reviews/0000-template.md"
  done
  assert "review prompt writes the report" grep -q 'docs/security-reviews/0000-template.md' "$PROJECT/prompts/security-review.md"
  assert "review prompt says a checklist is not proof" grep -q 'not proof of security' "$PROJECT/prompts/security-review.md"
  assert "review template is updated with the scaffold" is_managed docs/security-reviews/0000-template.md
  local owned
  for owned in SECURITY.md docs/threat-model.md docs/security-exceptions.md; do
    assert_fails "$owned is project-owned, never overwritten by updates" is_managed "$owned"
  done
  # REQ-042 architecture document with rules for new code
  local section
  for section in '^## Layers and dependency direction' '^## Composition root' '^## Rules for new code' '^## Third-party code'; do
    assert "architecture template has: $section" grep -q "$section" "$PROJECT/docs/architecture.md"
  done
  # REQ-043 versioned persisted data, migrations without data loss
  for section in 'carries a version' 'migrates older versions automatically' 'only that part is dropped' \
    'Keep the old data until' 'migration test' 'breaking change (major version)'; do
    assert "architecture migration rules: $section" grep -q "$section" "$PROJECT/docs/architecture.md"
  done
  assert "clean-code guide points to the migration rules" grep -q 'migration rules in .docs/architecture.md.' "$PROJECT/docs/clean-code.md"
  assert "release prompt counts format changes as breaking" grep -q 'stored or exchanged data formats' "$PROJECT/prompts/release.md"
  assert "kickoff fills the architecture" grep -q 'docs/architecture.md' "$PROJECT/prompts/kickoff.md"
  assert "feature prompt follows the rules for new code" grep -q 'Rules for new code' "$PROJECT/prompts/feature.md"
  assert "code review checks layering" grep -q 'docs/architecture.md' "$PROJECT/prompts/code-review.md"
  assert_fails "architecture is project-owned, never overwritten by updates" is_managed docs/architecture.md

  local check="$PROJECT/scripts/check-requirements.sh"
  assert_fails_with "invalid requirement status rejected" 'unknown status' \
    "$check" "$(requirements_variant bad-status 's/^status: .*/status: bogus/')"
  assert_fails_with "status pattern matching a real status rejected" 'unknown status' \
    "$check" "$(requirements_variant regex-status 's/^status: .*/status: d.*e/')"
  # REQ-021 complete fields and real dates
  assert_fails_with "empty acceptance criteria rejected" 'Acceptance criteria' \
    "$check" "$(requirements_variant no-criteria '/^- TODO: Given/d')"
  assert_fails_with "invalid date rejected" 'invalid date' \
    "$check" "$(requirements_variant bad-date 's/^updated: .*/updated: not-a-date/')"
  assert_fails_with "unfilled date placeholder rejected in projects" 'unfilled' \
    "$check" "$(requirements_variant placeholder-date 's/^updated: .*/updated: {{DATE}}/')"
  assert_fails_with "placeholder requirement blocks a release" 'before a release' "$check" --release
}

# REQ-022 commit reference checks cannot be bypassed
test_commit_bypasses() {
  local hook="$PROJECT/scripts/hooks/commit-msg" zero="0000000000000000000000000000000000000000" before_bad
  assert_fails "Merge prefix cannot smuggle an unknown ID" "$hook" "$(msg 'Merge branch x\n\nRefs: REQ-777\n')" # traceability: ignore
  assert_fails "fixup! prefix cannot smuggle an unknown ID" "$hook" "$(msg 'fixup! feat: x\n\nSee REQ-778\n')" # traceability: ignore
  assert "plain Merge message still accepted" "$hook" "$(msg 'Merge branch x\n')"
  assert "IDs in comments and the git commit -v diff are ignored" "$hook" \
    "$(msg 'docs: x\n\n# REQ-779 in a comment\n# ------------------------ >8 ------------------------\n+REQ-780 in the diff\n')" # traceability: ignore
  assert "fix with 'Refs: none' accepted" "$hook" "$(msg 'fix: x\n\nRefs: none\n')"
  assert_fails_with "fix with a word merely containing none rejected" "Refs: none" "$hook" "$(msg 'fix: x\n\nRefs: nonexistent\n')"
  set_status REQ-001 approved
  git -C "$PROJECT" commit -q -am "docs(requirements): approve REQ-001"
  assert "Refs in prose is not a trailer" bash -c "'$hook' '$(msg 'feat: x\n\nRefs: REQ-001\n\nMore prose after it.\n')' 2>&1 | grep -q \"need a 'Refs: REQ-nnn' trailer\""
  # A first push with a bad commit in the middle: every introduced commit is checked.
  before_bad="$(git -C "$PROJECT" rev-parse HEAD)"
  git -C "$PROJECT" commit -q --allow-empty --no-verify -m "feat: no refs in the middle"
  git -C "$PROJECT" commit -q --allow-empty -m "docs: fine on top"
  assert_fails "CI first push checks the whole new history" \
    env EVENT_NAME=push BEFORE_SHA="$zero" DEFAULT_BRANCH=main "$PROJECT/scripts/verify-commits.sh" --ci
  git -C "$PROJECT" update-ref refs/remotes/origin/main "$before_bad"
  assert_fails "CI pull request range includes the bad commit" \
    env EVENT_NAME=pull_request BASE_REF=main "$PROJECT/scripts/verify-commits.sh" --ci
  assert_fails "CI rejects a malformed base ref" \
    env EVENT_NAME=pull_request BASE_REF='main;rm' "$PROJECT/scripts/verify-commits.sh" --ci
  # REQ-109 a range the check could not read is never reported as OK
  assert_fails_with "CI fails when the base of a pull request cannot be read" "cannot read" \
    env EVENT_NAME=pull_request BASE_REF=gone "$PROJECT/scripts/verify-commits.sh" --ci
  git clone -q --depth 1 "file://$PROJECT" "$WORKDIR/shallow-ci"
  assert_fails_with "CI fails in a shallow checkout and names fetch-depth" "fetch-depth: 0" \
    env EVENT_NAME=push BEFORE_SHA="$zero" DEFAULT_BRANCH=main "$WORKDIR/shallow-ci/scripts/verify-commits.sh" --ci
  assert_fails_with "CI fails in a shallow checkout of a pull request too" "fetch-depth: 0" \
    env EVENT_NAME=pull_request BASE_REF=main "$WORKDIR/shallow-ci/scripts/verify-commits.sh" --ci
  rm -rf "$WORKDIR/shallow-ci"
  assert "an empty range that was read is still OK" \
    env EVENT_NAME=push BEFORE_SHA="$(git -C "$PROJECT" rev-parse HEAD)" "$PROJECT/scripts/verify-commits.sh" --ci
  git -C "$PROJECT" update-ref -d refs/remotes/origin/main
  git -C "$PROJECT" reset -q --hard "$before_bad~1"

  # git exports GIT_DIR to hooks. A rules file in a subfolder (the scaffold's template/AGENTS.md)
  # must still be read from that folder, not from the repository top.
  local git_dir cites_rule cites_unknown_rule
  mkdir -p "$PROJECT/rules" && printf -- '- **CC-77** test rule\n' >"$PROJECT/rules/AGENTS.md"
  git -C "$PROJECT" add rules/AGENTS.md
  git_dir="$(git -C "$PROJECT" rev-parse --absolute-git-dir)"
  cites_rule="$(msg 'docs: x\n\nSee CC-77.\n')"
  assert "rule in a subfolder found with GIT_DIR exported (worktree hook)" bash -c \
    "cd '$PROJECT' && GIT_DIR='$git_dir' RULES_FILE='$PROJECT/rules/AGENTS.md' scripts/verify-refs.sh '$cites_rule'"
  assert "rule in a subfolder found with a relative GIT_DIR and index" bash -c \
    "cd '$PROJECT' && GIT_DIR=.git GIT_INDEX_FILE=.git/index RULES_FILE='$PROJECT/rules/AGENTS.md' scripts/verify-refs.sh '$cites_rule'"
  cites_unknown_rule="$WORKDIR/unknown-rule.txt"
  printf 'docs: x\n\nSee CC-78.\n' >"$cites_unknown_rule"
  assert_fails_with "unknown rule still rejected with GIT_DIR exported" "unknown rule CC-78" bash -c \
    "cd '$PROJECT' && GIT_DIR='$git_dir' RULES_FILE='$PROJECT/rules/AGENTS.md' scripts/verify-refs.sh '$cites_unknown_rule'"
  git -C "$PROJECT" rm -q --cached rules/AGENTS.md && rm -rf "$PROJECT/rules"
}

# REQ-019 required checks cannot be skipped silently
test_missing_tools() {
  need_tool gitleaks "missing-scanner fixture" || return 0
  local restricted
  restricted="$(path_without gitleaks)"
  assert "local check reports INCOMPLETE without gitleaks" bash -c "cd '$PROJECT' && PATH='$restricted' scripts/check.sh 2>&1 | grep -q 'INCOMPLETE'"
  assert_fails "strict check fails without gitleaks" bash -c "cd '$PROJECT' && PATH='$restricted' scripts/check.sh --strict"
  assert "summary lists the skipped check" bash -c "cd '$PROJECT' && PATH='$restricted' scripts/check.sh 2>&1 | grep -q 'skipped: secret scan'"
}

# REQ-014: checkers get exactly the matching tracked files, chosen in one pass over the list.
test_file_selection() {
  local repo="$WORKDIR/selection"
  mkdir -p "$repo/hooks" "$repo/tests/semgrep" && git -C "$repo" init -q
  : >"$repo/a.sh" && : >"$repo/with space.sh" && : >"$repo/hooks/pre-commit" && : >"$repo/x.py" && : >"$repo/tests/semgrep/fixture.py"
  git -C "$repo" add -A
  assert "shell files and extension-less hooks selected" bash -c "cd '$repo' && source '$SCAFFOLD_ROOT/template/scripts/lib.sh' \
    && collect_files full '(\.sh\$|(^|/)hooks/[^/.]+\$)' && test \"\${TARGETS[*]}\" = 'a.sh hooks/pre-commit with space.sh'"
  assert "excluded paths left out" bash -c "cd '$repo' && source '$SCAFFOLD_ROOT/template/scripts/lib.sh' \
    && collect_files full '\.py\$' '^tests/semgrep/' && test \"\${TARGETS[*]}\" = 'x.py'"
}

# REQ-014 fast offline pre-commit, REQ-005 security (SAST blocks eval)
test_staged_checks() {
  printf 'x = 1\n' >"$PROJECT/clean.py"
  git -C "$PROJECT" add clean.py
  assert "staged check passes on clean file" bash -c "cd '$PROJECT' && scripts/check.sh --staged"
  if need_tool semgrep "staged SAST fixture"; then
    printf 'def run(user_input):\n    return eval(user_input)\n' >"$PROJECT/unsafe.py"
    git -C "$PROJECT" add unsafe.py
    assert_fails "staged check blocks eval via local semgrep rule" bash -c "cd '$PROJECT' && scripts/check.sh --staged"
    # REQ-040 the new rules ship with projects and run in the pre-commit check
    printf 'from flask import redirect, request\n\n\ndef go():\n    return redirect(request.args.get("next"))\n' >"$PROJECT/unsafe.py"
    git -C "$PROJECT" add unsafe.py
    assert_fails "staged check blocks an open redirect via local semgrep rule" bash -c "cd '$PROJECT' && scripts/check.sh --staged"
  fi
  git -C "$PROJECT" reset -q --hard
  rm -f "$PROJECT/clean.py" "$PROJECT/unsafe.py"
}

# REQ-020 staged snapshot: checks and commit-msg validate what will be committed
test_staged_snapshot() {
  local requirements before_status before_diff in_snapshot
  # REQ-014: large files the commit does not change are not copied; staged ones always are.
  head -c 1100000 /dev/zero >"$PROJECT/large-unchanged.bin"
  git -C "$PROJECT" add large-unchanged.bin && git -C "$PROJECT" commit -q --no-verify -m "chore: large file"
  head -c 1100000 /dev/zero >"$PROJECT/large-staged.bin" && printf 'x\n' >"$PROJECT/small-staged.txt"
  git -C "$PROJECT" add large-staged.bin small-staged.txt
  in_snapshot="source '$PROJECT/scripts/lib.sh'; enter_staged_snapshot '$PROJECT'"
  assert "snapshot leaves out large unchanged files" bash -c "$in_snapshot; test ! -e large-unchanged.bin && test -f AGENTS.md"
  assert "snapshot keeps staged files of any size" bash -c "$in_snapshot; test -f large-staged.bin && test -f small-staged.txt"
  git -C "$PROJECT" reset -q --hard HEAD~1
  requirements="$(req_file "$PROJECT" REQ-001)"
  cp "$requirements" "$WORKDIR/req-original.md"
  # staged content broken, working tree fixed: must fail
  sed 's/^status: .*/status: bogus/' "$WORKDIR/req-original.md" >"$requirements"
  git -C "$PROJECT" add docs/requirements
  cp "$WORKDIR/req-original.md" "$requirements"
  before_status="$(git -C "$PROJECT" status --porcelain)"
  before_diff="$(git -C "$PROJECT" diff)"
  assert_fails "staged invalid requirement not hidden by unstaged fix" bash -c "cd '$PROJECT' && scripts/check.sh --staged"
  assert "working tree and index untouched by staged check" test "$(git -C "$PROJECT" status --porcelain)$(git -C "$PROJECT" diff)" = "$before_status$before_diff"
  git -C "$PROJECT" reset -q --hard
  # staged content fine, working tree broken: must pass
  sed 's/^status: .*/status: bogus/' "$WORKDIR/req-original.md" >"$requirements"
  assert "unstaged breakage does not fail the staged check" bash -c "cd '$PROJECT' && scripts/check.sh --staged"
  git -C "$PROJECT" checkout -q -- docs
  if need_tool semgrep "staged SAST snapshot fixture"; then
    printf 'def run(user_input):\n    return eval(user_input)\n' >"$PROJECT/hidden.py"
    git -C "$PROJECT" add hidden.py
    printf 'def run(user_input):\n    return user_input\n' >"$PROJECT/hidden.py"
    assert_fails "staged eval not hidden by unstaged fix" bash -c "cd '$PROJECT' && scripts/check.sh --staged"
    git -C "$PROJECT" reset -q --hard && git -C "$PROJECT" clean -qfd
  fi
  # requirement only in the working tree cannot validate a commit
  "$PROJECT/scripts/req.sh" new first-epic job "Second job" >/dev/null
  set_status REQ-002 approved
  assert_fails "REQ only in unstaged file rejected by commit-msg" "$PROJECT/scripts/hooks/commit-msg" "$(msg 'feat: x\n\nRefs: REQ-002\n')"
  git -C "$PROJECT" add docs/requirements
  assert "same REQ accepted once staged" "$PROJECT/scripts/hooks/commit-msg" "$(msg 'feat: x\n\nRefs: REQ-002\n')"
  git -C "$PROJECT" reset -q --hard && git -C "$PROJECT" clean -qfd
}

# REQ-003 clean-code rules, REQ-015 linter presets and mandatory stack checks
test_stack_enforcement() {
  assert "CI installs requirements-dev.txt only when present" \
    grep -q 'if \[ -f requirements-dev.txt \]; then python -m pip install -r requirements-dev.txt' "$PROJECT/.github/workflows/ci.yml"
  if need_tool ruff "python preset fixture"; then
    printf '[project]\nname = "demo"\nversion = "0.1.0"\n' >"$PROJECT/pyproject.toml"
    printf '"""Demo."""\n' >"$PROJECT/ok.py"
    git -C "$PROJECT" add pyproject.toml ok.py
    assert_fails "python without ruff config fails" bash -c "cd '$PROJECT' && scripts/check.sh --staged"
    assert "python preset applies" "$PROJECT/scripts/apply-preset.sh" python
    printf '"""Demo."""\n\n\ndef f(a, b, c, d, e):\n    """Too many args."""\n    return a\n' >"$PROJECT/bad.py"
    git -C "$PROJECT" add ruff.toml bad.py
    assert_fails "preset rejects too many parameters (CC-01)" bash -c "cd '$PROJECT' && scripts/check.sh --staged"
    git -C "$PROJECT" rm -q --cached bad.py
    assert "preset accepts clean code" bash -c "cd '$PROJECT' && scripts/check.sh --staged"
    git -C "$PROJECT" reset -q --hard && git -C "$PROJECT" clean -qfd
  fi
  if need_tool npm "node stack fixture"; then
    (cd "$PROJECT" && npm init -y >/dev/null)
    git -C "$PROJECT" add package.json
    assert_fails "node without lint script fails" bash -c "cd '$PROJECT' && scripts/check.sh --staged"
    git -C "$PROJECT" reset -q --hard && git -C "$PROJECT" clean -qfd
  fi
}

# REQ-051 optional tools: tips where they fit, checks once adopted
test_optional_tools() {
  local log="$WORKDIR/optional.log" fakes tip_text label
  printf '[project]\nname = "demo"\n' >"$PROJECT/pyproject.toml"
  printf '{ "name": "demo" }\n' >"$PROJECT/package.json"
  printf '"""Demo."""\n' >"$PROJECT/ok.py"
  git -C "$PROJECT" add pyproject.toml package.json ok.py
  (cd "$PROJECT" && scripts/check.sh >"$log" 2>&1) || true
  for tip_text in 'python: vulture' 'python: Hypothesis' 'python: mutmut' 'node: knip' 'node: fast-check' \
    'node: StrykerJS' 'duplication: jscpd'; do
    assert "full check suggests $tip_text" grep -q "^TIP: $tip_text" "$log"
  done
  has_command zizmor || assert "workflow security tip without zizmor" grep -q '^TIP: workflows: zizmor' "$log"
  assert "staged check prints no tips" bash -c "cd '$PROJECT' && ! scripts/check.sh --staged 2>&1 | grep -q '^TIP:'"

  fakes="$(fake_tools actionlint zizmor vulture jscpd)"
  printf '\n[tool.vulture]\npaths = ["ok.py"]\n' >>"$PROJECT/pyproject.toml"
  printf '{ "threshold": 5 }\n' >"$PROJECT/.jscpd.json"
  git -C "$PROJECT" add pyproject.toml .jscpd.json
  (cd "$PROJECT" && PATH="$fakes:$PATH" scripts/check.sh >"$log" 2>&1) || true
  for label in 'python: vulture (dead code)' 'duplication: jscpd' 'workflows: actionlint' 'workflows: zizmor'; do
    assert "adopted $label runs and its findings fail" grep -q "$label failed" "$log"
  done
  assert_fails "adopted tools are no longer suggested" grep -qE '^TIP: (python: vulture|duplication|workflows)' "$log"
  assert "staged check lints staged workflows" bash -c "cd '$PROJECT' && printf '# staged edit\\n' >>.github/workflows/ci.yml && git add .github/workflows/ci.yml && PATH='$fakes:$PATH' scripts/check.sh --staged 2>&1 | grep -q 'workflows: zizmor failed'"
  git -C "$PROJECT" reset -q --hard && git -C "$PROJECT" clean -qfd

  assert "AGENTS.md says how to handle tips" grep -q 'install nothing without approval' "$PROJECT/AGENTS.md"
  assert "optional tools are a managed document" grep -q 'docs/optional-tools.md' "$PROJECT/.scaffold/manifest"
  assert "setup points to the optional tools" bash -c "'$PROJECT/scripts/setup.sh' --tools-only 2>&1 | grep -q 'docs/optional-tools.md'"
  assert "clean-code guide covers property and mutation testing" bash -c "grep -q 'property-based tests' '$PROJECT/docs/clean-code.md' && grep -q 'Mutation testing' '$PROJECT/docs/clean-code.md'"
}

# REQ-019: CI never leaves the job token in .git/config while project code runs
# (security review 2026-10-11, finding 3).
test_ci_credentials() {
  local workflow
  for workflow in "$SCAFFOLD_ROOT/.github/workflows/scaffold-ci.yml" "$SCAFFOLD_ROOT/template/.github/workflows/ci.yml"; do
    assert "$(basename "$workflow"): checkout does not persist credentials" \
      test "$(grep -c 'uses: actions/checkout@' "$workflow")" = "$(grep -c 'persist-credentials: false' "$workflow")"
    # REQ-004: the registry rules are the one unpinned input; the workflow says so where it runs
    assert "$(basename "$workflow"): unpinned semgrep registry rules are marked as intentional" \
      grep -q 'registry rules are not pinned on purpose' "$workflow"
  done
  assert "security checklist explains new semgrep registry findings" \
    grep -q 'report a finding without a code change' "$SCAFFOLD_ROOT/template/docs/security.md"
  # REQ-088: CI runs once per commit: on the pull request, and on main after the merge, not on every branch push
  assert "scaffold-ci.yml runs on pull requests" \
    grep -q '^  pull_request:' "$SCAFFOLD_ROOT/.github/workflows/scaffold-ci.yml"
  assert "scaffold-ci.yml runs on pushes to main only" \
    grep -q '^    branches: \[main\]' "$SCAFFOLD_ROOT/.github/workflows/scaffold-ci.yml"
  assert_fails "scaffold-ci.yml does not run on every branch push" \
    grep -q "branches: \['\*\*'\]" "$SCAFFOLD_ROOT/.github/workflows/scaffold-ci.yml"
  # REQ-093: a new push cancels the older run of the same pull request; a run on main is never cancelled
  assert "scaffold-ci.yml cancels superseded pull request runs only" \
    grep -q "cancel-in-progress: \${{ github.event_name == 'pull_request' }}" "$SCAFFOLD_ROOT/.github/workflows/scaffold-ci.yml"
  assert "scaffold-ci.yml gives each run on main its own concurrency group" \
    grep -q "group: scaffold-ci-\${{ github.event_name == 'pull_request' && github.ref || github.sha }}" "$SCAFFOLD_ROOT/.github/workflows/scaffold-ci.yml"
  assert_fails "AGENTS.md no longer asks for the full local run before the pull request" \
    grep -q 'once, before the pull request\|locally. Pushing is an' "$SCAFFOLD_ROOT/AGENTS.md"
  assert "AGENTS.md names when the full local run is still required" \
    grep -q 'touches no row of the area table' "$SCAFFOLD_ROOT/AGENTS.md"
  assert "REQ-088 marks the local full run before the pull request as superseded by REQ-093" \
    grep -q 'superseded by REQ-093' "$SCAFFOLD_ROOT"/docs/requirements/quality-gates/REQ-088-*.md
  # REQ-078: maintainer guidance asks for branch names prefixed with the requirement ID
  assert "AGENTS.md asks for requirement-prefixed branch names" \
    grep -q 'prefix the slug with the ID of the related requirement' "$SCAFFOLD_ROOT/AGENTS.md"
}

# REQ-083 the maintainer hooks run locally and refuse what CI refuses
# shellcheck disable=SC2016 # the bash -c scripts read their arguments as $1 and $2
test_maintainer_hooks() {
  local clone="$WORKDIR/scaffold-clone" remote="$WORKDIR/scaffold-remote.git" worktree="$WORKDIR/scaffold-clone-wt" long
  mkdir -p "$clone"
  (cd "$SCAFFOLD_ROOT" && tar -cf - .githooks scripts template docs/requirements) | tar -x -C "$clone"
  git -C "$clone" init -q -b main
  "$clone/scripts/setup.sh" >/dev/null 2>&1 || true # the tool report may be INCOMPLETE here; the hooks path is what counts
  assert "setup sets core.hooksPath to .githooks" test "$(git -C "$clone" config core.hooksPath)" = ".githooks"
  assert "core.hooksPath is a directory that exists" test -d "$clone/.githooks"
  assert "hooks path check passes" "$clone/scripts/check-hooks-path.sh" "$clone"
  git -C "$clone" add -A
  git -C "$clone" commit -q --no-verify -m "chore: scratch scaffold"
  git -C "$clone" worktree add -q "$worktree" -b scratch
  assert "a relative hooks path resolves inside each worktree" \
    test "$(git -C "$worktree" rev-parse --path-format=absolute --git-path hooks 2>/dev/null)" = "$(cd "$worktree" && pwd -P)/.githooks"
  git -C "$clone" config core.hooksPath /nonexistent/hooks
  assert_fails_with "a hooks path that does not exist fails the check and is named" '/nonexistent/hooks' "$clone/scripts/check-hooks-path.sh" "$clone"
  git -C "$clone" config core.hooksPath .githooks

  long="chore: $(printf 'x%.0s' $(seq 1 80))"
  assert "commit-msg accepts a feat with Refs in the trailer block" \
    bash -c 'cd "$1" && .githooks/commit-msg "$2"' _ "$clone" "$(msg 'feat(x): add it\n\nRefs: REQ-004\nCo-Authored-By: a <a@example.invalid>\n')"
  assert_fails_with "commit-msg refuses Refs outside the last paragraph" "'Refs: REQ-nnn' trailer" \
    bash -c 'cd "$1" && .githooks/commit-msg "$2"' _ "$clone" "$(msg 'feat(x): add it\n\nRefs: REQ-004\n\nCo-Authored-By: a <a@example.invalid>\n')"
  assert_fails_with "commit-msg refuses a feat without Refs" "'Refs: REQ-nnn' trailer" \
    bash -c 'cd "$1" && .githooks/commit-msg "$2"' _ "$clone" "$(msg 'feat(x): add it\n')"
  assert_fails_with "commit-msg refuses a subject over 72 characters" "Conventional Commits" \
    bash -c 'cd "$1" && .githooks/commit-msg "$2"' _ "$clone" "$(msg "$long\n")"

  git init -q --bare -b main "$remote"
  git -C "$clone" remote add origin "$remote"
  git -C "$clone" push -q --no-verify origin main
  git -C "$clone" commit -q --no-verify --allow-empty -m "chore: fine"
  assert "pre-push lets good commit messages through" git -C "$clone" push -q origin main
  git -C "$clone" commit -q --no-verify --allow-empty -m "feat(x): no requirement"
  assert_fails_with "pre-push refuses a feat without Refs" "'Refs: REQ-nnn' trailer" git -C "$clone" push -q origin main
  assert "the refused push left the remote untouched" \
    test "$(git -C "$remote" rev-parse main)" != "$(git -C "$clone" rev-parse main)"
}

# REQ-086 a check started from inside a check stops at once
test_nested_run_guard() {
  local name script
  for name in check-scaffold.sh smoke.sh check.sh; do
    case "$name" in
      check-scaffold.sh) script="$SCAFFOLD_ROOT/scripts/check-scaffold.sh" ;;
      smoke.sh) script="$SCAFFOLD_ROOT/tests/smoke.sh assistant-guidance" ;;
      check.sh) script="'$PROJECT/scripts/check.sh'" ;;
    esac
    # shellcheck disable=SC2086 # script may carry an option
    assert "$name refuses to start inside itself" bash -c "XADEN_RUNNING=$name $script 2>&1 | grep -q 'already running in this process tree'"
  done
  # shellcheck disable=SC2016 # the inner shell expands the variables
  assert "the override allows a nested run on purpose" bash -c 'source "$1/template/scripts/lib.sh"; XADEN_RUNNING=x.sh XADEN_ALLOW_NESTED=1 refuse_nested_run x.sh' _ "$SCAFFOLD_ROOT"
  assert "a staged run may nest (hooks inside tests)" bash -c "XADEN_RUNNING=check.sh '$PROJECT/scripts/check.sh' --staged 2>&1 | grep -qv 'already running'"
}

# REQ-092 every smoke area has a row in AGENTS.md, so the list of what each area covers cannot go stale
test_smoke_area_list() {
  local copy="$WORKDIR/smoke-areas" check="$SCAFFOLD_ROOT/scripts/check-smoke-areas.sh"
  assert "every smoke area has a row in AGENTS.md" "$check" "$SCAFFOLD_ROOT"
  mkdir -p "$copy/tests/smoke" "$copy/template/scripts"
  cp "$SCAFFOLD_ROOT/template/scripts/lib.sh" "$SCAFFOLD_ROOT/template/scripts/layout.sh" "$SCAFFOLD_ROOT/template/scripts/gate.sh" "$copy/template/scripts/"
  : >"$copy/tests/smoke/lib.sh"
  : >"$copy/tests/smoke/alpha.sh"
  # shellcheck disable=SC2016 # the backticks are literal Markdown, not a command substitution
  printf '| `alpha` | REQ-001 | `scripts/a.sh` |\n' >"$copy/AGENTS.md"
  mkdir -p "$copy/docs"
  printf 'alpha|scripts/a.sh\n*all*|tests/smoke.sh\n' >"$copy/docs/smoke-areas.txt"
  assert "a listed area passes" "$check" "$copy"
  printf 'alpha|scripts/other.sh\n' >"$copy/docs/smoke-areas.txt"
  assert_fails_with "REQ-114 paths that differ between AGENTS.md and the area table fail and the area is named" 'area alpha' "$check" "$copy"
  printf 'alpha|scripts/a.sh\n' >"$copy/docs/smoke-areas.txt"
  : >"$copy/tests/smoke/beta.sh"
  assert_fails_with "an area without a row fails and is named" 'beta' "$check" "$copy"
}

# REQ-114 a pull request runs the areas its change can affect, and all of them when unsure
test_area_selection() {
  local repo="$WORKDIR/select-repo" select="scripts/select-smoke-areas.sh" ci="$SCAFFOLD_ROOT/.github/workflows/scaffold-ci.yml"
  mkdir -p "$repo/scripts" "$repo/docs"
  cp "$SCAFFOLD_ROOT/$select" "$repo/scripts/"
  cp "$SCAFFOLD_ROOT/docs/smoke-areas.txt" "$repo/docs/"
  git -C "$repo" init -q -b main
  git -C "$repo" add -A
  git -C "$repo" commit -q --no-verify -m "chore: base"
  # selected <description> <changed file(s)> <expected output, one line>: a branch that changes these files
  selected() {
    git -C "$repo" checkout -q -B probe main
    local f
    for f in $2; do # the second argument may name several files, separated by spaces
      mkdir -p "$repo/$(dirname "$f")"
      echo "$RANDOM" >>"$repo/$f"
    done
    git -C "$repo" add -A
    git -C "$repo" commit -q --no-verify -m "chore: probe"
    assert "$1" test "$("$repo/$select" main HEAD 2>/dev/null | tr '\n' ' ')" = "$3"
  }
  selected "REQ-114 a path of one area selects that area" template/scripts/req.sh "requirements "
  selected "REQ-114 an area's requirement folder selects that area" docs/requirements/security/x.md "security "
  selected "REQ-114 a shared file selects all areas" tests/smoke/lib.sh "all "
  selected "REQ-114 anything under .github selects all areas" .github/workflows/other.yml "all "
  selected "REQ-114 a path in no area selects all areas" some/new/file.txt "all "
  selected "REQ-114 a path of one area and one in no area select all areas" README.md "all "
  assert "REQ-114 an unknown base ref selects all areas" test "$("$repo/$select" nope HEAD 2>/dev/null)" = all
  assert "REQ-114 a missing base ref selects all areas" test "$("$repo/$select" 2>/dev/null)" = all
  assert "REQ-114 an empty diff selects all areas" test "$("$repo/$select" main main 2>/dev/null)" = all
  selected "REQ-114 a second change in one area still selects only it" template/scripts/req.sh "requirements "
  # shellcheck disable=SC2016 # the bash -c script reads its file as $1
  assert "REQ-114 the skipped areas are named on stderr" bash -c '"$1" main probe 2>&1 >/dev/null | grep -q "skip adoption"' _ "$repo/$select"
  selected "REQ-114 a script of one area plus the changelog selects that area and release-and-docs" "template/scripts/req.sh CHANGELOG.md" "requirements release-and-docs "
  selected "REQ-114 a script, the changelog and the requirements index select two areas" "scripts/new-project.sh CHANGELOG.md docs/requirements/INDEX.md" "project-setup requirements release-and-docs "
  selected "REQ-114 the requirements index alone selects requirements" docs/requirements/INDEX.md "requirements "
  selected "REQ-114 the third-party list and the site page list select release-and-docs" "THIRD-PARTY.md docs/site-pages.txt" "release-and-docs "
  selected "REQ-114 a guide of the admin folder selects release-and-docs and assistant-guidance" docs/guide/admin/install-xaden.md "assistant-guidance release-and-docs "
  selected "REQ-114 a guide of the developer folder is in no area and selects all areas" docs/guide/developer/build-features.md "all "
  selected "REQ-114 the README with the changelog still selects all areas" "README.md CHANGELOG.md" "all "
  # the workflow keeps REQ-088/REQ-093 and the gate names the ruleset on main requires
  assert "REQ-114 the summary job is named check and runs for both systems" \
    awk '/^  check:/{f=1} f&&/os: \[ubuntu-latest, macos-latest\]/{ok=1} END{exit !ok}' "$ci"
  assert "REQ-114 the gate fails on a failed or cancelled area job" grep -q 'a smoke area did not pass' "$ci"
  assert "REQ-114 the gate runs even when a needed job failed" awk '/^  check:/{f=1} f&&/if: always\(\)/{ok=1} END{exit !ok}' "$ci"
  assert "REQ-114 a run on main runs all areas" grep -q 'EVENT_NAME" = pull_request' "$ci"
}

test_quiet_output
# shellcheck disable=SC2016 # the bash -c script reads its file as $1
# REQ-105 a project made by xaden create runs the audits itself, so it never reports them as not covered
test_classic_runs_what_adopted_lacks() {
  local out="$WORKDIR/classic-not-covered.out"
  printf '[project]\nname = "probe"\n' >"$PROJECT/pyproject.toml"
  (cd "$PROJECT" && scripts/check.sh >"$out" 2>&1) || true
  rm -f "$PROJECT/pyproject.toml"
  assert "REQ-105 the classic full run names no check as not covered" bash -c '! grep -q "NOT COVERED" "$1"' _ "$out"
  assert "REQ-105 the classic Python stack runs bandit and pip-audit" grep -q 'python: bandit' "$PROJECT/scripts/stacks/python.sh"
}

test_generated_project
test_commit_bypasses
test_missing_tools
test_file_selection
test_staged_checks
test_staged_snapshot
test_stack_enforcement
test_optional_tools
test_ci_credentials
test_maintainer_hooks
test_nested_run_guard
test_classic_runs_what_adopted_lacks
test_smoke_area_list
test_area_selection
