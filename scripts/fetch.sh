#!/usr/bin/env bash
# The only script of Xaden that talks to the network (REQ-072), and the version changes built on it.
# Usage: xaden fetch <version>             install the version this project pins, after you confirm
#        xaden upgrade [--check]           update Xaden itself: install the newest release, switch `current` (REQ-097)
#        xaden pin [--check] [version]     move the project to another Xaden on a branch (REQ-071, REQ-099)
#        xaden update-check [--if-due|--now] look for a newer Xaden and outdated dependencies (REQ-084)
# Nothing downloads without a person's yes: the question shows version, source and checksum, ends
# the output, and anything but yes means no. Without a terminal nothing downloads and the command
# exits with code 3 and prints the command to run. A yes is not remembered. A download is installed
# only when its checksum equals the one pinned in xaden/xaden.conf. A test greps every other script
# for network calls. The update check is the one lookup that needs no yes each time: the setting
# `update-check` (off by default) is the person's consent, and it only reports, never installs.
set -euo pipefail

SCAFFOLD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=SCRIPTDIR/../template/scripts/lib.sh
source "$SCAFFOLD_ROOT/template/scripts/lib.sh"
# shellcheck source=SCRIPTDIR/scaffold-lib.sh
source "$SCAFFOLD_ROOT/scripts/scaffold-lib.sh"
# shellcheck source=SCRIPTDIR/../template/scripts/update-check-lib.sh
source "$SCAFFOLD_ROOT/template/scripts/update-check-lib.sh"

EXIT_NO_TERMINAL=3     # nothing was downloaded because nobody could be asked
EXIT_CHECKSUM=5        # the download does not match the pinned checksum
EXIT_SIGNATURE=6       # the signature of a release is wrong
RELEASES_URL="${XADEN_RELEASES_URL:-https://github.com/flo1o1/xaden-dev/archive/refs/tags}"
ASSETS_URL="${XADEN_ASSETS_URL:-https://github.com/flo1o1/xaden-dev/releases/download}"
SIGNERS_FILE="$SCAFFOLD_ROOT/release-signers"
# Tests may point to their own key; no other caller can change which keys are trusted.
if [ "${XADEN_TEST_MODE:-0}" = "1" ]; then SIGNERS_FILE="${XADEN_SIGNERS_FILE:-$SIGNERS_FILE}"; fi
SIGNATURE_NAMESPACE="xaden-release"
SIGNER_PRINCIPAL="release@xaden.dev"
LATEST_URL="${XADEN_LATEST_URL:-https://api.github.com/repos/flo1o1/xaden-dev/releases/latest}"

# release_url <version>: where a release archive comes from.
release_url() { printf '%s/v%s.tar.gz' "$RELEASES_URL" "$1"; }

# require_version <string>: dies unless it looks like MAJOR.MINOR.PATCH.
require_version() { is_semver "$1" || die "not a version like 1.2.3: $1"; }

# project_conf: the settings file of the project around the current directory.
project_conf() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "run this inside a project (no git repository here)"
  [ -f "$root/xaden/xaden.conf" ] || die "this project has not adopted Xaden (xaden/xaden.conf is missing); see: xaden adopt"
  printf '%s' "$root/xaden/xaden.conf"
}

# confirm_download <version> <checksum|"">: shows what would arrive and asks. Returns 0 only for yes.
# Without a terminal it prints the command to run yourself and exits with EXIT_NO_TERMINAL.
confirm_download() {
  local version=$1 checksum=$2
  info "Xaden $version"
  echo "  source:   $(release_url "$version")"
  echo "  checksum: ${checksum:-not pinned yet; it is shown after the download and goes into xaden/xaden.conf}"
  if ! has_terminal; then
    warn "No terminal, so nothing was downloaded. Run this yourself in a terminal: xaden fetch $version"
    exit "$EXIT_NO_TERMINAL"
  fi
  ask "Download and install Xaden $version now?"
}

# MAX_RELEASE_BYTES: a release archive larger than this is refused (the real one is about 1 MB).
MAX_RELEASE_BYTES=52428800

