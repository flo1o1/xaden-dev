# Verify releases

Check that the Xaden you install is the release the maintainer published, and understand what the checks do and do not prove.

## What is checked

| Check | What it proves | Where |
|-------|----------------|-------|
| Checksum | The files are exactly those the project pinned | `checksum` in `xaden/xaden.conf`; compared by `xaden fetch`, `xaden pin` and the CI workflow |
| Signature | The checksum of a release was signed by the maintainer's key | `release-signers` in the Xaden folder holds the public key |
| Zip signature | The release zip is the file the maintainer signed | `xaden-<version>.zip.sig` on the release page; verified by hand before extracting ([Install Xaden](install-xaden.md)) |

The checksum is the SHA-256 of the paths and contents of all files of a release (the "tree checksum"). A git clone and an extracted
archive of the same release give the same value, because the release leaves out the files only maintainers need.

## What happens on install and upgrade

`xaden fetch`, `xaden pin` and `xaden upgrade` download the release archive and, next to it, the signed checksum. If a key is listed in
`release-signers` and the signature verifies, the checksum that gets pinned is the signed one, and the output says `signature verified`.

- **The signature does not verify:** nothing is installed and the command exits with code 6.
- **The pinned checksum differs from the signed one:** nothing is installed and the command exits with code 5.
- **There is no signature** (an older release, or `release-signers` holds no key yet): Xaden says the checksum is taken from the download
  itself, which means you trust the first download, and continues only after your yes.

Check which case applies to you: `grep -v '^#' ~/.xaden/release-signers` prints the trusted keys. No output means no key is published
yet.

## What signatures do not protect against

A stolen signing key, or a maintainer who signs something malicious. Reading the scripts before you run them is still the final check:
they are plain shell. The public key is also published on the Xaden website, so you can compare it with the one in `release-signers`.

## Verify by hand

```bash
ssh-keygen -Y verify -f ~/.xaden/release-signers -I release@xaden.dev -n xaden-release -s xaden-<version>.checksum.sig < xaden-<version>.checksum
```

- `ssh-keygen -Y verify ...`: checks the signature of a downloaded checksum file against the trusted keys. It prints `Good "xaden-release" signature` when it verifies.
