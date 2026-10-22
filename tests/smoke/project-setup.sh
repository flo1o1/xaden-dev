# shellcheck shell=bash
# Smoke test area "project-setup" (docs/requirements/project-setup). Sourced by tests/smoke.sh, which
# defines the helpers and creates the demo projects first. Runs against the adopted demo project (REQ-133).

# REQ-038 MIT license for the scaffold only
test_license() {
  assert "scaffold is MIT licensed" grep -qx 'MIT License' "$SCAFFOLD_ROOT/LICENSE"
  assert "generated projects do not inherit the scaffold license" test ! -e "$DEMO/LICENSE"
}

# REQ-001, REQ-133: the hooks of a project made by `xaden project create` run Xaden's checks
test_adopted_demo_hooks() {
  assert_fails_with "REQ-001 the commit-msg hook of a created project refuses a bad message" "types: feat fix" \
    git -C "$DEMO" commit -q --allow-empty -m "bad message"
  assert "REQ-001 the commit-msg hook of a created project accepts a conventional message" \
    git -C "$DEMO" commit -q --allow-empty -m "docs: a valid message"
  git -C "$DEMO" reset -q --keep HEAD~1
}

# REQ-012 usable by others (setup after clone, CI commit checks)
test_setup_and_commit_checks() {
  rm -f "$DEMO/.git/hooks/pre-commit" "$DEMO/.git/hooks/commit-msg"
  x_in "$DEMO" project setup
  assert "setup chains Xaden into the hooks of the clone" test "$XRC" -eq 0 -a -x "$DEMO/.git/hooks/pre-commit" -a -x "$DEMO/.git/hooks/commit-msg"
  # REQ-109 the range must exist: HEAD~1 is not there in a project with one commit, and such a range is no valid history
  git -C "$DEMO" commit -q --allow-empty --no-verify -m "docs: a valid commit"
  assert "verify-commits accepts valid history" "$DEMO_TOOLS/verify-commits.sh" HEAD~1..HEAD
  git -C "$DEMO" commit -q --allow-empty --no-verify -m "feat: sneaked past hooks"
  assert_fails "verify-commits catches skipped hooks" "$DEMO_TOOLS/verify-commits.sh" HEAD~1..HEAD
  assert_fails_with "verify-commits fails on a range it cannot read" "cannot read" "$DEMO_TOOLS/verify-commits.sh" HEAD~99..HEAD
  git -C "$DEMO" reset -q --hard HEAD~2
}

# REQ-056: `xaden` runs the scaffold's and the current project's scripts from any directory.
# REQ-135 `xaden core completion bash` prints a completion script whose lists are the ones `xaden ... help` shows
test_completion() {
  local xaden="$SCAFFOLD_ROOT/scripts/xaden.sh" script="$WORKDIR/xaden-completion.bash" namespace prompts
  "$xaden" core completion bash >"$script"
  assert "REQ-135 the completion script is valid bash" bash -n "$script"
  assert_fails_with "REQ-135 completion for another shell is refused" "xaden core completion" "$xaden" core completion zsh
  assert_fails_with "REQ-135 completion without a shell is refused" "xaden core completion" "$xaden" core completion
  # offered <words...>: what Tab offers after the words, the last one being the (possibly empty) word under the cursor
  offered() { bash -c 'source "$1"; shift; COMP_WORDS=("$@"); COMP_CWORD=$(($# - 1)); _xaden; printf "%s\n" "${COMPREPLY[@]}" | sort' _ "$script" "$@"; }
  listed() { "$xaden" "$@" help | sed -n 's/^  \([a-z][a-z-]*\).*/\1/p' | sort -u; }
  assert "REQ-135 xaden <Tab> offers the commands of xaden help" test "$(offered xaden '')" = "$(listed)"
  for namespace in core project aidd; do
    assert "REQ-135 xaden $namespace <Tab> offers the commands of xaden $namespace help" \
      test "$(offered xaden "$namespace" '')" = "$(listed "$namespace")"
  done
  assert "REQ-135 xaden pr<Tab> narrows the list" test "$(offered xaden pr)" = "$(printf 'project\nprompt')"
  prompts="$(printf '%s\n' "$SCAFFOLD_ROOT"/template/prompts/*.md | sed 's#.*/##; s#\.md$##' | grep -v '^00-index$' | sort)"
  assert "REQ-135 xaden prompt <Tab> offers the prompt names" test "$(offered xaden prompt '')" = "$prompts"
  assert "REQ-135 xaden doc <Tab> offers the guides" test "$(offered xaden doc clean)" = "clean-code"
  assert "REQ-135 add-preset offers the stacks" test "$(offered xaden project add-preset '')" = "$(printf 'node\npython')"
  assert "REQ-135 --stack offers the stacks" test "$(offered xaden project create --stack '')" = "$(printf 'node\npython')"
  assert "REQ-135 a dash offers the options of upgrade" test "$(offered xaden core upgrade -)" = "$(printf -- '--check\n--if-due')"
  assert "REQ-135 a dash narrows the options of create" test "$(offered xaden project create --a)" = "--autopilot"
}

