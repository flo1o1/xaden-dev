# shellcheck shell=bash
# Smoke test area "release-and-docs" (docs/requirements/release-and-docs). Sourced by tests/smoke.sh, which
# defines the helpers and creates the demo project first.

# REQ-007 semantic versioning
test_bump_version() {
  assert "bump patch" test "$(bump_version 1.2.3 patch)" = "1.2.4"
  assert "bump minor resets patch" test "$(bump_version 1.2.3 minor)" = "1.3.0"
  assert "bump major resets rest" test "$(bump_version 1.2.3 major)" = "2.0.0"
  assert_fails "reject invalid semver" bump_version "1.2" patch
}

# REQ-024: the scaffold's own release restores its files when stamping fails. Runs on a minimal
# copy with the full scaffold check stubbed out (the real one would run this smoke test again).
test_scaffold_release_failures() {
  local copy="$WORKDIR/scaffold-release" head
  mkdir -p "$copy/scripts" "$copy/template/scripts"
  cp "$SCAFFOLD_ROOT/scripts/release-scaffold.sh" "$copy/scripts/"
  cp "$SCAFFOLD_ROOT/template/scripts/lib.sh" "$SCAFFOLD_ROOT/template/scripts/layout.sh" "$SCAFFOLD_ROOT/template/scripts/gate.sh" "$copy/template/scripts/"
  printf '#!/bin/sh\nexit 0\n' >"$copy/scripts/check-scaffold.sh" && chmod +x "$copy/scripts/check-scaffold.sh"
  printf '0.1.0\n' >"$copy/VERSION"
  printf '# Changelog\n\n## [Unreleased]\n\n- change\n' >"$copy/CHANGELOG.md"
  git -C "$copy" init -q -b main && git -C "$copy" add -A && git -C "$copy" commit -q -m "chore: init"
  head="$(git -C "$copy" rev-parse HEAD)"
  chmod 444 "$copy/VERSION"
  assert_fails "unwritable VERSION aborts the scaffold release" "$copy/scripts/release-scaffold.sh" patch
  assert "scaffold release files restored after failed stamp" test "$(git -C "$copy" rev-parse HEAD)$(git -C "$copy" status --porcelain)" = "$head"
  chmod 644 "$copy/VERSION"
}

# REQ-007 release, REQ-010 docs gate: in the adopted demo project there are no guides to stamp or fill
test_release() {
  assert_fails "release blocked by TODO markers in the requirements" bash -c "cd '$DEMO' && xaden project release patch"
  edit_file "$(req_file "$DEMO" REQ-001)" \
    's/^TODO: When .*/When I close a month, I want to export my data, so I can send it to my accountant./; s/^- TODO: .*/- Given data, when I export, then a CSV file is written./'
  printf '# Reporting\n\n## Goal\n\nWhen I run my business, I want to see my numbers, so I can decide quickly.\n' \
    >"$DEMO/xaden/requirements/first-epic/EPIC.md"
  PROJECT_ROOT="$DEMO" "$SCAFFOLD_ROOT/template/scripts/req.sh" index >/dev/null
  git -C "$DEMO" commit -q --no-verify -am "docs(requirements): replace placeholder"
  if need_tool gitleaks "release without scanner fixture"; then
    assert_fails "release fails when a required scanner is missing" bash -c "cd '$DEMO' && PATH='$(path_without gitleaks)' xaden project release patch"
    assert "failed release left VERSION unchanged" test "$(tr -d '[:space:]' <"$DEMO/VERSION")" = "0.0.0"
  fi
  # REQ-058 security documents must be filled before a release
  assert_fails_with "release blocked by markers in SECURITY.md" "SECURITY.md" bash -c "cd '$DEMO' && xaden project release patch"
  assert "blocked release left VERSION unchanged" test "$(tr -d '[:space:]' <"$DEMO/VERSION")" = "0.0.0"
  edit_file "$DEMO/SECURITY.md" '/<!-- TODO/d'
  git -C "$DEMO" commit -q --no-verify -am "docs: fill SECURITY.md"
  assert_fails_with "release blocked by markers in the threat model" "threat-model.md" \
    env PROJECT_ROOT="$DEMO" "$SCAFFOLD_ROOT/template/scripts/check-docs.sh" --release
  edit_file "$DEMO/xaden/threat-model.md" '/<!-- TODO/d'
  git -C "$DEMO" commit -q --no-verify -am "docs: fill threat model"
  printf 'Rotate TODO list API keys yearly.\n' >>"$DEMO/SECURITY.md"
  assert "the word TODO in prose does not block a release" env PROJECT_ROOT="$DEMO" "$SCAFFOLD_ROOT/template/scripts/check-docs.sh" --release
  git -C "$DEMO" checkout -q -- SECURITY.md
  test_release_failures
  assert "release patch (release commit on main allowed)" bash -c "cd '$DEMO' && ALLOW_MAIN_COMMIT=0 xaden project release patch"
  assert "VERSION bumped" test "$(tr -d '[:space:]' <"$DEMO/VERSION")" = "0.0.1"
  assert "changelog stamped with the version" grep -q '^## \[0.0.1\]' "$DEMO/CHANGELOG.md"
  assert "tag created" git -C "$DEMO" rev-parse v0.0.1
}

