# Pin one Xaden version per project

Make a whole team use the same Xaden version, so the rules for assistants and the checks never change underneath anyone.

An adopted repository pins the Xaden version it uses, with a checksum, in `xaden/xaden.conf`. A newer Xaden installed on one machine
changes nothing in the repository.

## See which version a project uses

```bash
xaden project doctor
```

- `xaden project doctor`: prints `installed X, project pinned Y` and checks that the installed copy matches the pinned checksum. It reads two files and uses no network. It also shows the `update-check` setting in effect and the cached result of the last check ([Check for updates](check-for-updates.md)).

If `xaden/RULES.md` does not match the pinned version, `xaden check` fails and names the fix, `xaden project rules`, which regenerates the file from
the pinned version.

## Install a pinned version that is missing

When you run a project command and the pinned version is not installed, Xaden stops and asks:

```text
Download and install Xaden 0.3.0 now? [y/N]
```

The question shows the version, the source and the checksum first. Only a yes downloads. Xaden installs the download only if its
checksum equals the one in `xaden.conf`. The answer is not remembered. You can run the same step on purpose:

```bash
xaden project fetch 0.3.0
```

- `xaden project fetch 0.3.0`: shows the same facts, asks, downloads, verifies and installs into `~/.local/share/xaden/versions`. Set `XADEN_HOME` to use another place.

## When there is no terminal

An IDE git client, a script or an assistant cannot answer the question. Nothing downloads. The command exits with code 3 and prints the
`xaden project fetch <version>` to run yourself in a terminal. Assistants show the question to you and never answer it.

In CI, the workflow step names the version and the checksum and changes only by pull request.

## Move the team to a newer version

```bash
xaden project pin --check
xaden project pin 0.3.0
```

- `xaden project pin --check`: asks, then looks for a newer release on github.com. This is the only way Xaden looks for one.
- `xaden project pin 0.3.0`: works on a branch for a pull request. It bumps the version and checksum in `xaden.conf`, regenerates `xaden/RULES.md`, updates the workflow, and shows the diff and the changelog entries between the two versions.

`xaden core upgrade` is a different command: it updates Xaden on your machine and never moves a project. A file you edited, such as a command file in `.claude/commands/`, is never overwritten: the new text is written next to it as `<file>-dist`.

Your team reviews the pull request, so everyone moves at once. If the new version is not installed on your machine, Xaden asks before it
downloads it. With a signed release the pinned checksum is the one the maintainer signed ([Verify releases](verify-releases.md)).

## Next

[Verify releases](verify-releases.md).
