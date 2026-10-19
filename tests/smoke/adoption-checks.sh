# shellcheck shell=bash
# shellcheck disable=SC2016 # bash -c programs are single-quoted on purpose
# Smoke test area "adoption-checks" (REQ-121, part of REQ-066 to REQ-076: convention, modes and baselines, exit statuses, scope, commit check, audit kinds, NOT COVERED).
# Sourced by tests/smoke.sh, which defines the helpers and creates the demo project first.
# shellcheck source=SCRIPTDIR/adoption-lib.sh
source "$SMOKE_DIR/adoption-lib.sh"

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
  edit_file "$conf" 's/^expect = .*/expect = test,lint/' # this test is about exit statuses, not the audit kind (REQ-106)
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

# Xaden files present but untracked (a contributor in a foreign repository): the hook reads them from the working tree
test_hook_with_untracked_xaden_files() {
  local worktree
  worktree="$(adopted_copy untracked-xaden)"
  git -C "$worktree" rm -rq --cached xaden AGENTS.md
  printf 'xaden/\nAGENTS.md\n' >>"$(git -C "$worktree" rev-parse --git-common-dir)/info/exclude"
  git -C "$worktree" commit -q --no-verify -m "chore: untrack xaden"
  printf 'more\n' >>"$worktree/README.md"
  git -C "$worktree" add README.md
  x_in "$worktree" hook pre-commit
  assert "the hook passes without tracked Xaden files" test "$XRC" -eq 0
  assert "the hook does not look for docs/requirements" bash -c '! grep -q "not found" "$1"' _ "$XOUT"
}