# REQ-024 releases never leave a partial state
test_release_failures() {
  local head hooks="$WORKDIR/failing-hooks" release="cd '$DEMO' && xaden project release patch"
  head="$(git -C "$DEMO" rev-parse HEAD)"
  git -C "$DEMO" tag v0.0.1
  assert_fails "existing tag aborts the release" bash -c "$release"
  assert "nothing changed after tag conflict" test "$(git -C "$DEMO" rev-parse HEAD)$(git -C "$DEMO" status --porcelain)" = "$head"
  git -C "$DEMO" tag -d v0.0.1 >/dev/null
  # REQ-007: both release scripts share stamp_changelog, which needs an Unreleased section.
  edit_file "$DEMO/CHANGELOG.md" 's/^## \[Unreleased\]/## Pending/'
  git -C "$DEMO" commit -q --no-verify -am "docs: changelog without Unreleased section"
  assert_fails_with "changelog without Unreleased aborts the release" 'section; nothing was changed' bash -c "$release"
  assert "nothing released without Unreleased section" test "$(tr -d '[:space:]' <"$DEMO/VERSION")$(git -C "$DEMO" tag -l v0.0.1)" = "0.0.0"
  git -C "$DEMO" reset -q --hard "$head"
  mkdir -p "$hooks" && printf '#!/bin/sh\nexit 1\n' >"$hooks/pre-commit" && chmod +x "$hooks/pre-commit"
  git -C "$DEMO" config core.hooksPath "$hooks"
  assert_fails "failing release commit aborts" bash -c "$release"
  assert "files restored after failed commit" test "$(git -C "$DEMO" rev-parse HEAD)$(git -C "$DEMO" status --porcelain)" = "$head"
  git -C "$DEMO" config --unset core.hooksPath
  chmod 444 "$DEMO/CHANGELOG.md"
  assert_fails "unwritable changelog aborts the release" bash -c "$release"
  assert "files restored after failed changelog stamp" test "$(git -C "$DEMO" rev-parse HEAD)$(git -C "$DEMO" status --porcelain)" = "$head"
  chmod 644 "$DEMO/CHANGELOG.md"
  chmod 500 "$DEMO/.git/refs/tags"
  assert "failed tag is reported with recovery steps" bash -c "! ($release) 2>&1 | tee '$WORKDIR/tag-fail.log' >/dev/null; grep -q 'PARTIAL RELEASE' '$WORKDIR/tag-fail.log'"
  chmod 700 "$DEMO/.git/refs/tags"
  git -C "$DEMO" reset -q --hard "$head"
}