test_xaden_command() {
  local bin="$WORKDIR/xaden-bin" elsewhere="$WORKDIR/elsewhere" xaden
  xaden="$bin/xaden"
  mkdir -p "$elsewhere"
  assert "install warns when the directory is not on PATH" \
    bash -c "'$SCAFFOLD_ROOT/scripts/install.sh' '$bin' 2>&1 | grep -q 'not on PATH'"
  assert "install links xaden to this checkout" test "$(readlink "$xaden")" = "$SCAFFOLD_ROOT/scripts/xaden.sh"
  assert "xaden version prints the scaffold version" \
    test "$("$xaden" version)" = "$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")"
  assert "xaden project help lists the commands" bash -c "'$xaden' project help | grep -q 'create <name>'"
  assert_fails "unknown xaden command fails" "$xaden" fly
  # REQ-131 the moved commands live under core and project; their old top-level spellings are unknown
  assert "REQ-131 xaden core version prints the version" \
    test "$("$xaden" core version)" = "$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")"
  assert "REQ-131 xaden help lists the namespaces" bash -c "'$xaden' help | grep -q 'xaden <core|project|aidd>'"
  assert "REQ-131 xaden project help lists the project commands" bash -c "'$xaden' project help | grep -q 'pin \[--check\]' && '$xaden' project help | grep -q '^  add-preset '"
  assert "REQ-131 xaden core help lists the core commands" \
    bash -c "for c in upgrade version fetch doctor ignore-list help; do '$xaden' core help | grep -q \"^  \$c\" || exit 1; done"
  assert "REQ-131 -h and --help after a namespace list its commands" \
    bash -c "test \"\$('$xaden' core -h)\" = \"\$('$xaden' core help)\" && test \"\$('$xaden' project --help)\" = \"\$('$xaden' project help)\""
  assert "REQ-131 the project list no longer has fetch, doctor, ignore-list or preset" \
    bash -c "! '$xaden' project help | grep -qE '^  (fetch|doctor|ignore-list|preset) '"
  for old in fetch doctor ignore-list preset; do
    assert_fails_with "REQ-131 xaden project $old is unknown" "unknown command: xaden project $old" "$xaden" project "$old"
  done
  assert_fails_with "REQ-131 xaden help takes no namespace" "unknown command: xaden help core" "$xaden" help core
  assert_fails_with "REQ-131 xaden core without a command lists its commands" "xaden core <command>" "$xaden" core
  assert_fails_with "REQ-131 xaden project without a command lists its commands" "xaden project <command>" "$xaden" project
  assert_fails_with "REQ-131 an unknown project command is named" "unknown command: xaden project fly" "$xaden" project fly
  # REQ-132 version, check and req are aliases; aidd is a namespace with its own help
  assert "REQ-132 xaden version is xaden core version" test "$("$xaden" version)" = "$("$xaden" core version)"
  assert "REQ-132 xaden project help lists check and req" bash -c "'$xaden' project help | grep -q '^  check ' && '$xaden' project help | grep -q '^  req '"
  assert "REQ-132 xaden aidd help lists its commands" bash -c "'$xaden' aidd help | grep -q 'enable' && '$xaden' aidd --help | grep -q '^  help ' && '$xaden' help | grep -q 'xaden <core|project|aidd>'"
  for old in create adopt remove pin fetch doctor upgrade rules preset setup release persona ignore-list; do
    assert_fails_with "REQ-131 xaden $old is unknown at the top level" "unknown command: $old" "$xaden" "$old"
  done
  assert_fails_with "project command outside a project fails" "inside a project" \
    bash -c "cd '$elsewhere' && '$xaden' check"

  assert_fails_with "xaden project create --classic is an unknown option (REQ-001)" "unknown option: --classic" \
    bash -c "cd '$elsewhere' && '$xaden' project create --classic xaden-app"
  assert "xaden project create --classic creates nothing (REQ-001)" test ! -e "$elsewhere/xaden-app"
  assert "xaden project create makes the project in the current directory" bash -c "cd '$elsewhere' && '$xaden' project create xaden-app"
  assert "new project has its first commit" git -C "$elsewhere/xaden-app" log -1 --format=%s
  assert "xaden project create accepts a dotted name (REQ-155)" bash -c "cd '$elsewhere' && '$xaden' project create mywebsite.com"
  assert "a dotted name keeps its dot in the project files (REQ-155)" grep -q '^# mywebsite.com' "$elsewhere/mywebsite.com/README.md"
  assert_fails_with "a trailing dot is a bad project name (REQ-155)" "invalid project name" \
    bash -c "cd '$elsewhere' && '$xaden' project create trailing. '$WORKDIR/trailing-dot'"
  assert "a refused dotted name creates nothing (REQ-155)" test ! -e "$WORKDIR/trailing-dot"
  # REQ-158 a name is one line: grep matched per line, so a second line used to pass
  assert_fails_with "a name with a newline is a bad project name (REQ-158)" "invalid project name" \
    bash -c "cd '$elsewhere' && '$xaden' project create \"\$(printf 'ab\\n/../../escaped')\" '$WORKDIR/newline-name'"
  assert "a refused multi-line name creates nothing (REQ-158)" test ! -e "$WORKDIR/newline-name"
  assert_fails_with "an empty dot part is a bad project name (REQ-155)" "invalid project name" \
    bash -c "cd '$elsewhere' && '$xaden' project create 'my..website' '$WORKDIR/empty-dot-part'"
  assert "a refused double-dot name creates nothing (REQ-155)" test ! -e "$WORKDIR/empty-dot-part"
  assert "xaden new is an unknown command and creates nothing (REQ-130)" \
    bash -c "cd '$elsewhere' && ! '$xaden' new old-name-app >/dev/null 2>&1 && test ! -e old-name-app"
  assert "project command runs from a subdirectory" \
    bash -c "cd '$elsewhere/xaden-app/xaden' && '$xaden' req new core job 'Probe' >/dev/null && '$xaden' req list | grep -q '^REQ-001 '"
  assert "xaden update is an unknown command (REQ-001)" \
    bash -c "cd '$elsewhere/xaden-app/xaden' && ! '$xaden' update >/dev/null 2>&1"

  assert "REQ-132 xaden project req does what xaden req does" \
    bash -c "cd '$elsewhere/xaden-app' && test \"\$('$xaden' project req list)\" = \"\$('$xaden' req list)\" && '$xaden' project req list | grep -q '^REQ-001 '"
  assert "REQ-132 xaden project check and xaden check fail the same way for a bad flag" \
    bash -c "cd '$elsewhere/xaden-app' && test \"\$('$xaden' project check --bogus 2>&1)\" = \"\$('$xaden' check --bogus 2>&1)\""
  local nowhere="$WORKDIR/no-repository" unadopted="$WORKDIR/unadopted-repository" command
  mkdir -p "$nowhere" "$unadopted" && git -C "$unadopted" init -q -b main
  for command in "project setup" "project pin" "core doctor" "project rules" "project add-preset python" "project release patch" \
    "project persona new x" "core ignore-list" "core fetch 9.9.9" "project check" "project req list" check "req list" context "prompt feature" "doc security" "aidd status"; do
    # shellcheck disable=SC2086 # the command words are split on purpose
    assert_fails_with "REQ-132 outside a git repository '$command' names create and adopt" "xaden project create <name>, or adopt an existing repository with: xaden project adopt" \
      bash -c "cd '$nowhere' && '$xaden' $command"
    # shellcheck disable=SC2086
    assert_fails_with "REQ-132 in a repository without Xaden '$command' gives the one message" "this repository has not adopted Xaden; run: xaden project adopt" \
      bash -c "cd '$unadopted' && '$xaden' $command"
  done

  mkdir -p "$WORKDIR/other-bin" && ln -s /bin/echo "$WORKDIR/other-bin/xaden"
  assert_fails "uninstall keeps a xaden link to something else" "$SCAFFOLD_ROOT/scripts/install.sh" --uninstall "$WORKDIR/other-bin"
  assert "foreign link left in place" test -L "$WORKDIR/other-bin/xaden"
  printf 'x\n' >"$elsewhere/xaden-app/leftover.md-dist"
  assert "doctor names a leftover -dist file (REQ-100)" \
    bash -c "cd '$elsewhere/xaden-app' && '$xaden' core doctor 2>&1 | grep -q 'leftover.md-dist'"
  rm "$elsewhere/xaden-app/leftover.md-dist"
  assert "uninstall removes the link" "$SCAFFOLD_ROOT/scripts/install.sh" --uninstall "$bin"
  assert_fails "link gone after uninstall" test -L "$xaden"
}

