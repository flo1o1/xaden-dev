# shellcheck shell=bash
# Smoke test area "project-setup" (docs/requirements/project-setup). Sourced by tests/smoke.sh, which
# defines the helpers and creates the demo project first.

# REQ-038 MIT license for the scaffold only
test_license() {
  assert "scaffold is MIT licensed" grep -qx 'MIT License' "$SCAFFOLD_ROOT/LICENSE"
  assert "generated projects do not inherit the scaffold license" test ! -e "$PROJECT/LICENSE"
}

# REQ-018 safe generation: a git copy of the scaffold with junk that must never be copied
test_generation_safety() {
  local source="$WORKDIR/source-scaffold" target="$WORKDIR/safety/generated app"
  export_template "$SCAFFOLD_ROOT" "$source"
  git -C "$source" init -q -b main && git -C "$source" add -A && git -C "$source" commit -q -m "chore: fixture"
  printf 'SECRET=fixture\n' >"$source/template/.env"
  printf 'private\n' >"$source/template/local-private-note.txt"
  mkdir -p "$source/template/node_modules/pkg" && printf 'x\n' >"$source/template/node_modules/pkg/index.js"
  printf 'dropped\n' >"$source/template/inbox/dropped.txt"
  mkdir -p "$source/template/worktrees/leftover" && printf 'x\n' >"$source/template/worktrees/leftover/file.txt"
  printf '\nUNCOMMITTED EDIT\n' >>"$source/template/prompts/bugfix.md"
  local before
  before="$(git -C "$source" status --porcelain)"
  assert "generate from git source with junk" "$source/scripts/new-project.sh" safe-app "$target"
  assert "untracked private file not copied" test ! -e "$target/local-private-note.txt"
  assert ".env not copied" test ! -e "$target/.env"
  assert "node_modules not copied" test ! -e "$target/node_modules"
  assert "inbox content not copied" test ! -e "$target/inbox/dropped.txt"
  assert "worktrees content not copied" test ! -e "$target/worktrees/leftover"
  assert "uncommitted edit of tracked file copied (maintainer testing)" grep -q 'UNCOMMITTED EDIT' "$target/prompts/bugfix.md"
  assert "executable bits preserved" test -x "$target/scripts/check.sh"
  assert "source left untouched" test "$(git -C "$source" status --porcelain)" = "$before"
  assert_fails "existing target refused" "$source/scripts/new-project.sh" safe-app "$target"
  ln -s ../README.md "$source/template/link.md" && git -C "$source" add template/link.md
  assert_fails "symlink in template refused" "$source/scripts/new-project.sh" link-app "$WORKDIR/link-app"
  assert "nothing created when export is refused" test ! -e "$WORKDIR/link-app"
  git -C "$source" rm -q --cached template/link.md && rm "$source/template/link.md"
  edit_file "$(req_file "$source/template" REQ-001)" 's/^status: .*/status: bogus/'
  assert_fails "generation fails when the first commit is rejected" "$source/scripts/new-project.sh" late-fail "$WORKDIR/late-fail"
  assert "partial project removed after late failure" test ! -e "$WORKDIR/late-fail"
}

# REQ-026 local drop zone
test_inbox() {
  printf 'private\n' >"$PROJECT/inbox/notes.txt"
  assert "inbox README tracked" git -C "$PROJECT" ls-files --error-unmatch inbox/README.md
  assert "inbox contents ignored by git" git -C "$PROJECT" check-ignore -q inbox/notes.txt
  assert "inbox contents never staged by add -A" test -z "$(git -C "$PROJECT" add -A --dry-run | grep inbox/notes.txt || true)"
  rm -f "$PROJECT/inbox/notes.txt"
}

# REQ-012 usable by others (setup after clone, CI commit checks)
test_setup_and_commit_checks() {
  git -C "$PROJECT" config --unset core.hooksPath
  assert "setup activates hooks" "$PROJECT/scripts/setup.sh"
  assert "hooks path restored" test "$(git -C "$PROJECT" config core.hooksPath)" = "scripts/hooks"
  # REQ-109 the range must exist: HEAD~1 is not there in a project with one commit, and such a range is no valid history
  git -C "$PROJECT" commit -q --allow-empty --no-verify -m "docs: a valid commit"
  assert "verify-commits accepts valid history" "$PROJECT/scripts/verify-commits.sh" HEAD~1..HEAD
  git -C "$PROJECT" commit -q --allow-empty --no-verify -m "feat: sneaked past hooks"
  assert_fails "verify-commits catches skipped hooks" "$PROJECT/scripts/verify-commits.sh" HEAD~1..HEAD
  assert_fails_with "verify-commits fails on a range it cannot read" "cannot read" "$PROJECT/scripts/verify-commits.sh" HEAD~99..HEAD
  git -C "$PROJECT" reset -q --hard HEAD~2
}