# REQ-098 the one-line installer: asks first, checks the signature of the zip, then installs
test_get_xaden() {
  local script="$SCAFFOLD_ROOT/scripts/get-xaden.sh" work="$WORKDIR/get" version bin="$WORKDIR/get-bin" line
  need_tool ssh-keygen "installer tests" || return 0
  need_tool unzip "installer tests" || return 0
  version="$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")"
  while IFS= read -r line; do
    assert "the installer embeds the key of release-signers: ${line%% *}" grep -qxF "$line" "$script"
  done < <(grep -Ev '^[[:space:]]*(#|$)' "$SCAFFOLD_ROOT/release-signers")
  assert "the installer runs its function on the last line only" test "$(tail -n 1 "$script")" = 'get_xaden "$@"'
  mkdir -p "$work/v$version"
  ssh-keygen -q -t ed25519 -N '' -C test -f "$work/key"
  printf 'release@xaden.dev namespaces="xaden-release" %s\n' "$(cat "$work/key.pub")" >"$work/signers"
  git -C "$SCAFFOLD_ROOT" archive --format=zip --prefix="xaden-$version/" -o "$work/v$version/xaden-$version.zip" "$(git -C "$SCAFFOLD_ROOT" write-tree)"
  ssh-keygen -q -Y sign -f "$work/key" -n xaden-release "$work/v$version/xaden-$version.zip"
  export XADEN_ASSETS_URL="file://$work" XADEN_SIGNERS_FILE="$work/signers" XADEN_TEST_MODE=1 XADEN_VERSION="$version" XADEN_HOME="$work/home"

  assert "a no downloads and installs nothing" bash -c "! XADEN_TEST_ANSWER=n bash '$script' '$bin' && test ! -e '$bin/xaden'"
  assert "a yes installs from the signed zip" env XADEN_TEST_ANSWER=y bash "$script" "$bin"
  assert "the installed command runs" test "$("$bin/xaden" version)" = "$version"
  assert "the installer used the shared install step" test "$(readlink "$bin/xaden")" = "$work/home/current/scripts/xaden.sh"

  printf 'tampered\n' >>"$work/v$version/xaden-$version.zip"
  rm -rf "${work:?}/home" "${bin:?}"
  assert "a changed zip fails the signature check with exit code 6" bash -c "XADEN_TEST_ANSWER=y bash '$script' '$bin'; test \$? -eq 6"
  assert "a failed signature installs nothing" test ! -e "$bin/xaden" -a ! -e "$work/home/versions"
  unset XADEN_ASSETS_URL XADEN_SIGNERS_FILE XADEN_TEST_MODE XADEN_VERSION XADEN_HOME
}

