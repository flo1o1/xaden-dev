# Verify releases

Check that the Xaden you install is the release the maintainer published, and understand what the checks do and do not prove.

## What is checked

| Check | What it proves | Where |
|-------|----------------|-------|
| Checksum | The files are exactly those the project pinned | `checksum` in `xaden/xaden.conf`; compared by `xaden core fetch`, `xaden project pin` and the CI workflow |
| Signature | The checksum of a release was signed by the maintainer's key | `release-signers` in the Xaden folder holds the public key |
| Zip signature | The release zip is the file the maintainer signed | `xaden-<version>.zip.sig` on the release page; the one-command installer verifies it before it opens the zip ([Install Xaden](install-xaden.md)) |

The checksum is the SHA-256 of the paths and contents of all files of a release (the "tree checksum"). A git clone and an extracted
archive of the same release give the same value, because the release leaves out the files only maintainers need.
Two versions of the checksum exist (REQ-147). A bare 64-character value, like every pin made before, covers paths and contents. A value
written `mode1:<hex>` also covers which files are executable, so flipping a script's mode changes it. Both stay valid: Xaden verifies a
pin in the version it is written in, and a new pin takes the newest version the signed release has. The signed checksum file of a new
release holds both, the bare one first, so an older Xaden can still install it.

## What happens on install and upgrade

`xaden core fetch`, `xaden project pin` and `xaden core upgrade` download the release archive and, next to it, the signed checksum. If a key is listed in
`release-signers` and the signature verifies, the checksum that gets pinned is the signed one, and the output says `signature verified`.

- **The signature does not verify:** nothing is installed and the command exits with code 6.
- **The pinned checksum differs from the signed one:** nothing is installed and the command exits with code 5.
- **There is no signature for a release from 0.3.0 on** while `release-signers` holds a key (or `ssh-keygen` is missing): nothing is installed
  and the command exits with code 6. Releases from 0.3.0 on were published signed, so a missing signature means someone removed it, not that the release is old (REQ-136).
- **There is no signature** for an older release, or `release-signers` holds no key yet: Xaden says the checksum is taken from the download
  itself, which means you trust the first download, and continues only after your yes.
- **A download address comes from the environment** (`XADEN_RELEASES_URL`, `XADEN_ASSETS_URL`, `XADEN_LATEST_URL`): Xaden names each one and asks
  before it downloads from there. `XADEN_HOME` (another folder for the installed versions) gets the same question (REQ-140). Without a terminal it downloads nothing.
- **The installed copy differs from the pin** (a file in `~/.local/share/xaden/versions/<version>` was changed): Xaden stops before it runs
  and names `xaden core fetch <version>` to install it again (REQ-138). A tree that holds a symlink has no checksum at all (REQ-139).

Check which case applies to you: `grep -v '^#' ~/.xaden/release-signers` prints the trusted keys. No output means no key is published
yet.

## Require signed releases

A project created or adopted by a Xaden that knows a signing key gets `require-signature = true` in `xaden/xaden.conf` (REQ-136), and Xaden then
runs for it only after the copy you installed was verified once: if `xaden` stops with "no matching signature on record", run `xaden core fetch <version>`.
A project from before keeps its setting; without the line a release older than 0.3.0, or one checked without a key, is installed after your yes, on trust.
A team that wants no exceptions sets, in `xaden/xaden.conf`:

```
require-signature = true
```

Then, for that project:

- `xaden core fetch`, `xaden project pin` and `xaden core upgrade` install nothing and exit with code 6 when the key is missing from `release-signers`,
  `ssh-keygen` is not installed, no signature is published, or the signature cannot be downloaded. A signature that does not verify
  blocks with or without the setting. The first download of a version is covered too: the signed checksum is the one that gets pinned.
- Xaden runs for the project only when the installed files are exactly what the maintainer signed and what the project pins. Xaden keeps
  the signed checksum of every verified install in `<versions folder>/<version>.signed`, next to the version, not inside it. A copy with
  no record (installed before you set the option) is verified once: `xaden core fetch <version>` downloads the
  signed checksum after your yes, compares it with the installed files, and records the result. A git clone or worktree of Xaden is never accepted, whatever its committed files hold.
- Any value other than `true` or `false`, an empty one included, stops every `xaden` command in the project, so a typo cannot switch the control off. Only a missing line means `false`.
- Setting it back to `false`, or removing it, weakens a control: do it in a pull request your team reviews.
- **CI** does not verify signatures itself. The workflow `xaden project adopt` writes installs the version and checksum pinned in
  `xaden/xaden.conf` and refuses a download that differs; it then records that pin as the checksum to run, so the signed-only check passes
  for exactly that tree and no other. It does not verify a signature itself. Under the setting `xaden project pin` writes only a signed checksum, so the pin your team
  reviewed is the trust anchor for CI.

The setting proves that the checksum was signed by a key listed in `release-signers`. Who holds that key, how it is rotated and what
happens when it leaks stay with you and the maintainer.

## What signatures do not protect against

A stolen signing key, or a maintainer who signs something malicious. Reading the scripts before you run them is still the final check:
they are plain shell. The public key is also published on the Xaden website, so you can compare it with the one in `release-signers`.

## Verify by hand

```bash
ssh-keygen -Y verify -f ~/.xaden/release-signers -I release@xaden.dev -n xaden-release -s xaden-<version>.checksum.sig < xaden-<version>.checksum
```

- `ssh-keygen -Y verify ...`: checks the signature of a downloaded checksum file against the trusted keys. It prints `Good "xaden-release" signature` when it verifies.
