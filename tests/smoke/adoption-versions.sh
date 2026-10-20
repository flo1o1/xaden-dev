# shellcheck shell=bash
# shellcheck disable=SC2016 # bash -c programs are single-quoted on purpose
# Smoke test area "adoption-versions" (REQ-121, part of REQ-066 to REQ-076: versions, downloads, self-upgrade, update check, signed-only CI).
# Sourced by tests/smoke.sh, which defines the helpers and creates the demo project first.
# shellcheck source=SCRIPTDIR/adoption-lib.sh
source "$SMOKE_DIR/adoption-lib.sh"

# REQ-071 REQ-072 pinned versions, upgrades and downloads only with a yes
test_versions_and_downloads() {
  local current repo worktree hint releases="$WORKDIR/releases" home="$WORKDIR/xaden-home" upgraded
  current="$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")" # not hardcoded: a release bumps it
  fake_release "$releases" 9.9.9
  export XADEN_RELEASES_URL="file://$releases" XADEN_HOME="$home"
  worktree="$(adopted_copy versions)"
  repo="${worktree%-adopt-xaden}"

  x_in "$worktree" core doctor
  assert "doctor reports installed and pinned version" grep -q "installed $current, project pinned $current" "$XOUT"
  PATH="$(path_without curl)" x_in "$worktree" core doctor
  assert "doctor works without curl, so it uses no network" grep -q "installed $current" "$XOUT"
  x_in "$worktree" core upgrade --check
  assert "looking for newer releases needs a terminal and a yes" test "$XRC" -eq 3
  assert "nothing was looked up without a terminal" grep -q 'did not look for a newer release' "$XOUT"

  x_in "$worktree" project pin --check
  assert "pin --check needs a terminal and a yes as well (REQ-099)" test "$XRC" -eq 3
  x_in "$worktree" project pin 9.9.9
  assert "upgrade <version> in a project no longer pins it (REQ-099, REQ-130)" test -z "$(git -C "$repo" branch --list 'chore/upgrade-xaden-*')"
  hint="$(adopted_copy hint)"
  mkdir -p "$home/versions/0.0.1/scripts" && printf '#!/bin/sh\n' >"$home/versions/0.0.1/scripts/xaden.sh" && chmod +x "$home/versions/0.0.1/scripts/xaden.sh"
  edit_file "$hint/xaden/xaden.conf" 's/^version = .*/version = 0.0.1/'
  x_in "$hint" core doctor
  assert "doctor names xaden project pin when a newer Xaden is installed (REQ-099)" grep -q "xaden project pin $current" "$XOUT"
  rm -rf "${home:?}"

  x_answers n "$worktree" project pin 9.9.9
  assert "no answer but yes downloads nothing" test ! -e "$home/versions/9.9.9"
  assert "a no leaves no upgrade branch" test -z "$(git -C "$repo" branch --list 'chore/upgrade-xaden-*')"
  x_in "$worktree" project pin 9.9.9
  assert "without a terminal nothing downloads, exit code 3" test "$XRC" -eq 3
  assert "without a terminal the exact command is named" grep -q 'xaden core fetch 9.9.9' "$XOUT"
  assert "without a terminal nothing is installed" test ! -e "$home/versions"

  # REQ-107 a workflow from before the commit check lacks its step
  awk '/- name: Commit messages \(the hooks can be skipped/ { skip = 1 } !skip { print }' "$worktree/.github/workflows/xaden.yml" >"$WORKDIR/older-workflow.yml"
  cp "$WORKDIR/older-workflow.yml" "$worktree/.github/workflows/xaden.yml"
  git -C "$worktree" -c core.hooksPath=/dev/null commit -q -am "test: older workflow"
  x_answers y "$worktree" project pin 9.9.9
  upgraded="$worktree-upgrade-xaden-9.9.9"
  assert "REQ-107 upgrade adds the commit check to an older workflow, once" test "$(grep -c 'xaden.sh verify-commits --ci' "$upgraded/.github/workflows/xaden.yml")" -eq 1
  assert "REQ-107 the branch the person is on keeps its workflow" bash -c '! grep -q verify-commits "$1"' _ "$worktree/.github/workflows/xaden.yml"
  assert "REQ-129 a workflow that equals the generated one gets no -dist file" test ! -e "$upgraded/.github/workflows/xaden.yml-dist"
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
  x_in "$worktree" core doctor
  assert "an installed newer version changes nothing in the project" test -z "$(git -C "$worktree" status --porcelain)"

  # a pinned version that is missing
  rm -rf "$home"
  x_in "$upgraded" check
  assert "a missing pinned version without a terminal exits with 3" test "$XRC" -eq 3
  assert "the exact fetch command is printed" grep -q 'xaden core fetch 9.9.9' "$XOUT"
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
  x_answers y "$upgraded" core fetch 9.9.9
  assert "a checksum mismatch exits non-zero" test "$XRC" -eq 5
  assert "a checksum mismatch installs nothing" test ! -e "$home/versions/9.9.9"
  assert "a checksum mismatch is a plain error without jokes" grep -q 'does not match the checksum' "$XOUT"

  # rules that do not match the pinned version fail the check and name the fix
  edit_file "$worktree/xaden/RULES.md" 's/Generated, do not edit/Edited by hand/'
  x_in "$worktree" check
  assert "RULES.md that does not match the pinned version fails" test "$XRC" -ne 0
  assert "the fix is named" grep -q 'run: xaden project rules' "$XOUT"
  x_in "$worktree" project rules
  x_in "$worktree" check
  assert "xaden project rules repairs it" test "$XRC" -eq 0

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
      XADEN_RELEASES_URL="file://$bad" x_answers y "$worktree2" core upgrade "$version"
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
    x_answers y "$signed_worktree" project pin 9.9.9
    assert "a signed release upgrades" test "$XRC" -eq 0
    assert "the signature is reported as verified" grep -q 'signature verified' "$XOUT"
    assert "the pinned checksum is the signed one" grep -q "^checksum = $extracted\$" "$signed_worktree-upgrade-xaden-9.9.9/xaden/xaden.conf"

    rm -rf "$home" "$signed_worktree-upgrade-xaden-9.9.9" && git -C "${signed_worktree%-adopt-xaden}" worktree prune && git -C "${signed_worktree%-adopt-xaden}" branch -D chore/upgrade-xaden-9.9.9 >/dev/null
    printf '%s  xaden-9.9.9\n' "0000000000000000000000000000000000000000000000000000000000000000" >"$assets/xaden-9.9.9.checksum.tampered"
    cp "$assets/xaden-9.9.9.checksum" "$assets/original.checksum" && cp "$assets/xaden-9.9.9.checksum.tampered" "$assets/xaden-9.9.9.checksum"
    x_answers y "$signed_worktree" project pin 9.9.9
    assert "a changed checksum file fails with exit code 6" test "$XRC" -eq 6
    assert "nothing is installed after a bad signature" test ! -e "$home/versions/9.9.9"

    cp "$assets/original.checksum" "$assets/xaden-9.9.9.checksum" && rm -f "$assets/xaden-9.9.9.checksum.sig"
    ssh-keygen -q -Y sign -f "$sign/other" -n xaden-release "$assets/xaden-9.9.9.checksum"
    x_answers y "$signed_worktree" project pin 9.9.9
    assert "a signature by an unknown key fails with exit code 6" test "$XRC" -eq 6

    # REQ-136 a release that was published signed is refused when its signature is gone
    rm -rf "${assets:?}"/* "$home"
    assert "a project created with a key on record requires signed releases" grep -q '^require-signature = true' "$signed_worktree/xaden/xaden.conf"
    edit_file "$signed_worktree/xaden/xaden.conf" '/^require-signature = true/d'
    git -C "$signed_worktree" -c core.hooksPath=/dev/null commit -q -n -am "test: trust on first use"
    XADEN_FIRST_SIGNED_VERSION=0.3.0 x_answers y "$signed_worktree" project pin 9.9.9
    assert "REQ-136 a missing signature of a signed-era release fails with exit code 6" test "$XRC" -eq 6
    assert "REQ-136 the refusal says the signature is missing" grep -q 'is missing or does not verify' "$XOUT"
    assert "REQ-136 nothing is installed without it" test ! -e "$home/versions/9.9.9"
    XADEN_SIGNERS_FILE=/dev/null XADEN_FIRST_SIGNED_VERSION=0.3.0 x_answers y "$signed_worktree" project pin 9.9.9
    assert "REQ-136 without a key on record trust on first use stays" test "$XRC" -eq 0
    rm -rf "$home" "$signed_worktree-upgrade-xaden-9.9.9" && git -C "${signed_worktree%-adopt-xaden}" worktree prune && git -C "${signed_worktree%-adopt-xaden}" branch -D chore/upgrade-xaden-9.9.9 >/dev/null
    x_answers y "$signed_worktree" project pin 9.9.9
    assert "a release older than the first signed one is installed with a warning" test "$XRC" -eq 0
    assert "the warning names trust on first use" grep -q 'trust on first use' "$XOUT"
    # REQ-138 the installed copy must match the pin before it runs
    local pinned_copy="$signed_worktree-upgrade-xaden-9.9.9"
    x_in "$pinned_copy" req list
    assert "REQ-138 an untouched installed copy runs" test "$XRC" -eq 0
    printf '\n' >>"$home/versions/9.9.9/VERSION"
    x_in "$pinned_copy" req list
    assert "REQ-138 a changed installed copy stops with exit 1" test "$XRC" -ne 0
    assert "REQ-138 the message names the pin and the fix" grep -q 'does not match the checksum pinned.*xaden core fetch 9.9.9' "$XOUT"
    # REQ-139 a link is not hashed, so a tree that holds one has no checksum
    mkdir -p "$WORKDIR/linked" && printf 'a\n' >"$WORKDIR/linked/file" && ln -s file "$WORKDIR/linked/link"
    assert_fails "REQ-139 tree_checksum refuses a tree with a symlink" tree_checksum "$WORKDIR/linked"
    # REQ-140 a moved Xaden home is named and, without a terminal, nothing is installed
    XADEN_HOME="$WORKDIR/elsewhere" XADEN_TEST_MODE=0 x_in "$signed_worktree" project pin 9.9.9 </dev/null
    assert "REQ-140 XADEN_HOME is named" grep -q 'XADEN_HOME is set in the environment' "$XOUT"
    assert "REQ-140 nothing is installed there" test ! -e "$WORKDIR/elsewhere/versions"
    # REQ-103 require-signature = true: only releases the maintainer signed, on every path
    local policy_worktree policy_pinned
    policy_worktree="$(adopted_copy policy)"
    printf 'require-signature = true\n' >>"$policy_worktree/xaden/xaden.conf"
    git -C "$policy_worktree" add -A && git -C "$policy_worktree" -c core.hooksPath=/dev/null commit -q -n -m "chore: require signed releases"
    policy_pinned="$policy_worktree-upgrade-xaden-9.9.9"
    rm -rf "$home"
    x_answers y "$policy_worktree" project pin 9.9.9
    assert "policy: a release without a published signature is refused with exit code 6" test "$XRC" -eq 6
    assert "policy: the refusal names the setting" grep -q 'require-signature = true' "$XOUT"
    assert "policy: nothing is installed without a signature" test ! -e "$home/versions/9.9.9"
    printf '%s  xaden-9.9.9\n' "$extracted" >"$assets/xaden-9.9.9.checksum"
    ssh-keygen -q -Y sign -f "$sign/other" -n xaden-release "$assets/xaden-9.9.9.checksum"
    x_answers y "$policy_worktree" project pin 9.9.9
    assert "policy: a signature by an unknown key still fails with exit code 6" test "$XRC" -eq 6
    rm -f "$assets/xaden-9.9.9.checksum.sig" && ssh-keygen -q -Y sign -f "$sign/key" -n xaden-release "$assets/xaden-9.9.9.checksum"
    x_answers y "$policy_worktree" project pin 9.9.9
    assert "policy: the first download with a valid signature is installed" test "$XRC" -eq 0
    assert "policy: the signed checksum is what gets pinned" grep -q "^checksum = $extracted\$" "$policy_pinned/xaden/xaden.conf"
    assert "policy: the signed checksum is recorded outside the installed folder" test "$(tr -d '[:space:]' <"$home/versions/9.9.9.signed")" = "$extracted"
    x_in "$policy_pinned" check
    assert "policy: the authenticated copy runs for the project" grep -q 'check mode: full' "$XOUT"
    rm -f "$home/versions/9.9.9.signed"
    x_in "$policy_pinned" check
    assert "policy: a copy with no signature on record is not run" test "$XRC" -ne 0
    assert "policy: the message names the fix" grep -q 'xaden core fetch 9.9.9' "$XOUT"
    x_answers y "$policy_pinned" core fetch 9.9.9
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
    x_answers y "$policy_pinned" core fetch 9.9.9
    assert "policy: fetch does not bless a changed copy" test "$XRC" -eq 6
    rm -rf "$home"
    x_answers n "$policy_worktree" project pin 9.9.9
    assert "policy: the download still needs a yes" test ! -e "$home/versions/9.9.9"
    edit_file "$policy_pinned/xaden/xaden.conf" 's/^require-signature = true/require-signature = yes/'
    for command in check "core doctor" "core fetch 9.9.9"; do
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

# REQ-097 xaden core upgrade updates Xaden itself
test_self_upgrade() {
  local releases="$WORKDIR/self-releases" home="$WORKDIR/self-home" source="$WORKDIR/self-source" bin="$WORKDIR/self-bin" current
  current="$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")"
  fake_release "$releases" 9.9.9
  export XADEN_RELEASES_URL="file://$releases" XADEN_HOME="$home"
  mkdir -p "$source" && git -C "$SCAFFOLD_ROOT" archive "$(git -C "$SCAFFOLD_ROOT" write-tree)" | tar -x -C "$source"
  "$source/scripts/install.sh" "$bin" >/dev/null
  rm -rf "$source"
  run_installed() { XRC=0; (cd "$WORKDIR" && "$bin/xaden" "$@") >"$XOUT" 2>&1 || XRC=$?; }

  run_installed core upgrade 9.9.9
  assert "without a terminal nothing downloads, exit code 3" test "$XRC" -eq 3
  assert "without a terminal current stays" test "$(readlink "$home/current")" = "versions/$current"
  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=n run_installed core upgrade 9.9.9
  assert "a no downloads nothing" test ! -e "$home/versions/9.9.9"
  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=y run_installed core upgrade 7.7.7
  assert "a failed download fails" test "$XRC" -ne 0
  assert "a failed download leaves current on the old version" test "$(readlink "$home/current")" = "versions/$current"
  assert "a failed download leaves no folder behind" test ! -e "$home/versions/7.7.7"

  local inside
  inside="$(adopted_copy selfupgrade)"
  XRC=0; (cd "$inside" && XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=y "$bin/xaden" core upgrade 9.9.9) >"$XOUT" 2>&1 || XRC=$?
  assert "upgrade succeeds" test "$XRC" -eq 0
  assert "inside a project upgrade names xaden project pin for the project (REQ-130)" grep -q 'xaden project pin 9.9.9' "$XOUT"
  assert "inside a project upgrade does not touch the project (REQ-130)" test -z "$(git -C "$inside" status --porcelain)"
  assert "current points to the new version" test "$(readlink "$home/current")" = "versions/9.9.9"
  assert "the same command now runs the new version" test "$("$bin/xaden" version)" = "9.9.9"
  assert "the old version stays installed" test -x "$home/versions/$current/scripts/xaden.sh"
  assert "the changelog entries are shown" grep -q 'Something new in 9.9.9' "$XOUT"
  assert "the command link did not change" test "$(readlink "$bin/xaden")" = "$home/current/scripts/xaden.sh"
  run_installed core upgrade 9.9.9
  assert "upgrading to the installed version says so" grep -q 'installed already' "$XOUT"

  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=y x_in "$WORKDIR" core upgrade 9.9.9
  assert "a git clone is not upgraded, it is pulled" grep -q 'git -C .* pull' "$XOUT"
  assert "a git clone changed nothing" test "$(readlink "$home/current")" = "versions/9.9.9"
  unset XADEN_RELEASES_URL XADEN_HOME
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

  x_in "$worktree" core upgrade --check --if-due
  assert "without a setting nothing is checked" test "$XRC" -eq 0 -a ! -e "$cache"
  x_in "$worktree" core doctor
  assert "doctor names the value and where it comes from" grep -q 'update check: off (default)' "$XOUT"

  printf 'update-check = 1d\n' >>"$conf"
  x_in "$worktree" core upgrade --check --if-due
  assert "with a setting a due check runs" test "$XRC" -eq 0 -a -f "$cache"
  assert "the cache lives in the git folder, so it is never tracked" test -z "$(git -C "$worktree" status --porcelain | grep xaden-update-check)"
  assert "the cache names the newest Xaden" grep -qE '^Xaden.*9\.9\.9' "$cache"
  assert "the cache lists outdated dependencies on their own line" grep -qE '^Dependencies.*left-pad' "$cache"
  assert "a name that is no package name is left out of the cache" bash -c '! grep -q "Ignore" "$1"' _ "$cache"
  stub_tool "$stubs" npm 'Package Current Wanted Latest'
  x_answers y "$worktree" core upgrade --check
  assert "no outdated package reads as up to date" grep -qE '^Dependencies: npm: up to date' "$XOUT"
  stub_tool "$stubs" npm $'Package Current Wanted Latest\nleft-pad 1.0.0 1.3.0 1.3.0\nIgnore;rules 1.0.0 2.0.0 2.0.0'
  x_in "$worktree" core doctor
  assert "doctor shows the project value" grep -q 'update check: 1d (xaden/xaden.conf)' "$XOUT"
  assert "doctor prints the cached result" grep -q '9\.9\.9' "$XOUT"

  printf '{"tag_name": "v9.9.8"}\n' >"$latest"
  XADEN_TEST_MODE=1 XADEN_NOW=$((now + 3600)) x_in "$worktree" core upgrade --check --if-due
  assert "a check that is not due yet keeps the cache" grep -qE '^Xaden.*9\.9\.9' "$cache"
  XADEN_TEST_MODE=1 XADEN_NOW=$((now + 2 * 86400)) x_in "$worktree" core upgrade --check --if-due
  assert "a due check refreshes the cache" grep -qE '^Xaden.*9\.9\.8' "$cache"
  printf '{"tag_name": "v9.9.7"}\n' >"$latest"
  x_answers y "$worktree" core upgrade --check
  assert "upgrade --check by hand ignores the interval and reports now" grep -q '9\.9\.7' "$XOUT"
  assert "upgrade --check by hand leaves the cache alone" grep -qE '^Xaden.*9\.9\.8' "$cache"

  cp "$cache" "$WORKDIR/cache.before"
  XADEN_LATEST_URL="file://$WORKDIR/does-not-exist" XADEN_TEST_MODE=1 XADEN_NOW=$((now + 9 * 86400)) x_in "$worktree" core upgrade --check --if-due
  assert "no network: the check is silent and exits 0" test "$XRC" -eq 0 -a ! -s "$XOUT"
  assert "no network: the old cache stays" cmp -s "$cache" "$WORKDIR/cache.before"

  local value
  for value in 30m 0h abc 1.5d 1w; do
    conf_set "$conf" update-check "$value"
    rm -f "$cache"
    x_in "$worktree" core upgrade --check --if-due
    assert "the value '$value' is refused" test "$XRC" -ne 0
    assert "the refusal names the allowed forms" grep -q "off, or a number with h or d" "$XOUT"
    assert "nothing is checked for '$value'" test ! -e "$cache"
  done

  conf_set "$conf" update-check off
  x_in "$worktree" core upgrade --check --if-due
  assert "with the value off nothing is checked" test "$XRC" -eq 0 -a ! -e "$cache"
  XADEN_UPDATE_CHECK=12h x_in "$worktree" core upgrade --check --if-due
  assert "the environment variable overrides the project value for one person" test -f "$cache"
  XADEN_UPDATE_CHECK=12h x_in "$worktree" core doctor
  assert "doctor names the environment as the source" grep -q 'update check: 12h (XADEN_UPDATE_CHECK)' "$XOUT"
  assert "the override leaves the project file alone" grep -q '^update-check = off$' "$conf"
  XADEN_UPDATE_CHECK=often x_in "$worktree" core upgrade --check --if-due
  assert "a bad environment value is refused too" test "$XRC" -ne 0

  # offline readers never touch the network
  conf_set "$conf" update-check 1d
  rm -f "$cache"
  x_in "$worktree" core upgrade --check --if-due
  PATH="$(path_without curl)" x_in "$worktree" core doctor
  assert "doctor prints the cache without curl" grep -q '9\.9\.7' "$XOUT"
  assert "context-status prints the cached result" bash -c 'PROJECT_ROOT="$1" "$2/template/scripts/context-status.sh" | grep -q "9\.9\.7"' _ "$worktree" "$SCAFFOLD_ROOT"
  rm -f "$cache"
  git -C "$worktree" commit -q --allow-empty -m "chore: hooks stay offline"
  assert "the commit hooks started no check" test ! -e "$cache"
  PATH="$(path_without curl)" XADEN_LATEST_URL="file://$latest" x_in "$worktree" core doctor
  assert "doctor started no check" test ! -e "$cache"

  # REQ-130: one command, one verb
  stub_tool "$stubs" npm $'Package Current Wanted Latest\nleft-pad 1.0.0 1.3.0 1.3.0\nbig-lib 1.4.0 1.4.0 2.0.0\nnew-lib MISSING 1.0.0 3.0.0'
  x_answers y "$worktree" core upgrade --check
  assert "upgrade --check in a project reports the newest Xaden" grep -q '9\.9\.7' "$XOUT"
  assert "upgrade --check lists the outdated dependencies, majors marked" grep -q 'Dependencies: npm: left-pad, big-lib (major), new-lib$' "$XOUT"
  assert "upgrade --check changes nothing" test ! -e "$cache"
  conf_set "$conf" update-check off
  x_answers y "$worktree" core upgrade --check
  assert "upgrade --check checks although the setting is off" grep -q '^Dependencies' "$XOUT"
  conf_set "$conf" update-check 1d
  x_in "$worktree" core upgrade --check --if-due
  assert "upgrade --check --if-due fills the cache without a word" test "$XRC" -eq 0 -a -s "$cache" -a ! -s "$XOUT"
  x_in "$worktree" update-check
  assert "update-check is an unknown command" grep -q 'unknown command: update-check' "$XOUT"
  x_in "$worktree" new some-app
  assert "new is an unknown command" grep -q 'unknown command: new' "$XOUT"
  x_in "$worktree" help
  assert "help lists neither update-check nor new" bash -c '! grep -qE "^  (update-check|new)( |$)" "$1"' _ "$XOUT"
  x_answers y "$WORKDIR" core upgrade --check
  assert "outside a project upgrade --check reports the Xaden line only" bash -c '! grep -q "^Dependencies" "$1"' _ "$XOUT"

  # the update is reported, never applied; user-owned files stay
  local releases="$WORKDIR/update-releases" base_commit
  fake_release "$releases" 9.9.9
  export XADEN_RELEASES_URL="file://$releases" XADEN_HOME="$WORKDIR/update-home"
  printf '{}\n' >"$worktree/package-lock.json"
  printf 'pytest\n' >"$worktree/requirements-dev.txt"
  git -C "$worktree" add -A && git -C "$worktree" -c core.hooksPath=/dev/null commit -q -m "chore: lockfiles"
  base_commit="$(git -C "$worktree" rev-parse HEAD)"
  x_answers y "$worktree" project pin 9.9.9
  assert "upgrade succeeds" test "$XRC" -eq 0
  assert "upgrade leaves package.json, lockfile and requirements-dev.txt alone" bash -c \
    '! git -C "$1" diff --name-only "$2" "chore/upgrade-xaden-9.9.9" | grep -E "^(package(-lock)?\.json|requirements-dev\.txt)$"' _ "$worktree" "$base_commit"
  unset XADEN_RELEASES_URL XADEN_HOME

  # create and adopt ask once, off is the default answer
  local asked="$WORKDIR/repos/asked"
  make_repo "$asked" shop
  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=7d x_in "$asked" project adopt --yes --skip-ci
  assert "adopt asks for the interval and records the answer" grep -q '^update-check = 7d$' "$asked-adopt-xaden/xaden/xaden.conf"
  make_repo "$asked" shop
  rm -rf "$asked-adopt-xaden"
  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER='' x_in "$asked" project adopt --yes --skip-ci
  assert "an empty answer records off" grep -q '^update-check = off$' "$asked-adopt-xaden/xaden/xaden.conf"
  make_repo "$asked" shop
  rm -rf "$asked-adopt-xaden"
  x_in "$asked" project adopt --yes --skip-ci
  assert "without a terminal adopt sets nothing" bash -c '! grep -q "^update-check" "$1/xaden/xaden.conf"' _ "$asked-adopt-xaden"
  rm -rf "$WORKDIR/asked-create" && mkdir -p "$WORKDIR/asked-create"
  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=12h x_in "$WORKDIR/asked-create" project create demo
  assert "create asks for the interval and records the answer" grep -q '^update-check = 12h$' "$WORKDIR/asked-create/demo/xaden/xaden.conf"
  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=banana x_in "$WORKDIR/asked-create" project create demo2
  assert "an unreadable answer names the allowed forms and records off" bash -c 'grep -q "off, or a number with h or d" "$1" && grep -q "^update-check = off$" "$2"' _ "$XOUT" "$WORKDIR/asked-create/demo2/xaden/xaden.conf"

  export PATH=$saved_path
  unset XADEN_LATEST_URL
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

# REQ-129 an older workflow (no signed-record step, no Python audit tools): pin keeps it and writes the generated one
# beside it; under require-signature = true the candidate step also warns (the fake release cannot be signed, so
# that part calls ci_candidate directly)
test_pin_offers_ci_candidate() {
  local worktree upgraded releases="$WORKDIR/ci-candidate-releases" home="$WORKDIR/ci-candidate-home"
  worktree="$(adopted_copy ci-old)"
  # drop the signed-record lines and the audit step the way an older workflow lacked them
  grep -v -e 'versions/\${XADEN_VERSION}.signed' -e 'mkdir -p "\${XDG_DATA_HOME' "$worktree/.github/workflows/xaden.yml" |
    awk '/- name: Install the dependency audit and Bandit/ { skip = 1; next } skip && /- name:/ { skip = 0 } !skip { print }' >"$WORKDIR/old-ci.yml"
  cp "$WORKDIR/old-ci.yml" "$worktree/.github/workflows/xaden.yml"
  assert "the older workflow lacks the signed-record step" bash -c '! grep -q "\.signed" "$1"' _ "$worktree/.github/workflows/xaden.yml"
  git -C "$worktree" add -A && git -C "$worktree" -c core.hooksPath=/dev/null commit -q -n -m "test: older workflow, signed only"
  fake_release "$releases" 9.9.8
  XADEN_RELEASES_URL="file://$releases" XADEN_HOME="$home" x_answers y "$worktree" project pin 9.9.8
  upgraded="$worktree-upgrade-xaden-9.9.8"
  assert "REQ-129 pin writes the generated workflow beside the project's" test -f "$upgraded/.github/workflows/xaden.yml-dist"
  assert "REQ-129 the candidate has the signed-record step" grep -q '\.signed' "$upgraded/.github/workflows/xaden.yml-dist"
  assert "REQ-129 the project's workflow is not replaced" bash -c '! grep -q "\.signed" "$1"' _ "$upgraded/.github/workflows/xaden.yml"
  assert "REQ-129 pin names the diff command" grep -q 'diff .github/workflows/xaden.yml .github/workflows/xaden.yml-dist' "$XOUT"
  assert "REQ-129 the candidate is on the footprint list" grep -q 'xaden.yml-dist' "$upgraded/xaden/footprint.txt"
  rm "$upgraded/.github/workflows/xaden.yml-dist"
  printf 'require-signature = true\n' >>"$upgraded/xaden/xaden.conf"
  sed -e '/^command_name=/,$d' -e 's|^SCAFFOLD_ROOT=.*|SCAFFOLD_ROOT=${SCAFFOLD_ROOT:?}|' "$SCAFFOLD_ROOT/scripts/fetch.sh" >"$WORKDIR/fetch-functions.sh"
  XRC=0
  SCAFFOLD_ROOT="$SCAFFOLD_ROOT" bash -c 'source "$1"; ci_candidate "$2" "$SCAFFOLD_ROOT" 9.9.8 abc' _ "$WORKDIR/fetch-functions.sh" "$upgraded" >"$XOUT" 2>&1 || XRC=$?
  assert "REQ-129 under signed-only the warning names the fresh runner's refusal" grep -q 'no matching signature on record' "$XOUT"
  assert "REQ-129 the warning does not fail pin" test "$XRC" -eq 0
}

test_versions_and_downloads
test_self_upgrade
test_signed_only_in_generated_ci
test_pin_offers_ci_candidate
test_update_check
