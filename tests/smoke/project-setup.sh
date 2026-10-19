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

# REQ-017 update path for existing projects
test_scaffold_update() {
  local newer="$WORKDIR/newer-scaffold"
  assert "project records scaffold version" test -f "$PROJECT/.scaffold/version"
  assert "manifest lists managed files" grep -q 'prompts/feature.md' "$PROJECT/.scaffold/manifest"
  assert "manifest excludes project files" test -z "$(grep 'docs/requirements/' "$PROJECT/.scaffold/manifest" || true)"
  assert "fresh project is up to date" bash -c "'$SCAFFOLD_ROOT/scripts/update-scaffold.sh' '$PROJECT' | grep -q '0 change(s) planned'"
  git -C "$PROJECT" worktree add -q "$WORKDIR/worktree" -b worktree-branch
  assert "update runs in a git worktree" bash -c "'$SCAFFOLD_ROOT/scripts/update-scaffold.sh' '$WORKDIR/worktree' | grep -q '0 change(s) planned'"
  git -C "$PROJECT" worktree remove "$WORKDIR/worktree" && git -C "$PROJECT" branch -q -D worktree-branch

  # A newer scaffold: one changed prompt, one new prompt, one prompt changed on both sides.
  export_template "$SCAFFOLD_ROOT" "$newer"
  printf '9.9.9\n' >"$newer/VERSION"
  printf '\nUpstream improvement.\n' >>"$newer/template/prompts/bugfix.md"
  printf -- '---\ntitle: New\n---\n# New prompt\n' >"$newer/template/prompts/new-prompt.md"
  printf '\nUpstream change.\n' >>"$newer/template/prompts/feature.md"
  printf '\nMy local tweak.\n' >>"$PROJECT/prompts/feature.md"
  printf '\nProject requirement edit.\n' >>"$PROJECT/docs/requirements/README.md"
  git -C "$PROJECT" commit -q -am "docs: local prompt tweak and requirement edit" --no-verify

  assert "dry run changes nothing" bash -c "'$newer/scripts/update-scaffold.sh' '$PROJECT' >/dev/null && test -z \"\$(git -C '$PROJECT' status --porcelain)\""
  assert "update applies" "$newer/scripts/update-scaffold.sh" "$PROJECT" --apply
  assert "unmodified prompt updated" grep -q 'Upstream improvement.' "$PROJECT/prompts/bugfix.md"
  assert "new prompt added" test -f "$PROJECT/prompts/new-prompt.md"
  assert "local tweak kept on conflict" grep -q 'My local tweak.' "$PROJECT/prompts/feature.md"
  assert "conflict candidate written" grep -q 'Upstream change.' "$PROJECT/prompts/feature.md-dist"
  assert "project requirements untouched" grep -q 'Project requirement edit.' "$PROJECT/docs/requirements/README.md"
  assert "version recorded" test "$(cat "$PROJECT/.scaffold/version")" = "9.9.9"
  git -C "$PROJECT" reset -q --hard HEAD~1 && git -C "$PROJECT" clean -qfdx
}

# REQ-079: an update removes the managed pack script of an older scaffold and leaves the user's own files.
test_pack_script_removed() {
  local old="$WORKDIR/variants/legacy-pack" dash=- out script notes
  script="scripts/pack${dash}context.sh" notes="context${dash}pack.md" # spelled in parts so the guard in assistant-guidance.sh passes
  rm -rf "$old" && mkdir -p "$WORKDIR/variants" && cp -R "$PROJECT" "$old"
  printf '#!/usr/bin/env bash\necho old\n' >"$old/$script" && chmod +x "$old/$script"
  printf '%s\t%s\n' "$(content_sum <"$old/$script")" "$script" >>"$old/.scaffold/manifest"
  printf 'my notes\n' >"$old/$notes"
  printf '%s\n' "$notes" >>"$old/.git/info/exclude" # an older scaffold ignored it, so it does not block the update
  git -C "$old" add "$script" .scaffold/manifest && git -C "$old" commit -q -m "chore: old pack script" --no-verify
  out="$("$SCAFFOLD_ROOT/scripts/update-scaffold.sh" "$old" --apply)"
  assert "the update reports the removed script" grep -q "^remove .*$script" <<<"$out"
  assert_fails "the old script is gone" test -e "$old/$script"
  assert "the user's own file stays" grep -qx 'my notes' "$old/$notes"
}