# REQ-106 the dependency audit and Bandit are check kinds of an adopted project
# shellcheck disable=SC2016 # the bash -c scripts read their arguments as $1
test_audit_kinds() {
  local py="$WORKDIR/repos/audit-py" node="$WORKDIR/repos/audit-node" shop="$WORKDIR/repos/audit-shop" conf mode
  # a new adoption expects the audits and reports them as gaps until they are mapped
  make_repo "$py" bare-python
  x_in "$py" adopt --scan
  assert "REQ-106 the scan lists the audit and security gaps" grep -q 'gaps .*audit security' "$XOUT"
  x_in "$py" adopt --yes --skip-ci --mode strict
  conf="$py-adopt-xaden/xaden/xaden.conf"
  assert "REQ-106 a new Python adoption expects audit and security" grep -q '^expect = test,lint,typecheck,audit,security$' "$conf"
  assert "REQ-106 the pre-commit hook still runs lint only" grep -q '^hook-checks = lint$' "$conf"
  x_in "$py-adopt-xaden" check
  assert "REQ-106 strict: an unmapped expected audit is a gap and fails" test "$XRC" -ne 0
  assert "REQ-106 the audit gap is named" grep -q "gap: no 'audit' check is configured" "$XOUT"
  assert "REQ-106 the security gap is named" grep -q "gap: no 'security' check is configured" "$XOUT"
  make_repo "$node" shop
  x_in "$node" adopt --yes --skip-ci --mode advisory
  assert "REQ-106 a new Node adoption expects audit but not security" grep -q '^expect = test,lint,audit$' "$node-adopt-xaden/xaden/xaden.conf"

  # a preset maps the classic commands, with the exit status that means findings
  x_in "$py-adopt-xaden" preset python
  assert "REQ-106 the Python preset maps pip-audit" grep -q '^check.audit = pip-audit$' "$conf"
  assert "REQ-106 the Python preset maps bandit like the classic project" grep -q '^check.security = bandit -q -r . -x ./.venv,./node_modules,./tests$' "$conf"
  assert "REQ-106 the Python preset declares exit status 1 as findings" bash -c 'grep -q "^findings-status.audit = 1$" "$1" && grep -q "^findings-status.security = 1$" "$1"' _ "$conf"
  x_in "$node-adopt-xaden" preset node
  assert "REQ-106 the Node preset maps npm audit" grep -q '^check.audit = npm audit --audit-level=high$' "$node-adopt-xaden/xaden/xaden.conf"
  assert "REQ-106 the Node preset declares exit status 1 as findings" grep -q '^findings-status.audit = 1$' "$node-adopt-xaden/xaden/xaden.conf"

  # an existing target is detected like test and lint
  make_repo "$shop" shop
  printf 'audit:\n\techo audit\n' >>"$shop/Makefile"
  git -C "$shop" add -A && git -C "$shop" commit -q -m "build: audit target"
  x_in "$shop" adopt --scan
  assert "REQ-106 the scan finds a Makefile audit target" grep -q 'dependency audit .*make audit' "$XOUT"

  # an adoption from before: no gap, a TIP and the NOT COVERED line, and expect is not touched
  make_repo "$WORKDIR/repos/audit-old" bare-python
  x_in "$WORKDIR/repos/audit-old" adopt --yes --skip-ci --mode strict
  edit_file "$WORKDIR/repos/audit-old-adopt-xaden/xaden/xaden.conf" 's/^expect = .*/expect = test,lint,typecheck/'
  x_in "$WORKDIR/repos/audit-old-adopt-xaden" check
  assert "REQ-106 an older adoption gets the NOT COVERED line" grep -q '^NOT COVERED: pip-audit' "$XOUT"
  assert "REQ-106 an older adoption gets a TIP" grep -q "^TIP: name them in 'expect'" "$XOUT"
  assert "REQ-106 an older adoption has no audit gap" bash -c '! grep -q "gap: no .audit. check" "$1"' _ "$XOUT"
  x_in "$WORKDIR/repos/audit-old-adopt-xaden" pin
  assert "REQ-106 xaden pin leaves expect alone" grep -q '^expect = test,lint,typecheck$' "$WORKDIR/repos/audit-old-adopt-xaden/xaden/xaden.conf"

  # a stub audit: findings name no file, so they cannot be baselined
  make_repo "$WORKDIR/repos/audit-stub" shop
  mkdir -p "$WORKDIR/repos/audit-stub/tools"
  printf '#!/bin/sh\necho "left-pad 1.0.0 has a known vulnerability"\nexit "$(cat "$(dirname "$0")/status")"\n' >"$WORKDIR/repos/audit-stub/tools/audit.sh"
  printf '0\n' >"$WORKDIR/repos/audit-stub/tools/status"
  git -C "$WORKDIR/repos/audit-stub" add -A && git -C "$WORKDIR/repos/audit-stub" commit -q -m "build: audit stub"
  x_in "$WORKDIR/repos/audit-stub" adopt --yes --skip-ci --mode strict --check "audit=sh tools/audit.sh"
  conf="$WORKDIR/repos/audit-stub-adopt-xaden/xaden/xaden.conf"
  printf 'findings-status.audit = 1\n' >>"$conf"
  printf '1\n' >"$WORKDIR/repos/audit-stub-adopt-xaden/tools/status"
  for mode in strict changed-files advisory; do
    edit_file "$conf" "s/^mode = .*/mode = $mode/"
    x_in "$WORKDIR/repos/audit-stub-adopt-xaden" check
    if [ "$mode" = advisory ]; then
      assert "REQ-106 advisory: an audit finding without a file name only warns" grep -q 'check: audit (needs the network) failed (advisory mode: not blocking)' "$XOUT"
    else
      assert "REQ-106 $mode: an audit finding without a file name fails" grep -q 'check: audit (needs the network) failed (exit status 1)' "$XOUT"
    fi
  done
  edit_file "$conf" 's/^mode = .*/mode = strict/'
  printf '2\n' >"$WORKDIR/repos/audit-stub-adopt-xaden/tools/status"
  x_in "$WORKDIR/repos/audit-stub-adopt-xaden" check
  assert "REQ-106 an exit status that is no finding fails the run, never passes it" test "$XRC" -ne 0
  assert "REQ-106 the run says the audit needs the network" grep -q 'check: audit (needs the network)' "$XOUT"
  edit_file "$conf" 's/^expect = .*/expect = test,lint/'
  edit_file "$conf" '/^check.audit = /d'
  x_in "$WORKDIR/repos/audit-stub-adopt-xaden" check
  assert "REQ-106 no gap when expect leaves the audit out" bash -c '! grep -q "gap: no .audit. check" "$1"' _ "$XOUT"

  # CI installs the pinned tools, and the pins match the preset's
  assert "REQ-106 the generated CI installs the audit tools of a Python project" grep -q 'pip install "bandit==$BANDIT_VERSION" "pip-audit==$PIP_AUDIT_VERSION"' "$SCAFFOLD_ROOT/scripts/adopt/ci.yml"
  assert "REQ-106 the CI pin of bandit equals the preset's" grep -q "BANDIT_VERSION: \"$(sed -n 's/^bandit==//p' "$SCAFFOLD_ROOT/template/presets/python/requirements-dev.txt")\"" "$SCAFFOLD_ROOT/scripts/adopt/ci.yml"
  assert "REQ-106 the CI pin of pip-audit equals the preset's" grep -q "PIP_AUDIT_VERSION: \"$(sed -n 's/^pip-audit==//p' "$SCAFFOLD_ROOT/template/presets/python/requirements-dev.txt")\"" "$SCAFFOLD_ROOT/scripts/adopt/ci.yml"
}