# REQ-065: the guide documents both ways to get Xaden, and both ways work as written.
test_install_ways() {
  local install="$SCAFFOLD_ROOT/docs/guide/admin/install-xaden.md" platforms="$SCAFFOLD_ROOT/docs/guide/admin/requirements-and-platforms.md"
  local update="$SCAFFOLD_ROOT/docs/guide/admin/update-xaden.md" contributing="$SCAFFOLD_ROOT/docs/guide/contributing" page
  local extracted="$WORKDIR/extracted-zip" clone="$WORKDIR/cloned-xaden" heading version
  for heading in '## Install with one command' '## Verify what you downloaded'; do
    assert "install guide has the heading $heading" grep -qE "^$heading\$" "$install"
  done
  for heading in '## Linux' '## macOS' '## Windows'; do
    assert "platform guide has the heading $heading" grep -qE "^$heading\$" "$platforms"
  done
  assert "guide states the Windows support level" grep -q 'untested' "$platforms"
  assert "guide says native PowerShell is not supported" grep -qi 'native PowerShell is not supported' "$platforms"
  assert "guide says the maintainer signs the checksum of every release" grep -q 'signs the checksum of every release' "$install"
  assert "install guide describes no manual zip route (REQ-104)" test -z "$(grep -nE 'unzip|Install from a signed zip' "$install" "$SCAFFOLD_ROOT/GETTING-STARTED.md" || true)"
  for page in install-with-git architecture work-on-xaden release-and-signing threat-model-and-requirements; do
    assert "contributing page $page exists (REQ-104)" test -f "$contributing/$page.md"
    assert "contributing page $page is listed for the site (REQ-104)" grep -qxF "docs/guide/contributing/$page.md" "$SCAFFOLD_ROOT/docs/site-pages.txt"
  done
  assert "guide explains xaden core upgrade" grep -q '^xaden core upgrade$' "$update"
  assert "contributing guide explains the clone update" grep -q 'git -C ~/.xaden pull' "$contributing/install-with-git.md"
  assert "contributing guide explains picking a release tag" grep -q 'git -C ~/.xaden checkout v' "$contributing/install-with-git.md"
  assert "admin guides do not cover installing with git (REQ-104)" test -z "$(grep -ln 'install-with-git' "$install" "$update" "$SCAFFOLD_ROOT/docs/guide/admin/uninstall.md" || true)"

  # The zip way: an archive has no .git; install.sh and xaden project create must still work from it.
  version="$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")"
  mkdir -p "$extracted"
  git -C "$SCAFFOLD_ROOT" archive HEAD | tar -x -C "$extracted"
  assert "extracted archive has no git history" test ! -e "$extracted/.git"
  export XADEN_HOME="$WORKDIR/zip-home"
  assert "extracted archive installs the xaden command" "$extracted/scripts/install.sh" "$WORKDIR/zip-bin"
  assert "the command links through current (REQ-098)" test "$(readlink "$WORKDIR/zip-bin/xaden")" = "$XADEN_HOME/current/scripts/xaden.sh"
  assert "the release sits in versions/" test -x "$XADEN_HOME/versions/$version/scripts/xaden.sh"
  mv "$extracted" "$extracted-moved"
  assert "xaden still runs after the extracted folder is gone" test "$("$WORKDIR/zip-bin/xaden" version)" = "$version"
  mv "$extracted-moved" "$extracted"
  assert "xaden from the archive prints the version" test "$("$WORKDIR/zip-bin/xaden" version)" = "$version"
  assert "xaden from the archive creates a project" bash -c "cd '$WORKDIR' && '$WORKDIR/zip-bin/xaden' project create zip-app"
  # A second extraction installs over the first; an older link into a former folder is replaced (REQ-098).
  mkdir -p "$extracted-next" "$WORKDIR/old-style-bin"
  git -C "$SCAFFOLD_ROOT" archive HEAD | tar -x -C "$extracted-next"
  assert "a second extraction installs again" "$extracted-next/scripts/install.sh" "$WORKDIR/zip-bin"
  ln -s "$extracted/scripts/xaden.sh" "$WORKDIR/old-style-bin/xaden"
  assert "an older link into a former folder is replaced" "$extracted-next/scripts/install.sh" "$WORKDIR/old-style-bin"
  assert "the replaced link goes through current" test "$(readlink "$WORKDIR/old-style-bin/xaden")" = "$XADEN_HOME/current/scripts/xaden.sh"
  ln -sf /bin/echo "$WORKDIR/old-style-bin/xaden"
  assert_fails "a link to something else is not replaced" "$extracted-next/scripts/install.sh" "$WORKDIR/old-style-bin"
  assert "uninstall removes the link and keeps the versions" "$extracted/scripts/install.sh" --uninstall "$WORKDIR/zip-bin"
  assert "the versions stay after uninstall" test -x "$XADEN_HOME/versions/$version/scripts/xaden.sh"
  assert "the newer extraction installs afterwards" "$extracted-next/scripts/install.sh" "$WORKDIR/zip-bin"
  unset XADEN_HOME

  # The clone way: a release tag can be checked out and git pull follows the branch.
  git clone -q "$SCAFFOLD_ROOT" "$clone"
  # A clone has the release tags; a checkout between releases has none yet.
  git -C "$clone" rev-parse -q --verify "refs/tags/v$version" >/dev/null || git -C "$clone" tag "v$version"
  assert "a release tag can be checked out in a clone" git -C "$clone" checkout -q "v$version"
  assert "the clone installs the xaden command" "$clone/scripts/install.sh" "$WORKDIR/clone-bin"
  assert "xaden from the clone prints the version" test "$("$WORKDIR/clone-bin/xaden" version)" = "$version"
}