# REQ-056: `xaden` runs the scaffold's and the current project's scripts from any directory.
test_xaden_command() {
  local bin="$WORKDIR/xaden-bin" elsewhere="$WORKDIR/elsewhere" xaden
  xaden="$bin/xaden"
  mkdir -p "$elsewhere"
  assert "install warns when the directory is not on PATH" \
    bash -c "'$SCAFFOLD_ROOT/scripts/install.sh' '$bin' 2>&1 | grep -q 'not on PATH'"
  assert "install links xaden to this checkout" test "$(readlink "$xaden")" = "$SCAFFOLD_ROOT/scripts/xaden.sh"
  assert "xaden version prints the scaffold version" \
    test "$("$xaden" version)" = "$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")"
  assert "xaden help lists the commands" bash -c "'$xaden' help | grep -q 'create <name>'"
  assert_fails "unknown xaden command fails" "$xaden" fly
  # REQ-131 the moved commands live under core and project; their old top-level spellings are unknown
  assert "REQ-131 xaden core version prints the version" \
    test "$("$xaden" core version)" = "$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")"
  assert "REQ-131 xaden help lists the namespaces" bash -c "'$xaden' help | grep -q 'xaden <core|project>'"
  assert "REQ-131 xaden help project lists the project commands" bash -c "'$xaden' help project | grep -q 'pin \[--check\]'"
  assert "REQ-131 xaden help core lists the core commands" bash -c "'$xaden' help core | grep -q 'upgrade'"
  assert_fails_with "REQ-131 xaden core without a command lists its commands" "xaden core <command>" "$xaden" core
  assert_fails_with "REQ-131 xaden project without a command lists its commands" "xaden project <command>" "$xaden" project
  assert_fails_with "REQ-131 an unknown project command is named" "unknown command: xaden project fly" "$xaden" project fly
  for old in create adopt remove pin fetch doctor upgrade rules preset setup release persona ignore-list; do
    assert_fails_with "REQ-131 xaden $old is unknown at the top level" "unknown command: $old" "$xaden" "$old"
  done
  assert_fails_with "project command outside a project fails" "inside a project" \
    bash -c "cd '$elsewhere' && '$xaden' check"

  assert_fails_with "xaden project create --classic is an unknown option (REQ-001)" "unknown option: --classic" \
    bash -c "cd '$elsewhere' && '$xaden' project create --classic xaden-app"
  assert "xaden project create --classic creates nothing (REQ-001)" test ! -e "$elsewhere/xaden-app"
  assert "the maintainers' fixture makes a project with its own tooling" "$SCAFFOLD_ROOT/scripts/new-project.sh" xaden-app "$elsewhere/xaden-app"
  assert "new project has its first commit" git -C "$elsewhere/xaden-app" log -1 --format=%s
  assert "xaden new is an unknown command and creates nothing (REQ-130)" \
    bash -c "cd '$elsewhere' && ! '$xaden' new old-name-app >/dev/null 2>&1 && test ! -e old-name-app"
  assert "project command runs from a subdirectory" \
    bash -c "cd '$elsewhere/xaden-app/docs' && '$xaden' req list | grep -q '^REQ-001 '"
  assert "xaden update is an unknown command (REQ-001)" \
    bash -c "cd '$elsewhere/xaden-app/docs' && ! '$xaden' update >/dev/null 2>&1"

  mkdir -p "$WORKDIR/other-bin" && ln -s /bin/echo "$WORKDIR/other-bin/xaden"
  assert_fails "uninstall keeps a xaden link to something else" "$SCAFFOLD_ROOT/scripts/install.sh" --uninstall "$WORKDIR/other-bin"
  assert "foreign link left in place" test -L "$WORKDIR/other-bin/xaden"
  printf 'x\n' >"$elsewhere/xaden-app/prompts/leftover.md-dist"
  assert "doctor names a leftover -dist file (REQ-100)" \
    bash -c "cd '$elsewhere/xaden-app' && '$xaden' project doctor 2>&1 | grep -q 'prompts/leftover.md-dist'"
  rm "$elsewhere/xaden-app/prompts/leftover.md-dist"
  assert "uninstall removes the link" "$SCAFFOLD_ROOT/scripts/install.sh" --uninstall "$bin"
  assert_fails "link gone after uninstall" test -L "$xaden"
}