# safe_archive <archive>: dies unless every member is a plain file or folder inside the archive's
# top folder: no absolute path, no "..", no link. The archive comes from the network; extracting
# one with such a member could write outside the target folder.
safe_archive() {
  # no -q: grep must read all input, or tar dies of SIGPIPE and pipefail hides the match
  if tar -tzf "$1" | grep -E '^/|(^|/)\.\.(/|$)' >/dev/null; then die "the archive has a path that leaves its folder; refusing to extract it"; fi
  if tar -tvzf "$1" | grep -E '^[lh]' >/dev/null; then die "the archive contains a link; refusing to extract it"; fi
}

# download_release <version> <dir>: the one download. Fetches the release archive, checks that
# it is safe to extract, and extracts it into <dir>.
download_release() {
  local archive
  archive="$(mktemp)"
  if ! curl -fsSL --max-filesize "$MAX_RELEASE_BYTES" -o "$archive" "$(release_url "$1")"; then
    rm -f "$archive"
    return 1
  fi
  if ! (safe_archive "$archive"); then rm -f "$archive"; return 1; fi
  tar -xz -C "$2" --strip-components=1 -f "$archive"
  rm -f "$archive"
}

# signing_keys_exist: true when release-signers holds at least one key.
signing_keys_exist() { [ -f "$SIGNERS_FILE" ] && grep -Ev '^[[:space:]]*(#|$)' "$SIGNERS_FILE" >/dev/null; }

# signed_checksum <version>: prints the checksum of a release that the maintainer signed. Returns 0
# when the signature is valid, 10 when there is nothing to verify (no key in release-signers, no
# ssh-keygen, no signature published for the release) and EXIT_SIGNATURE when a signature exists and
# is wrong.
signed_checksum() {
  local version=$1 dir status=0 line
  signing_keys_exist && has_command ssh-keygen || return 10
  dir="$(mktemp -d)"
  if ! curl -fsSL --max-filesize 4096 -o "$dir/checksum" "$ASSETS_URL/v$version/xaden-$version.checksum" ||
    ! curl -fsSL --max-filesize 4096 -o "$dir/checksum.sig" "$ASSETS_URL/v$version/xaden-$version.checksum.sig"; then
    rm -rf "${dir:?}"
    return 10
  fi
  ssh-keygen -Y verify -f "$SIGNERS_FILE" -I "$SIGNER_PRINCIPAL" -n "$SIGNATURE_NAMESPACE" -s "$dir/checksum.sig" <"$dir/checksum" >/dev/null 2>&1 || status=$?
  line="$(awk 'NR == 1 { print $1 }' "$dir/checksum")"
  rm -rf "${dir:?}"
  if [ "$status" -ne 0 ]; then
    return "$EXIT_SIGNATURE"
  fi
  printf '%s' "$line"
}

# install_release <version> <expected-checksum|"">: downloads, verifies and installs one version
# into the versions folder. Prints the checksum of what was installed.
install_release() {
  local version=$1 expected=$2 staging actual target signed status
  staging="$(mktemp -d)"
  download_release "$version" "$staging" || { rm -rf "${staging:?}"; die "download failed for Xaden $version"; }
  if [ ! -f "$staging/VERSION" ] || [ "$(tr -d '[:space:]' <"$staging/VERSION")" != "$version" ]; then
    rm -rf "${staging:?}"
    die "the download is not Xaden $version; nothing was installed"
  fi
  actual="$(tree_checksum "$staging")"
  signed=""
  status=0
  signed="$(signed_checksum "$version")" || status=$?
  if [ "$status" -eq "$EXIT_SIGNATURE" ]; then
    rm -rf "${staging:?}"
    warn "The signature of Xaden $version does not verify against the keys in release-signers. Nothing was installed."
    exit "$EXIT_SIGNATURE"
  elif [ "$status" -eq 0 ]; then
    if [ -n "$expected" ] && [ "$expected" != "$signed" ]; then
      rm -rf "${staging:?}"
      warn "The checksum pinned in xaden/xaden.conf is not the one the maintainer signed for Xaden $version. Nothing was installed."
      exit "$EXIT_CHECKSUM"
    fi
    expected=$signed
    info "signature verified: the checksum of Xaden $version comes from the maintainer" >&2
  elif [ "$SIGNATURE_REQUIRED" = 1 ]; then
    rm -rf "${staging:?}"
    warn "This project requires signed releases (require-signature = true), and Xaden $version has no signature that can be verified: no key in release-signers, no ssh-keygen, or no signature published. Nothing was installed." >&2
    exit "$EXIT_SIGNATURE"
  elif [ -z "$expected" ]; then
    warn "No verifiable signature for Xaden $version: the checksum is taken from the download itself (trust on first use)." >&2
  fi
  if [ -n "$expected" ] && [ "$actual" != "$expected" ]; then
    rm -rf "${staging:?}"
    warn "expected checksum $expected"
    warn "received checksum $actual"
    warn "The download does not match the checksum pinned in xaden/xaden.conf. Nothing was installed."
    exit "$EXIT_CHECKSUM"
  fi
  target="$(versions_dir)/$version"
  mkdir -p "$(versions_dir)"
  rm -rf "${target:?}"
  mv "$staging" "$target"
  if [ -n "$signed" ]; then printf '%s\n' "$signed" >"$(signed_record "$version")"; else rm -f "$(signed_record "$version")"; fi
  printf '%s' "$actual"
}

