#!/usr/bin/env bash
# Signs a release of Xaden (maintainers). Writes dist/xaden-<version>.checksum, the tree checksum of
# the tagged release, and dist/xaden-<version>.checksum.sig, its SSH signature. `xaden core fetch` and
# `xaden core upgrade` and `xaden project pin` verify the signature with the public keys in `release-signers` and pin the signed
# checksum, so nobody has to trust the first download. It also writes the release zip
# dist/xaden-<version>.zip and its signature .zip.sig (REQ-094): the download for people who install
# without git; the zip holds no maintainer files (.gitattributes). Never uploads: it prints the command.
# Usage: XADEN_SIGNING_KEY=<private ssh key> scripts/sign-release.sh <version>   (the tag v<version> must exist)
# Set up the key once: docs/release-signing.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=SCRIPTDIR/../template/scripts/lib.sh
source "$ROOT/template/scripts/lib.sh"
# shellcheck source=SCRIPTDIR/scaffold-lib.sh
source "$ROOT/scripts/scaffold-lib.sh"

SIGNATURE_NAMESPACE="xaden-release"

main() {
  local version=${1:-} key=${XADEN_SIGNING_KEY:-} out
  is_semver "$version" || die "usage: XADEN_SIGNING_KEY=<key> scripts/sign-release.sh <version>"
  [ -f "$key" ] || die "XADEN_SIGNING_KEY must name your private SSH key file (docs/release-signing.md)"
  has_command ssh-keygen || die "ssh-keygen is required"
  git -C "$ROOT" rev-parse -q --verify "refs/tags/v$version" >/dev/null || die "tag v$version does not exist"
  STAGING="$(mktemp -d)" # global: the EXIT trap runs after main has returned, when a local would be gone
  trap 'rm -rf "${STAGING:?}"' EXIT
  git -C "$ROOT" archive "v$version" | tar -x -C "$STAGING"
  out="$ROOT/dist"
  mkdir -p "$out"
  printf '%s  xaden-%s\n' "$(tree_checksum "$STAGING")" "$version" >"$out/xaden-$version.checksum"
  git -C "$ROOT" archive --format=zip --prefix="xaden-$version/" -o "$out/xaden-$version.zip" "v$version"
  rm -f "$out/xaden-$version.checksum.sig" "$out/xaden-$version.zip.sig"
  ssh-keygen -q -Y sign -f "$key" -n "$SIGNATURE_NAMESPACE" "$out/xaden-$version.checksum"
  ssh-keygen -q -Y sign -f "$key" -n "$SIGNATURE_NAMESPACE" "$out/xaden-$version.zip"
  ok "signed: $out/xaden-$version.checksum and .zip, each with a .sig"
  echo "Publish the four files with the release (this uploads, so it is your call):"
  echo "  gh release upload v$version dist/xaden-$version.checksum dist/xaden-$version.checksum.sig dist/xaden-$version.zip dist/xaden-$version.zip.sig"
}

main "$@"
