#!/usr/bin/env bash
# Installs the `xaden` command (REQ-056, REQ-098). From an extracted release it copies the folder to
# <xaden home>/versions/<version>, points `current` at it and links `xaden` to current/scripts/xaden.sh,
# so the extracted folder can be deleted and `xaden core upgrade` needs no new link. From a git clone it
# links to the clone instead (`git pull` updates it). It never replaces a file that is not a Xaden link.
# Usage: scripts/install.sh [--uninstall] [bin-dir]   (default bin-dir: ~/.local/bin)
set -euo pipefail

SCAFFOLD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=SCRIPTDIR/../template/scripts/lib.sh
source "$SCAFFOLD_ROOT/template/scripts/lib.sh"
# shellcheck source=SCRIPTDIR/scaffold-lib.sh
source "$SCAFFOLD_ROOT/scripts/scaffold-lib.sh"

COMMAND_NAME="xaden"

# place_release: copies this extracted release into versions/ and makes it the current one.
place_release() {
  local version dest
  version="$(tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION")"
  is_semver "$version" || die "$SCAFFOLD_ROOT/VERSION does not hold a version like 1.2.3"
  dest="$(versions_dir)/$version"
  if [ ! -d "$dest" ] || [ "$(cd "$SCAFFOLD_ROOT" && pwd -P)" != "$(cd "$dest" && pwd -P)" ]; then
    mkdir -p "$(versions_dir)"
    rm -rf "${dest:?}.new"
    cp -R "$SCAFFOLD_ROOT" "$dest.new"
    rm -rf "${dest:?}"
    mv "$dest.new" "$dest"
  fi
  switch_current "$version"
}

# install_link <bin-dir>: creates the link; replaces only a link to another Xaden.
install_link() {
  local link="$1/$COMMAND_NAME" target
  if [ -e "$SCAFFOLD_ROOT/.git" ]; then
    target="$SCAFFOLD_ROOT/scripts/xaden.sh"
  else
    place_release
    target="$(current_link)/scripts/xaden.sh"
  fi
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
    info "already installed: $link"
  else
    if is_xaden_link "$link"; then
      info "replacing the link to the former Xaden: $(readlink "$link")"
      rm "$link"
    elif [ -e "$link" ] || [ -L "$link" ]; then
      die "$link exists and is not a link to a Xaden; left unchanged"
    fi
    mkdir -p "$1"
    ln -s "$target" "$link"
    info "installed $link -> $target"
  fi
  case ":$PATH:" in
    *":$1:"*) ;;
    *) warn "$1 is not on PATH; add this line to your shell profile: export PATH=\"$1:\$PATH\"" ;;
  esac
}

# uninstall_link <bin-dir>: removes the link only if it points to a Xaden. The installed versions stay.
uninstall_link() {
  local link="$1/$COMMAND_NAME"
  is_xaden_link "$link" || die "$link is not a link to a Xaden; left unchanged"
  rm "$link"
  info "removed $link (the versions in $(versions_dir) stay; delete $(xaden_home) to remove them)"
}

main() {
  local uninstall=0 bin_dir="" arg
  for arg in "$@"; do
    case "$arg" in
      --uninstall) uninstall=1 ;;
      -*) die "usage: scripts/install.sh [--uninstall] [bin-dir]" ;;
      *) bin_dir=$arg ;;
    esac
  done
  bin_dir="${bin_dir:-${HOME:?HOME is not set}/.local/bin}"
  if [ "$uninstall" = "1" ]; then uninstall_link "$bin_dir"; else install_link "$bin_dir"; fi
}

main "$@"
