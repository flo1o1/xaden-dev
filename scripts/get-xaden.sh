#!/usr/bin/env bash
# Installs Xaden from its signed release zip with one command (REQ-098). The website serves this file
# at https://xaden.dev/install:
#   curl -fsSL https://xaden.dev/install | bash        read it first: curl -fsSL https://xaden.dev/install | less
# It asks before anything downloads (the question is read from the terminal, not from the pipe), checks
# the signature of the zip against the key below, and only then runs the zip's own scripts/install.sh.
# Everything is inside one function that the last line calls, so a cut connection runs nothing.
# Variables: XADEN_VERSION=<x.y.z> installs that release instead of the newest; arguments go to install.sh
# (for example a bin directory). Exit codes: 3 no terminal to ask, 6 wrong signature.
set -euo pipefail

get_xaden() {
  local assets=${XADEN_ASSETS_URL:-https://github.com/flo1o1/xaden-dev/releases/download}
  local latest=${XADEN_LATEST_URL:-https://api.github.com/repos/flo1o1/xaden-dev/releases/latest}
  local version=${XADEN_VERSION:-} signers tool answer

  for tool in curl ssh-keygen unzip; do
    command -v "$tool" >/dev/null 2>&1 || { echo "Xaden install needs $tool; install it and run this again." >&2; return 1; }
  done

  # ask <question>: reads the answer from the terminal; returns 0 only for yes. Tests answer through
  # XADEN_TEST_ANSWER with XADEN_TEST_MODE=1; nothing else answers for a person.
  ask() {
    if [ "${XADEN_TEST_MODE:-0}" = "1" ] && [ -n "${XADEN_TEST_ANSWER+x}" ]; then
      answer=$XADEN_TEST_ANSWER
    elif { : >/dev/tty; } 2>/dev/null; then
      printf '%s [y/N] ' "$1" >/dev/tty
      read -r answer </dev/tty || answer=""
    else
      echo "No terminal, so nothing was downloaded. Run this in a terminal: curl -fsSL https://xaden.dev/install | bash" >&2
      exit 3
    fi
    [ "$answer" = "y" ] || [ "$answer" = "yes" ]
  }

  if [ -z "$version" ]; then
    ask "Look up the newest Xaden release on github.com? Nothing else is sent." || { echo "Nothing was looked up."; return 1; }
    version="$(curl -fsSL "$latest" | sed -n 's/.*"tag_name": *"v\{0,1\}\([0-9][0-9.]*\)".*/\1/p' | head -n 1)"
  fi
  case "$version" in
    [0-9]*.[0-9]*.[0-9]*) ;;
    *) echo "Not a version like 1.2.3: ${version:-nothing}" >&2; return 1 ;;
  esac
  echo "Xaden $version"
  echo "  source:    $assets/v$version/xaden-$version.zip"
  echo "  signed by: release@xaden.dev (key inside this script; the zip is checked before it is opened)"
  ask "Download and install Xaden $version now?" || { echo "Nothing was downloaded."; return 1; }

  GET_XADEN_WORK="$(mktemp -d)"
  trap 'rm -rf "${GET_XADEN_WORK:?}"' EXIT
  local work=$GET_XADEN_WORK
  signers="$work/signers"
  if [ "${XADEN_TEST_MODE:-0}" = "1" ] && [ -n "${XADEN_SIGNERS_FILE:-}" ]; then
    cp "$XADEN_SIGNERS_FILE" "$signers"
  else
    cat >"$signers" <<'KEYS'
release@xaden.dev namespaces="xaden-release" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIY0fmJjw8aLB9x1otNvJkgIgZ2Q7w5vHcwjskJTOgQy
KEYS
  fi
  curl -fsSL --max-filesize 52428800 -o "$work/xaden.zip" "$assets/v$version/xaden-$version.zip"
  curl -fsSL --max-filesize 4096 -o "$work/xaden.zip.sig" "$assets/v$version/xaden-$version.zip.sig"
  if ! ssh-keygen -Y verify -f "$signers" -I release@xaden.dev -n xaden-release -s "$work/xaden.zip.sig" <"$work/xaden.zip" >/dev/null 2>&1; then
    echo "The signature of Xaden $version does not verify. Nothing was installed." >&2
    exit 6
  fi
  echo "signature verified"
  unzip -q "$work/xaden.zip" -d "$work/unpacked"
  [ -x "$work/unpacked/xaden-$version/scripts/install.sh" ] || { echo "The zip holds no scripts/install.sh. Nothing was installed." >&2; return 1; }
  "$work/unpacked/xaden-$version/scripts/install.sh" "$@"
}

get_xaden "$@"
