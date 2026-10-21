# Release and sign Xaden

How a Xaden release is cut and signed. Releases happen only when the maintainer decides, and never by pushing to `main`.

## Cut the release

A release is a change like any other: it goes through a branch and a pull request.

```bash
git worktree add worktrees/release-v<version> -b release/v<version> main
cd worktrees/release-v<version>
scripts/release-scaffold.sh minor
git push -u origin release/v<version>
```

- `git worktree add ... -b release/v<version>`: a branch and a folder for the release commit.
- `scripts/release-scaffold.sh minor`: bumps `VERSION` (SemVer: `major`, `minor` or `patch`), stamps the changelog and makes the release commit. It never pushes. `--check` runs the full check first; CI checks the release pull request anyway.
- `git push -u origin ...`: pushes the branch. Open the pull request, wait for CI and merge it as in [Work on Xaden](work-on-xaden.md).

Then tag the merge commit and push the tag:

```bash
git tag -a v<version> <merge commit>
git push origin v<version>
```

- `git tag -a v<version> <merge commit>`: tags the commit the pull request created on `main`.
- `git push origin v<version>`: publishes the tag. The website is released afterwards, under the same version, from that tag.

## Why releases are signed

Releases are signed so that nobody has to trust the first download. The signature covers the tree checksum of the tagged release, the same value a project pins in `xaden/xaden.conf`.

## One-time setup

```bash
ssh-keygen -t ed25519 -f ~/.ssh/xaden-release -C release@xaden.dev
```

- `ssh-keygen ...`: creates the signing key.

1. Add the public key to `release-signers` in the form `release@xaden.dev namespaces="xaden-release" ssh-ed25519 AAAA...` and commit it. The key is trusted from the release that contains it, so also publish it where people can compare it (the website, the GitHub profile).
2. Keep the private key off shared machines and back it up. If it leaks, publish a new key and say so in the changelog.

## Sign every release

```bash
XADEN_SIGNING_KEY=~/.ssh/xaden-release scripts/sign-release.sh <version>
gh release upload v<version> dist/xaden-<version>.checksum dist/xaden-<version>.checksum.sig dist/xaden-<version>.zip dist/xaden-<version>.zip.sig
```

- `sign-release.sh <version>`: needs the tag `v<version>`. It writes the tree checksum (two lines, the bare one first and the `mode1:` one second, REQ-147) and its signature, builds the release zip without the maintainer files that `.gitattributes` leaves out, and signs the zip. It never uploads: it prints the upload command.
- `gh release upload ...`: attaches the four files to the GitHub release.

The one-command installer downloads this zip and verifies its signature with the key embedded in the installer script. When you change the key in `release-signers`, change it in `scripts/get-xaden.sh` as well; a smoke test fails when they differ.

## What people see

`xaden core fetch <version>`, `xaden project pin <version>` and `xaden core upgrade` download the two checksum files next to the release archive and verify the signature with the keys in the installed Xaden's `release-signers`.
A valid signature means the checksum that gets pinned comes from the maintainer, not from the download. A wrong signature stops with exit code 6 and installs nothing. Without a signature
(an old release, or no key in `release-signers` yet) Xaden says so and pins the checksum of the download itself, after the person's yes.

Signatures protect against a changed or substituted archive. They do not protect against a maintainer who signs something malicious, or against a stolen key. More: [Verify releases](../admin/verify-releases.md).

## Next

[Threat model and requirements](threat-model-and-requirements.md).