# project_signature_policy: reads require-signature from the project around the current directory,
# if there is one. Outside a project, or in one without the setting, releases need no signature.
project_signature_policy() {
  local root
  SIGNATURE_REQUIRED=0
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  [ -f "$root/xaden/xaden.conf" ] || return 0
  load_signature_policy "$root/xaden/xaden.conf"
}

# ensure_authenticated <version> <dir> [pinned-checksum]: under require-signature, an installed copy
# must match the checksum the maintainer signed. A copy without a record (installed from a zip, or
# before the setting) is verified once against the signed checksum, after a yes, and recorded.
ensure_authenticated() {
  local version=$1 dir=$2 signed status=0
  [ "$SIGNATURE_REQUIRED" = 1 ] || return 0
  if installation_authenticated "$version" "$dir" "${3:-}"; then return 0; fi
  info "This project requires signed releases; Xaden $version in $dir has no verified signature on record." >&2
  has_terminal || { warn "No terminal, so nothing was verified. Run this yourself in a terminal: xaden fetch $version" >&2; exit "$EXIT_NO_TERMINAL"; }
  ask "Download the signed checksum of Xaden $version from github.com and verify the installed copy against it?" ||
    { echo "Nothing was verified." >&2; exit 1; }
  signed="$(signed_checksum "$version")" || status=$?
  if [ "$status" -ne 0 ]; then
    warn "Xaden $version cannot be verified against a signature by a key in release-signers. It is not used." >&2
    exit "$EXIT_SIGNATURE"
  fi
  if [ "$(tree_checksum "$dir")" != "$signed" ]; then
    warn "The files of Xaden $version in $dir are not what the maintainer signed. It is not used." >&2
    exit "$EXIT_SIGNATURE"
  fi
  if [ -n "${3:-}" ] && [ "$3" != "$signed" ]; then
    warn "The checksum pinned in xaden/xaden.conf is not the one the maintainer signed for Xaden $version." >&2
    exit "$EXIT_CHECKSUM"
  fi
  mkdir -p "$(versions_dir)"
  printf '%s\n' "$signed" >"$(signed_record "$version")"
  info "signature verified: Xaden $version in $dir is what the maintainer signed" >&2
}

# fetch_main <version>: installs the version the project pins.
fetch_main() {
  local version=${1:-} conf pinned checksum
  [ -n "$version" ] || die "usage: xaden fetch <version>"
  require_version "$version"
  conf="$(project_conf)"
  pinned="$(conf_get "$conf" version)"
  checksum="$(conf_get "$conf" checksum)"
  [ "$version" = "$pinned" ] || die "this project pins Xaden $pinned, not $version. To move it to $version: xaden pin $version"
  if [ "$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")" = "$version" ]; then
    ensure_authenticated "$version" "$SCAFFOLD_ROOT" "$checksum"
    ok "Xaden $version is installed already"
    return 0
  fi
  if [ -x "$(versions_dir)/$version/scripts/xaden.sh" ]; then
    ensure_authenticated "$version" "$(versions_dir)/$version" "$checksum"
    ok "Xaden $version is installed already"
    return 0
  fi
  confirm_download "$version" "$checksum" || { echo "Nothing was downloaded."; exit 1; }
  install_release "$version" "$checksum" >/dev/null
  ok "Xaden $version is installed in $(versions_dir)/$version (checksum verified)"
}