# REQ-064: the site contract lists existing pages and the scaffold holds no site credential.
test_site_pages() {
  local copy="$WORKDIR/site-pages" check="$SCAFFOLD_ROOT/scripts/check-site-pages.sh"
  assert "every listed site page exists" "$check" "$SCAFFOLD_ROOT"
  mkdir -p "$copy/docs" "$copy/template/scripts" "$copy/.github/workflows"
  cp "$SCAFFOLD_ROOT/template/scripts/lib.sh" "$SCAFFOLD_ROOT/template/scripts/layout.sh" "$SCAFFOLD_ROOT/template/scripts/gate.sh" "$copy/template/scripts/"
  printf 'README.md\n' >"$copy/docs/site-pages.txt"
  assert_fails "a missing site page fails the check" "$check" "$copy"
  : >"$copy/README.md"
  assert "a present site page passes" "$check" "$copy"
  printf 'token: $%s\n' '{{ secrets.SITE_DEPLOY_KEY }}' >"$copy/.github/workflows/x.yml"
  assert_fails "a site credential in a workflow fails the check" "$check" "$copy"
  printf 'token: $%s\n' '{{ secrets["SITE_DEPLOY_KEY"] }}' >"$copy/.github/workflows/x.yml"
  assert_fails "a bracket-style secret in a workflow fails the check" "$check" "$copy"
  printf 'all: $%s\n' '{{ toJSON(secrets) }}' >"$copy/.github/workflows/x.yml"
  assert_fails "passing all secrets fails the check" "$check" "$copy"
  printf 'token: $%s\n' '{{ secrets.GITHUB_TOKEN }}' >"$copy/.github/workflows/x.yml"
  assert "the built-in GITHUB_TOKEN passes" "$check" "$copy"
  printf 'README.md\nGETTING-STARTED.md' >"$copy/docs/site-pages.txt"
  assert_fails "a missing last line without newline fails the check" "$check" "$copy"
}

# REQ-113: THIRD-PARTY.md credits every tool the stack files, presets and CI workflow name.
test_third_party() {
  local copy="$WORKDIR/third-party" check="$SCAFFOLD_ROOT/scripts/check-third-party.sh"
  assert "the complete THIRD-PARTY.md passes" "$check" "$SCAFFOLD_ROOT"
  mkdir -p "$copy/template/docs" "$copy/scripts" "$copy/template/scripts"
  cp -R "$SCAFFOLD_ROOT/template/scripts/stacks" "$copy/template/scripts/"
  cp "$SCAFFOLD_ROOT/template/scripts/lib.sh" "$SCAFFOLD_ROOT/template/scripts/layout.sh" "$SCAFFOLD_ROOT/template/scripts/gate.sh" "$copy/template/scripts/"
  cp -R "$SCAFFOLD_ROOT/template/presets" "$copy/template/"
  cp "$SCAFFOLD_ROOT/template/docs/optional-tools.md" "$copy/template/docs/"
  cp -R "$SCAFFOLD_ROOT/scripts/adopt" "$copy/scripts/"
  cp "$SCAFFOLD_ROOT/THIRD-PARTY.md" "$copy/"
  assert "a copy of the complete file passes" "$check" "$copy"
  grep -vi 'astral-sh/ruff' "$SCAFFOLD_ROOT/THIRD-PARTY.md" >"$copy/THIRD-PARTY.md"
  assert_fails "a stack tool missing from the file fails the check" "$check" "$copy"
  sed 's#https://github.com/astral-sh/ruff#ruff-site#' "$SCAFFOLD_ROOT/THIRD-PARTY.md" >"$copy/THIRD-PARTY.md"
  assert_fails "a tool without a link fails the check" "$check" "$copy"
  sed '/astral-sh\/ruff/s/| MIT |/| unknown |/' "$SCAFFOLD_ROOT/THIRD-PARTY.md" >"$copy/THIRD-PARTY.md"
  assert_fails "a tool without a license fails the check" "$check" "$copy"
  assert "the file says the Semgrep rules are not LGPL" grep -q 'Semgrep Rules License v1.0.*not LGPL' "$SCAFFOLD_ROOT/THIRD-PARTY.md"
}