# REQ-105 the full run says what an adopted project does not check, and the guide page matches it
# shellcheck disable=SC2016 # the bash -c scripts read their arguments as $1
test_not_covered() {
  local page="$SCAFFOLD_ROOT/docs/guide/developer/what-xaden-checks.md" py="$WORKDIR/repos/not-covered-py" node="$WORKDIR/repos/not-covered-node" listed said tool
  make_repo "$py" bare-python
  x_in "$py" adopt --yes --skip-ci --mode strict
  edit_file "$py-adopt-xaden/xaden/xaden.conf" 's/^expect = .*/expect = test,lint,typecheck/' # an adoption from before REQ-106
  x_in "$py-adopt-xaden" check
  assert "REQ-105 a Python repository is told that pip-audit is not covered" grep -q '^NOT COVERED: pip-audit; .*check.audit in xaden/xaden.conf' "$XOUT"
  assert "REQ-105 a Python repository is told that bandit is not covered" grep -q '^NOT COVERED: bandit; .*check.security in xaden/xaden.conf' "$XOUT"
  said="$(grep '^NOT COVERED:' "$XOUT" | sed 's/^NOT COVERED: \([^;]*\);.*/\1/')"
  make_repo "$node" shop
  x_in "$node" adopt --yes --skip-ci --mode strict
  edit_file "$node-adopt-xaden/xaden/xaden.conf" 's/^expect = .*/expect = test,lint/'
  x_in "$node-adopt-xaden" check
  assert "REQ-105 a Node repository is told that npm audit is not covered" grep -q '^NOT COVERED: npm audit; .*check.audit in xaden/xaden.conf' "$XOUT"
  said="$said
$(grep '^NOT COVERED:' "$XOUT" | sed 's/^NOT COVERED: \([^;]*\);.*/\1/')"
  listed="$(grep -F '**unless mapped**' "$page" | sed 's/^| `\([^`]*\)`.*/\1/')"
  assert "REQ-105 the page lists as unmapped exactly what the full run reports" test "$(printf '%s\n' "$said" | sort -u)" = "$(printf '%s\n' "$listed" | sed 's/ (.*//' | sort -u)"

  # an expected kind is a gap, reported once
  edit_file "$py-adopt-xaden/xaden/xaden.conf" 's/^expect = .*/expect = test,lint,typecheck,audit/'
  x_in "$py-adopt-xaden" check
  assert "REQ-105 an expected kind is a gap" grep -q "gap: no 'audit' check is configured" "$XOUT"
  assert "REQ-105 an expected kind is not also reported as not covered" bash -c '! grep -q "^NOT COVERED: pip-audit" "$1"' _ "$XOUT"

  # a mapped kind is covered
  printf 'check.audit = true\n' >>"$py-adopt-xaden/xaden/xaden.conf"
  x_in "$py-adopt-xaden" check
  assert "REQ-105 a mapped kind is not reported" bash -c '! grep -q "^NOT COVERED: pip-audit" "$1"' _ "$XOUT"

  # every tool the page names exists in the scaffold, so the page cannot describe a check that is gone
  while read -r tool; do
    assert "REQ-105 the page names $tool, which the scaffold runs" grep -rqF -- "$tool" "$SCAFFOLD_ROOT/template/scripts" "$SCAFFOLD_ROOT/template/presets"
  done < <(grep -E '^\| `' "$page" | sed 's/^| `\([^`]*\)`.*/\1/' | awk '{print $1}' | sort -u)
}

test_convention_from_evidence
test_modes_and_baselines
test_exit_status_of_checks
test_commit_check_in_ci
test_commit_check_range
test_scope_of_changed_files
test_not_covered
test_audit_kinds
test_hook_with_untracked_xaden_files