# latest_version: asks the release API for the newest version (after the person agreed).
latest_version() {
  curl -fsSL "$LATEST_URL" | sed -n 's/.*"tag_name": *"v\{0,1\}\([0-9][0-9.]*\)".*/\1/p' | head -n 1
}

# changelog_between <changelog> <from> <to>: the entries of versions after <from> up to <to>.
changelog_between() {
  awk -v from="$2" -v to="$3" '
    function key(v,   p) { split(v, p, "."); return p[1] * 1000000 + p[2] * 1000 + p[3] }
    /^## \[[0-9]/ { v = $2; gsub(/[\[\]]/, "", v); show = (key(v) > key(from) && key(v) <= key(to)) }
    show { print }' "$1"
}

# tools_for <version>: the folder of an installed Xaden of that version; downloads it after a yes.
tools_for() {
  local version=$1 checksum
  if [ "$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")" = "$version" ]; then
    ensure_authenticated "$version" "$SCAFFOLD_ROOT" >&2
    printf '%s' "$SCAFFOLD_ROOT"
    return 0
  fi
  if [ -x "$(versions_dir)/$version/scripts/xaden.sh" ]; then
    ensure_authenticated "$version" "$(versions_dir)/$version" >&2
    printf '%s' "$(versions_dir)/$version"
    return 0
  fi
  confirm_download "$version" "" >&2 || { echo "Nothing was downloaded." >&2; exit 1; }
  checksum="$(install_release "$version" "")" || exit $? # the subshell cannot stop this script by itself
  info "checksum of Xaden $version: $checksum (it goes into xaden/xaden.conf; your team reviews it in the pull request)" >&2
  printf '%s' "$(versions_dir)/$version"
}

# pin_main [--check] [version]
pin_main() {
  local check_only=0 target="" conf root pinned tools checksum branch worktree base
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --check) check_only=1 ;;
      -*) die "usage: xaden pin [--check] [version]" ;;
      *) target=$1 ;;
    esac
    shift
  done
  conf="$(project_conf)"
  root="$(dirname "$(dirname "$conf")")"
  pinned="$(conf_get "$conf" version)"
  if [ "$check_only" = 1 ] || [ -z "$target" ]; then
    if ! has_terminal; then
      warn "No terminal, so Xaden did not look for a newer release. Run 'xaden pin --check' in a terminal, or name the version: xaden pin <version>"
      exit "$EXIT_NO_TERMINAL"
    fi
    ask "Look up the newest Xaden release on github.com? Nothing else is sent." || { echo "Nothing was looked up."; exit 1; }
    target="$(latest_version)"
    [ -n "$target" ] || die "could not read the newest version from $LATEST_URL"
    if [ "$check_only" = 1 ]; then
      if [ "$target" = "$pinned" ]; then ok "project pins Xaden $pinned, the newest release"; else info "project pins Xaden $pinned, newest release is $target (xaden pin $target)"; fi
      return 0
    fi
  fi
  require_version "$target"
  [ "$target" != "$pinned" ] || { ok "project pins Xaden $pinned already"; return 0; }
  tools="$(tools_for "$target")"
  checksum="$(tree_checksum "$tools")"
  base="$(git -C "$root" symbolic-ref -q --short HEAD)" || die "check out a branch first"
  branch="chore/upgrade-xaden-$target"
  worktree="$(dirname "$root")/$(basename "$root")-upgrade-xaden-$target"
  [ ! -e "$worktree" ] || die "$worktree exists already; remove it first (git worktree remove)"
  git -C "$root" worktree add -q -b "$branch" "$worktree" "$base"
  conf_set "$worktree/xaden/xaden.conf" version "$target"
  conf_set "$worktree/xaden/xaden.conf" checksum "$checksum"
  (cd "$worktree" && bash -c 'source "$1/template/scripts/lib.sh"; TOOLS_DIR="$1/template"; render_rules' _ "$tools" >xaden/RULES.md)
  # REQ-080, REQ-081 the command files follow the prompts of the new version
  assistants="$(conf_get "$worktree/xaden/xaden.conf" assistants)"
  if [ -n "$(command_kinds "$assistants")" ]; then sync_commands "$worktree" "$tools/template" "$assistants" "$SCAFFOLD_ROOT/template"; fi
  if [ -f "$worktree/.github/workflows/xaden.yml" ]; then
    sed -i.bak -e "s/^  XADEN_VERSION: .*/  XADEN_VERSION: \"$target\"/" -e "s/^  XADEN_CHECKSUM: .*/  XADEN_CHECKSUM: \"$checksum\"/" "$worktree/.github/workflows/xaden.yml"
    rm -f "$worktree/.github/workflows/xaden.yml.bak"
  fi
  git -C "$worktree" add -A
  git -C "$worktree" -c core.hooksPath=/dev/null commit -q -n -m "chore: upgrade Xaden from $pinned to $target" \
    -m "Pins version $target and its checksum, and regenerates xaden/RULES.md. Review the rules diff and the changelog in the pull request."
  info "changes of this upgrade"
  git -C "$worktree" show --stat --format= HEAD
  git -C "$worktree" show --format= HEAD -- xaden/xaden.conf xaden/RULES.md
  info "changelog, Xaden $pinned to $target"
  changelog_between "$tools/CHANGELOG.md" "$pinned" "$target"
  ok "branch $branch is ready in $worktree; push it and open the pull request your team reviews"
}