# REQ-001 generation ignores a PROJECT_ROOT that the caller's environment already carries
test_generation_ignores_project_root() {
  local other="$WORKDIR/foreign-repo" target="$WORKDIR/root-env/app"
  git init -q -b main "$other"
  assert "generate while PROJECT_ROOT names another repository" env PROJECT_ROOT="$other" "$SCAFFOLD_ROOT/scripts/new-project.sh" root-app "$target"
  assert "new project has its hooks path" test "$(git -C "$target" config core.hooksPath)" = "scripts/hooks"
  assert "other repository's configuration untouched" test -z "$(git -C "$other" config --get core.hooksPath || true)"
}

# REQ-090 worktrees/ folder for change worktrees
test_worktrees_folder() {
  assert "worktrees README tracked" git -C "$PROJECT" ls-files --error-unmatch worktrees/README.md
  git -C "$PROJECT" worktree add -q worktrees/probe -b chore/probe-worktree HEAD
  assert "a worktree in worktrees/ is ignored by git" git -C "$PROJECT" check-ignore -q worktrees/probe
  assert "worktrees contents never staged by add -A" test -z "$(git -C "$PROJECT" add -A --dry-run | grep worktrees/probe || true)"
  assert "the guidance names worktrees/<slug>" grep -q 'git worktree add worktrees/<slug>' "$PROJECT/docs/rules/git.md"
  git -C "$PROJECT" worktree remove --force worktrees/probe && git -C "$PROJECT" branch -D chore/probe-worktree >/dev/null
}

# REQ-100 command files: an unedited one follows the new prompts, an edited one stays and the new text is <file>-dist
test_command_dist() {
  local dir="$WORKDIR/dist-sync" old="$WORKDIR/dist-old" new="$WORKDIR/dist-new" newer="$WORKDIR/dist-newer" file
  mkdir -p "$dir" "$old/prompts" "$new/prompts" "$newer/prompts"
  printf -- '---\ntitle: Old title\n---\n' >"$old/prompts/feature.md"
  printf -- '---\ntitle: New title\n---\n' >"$new/prompts/feature.md"
  printf -- '---\ntitle: Newer title\n---\n' >"$newer/prompts/feature.md"
  file=".claude/commands/xaden-feature.md"
  sync_commands "$dir" "$old" claude
  assert "a command file is written" grep -q 'Old title' "$dir/$file"
  sync_commands "$dir" "$new" claude "$old"
  assert "an unedited command file follows the new prompt" grep -q 'New title' "$dir/$file"
  assert "an unedited command file leaves no -dist file" test ! -e "$dir/$file-dist"
  printf 'My own wording.\n' >"$dir/$file"
  sync_commands "$dir" "$newer" claude "$new"
  assert "an edited command file stays as it is" grep -q 'My own wording.' "$dir/$file"
  assert "the new command text comes as -dist" grep -q 'Newer title' "$dir/$file-dist"
  assert "the -dist file is in the footprint, so remove takes it out" grep -qxF "file $file-dist" "$dir/$FOOTPRINT_FILE"
  assert "the template ignores -dist files" grep -qxF '*-dist' "$SCAFFOLD_ROOT/template/.gitignore"
}

# REQ-118 the AIDD framework is switched on, checked and off again through its own CLI, pinned. The CLI is a stub
# (XADEN_AIDD_RUNNER) that writes what the real one writes: .aidd/manifest.json with the release of every plugin.
# shellcheck disable=SC2016 # the stub and the bash -c scripts are single-quoted on purpose
test_aidd_framework() {
  local x="$SCAFFOLD_ROOT/scripts/xaden.sh" stub="$WORKDIR/aidd-stub" fakebin="$WORKDIR/aidd-node" log="$WORKDIR/aidd-stub.log" repo="$WORKDIR/aidd-repo" out="$WORKDIR/aidd.out" version
  version="$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")"
  mkdir -p "$fakebin"
  cat >"$stub" <<'STUB'