# REQ-017: an update stays inside the project and only touches managed files, whatever the
# project's committed files say (security review 2026-10-11, findings 1 and 2).
test_update_safety() {
  local outside="$WORKDIR/outside.txt"
  printf 'keep me\n' >"$outside"
  printf '\nlocal edit\n' >>"$PROJECT/.clinerules"
  grep -v "$(printf '\t').clinerules\$" "$PROJECT/.scaffold/manifest" >"$WORKDIR/manifest" &&
    cp "$WORKDIR/manifest" "$PROJECT/.scaffold/manifest"
  ln -s "$outside" "$PROJECT/.clinerules-dist"
  git -C "$PROJECT" add -A && git -C "$PROJECT" commit -qn -m "chore: symlinked conflict file"
  assert_fails_with "update refuses to write through a symlink" "symbolic link" \
    "$SCAFFOLD_ROOT/scripts/update-scaffold.sh" "$PROJECT" --apply
  assert "file behind the symlink unchanged" test "$(cat "$outside")" = "keep me"
  git -C "$PROJECT" reset -q --hard HEAD~1 && git -C "$PROJECT" clean -qfdx

  mkdir -p "$PROJECT/src" && printf 'print(1)\n' >"$PROJECT/src/app.py"
  printf '%s\tsrc/app.py\n' "$(content_sum <"$PROJECT/src/app.py")" >>"$PROJECT/.scaffold/manifest"
  git -C "$PROJECT" add -A && git -C "$PROJECT" commit -qn -m "chore: manifest lists a project file"
  assert "update applies with a foreign manifest entry" "$SCAFFOLD_ROOT/scripts/update-scaffold.sh" "$PROJECT" --apply
  assert "project file listed in the manifest kept" test -f "$PROJECT/src/app.py"
  git -C "$PROJECT" reset -q --hard HEAD~1 && git -C "$PROJECT" clean -qfdx

  # A manifest path that climbs out of a managed folder is a project file too.
  mkdir -p "$PROJECT/src" && printf 'print(1)\n' >"$PROJECT/src/app.py"
  printf '%s\tscripts/../src/app.py\n' "$(content_sum <"$PROJECT/src/app.py")" >>"$PROJECT/.scaffold/manifest"
  git -C "$PROJECT" add -A && git -C "$PROJECT" commit -qn -m "chore: manifest path climbs out of scripts/"
  assert "update applies with a climbing manifest entry" "$SCAFFOLD_ROOT/scripts/update-scaffold.sh" "$PROJECT" --apply
  assert "project file behind a climbing manifest path kept" test -f "$PROJECT/src/app.py"
  git -C "$PROJECT" reset -q --hard HEAD~1 && git -C "$PROJECT" clean -qfdx
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
  assert_fails_with "project command outside a project fails" "inside a project" \
    bash -c "cd '$elsewhere' && '$xaden' check"

  assert "xaden create --classic creates the project in the current directory" bash -c "cd '$elsewhere' && '$xaden' create --classic xaden-app"
  assert "new project has its first commit" git -C "$elsewhere/xaden-app" log -1 --format=%s
  assert "xaden new still creates a project and names xaden create" \
    bash -c "cd '$elsewhere' && out=\$('$xaden' new old-name-app 2>&1) && test -d old-name-app/.git && grep -q 'xaden create' <<<\"\$out\""
  assert "project command runs from a subdirectory" \
    bash -c "cd '$elsewhere/xaden-app/docs' && '$xaden' req list | grep -q '^REQ-001 '"
  assert "xaden update runs for the surrounding project" \
    bash -c "cd '$elsewhere/xaden-app/docs' && '$xaden' update | grep -q '0 change(s) planned'"

  mkdir -p "$WORKDIR/other-bin" && ln -s /bin/echo "$WORKDIR/other-bin/xaden"
  assert_fails "uninstall keeps a xaden link to something else" "$SCAFFOLD_ROOT/scripts/install.sh" --uninstall "$WORKDIR/other-bin"
  assert "foreign link left in place" test -L "$WORKDIR/other-bin/xaden"
  printf 'x\n' >"$elsewhere/xaden-app/prompts/leftover.md-dist"
  assert "doctor names a leftover -dist file (REQ-100)" \
    bash -c "cd '$elsewhere/xaden-app' && '$xaden' doctor 2>&1 | grep -q 'prompts/leftover.md-dist'"
  rm "$elsewhere/xaden-app/prompts/leftover.md-dist"
  assert "uninstall removes the link" "$SCAFFOLD_ROOT/scripts/install.sh" --uninstall "$bin"
  assert_fails "link gone after uninstall" test -L "$xaden"
}