# upgrade_main [--self] [--check] [version]: updates Xaden itself. The old meaning of `xaden upgrade
# <version>` inside an adopted project (move the pin) is `xaden pin <version>` now (REQ-099).
upgrade_main() {
  local arg version=""
  for arg in "$@"; do
    case "$arg" in -*) ;; *) version=$arg ;; esac
  done
  if [ -n "$version" ] && [ -f "$(git rev-parse --show-toplevel 2>/dev/null || echo /nonexistent)/xaden/xaden.conf" ]; then
    warn "xaden upgrade <version> now updates Xaden itself; moving a project is: xaden pin $version (running that now)"
    pin_main "$@"
    return
  fi
  self_upgrade_main "$@"
}

# self_upgrade_main [--self] [--check] [version]: installs a release next to the others and switches
# `current` to it (REQ-097). Download, signature and checksum are install_release's; the switch is the
# last step, so any failure leaves the old version active.
self_upgrade_main() {
  local check_only=0 target="" arg installed
  for arg in "$@"; do
    case "$arg" in
      --check) check_only=1 ;;
      --self) ;;
      -*) die "usage: xaden upgrade [--check] [version]" ;;
      *) target=$arg ;;
    esac
  done
  installed="$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")"
  if [ "$check_only" = 1 ] || [ -z "$target" ]; then
    if ! has_terminal; then
      warn "No terminal, so Xaden did not look for a newer release. Run 'xaden upgrade --check' in a terminal, or name the version: xaden upgrade <version>"
      exit "$EXIT_NO_TERMINAL"
    fi
    ask "Look up the newest Xaden release on github.com? Nothing else is sent." || { echo "Nothing was looked up."; exit 1; }
    target="$(latest_version)"
    [ -n "$target" ] || die "could not read the newest version from $LATEST_URL"
    if [ "$check_only" = 1 ]; then
      if [ "$target" = "$installed" ]; then ok "Xaden $installed is the newest release"; else info "Xaden $installed is installed, newest release is $target (xaden upgrade)"; fi
      return 0
    fi
  fi
  require_version "$target"
  [ "$target" != "$installed" ] || { ok "Xaden $installed is installed already"; return 0; }
  if [ -e "$SCAFFOLD_ROOT/.git" ]; then die "this Xaden runs from a git clone; update it with: git -C $SCAFFOLD_ROOT pull"; fi
  case "$SCAFFOLD_ROOT" in
    "$(current_link)" | "$(versions_dir)"/*) ;;
    *) die "this Xaden does not live in $(xaden_home); install it once with: curl -fsSL https://xaden.dev/install | bash, then use xaden upgrade" ;;
  esac
  if [ ! -x "$(versions_dir)/$target/scripts/xaden.sh" ]; then
    confirm_download "$target" "" || { echo "Nothing was downloaded."; exit 1; }
    install_release "$target" "" >/dev/null
  else
    ensure_authenticated "$target" "$(versions_dir)/$target"
  fi
  switch_current "$target"
  ok "Xaden $target is active (was $installed); $installed stays in $(versions_dir) for projects that pin it"
  changelog_between "$(versions_dir)/$target/CHANGELOG.md" "$installed" "$target"
}

# outdated_dependencies <root>: one line about the project's own dependencies. Reports only; never
# updates anything. shortcut: npm and pip only, no timeout around them; add more stacks on request.
outdated_dependencies() {
  local root=$1 parts="" names
  if [ -f "$root/package.json" ]; then
    if command -v npm >/dev/null 2>&1; then
      names="$(cd "$root" && { npm outdated || true; } 2>/dev/null | awk 'NR > 1 { print $1 }' | { grep -E '^[A-Za-z0-9@/._-]+$' || true; } | paste -sd, - | sed 's/,/, /g')"
      parts="npm: ${names:-up to date}"
    else
      parts="npm: not checked (npm is not installed)"
    fi
  fi
  if [ -f "$root/pyproject.toml" ] || ls "$root"/requirements*.txt >/dev/null 2>&1; then
    if command -v pip >/dev/null 2>&1; then
      names="$(cd "$root" && { pip list --outdated --format=freeze || true; } 2>/dev/null | sed 's/==.*//' | { grep -E '^[A-Za-z0-9@/._-]+$' || true; } | paste -sd, - | sed 's/,/, /g')"
      parts="${parts:+$parts; }pip: ${names:-up to date}"
    else
      parts="${parts:+$parts; }pip: not checked (pip is not installed)"
    fi
  fi
  printf 'Dependencies: %s\n' "${parts:-no npm or pip project found}"
}