#!/usr/bin/env bash
echo "$XADEN_AIDD_CLI_VERSION $*" >>"$STUB_LOG"
case "$1" in
  setup)
    if [ "${2:-}" = "--help" ]; then [ "${STUB_NO_RELEASE:-0}" = 1 ] || echo "  --release <tag>  Marketplace release tag to fetch"; exit 0; fi
    release=""
    while [ "$#" -gt 0 ]; do if [ "$1" = "--release" ]; then release=$2; fi; shift; done
    [ "${STUB_WRONG_REF:-0}" != 1 ] || release=v0.0.1
    mkdir -p .aidd .claude
    printf '{\n  "plugins": [\n    {\n      "ref": "%s"\n    }\n  ]\n}\n' "$release" >.aidd/manifest.json
    printf '{}\n' >.claude/settings.json ;;
  clean) rm -rf .aidd .claude ;;
esac
STUB
  chmod +x "$stub"
  printf '#!/bin/sh\necho v22.12.0\n' >"$fakebin/node" && chmod +x "$fakebin/node"
  mkdir -p "$repo/xaden" && git -C "$repo" init -q -b main
  printf 'version = %s\nmode = advisory\nassistants = claude,vibe\n' "$version" >"$repo/xaden/xaden.conf"
  printf '# Rules\n' >"$repo/AGENTS.md"
  git -C "$repo" add -A && git -C "$repo" -c user.name=t -c user.email=t@example.com commit -q -m "chore: init"
  # aidd <env...> -- <args...>: xaden aidd in the repository, output in $out, status in $aidd_rc
  aidd() {
    aidd_rc=0
    (cd "$repo" && env -u CI PATH="$fakebin:$PATH" XADEN_AIDD_RUNNER="$stub" STUB_LOG="$log" "$@") >"$out" 2>&1 || aidd_rc=$?
  }
  aidd_yes() { aidd env XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=y "$x" aidd "$@"; }

  aidd "$x" aidd status
  assert "REQ-118 status says the framework is not enabled" grep -q 'not enabled' "$out"

  aidd env STUB_NO_RELEASE=1 XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=y "$x" aidd enable
  assert "REQ-118 a CLI that cannot take a release stops enable" test "$aidd_rc" -ne 0 -a ! -e "$repo/.aidd"
  assert "REQ-118 the refusal says why" grep -q 'cannot be held to release' "$out"

  printf '#!/bin/sh\necho v20.1.0\n' >"$fakebin/node"
  aidd_yes enable
  assert "REQ-118 an old Node stops enable before it installs" test "$aidd_rc" -ne 0 -a ! -e "$repo/.aidd"
  assert "REQ-118 the refusal names the prerequisite and the version found" grep -q 'needs Node 22.12 or later; found v20.1.0' "$out"
  printf '#!/bin/sh\necho v22.12.0\n' >"$fakebin/node"

  : >"$log"
  aidd "$x" aidd enable
  assert "REQ-118 enable without a terminal installs nothing" test "$aidd_rc" -ne 0 -a ! -e "$repo/.aidd"
  assert "REQ-128 enable without a terminal never calls the framework's CLI" test ! -s "$log"
  aidd env XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=n "$x" aidd enable
  assert "REQ-118 enable answered no installs nothing" test "$aidd_rc" -ne 0 -a ! -e "$repo/.aidd"
  assert "REQ-128 enable answered no never calls the framework's CLI" test ! -s "$log"

  aidd_yes enable
  assert "REQ-118 enable installs" test "$aidd_rc" -eq 0 -a -f "$repo/.aidd/manifest.json"
  assert "REQ-118 it skips an assistant the framework does not support" grep -q 'skipped vibe' "$out"
  assert "REQ-118 it lists the files it added" grep -q '\.aidd/manifest.json' "$out"
  assert "REQ-118 it warns about the user-level marketplace before the question" grep -q "registers the marketplace 'aidd-framework'" "$out"
  assert "REQ-118 the pinned CLI version and release are recorded" bash -c 'grep -q "^aidd-cli = 5.5.0$" "$1" && grep -q "^aidd-release = v5.12.0$" "$1"' _ "$repo/xaden/xaden.conf"
  assert "REQ-118 the CLI is called with the exact version and the release, never latest" bash -c '! grep -qi latest "$1" && grep -q "^5.5.0 setup .*--release v5.12.0" "$1"' _ "$log"
  assert "REQ-118 the rules file gets the mapping block" bash -c 'grep -q "xaden:aidd:begin" "$1" && grep -q "these rules win" "$1"' _ "$repo/AGENTS.md"
  aidd "$x" aidd status
  assert "REQ-118 status shows the pin next to the installed release" bash -c 'grep -q "pinned:    CLI 5.5.0, release v5.12.0" "$1" && grep -q "installed: release v5.12.0" "$1"' _ "$out"
  aidd_yes enable
  assert "REQ-118 enable twice is harmless" test "$aidd_rc" -eq 0
  assert "REQ-118 nothing in the template or the checks depends on the add-on" bash -c '! grep -rlE "aidd-cli|aidd\.sh" "$1/template" "$1/scripts/check-scaffold.sh"' _ "$SCAFFOLD_ROOT"

  : >"$log"
  aidd "$x" aidd pin 5.5.0 v5.13.0
  assert "REQ-128 pin without a terminal never calls the framework's CLI" test "$aidd_rc" -ne 0 -a ! -s "$log"
  aidd env XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=n "$x" aidd pin 5.5.0 v5.13.0
  assert "REQ-128 pin answered no never calls the framework's CLI" test "$aidd_rc" -ne 0 -a ! -s "$log"
  aidd env STUB_NO_RELEASE=1 XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=y "$x" aidd pin 5.5.0 v5.13.0
  assert "REQ-128 pin with a CLI that cannot take a release stops after the yes and changes nothing" test "$aidd_rc" -ne 0 -a -s "$log" -a ! -e "$repo-pin-aidd-v5.13.0"
  aidd_yes pin 5.5.0 v5.13.0
  assert "REQ-118 pin makes a branch of its own and leaves the current one unpinned" bash -c 'git -C "$1" rev-parse --verify -q chore/pin-aidd-v5.13.0 >/dev/null && grep -q "^aidd-release = v5.12.0$" "$1/xaden/xaden.conf"' _ "$repo"
  assert "REQ-118 pin records the new release and links the framework's changes" bash -c 'grep -q "^aidd-release = v5.13.0$" "$1/xaden/xaden.conf" && git -C "$1" log -1 --format=%B | grep -q "compare/v5.12.0...v5.13.0"' _ "$repo-pin-aidd-v5.13.0"
  git -C "$repo" worktree remove --force "$repo-pin-aidd-v5.13.0" && git -C "$repo" branch -D chore/pin-aidd-v5.13.0 >/dev/null

  aidd_yes disable
  assert "REQ-118 disable removes what enable added" test "$aidd_rc" -eq 0 -a ! -e "$repo/.aidd" -a ! -e "$repo/.claude"
  assert "REQ-118 disable removes the pin and the rules block" bash -c '! grep -q "aidd" "$1" && ! grep -q "xaden:aidd" "$2"' _ "$repo/xaden/xaden.conf" "$repo/AGENTS.md"
  assert "REQ-118 disable leaves the project's own rules" grep -q '^# Rules$' "$repo/AGENTS.md"

  aidd env STUB_WRONG_REF=1 XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=y "$x" aidd enable
  assert "REQ-118 a pin that did not hold removes the installation again" test "$aidd_rc" -ne 0 -a ! -e "$repo/.aidd"
  assert "REQ-118 and says so" grep -q 'the pin did not hold' "$out"
  assert "REQ-118 and records no pin" bash -c '! grep -q "aidd" "$1"' _ "$repo/xaden/xaden.conf"

  mkdir -p "$WORKDIR/aidd-classic" && git -C "$WORKDIR/aidd-classic" init -q -b main
  assert_fails_with "REQ-118 a project that did not adopt Xaden is told so" "adopted Xaden" bash -c 'cd "$1" && "$2" aidd status' _ "$WORKDIR/aidd-classic" "$x"
}

test_license
test_command_dist
test_generation_safety
test_generation_ignores_project_root
test_inbox
test_worktrees_folder
test_setup_and_commit_checks
test_xaden_command
test_aidd_framework