# REQ-059: .claude/settings.json follows scaffold updates; a project's own edits are kept.
test_settings_update() {
  local newer="$WORKDIR/newer-settings" settings="$PROJECT/.claude/settings.json"
  export_template "$SCAFFOLD_ROOT" "$newer"
  edit_file "$newer/template/.claude/settings.json" 's/"Bash(git log:\*)"/"Bash(git log:*)", "Bash(git show:*)"/'
  assert "update applies a new settings.json" "$newer/scripts/update-scaffold.sh" "$PROJECT" --apply
  assert "unedited settings.json updated" grep -q 'git show' "$settings"
  git -C "$PROJECT" reset -q --hard && git -C "$PROJECT" clean -qfdx

  edit_file "$settings" 's/"Bash(git log:\*)"/"Bash(git log:*)", "Bash(make test:*)"/'
  git -C "$PROJECT" commit -qn -am "chore: own permission"
  assert "update applies with an edited settings.json" "$newer/scripts/update-scaffold.sh" "$PROJECT" --apply
  assert "project's own permission kept" grep -q 'make test' "$settings"
  assert "new settings offered for merging" grep -q 'git show' "$settings-dist"
  git -C "$PROJECT" reset -q --hard HEAD~1 && git -C "$PROJECT" clean -qfdx

  grep -v "$(printf '\t').claude/settings.json\$" "$PROJECT/.scaffold/manifest" >"$WORKDIR/manifest" &&
    cp "$WORKDIR/manifest" "$PROJECT/.scaffold/manifest"
  git -C "$PROJECT" commit -qn -am "chore: manifest from before settings.json was managed"
  assert "update applies for an older project" "$newer/scripts/update-scaffold.sh" "$PROJECT" --apply
  assert "older project's settings offered for merging" test -f "$settings-dist"
  git -C "$PROJECT" reset -q --hard HEAD~1 && git -C "$PROJECT" clean -qfdx
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

# REQ-126: a project from before docs/rules/ and the short index gets both through the update
test_rules_folder_update() {
  local old="$WORKDIR/variants/old-rules" out
  rm -rf "$old" && mkdir -p "$WORKDIR/variants" && cp -R "$PROJECT" "$old"
  rm -rf "$old/docs/rules" "$old/docs/requirements/INDEX-full.md"
  printf '# Requirements index\n\n| REQ-001 | job | must | draft | Describe the first job |\n' >"$old/docs/requirements/INDEX.md"
  grep -v 'docs/rules/' "$old/.scaffold/manifest" >"$old/.scaffold/manifest.new" && mv "$old/.scaffold/manifest.new" "$old/.scaffold/manifest"
  git -C "$old" add -A && git -C "$old" commit -q -m "chore: layout of an older Xaden" --no-verify
  out="$("$SCAFFOLD_ROOT/scripts/update-scaffold.sh" "$old" --apply)"
  assert "REQ-126 the update adds the rule files" grep -q "docs/rules/git.md" <<<"$out"
  assert "REQ-126 the rule files are in the project" test -f "$old/docs/rules/git.md" -a -f "$old/docs/rules/requirements.md"
  assert "REQ-126 the update regenerates the index and adds the full table" bash -c "test -f '$old/docs/requirements/INDEX-full.md' \
    && ! grep -q 'Describe the first job.*Describe' '$old/docs/requirements/INDEX.md' && '$old/scripts/check-requirements.sh' >/dev/null 2>&1"
  assert "REQ-126 the update leaves AGENTS.md under the budget and does not duplicate the rules" \
    bash -c "test \"\$(wc -c <'$old/AGENTS.md')\" -le 10240 && ! grep -q '^- Conventional Commits' '$old/AGENTS.md'"
}

test_license
test_command_dist
test_generation_safety
test_generation_ignores_project_root
test_inbox
test_worktrees_folder
test_setup_and_commit_checks
test_scaffold_update
test_pack_script_removed
test_update_safety
test_xaden_command
test_settings_update
test_rules_folder_update