# REQ-116: the AIDD mapping page has a row for each value and principle, cites only rules that exist and claims no certification.
test_aidd_mapping() {
  local copy="$WORKDIR/aidd-mapping" check="$SCAFFOLD_ROOT/scripts/check-aidd-mapping.sh" page ghost="REQ-""999"
  assert "the real mapping page passes" "$check" "$SCAFFOLD_ROOT"
  page="$copy/docs/guide/developer/xaden-and-the-aidd-manifesto.md"
  mkdir -p "$copy/docs/guide/developer" "$copy/template/scripts"
  cp "$SCAFFOLD_ROOT/template/scripts/lib.sh" "$SCAFFOLD_ROOT/template/scripts/layout.sh" "$SCAFFOLD_ROOT/template/scripts/gate.sh" "$copy/template/scripts/"
  cp -R "$SCAFFOLD_ROOT/docs/requirements" "$copy/docs/" && cp -R "$SCAFFOLD_ROOT/template/AGENTS.md" "$copy/template/" && cp "$SCAFFOLD_ROOT/THIRD-PARTY.md" "$copy/"
  cp "$SCAFFOLD_ROOT/docs/guide/developer/xaden-and-the-aidd-manifesto.md" "$page"
  assert "a copy of the page passes" "$check" "$copy"
  grep -v '^| P09 |' "$SCAFFOLD_ROOT/docs/guide/developer/xaden-and-the-aidd-manifesto.md" >"$page"
  assert_fails_with "a missing principle row fails" "P09" "$check" "$copy"
  sed 's/| partly | A human approves/| mostly | A human approves/' "$SCAFFOLD_ROOT/docs/guide/developer/xaden-and-the-aidd-manifesto.md" >"$page"
  assert_fails_with "an unknown status fails" "mostly" "$check" "$copy"
  sed "s/REQ-110, REQ-112/REQ-110, $ghost/" "$SCAFFOLD_ROOT/docs/guide/developer/xaden-and-the-aidd-manifesto.md" >"$page"
  assert_fails_with "a cited requirement that does not exist fails" "$ghost" "$check" "$copy"
  sed "s#\`template/AGENTS.md\`, REQ-045#\`template/nothing.md\`, REQ-045#" "$SCAFFOLD_ROOT/docs/guide/developer/xaden-and-the-aidd-manifesto.md" >"$page"
  assert_fails_with "a cited path that does not exist fails" "template/nothing.md" "$check" "$copy"
  { cat "$SCAFFOLD_ROOT/docs/guide/developer/xaden-and-the-aidd-manifesto.md"; printf 'Xaden is officially certified.\n'; } >"$page"
  assert_fails_with "a certification claim fails" "certified" "$check" "$copy"
  sed 's#https://creativecommons.org/licenses/by/4.0/#x#' "$SCAFFOLD_ROOT/docs/guide/developer/xaden-and-the-aidd-manifesto.md" >"$page"
  assert_fails_with "a missing license link fails" "license link" "$check" "$copy"
}

# REQ-117: the README names AI-Driven Development, links the mapping page and no longer calls Xaden "vibe" coding.
test_readme_wording() {
  assert "the README says AI-Driven Development" grep -q 'starter for AI-Driven Development' "$SCAFFOLD_ROOT/README.md"
  assert "the README links the manifesto mapping" grep -qF 'docs/guide/developer/xaden-and-the-aidd-manifesto.md' "$SCAFFOLD_ROOT/README.md"
  assert "the README does not call Xaden vibe coding" test -z "$(grep -i 'vibe) coding\|vibe coding' "$SCAFFOLD_ROOT/README.md" || true)"
}

# REQ-115: the assessment of the AIDD reference framework is a decision record that stays proposed until approved.
test_aidd_decision_record() {
  local record="$SCAFFOLD_ROOT/docs/decisions/0001-aidd-reference-framework.md"
  assert "the decision record exists with a status" grep -qE '^- Status: (proposed|accepted)' "$record"
  assert "the decision record names license and maturity" grep -q 'MIT' "$record"
  assert "the archive leaves out the maintainer decision records" grep -qx '/docs/decisions export-ignore' "$SCAFFOLD_ROOT/.gitattributes"
}

# The guides link to each other with relative paths (the website turns them into page links): every target exists.
test_guide_links() {
  local file link target broken=""
  while IFS= read -r file; do
    while IFS= read -r link; do
      target="${link%%#*}"
      [ -n "$target" ] || continue
      [ -e "$(dirname "$file")/$target" ] || broken="$broken ${file#"$SCAFFOLD_ROOT"/}->$link"
    done < <(grep -oE '\]\([^)#][^)]*\.md(#[^)]*)?\)' "$file" | sed -e 's/^](//' -e 's/)$//')
  done < <(find "$SCAFFOLD_ROOT/docs/guide" -name '*.md'; printf '%s\n' "$SCAFFOLD_ROOT/GETTING-STARTED.md")
  assert "every relative link in the guides resolves" test -z "$broken"
}

