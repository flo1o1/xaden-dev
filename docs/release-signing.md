# Signing Xaden releases (REQ-077)

Releases are signed so that nobody has to trust the first download. The signature covers the *tree
checksum* of the tagged release, the same value a project pins in `xaden/xaden.conf`.

## One-time setup (maintainer)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/xaden-release -C release@xaden.dev
```

1. Add the public key to `release-signers` in the form
   `release@xaden.dev namespaces="xaden-release" ssh-ed25519 AAAA...` and commit it. The key is trusted
   from the release that contains it, so also publish it where people can compare (the website, the GitHub profile).
2. Keep the private key off shared machines. Back it up. If it leaks, publish a new key and say so in the changelog.

## For every release

```bash
scripts/release-scaffold.sh minor     # --check first runs the full check; CI checks the release pull request anyway
XADEN_SIGNING_KEY=~/.ssh/xaden-release scripts/sign-release.sh 0.3.0
gh release upload v0.3.0 dist/xaden-0.3.0.checksum dist/xaden-0.3.0.checksum.sig dist/xaden-0.3.0.zip dist/xaden-0.3.0.zip.sig
```

`sign-release.sh` also builds the release zip (without the maintainer files that `.gitattributes` export-ignores) and signs it, so people
can verify the file before they extract it (REQ-094).

## What users see

`xaden project fetch <version>`, `xaden project pin <version>` and `xaden core upgrade` download the two files next to the release archive and verify the
signature with the keys in the installed Xaden's `release-signers`. A valid signature means the checksum that gets pinned
comes from the maintainer, not from the download. A wrong signature stops with exit code 6 and installs nothing. Without
a signature (an old release, or no key in `release-signers` yet) Xaden says so and pins the checksum of the download
itself, after the person's yes.

Signatures protect against a changed or substituted archive. They do not protect against a maintainer who signs
something malicious, or against a stolen key.