# update_check_main [--if-due|--now]
# By hand it checks now (refused while the setting is off); --now checks regardless; --if-due is
# what commands call: silent, only when the interval has passed, and never an error for a network that is down.
update_check_main() {
  local mode=manual root conf setting value origin seconds cache newest installed pinned tmp
  case "${1:-}" in
    "") ;;
    --if-due) mode=due ;;
    --now) mode=now ;;
    *) die "usage: xaden update-check [--if-due|--now]" ;;
  esac
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "run this inside a project (no git repository here)"
  conf="$root/xaden/xaden.conf"
  setting="$(update_check_setting "$conf")"
  value="${setting% *}"
  origin="${setting#* }"
  seconds="$(update_check_seconds "$value")" || die "update-check = $value ($origin) is not valid. Use $UPDATE_CHECK_FORMS"
  if [ "$seconds" = 0 ] && [ "$mode" != now ]; then
    [ "$mode" = due ] && return 0
    die "update-check is off ($origin). Turn it on with update-check = 1d in xaden/xaden.conf, or run: xaden update-check --now"
  fi
  cache="$(update_check_cache "$root")" || die "run this inside a git repository"
  if [ "$mode" = due ] && ! update_check_is_due "$cache" "$seconds"; then return 0; fi
  if ! newest="$(latest_version 2>/dev/null)" || [ -z "$newest" ]; then
    [ "$mode" = due ] && return 0
    die "could not read the newest version from $LATEST_URL"
  fi
  installed="$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")"
  pinned="$(conf_get "$conf" version "$installed")"
  tmp="$(mktemp)"
  {
    printf 'checked %s\n' "$(update_check_now)"
    if [ "$newest" = "$pinned" ]; then
      printf 'Xaden: pinned %s, installed %s, up to date\n' "$pinned" "$installed"
    else
      printf 'Xaden: pinned %s, installed %s, newest %s (move the project with: xaden pin %s)\n' "$pinned" "$installed" "$newest" "$newest"
    fi
    outdated_dependencies "$root"
  } >"$tmp"
  mv "$tmp" "$cache"
  [ "$mode" = due ] || update_check_print_cached "$root"
}

command_name=${1:-}
[ "$#" -eq 0 ] || shift
project_signature_policy
case "$command_name" in
  fetch) fetch_main "$@" ;;
  upgrade) upgrade_main "$@" ;;
  pin) pin_main "$@" ;;
  update-check) update_check_main "$@" ;;
  *) die "usage: fetch.sh fetch <version> | upgrade [--check] [version] | pin [--check] [version] | update-check [--if-due|--now]" ;;
esac
