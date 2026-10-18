# Install Xaden

Get Xaden onto your machine and run it as one command, `xaden`, from any folder. Xaden keeps every installed version in
`~/.local/share/xaden/versions/<version>`, a link `~/.local/share/xaden/current` points at the active one, and the command links to
`current`. An upgrade only moves that link.

## Before you start

You have the [requirements](requirements-and-platforms.md): git, bash and the other standard tools, on Linux or macOS (Windows: WSL).

## Install with one command

```bash
curl -fsSL https://xaden.dev/install | bash
```

- `curl -fsSL https://xaden.dev/install`: downloads the installer script and stops with an error if the download fails.
- `| bash`: runs it. The script runs only when it arrived completely. Before it downloads anything it shows the version and the source and asks `[y/N]` in your terminal; without a terminal it downloads nothing and exits with code 3. It checks the signature of the release against the maintainer's key, which is inside the script, and then installs it into `~/.local/share/xaden` with one link, `~/.local/bin/xaden`. It replaces a link to a former Xaden (after saying so) and never replaces any other file of that name.

To read the script first, run `curl -fsSL https://xaden.dev/install | less`, or save it with `curl -fsSLO https://xaden.dev/install` and read the file before you run it with `bash install`. To install a release other than the newest, name it for `bash`: `curl -fsSL https://xaden.dev/install | XADEN_VERSION=<version> bash`.

From now on, `xaden upgrade` keeps Xaden current ([Update Xaden](update-xaden.md)).

If `~/.local/bin` is not on your `PATH`, the installer says so. Add this line to your shell profile (`~/.bashrc` for bash, `~/.zshrc` for zsh)
and open a new terminal:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

- `export PATH=...`: puts `~/.local/bin` in front of the folders your shell searches for commands, so it finds `xaden`.

Check the result:

```bash
xaden version
```

- `xaden version`: prints the installed Xaden version.

## Install from a git clone

Clone Xaden only to read its history, contribute or work on it. The clone also holds the files Xaden's maintainers work with (tests,
requirements, signing scripts). The steps are in [Install with git](../contributing/install-with-git.md) in the Contributing section.

## Verify what you downloaded

The installer checks the signature of the release zip before it opens it. Check that `xaden version` prints the version you expect, and read
the scripts you are about to run: they are plain shell. The maintainer also signs the checksum of every release; see [Verify releases](verify-releases.md).

## Next

[Create a project](../developer/create-a-project.md) or [add Xaden to a repository](../developer/add-xaden-to-a-repository.md).
Later: [Update Xaden](update-xaden.md) (`xaden upgrade`).