# REQ-089: the full check before a release runs only with --check. The stub records that it ran and fails on demand.
test_scaffold_release_check_option() {
  local base="$WORKDIR/scaffold-release-check" copy head out
  mkdir -p "$base/scripts" "$base/template/scripts"
  cp "$SCAFFOLD_ROOT/scripts/release-scaffold.sh" "$base/scripts/"
  cp "$SCAFFOLD_ROOT/template/scripts/lib.sh" "$SCAFFOLD_ROOT/template/scripts/layout.sh" "$SCAFFOLD_ROOT/template/scripts/gate.sh" "$base/template/scripts/"
  # shellcheck disable=SC2016 # the $ expressions belong to the stub script, not to this shell
  printf '#!/bin/sh\ntouch "$CHECK_MARKER"\n[ -z "${FAIL_CHECK:-}" ] || exit 1\n' >"$base/scripts/check-scaffold.sh" && chmod +x "$base/scripts/check-scaffold.sh"
  printf '0.1.0\n' >"$base/VERSION"
  printf '# Changelog\n\n## [Unreleased]\n\n- change\n' >"$base/CHANGELOG.md"
  git -C "$base" init -q -b main && git -C "$base" add -A && git -C "$base" commit -q -m "chore: init"

  copy="$WORKDIR/scaffold-release-default" && rm -rf "$copy" && cp -R "$base" "$copy"
  out="$(CHECK_MARKER="$copy.ran" "$copy/scripts/release-scaffold.sh" patch 2>&1)" || true
  assert "a release without --check does not run the full check" test ! -e "$copy.ran"
  assert "a release without --check says the check was skipped" grep -q 'full check skipped' <<<"$out"
  assert "a release without --check still stamps the version" test "$(cat "$copy/VERSION")" = "0.1.1"

  copy="$WORKDIR/scaffold-release-fail" && rm -rf "$copy" && cp -R "$base" "$copy"
  head="$(git -C "$copy" rev-parse HEAD)"
  assert_fails "a failing --check aborts the release" env FAIL_CHECK=1 CHECK_MARKER="$copy.ran" "$copy/scripts/release-scaffold.sh" --check patch
  assert "a failing --check leaves everything unchanged" test "$(git -C "$copy" rev-parse HEAD)$(git -C "$copy" status --porcelain)$(cat "$copy/VERSION")" = "${head}0.1.0"

  copy="$WORKDIR/scaffold-release-checked" && rm -rf "$copy" && cp -R "$base" "$copy"
  CHECK_MARKER="$copy.ran" "$copy/scripts/release-scaffold.sh" --check patch >/dev/null 2>&1 || true
  assert "--check runs the full check" test -e "$copy.ran"
  assert "a passing --check releases" test "$(cat "$copy/VERSION")" = "0.1.1"
}

# REQ-077: signing a release runs clean and leaves no temp folder behind. Runs on a minimal copy with a
# throwaway key; TMPDIR points at a folder of its own so a leftover staging folder shows.
test_sign_release() {
  local copy="$WORKDIR/sign-release" tmp="$WORKDIR/sign-tmp" err="$WORKDIR/sign-release.err" rc=0
  need_tool ssh-keygen "signing test" || return 0
  mkdir -p "$copy/scripts" "$copy/template/scripts" "$tmp"
  cp "$SCAFFOLD_ROOT/scripts/sign-release.sh" "$SCAFFOLD_ROOT/scripts/scaffold-lib.sh" "$copy/scripts/"
  cp "$SCAFFOLD_ROOT/template/scripts/lib.sh" "$SCAFFOLD_ROOT/template/scripts/layout.sh" "$SCAFFOLD_ROOT/template/scripts/gate.sh" "$copy/template/scripts/"
  printf '0.1.0\n' >"$copy/VERSION"
  git -C "$copy" init -q -b main && git -C "$copy" add -A && git -C "$copy" commit -q -m "chore: init" && git -C "$copy" tag v0.1.0
  ssh-keygen -q -t ed25519 -N '' -C test -f "$WORKDIR/sign-key"
  env TMPDIR="$tmp" XADEN_SIGNING_KEY="$WORKDIR/sign-key" "$copy/scripts/sign-release.sh" 0.1.0 >/dev/null 2>"$err" || rc=$?
  assert "signing a release exits 0" test "$rc" -eq 0
  assert "signing prints no shell error" test ! -s "$err"
  assert "the checksum and its signature are written" test -s "$copy/dist/xaden-0.1.0.checksum" -a -s "$copy/dist/xaden-0.1.0.checksum.sig"
  assert "signing leaves no temp folder behind" test -z "$(ls -A "$tmp")"
  # REQ-094 the release zip is written and signed too; the signature verifies against the key
  printf 'release@xaden.dev namespaces="xaden-release" %s\n' "$(cat "$WORKDIR/sign-key.pub")" >"$WORKDIR/sign-signers"
  assert "the zip and its signature are written" test -s "$copy/dist/xaden-0.1.0.zip" -a -s "$copy/dist/xaden-0.1.0.zip.sig"
  assert "the zip signature verifies" bash -c "ssh-keygen -Y verify -f '$WORKDIR/sign-signers' -I release@xaden.dev -n xaden-release -s '$copy/dist/xaden-0.1.0.zip.sig' <'$copy/dist/xaden-0.1.0.zip'"
  assert "a changed zip does not verify" bash -c "! { cat '$copy/dist/xaden-0.1.0.zip'; echo x; } | ssh-keygen -Y verify -f '$WORKDIR/sign-signers' -I release@xaden.dev -n xaden-release -s '$copy/dist/xaden-0.1.0.zip.sig'"
}