# REQ-001 generation ignores a PROJECT_ROOT that the caller's environment already carries
# shellcheck disable=SC2153 # XADEN is set by lib.sh
test_generation_ignores_project_root() {
  local other="$WORKDIR/foreign-repo" target="$WORKDIR/root-env/app"
  git init -q -b main "$other"
  assert "create while PROJECT_ROOT names another repository" env PROJECT_ROOT="$other" "$XADEN" project create root-app "$target"
  assert "new project has its hooks" test -x "$target/.git/hooks/pre-commit" -a -x "$target/.git/hooks/commit-msg"
  assert "other repository's configuration and hooks untouched" test -z "$(git -C "$other" config --get core.hooksPath || true)$(find "$other/.git/hooks" -type f ! -name '*.sample')"
}

# REQ-090 worktrees/ folder for change worktrees
test_worktrees_folder() {
  assert "the guidance names worktrees/<slug>" grep -q 'git worktree add worktrees/<slug>' "$SCAFFOLD_ROOT/template/docs/rules/git.md"
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
}

# REQ-118 the AIDD framework is switched on, checked and off again through its own CLI, pinned. The CLI is a stub
# (XADEN_AIDD_RUNNER) that writes what the real one writes: .aidd/manifest.json with the release of every plugin.
# REQ-153 npm and the framework's repository are stubs too (XADEN_AIDD_NPM_VIEW, XADEN_AIDD_LS_REMOTE): they
# answer the files $npm and $tag hold, so the pin check runs offline and every test can rewrite the answers.
# shellcheck disable=SC2016 # the stub and the bash -c scripts are single-quoted on purpose
test_aidd_framework() {
  local x="$SCAFFOLD_ROOT/scripts/xaden.sh" stub="$WORKDIR/aidd-stub" fakebin="$WORKDIR/aidd-node" log="$WORKDIR/aidd-stub.log" repo="$WORKDIR/aidd-repo" out="$WORKDIR/aidd.out" version npm="$WORKDIR/aidd-npm.txt" tag="$WORKDIR/aidd-tag.txt" npmview="$WORKDIR/aidd-npm-view" gitview="$WORKDIR/aidd-tag-view" integrity commit
  version="$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")"
  integrity="$(sed -n 's/^AIDD_DEFAULT_INTEGRITY="\([^"]*\)"$/\1/p' "$SCAFFOLD_ROOT/scripts/aidd.sh")"
  commit="$(sed -n 's/^AIDD_DEFAULT_COMMIT="\([^"]*\)"$/\1/p' "$SCAFFOLD_ROOT/scripts/aidd.sh")"
  printf '%s\n' "$integrity" >"$npm"
  printf '%s\n' "$commit" >"$tag"
  printf '#!/bin/sh\ncat %s\n' "$npm" >"$npmview"
  printf '#!/bin/sh\ncat %s\n' "$tag" >"$gitview"
  chmod +x "$npmview" "$gitview"
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
    (cd "$repo" && env -u CI PATH="$fakebin:$PATH" XADEN_AIDD_RUNNER="$stub" XADEN_AIDD_NPM_VIEW="$npmview" XADEN_AIDD_LS_REMOTE="$gitview" STUB_LOG="$log" "$@") >"$out" 2>&1 || aidd_rc=$?
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

  printf 'sha512-attacker-swapped-the-tarball-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==\n' >"$npm"
  : >"$log"
  aidd_yes enable
  assert "REQ-153 enable stops when npm answers another integrity" test "$aidd_rc" -ne 0 -a ! -e "$repo/.aidd"
  assert "REQ-153 the refusal says what npm answers" grep -q 'not the pinned integrity' "$out"
  assert "REQ-153 and the framework's CLI never ran" test ! -s "$log"
  printf '%s\n' "$integrity" >"$npm"

  printf '0000000000000000000000000000000000000000\n' >"$tag"
  : >"$log"
  aidd_yes enable
  assert "REQ-153 enable stops when the release tag points elsewhere" test "$aidd_rc" -ne 0 -a ! -e "$repo/.aidd"
  assert "REQ-153 the refusal says the tag moved" grep -q 'the tag moved after the pin was set' "$out"
  assert "REQ-153 and the framework's CLI never ran" test ! -s "$log"
  printf '%s\n' "$commit" >"$tag"

  aidd_yes enable
  assert "REQ-118 enable installs" test "$aidd_rc" -eq 0 -a -f "$repo/.aidd/manifest.json"
  assert "REQ-118 it skips an assistant the framework does not support" grep -q 'skipped vibe' "$out"
  assert "REQ-118 it lists the files it added" grep -q '\.aidd/manifest.json' "$out"
  assert "REQ-118 it warns about the user-level marketplace before the question" grep -q "registers the marketplace 'aidd-framework'" "$out"
  assert "REQ-118 the pinned CLI version and release are recorded" bash -c 'grep -q "^aidd-cli = 5.5.0$" "$1" && grep -q "^aidd-release = v5.12.0$" "$1"' _ "$repo/xaden/xaden.conf"
  assert "REQ-153 enable records the integrity and the commit of the pin" bash -c 'grep -qF "aidd-integrity = $2" "$1" && grep -qF "aidd-commit = $3" "$1"' _ "$repo/xaden/xaden.conf" "$integrity" "$commit"
  assert "REQ-118 the CLI is called with the exact version and the release, never latest" bash -c '! grep -qi latest "$1" && grep -q "^5.5.0 setup .*--release v5.12.0" "$1"' _ "$log"
  assert "REQ-118 the rules file gets the mapping block" bash -c 'grep -q "xaden:aidd:begin" "$1" && grep -q "these rules win" "$1"' _ "$repo/AGENTS.md"
  aidd "$x" aidd status
  assert "REQ-118 status shows the pin next to the installed release" bash -c 'grep -q "pinned:    CLI 5.5.0, release v5.12.0" "$1" && grep -q "installed: release v5.12.0" "$1"' _ "$out"
  assert "REQ-153 status shows what npm and the release tag must answer" bash -c 'grep -qF "$2" "$1" && grep -qF "$3" "$1"' _ "$out" "$integrity" "$commit"
  aidd_yes enable
  assert "REQ-118 enable twice is harmless" test "$aidd_rc" -eq 0
  assert "REQ-118 nothing in the template or the checks depends on the add-on" bash -c '! grep -rlE "aidd-cli|aidd\.sh" "$1/template" "$1/scripts/check-scaffold.sh"' _ "$SCAFFOLD_ROOT"

  grep -v -e '^aidd-integrity' -e '^aidd-commit' "$repo/xaden/xaden.conf" >"$WORKDIR/aidd.pre152" && cat "$WORKDIR/aidd.pre152" >"$repo/xaden/xaden.conf"
  : >"$log"
  aidd_yes disable
  assert "REQ-153 disable refuses a pin recorded before REQ-153" test "$aidd_rc" -ne 0 -a -e "$repo/.aidd"
  assert "REQ-153 and names the way to record the values" bash -c 'grep -q "recorded before REQ-153" "$1" && grep -q "move the pin once" "$1"' _ "$out"
  assert "REQ-153 the framework's CLI never ran" test ! -s "$log"
  printf 'aidd-integrity = %s\naidd-commit = %s\n' "$integrity" "$commit" >>"$repo/xaden/xaden.conf"

  # REQ-159 a pin that is not a version is refused before the CLI runs, even with a matching integrity
  cp "$repo/xaden/xaden.conf" "$WORKDIR/aidd.conf.keep"
  grep -v '^aidd-cli' "$WORKDIR/aidd.conf.keep" >"$repo/xaden/xaden.conf" && printf 'aidd-cli = npm:evil-pkg@1.0.0\n' >>"$repo/xaden/xaden.conf"
  : >"$log"
  aidd_yes disable
  assert "REQ-159 disable refuses an aidd-cli that is not a version" test "$aidd_rc" -ne 0 -a -e "$repo/.aidd"
  assert "REQ-159 and names the value" grep -q 'aidd-cli in xaden/xaden.conf must be a version like 5.5.0 (got: npm:evil-pkg@1.0.0)' "$out"
  assert "REQ-159 the framework's CLI never ran" test ! -s "$log"
  grep -v '^aidd-release' "$WORKDIR/aidd.conf.keep" >"$repo/xaden/xaden.conf" && printf 'aidd-release = main\n' >>"$repo/xaden/xaden.conf"
  aidd_yes disable
  assert "REQ-159 disable refuses an aidd-release that is not a tag" bash -c 'test "$1" -ne 0 && grep -q "aidd-release in xaden/xaden.conf must look like v5.12.0 (got: main)" "$2"' _ "$aidd_rc" "$out"
  cp "$WORKDIR/aidd.conf.keep" "$repo/xaden/xaden.conf"

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
  assert "REQ-153 pin records the integrity and the commit of the new pin" bash -c 'grep -qE "^aidd-integrity = sha512-" "$1/xaden/xaden.conf" && grep -qE "^aidd-commit = [0-9a-f]{40}$" "$1/xaden/xaden.conf"' _ "$repo-pin-aidd-v5.13.0"
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
test_adopted_demo_hooks
test_command_dist
test_generation_ignores_project_root
test_worktrees_folder
test_setup_and_commit_checks
test_xaden_command
test_completion
test_aidd_framework