# REQ-094: a release archive holds no maintainer files, and Xaden runs from it.
test_release_archive() {
  local extracted="$WORKDIR/archive-run" bin="$WORKDIR/archive-bin" root="$WORKDIR/archive-root" repo="$WORKDIR/archive-repo" path
  mkdir -p "$extracted"
  git -C "$SCAFFOLD_ROOT" archive "$(git -C "$SCAFFOLD_ROOT" write-tree)" | tar -x -C "$extracted"
  for path in tests docs/requirements docs/security-reviews docs/threat-model.md docs/release-signing.md docs/site-pages.txt .githooks .github .claude inbox \
    AGENTS.md CLAUDE.md scripts/sign-release.sh scripts/release-scaffold.sh scripts/check-scaffold.sh scripts/setup.sh; do
    assert "the archive leaves out $path" test ! -e "$extracted/$path"
  done
  for path in template/AGENTS.md docs/guide/admin/install-xaden.md release-signers VERSION CHANGELOG.md LICENSE README.md GETTING-STARTED.md scripts/xaden.sh; do
    assert "the archive holds $path" test -e "$extracted/$path"
  done
  assert "the archive installs the xaden command" env XADEN_HOME="$WORKDIR/archive-home" "$extracted/scripts/install.sh" "$bin"
  mkdir -p "$repo" && git -C "$repo" init -q -b main && printf 'x\n' >"$repo/README.md" && git -C "$repo" add README.md && git -C "$repo" commit -q -m "chore: init"
  assert "xaden project adopt --plan works from the archive" bash -c "cd '$repo' && '$bin/xaden' project adopt --plan"
  mkdir -p "$extracted-head" && git -C "$SCAFFOLD_ROOT" archive HEAD | tar -x -C "$extracted-head"
  assert "a clone and its extracted archive have the same tree checksum" test "$(tree_checksum "$SCAFFOLD_ROOT")" = "$(tree_checksum "$extracted-head")"
  assert "the guides name no path of a maintainer's machine" test -z "$(grep -rnE '/Users/|/home/[a-z]' "$SCAFFOLD_ROOT/docs/guide" || true)"

  # the check passes on a tree made of the archive and fails when a maintainer file is added
  mkdir -p "$root" && cp -R "$extracted/." "$root/" && git -C "$root" init -q -b main && git -C "$root" add -A
  assert "the archive check passes on the shipped files" "$SCAFFOLD_ROOT/scripts/check-release-archive.sh" "$root"
  mkdir -p "$root/tests" && printf 'x\n' >"$root/tests/new.sh" && git -C "$root" add tests/new.sh
  assert_fails_with "the archive check names a file that would ship" "tests/new.sh" "$SCAFFOLD_ROOT/scripts/check-release-archive.sh" "$root"
}

test_bump_version
test_guide_links
test_site_pages
test_third_party
test_aidd_mapping
test_readme_wording
test_aidd_decision_record
test_scaffold_release_failures
test_scaffold_release_check_option
test_sign_release
test_release
test_install_ways
test_get_xaden
test_release_archive
