# Install with git

Clone Xaden when you want to read its history, contribute, or work on Xaden itself. To use Xaden, [install it with one command](../admin/install-xaden.md)
instead. The clone also holds the files Xaden's maintainers work with: tests, requirements and the signing scripts.

## Install

```bash
git clone https://github.com/flo1o1/xaden-dev.git ~/.xaden
~/.xaden/scripts/install.sh
```

- `git clone ...`: downloads Xaden into the hidden folder `.xaden` in your home directory. Keep that folder where it is, because the `xaden` command runs from it.
- `~/.xaden/scripts/install.sh`: creates one link, `~/.local/bin/xaden`, that points into that folder. It changes nothing else and never replaces a file that is not a link to a Xaden.

If `~/.local/bin` is not on your `PATH`, the installer says so; [Install Xaden](../admin/install-xaden.md) shows the line to add. Check the result:

```bash
xaden version
```

- `xaden version`: prints the installed Xaden version.

## Update

```bash
git -C ~/.xaden pull
xaden version
```

- `git -C ~/.xaden pull`: fetches the newest Xaden into the folder. The `xaden` command keeps working. `xaden core upgrade` refuses to touch a clone and names this command.
- `xaden version`: prints the version you now have.

To stay on a fixed release instead of the newest code:

```bash
git -C ~/.xaden tag -l
git -C ~/.xaden checkout v<version>
```

- `git -C ~/.xaden tag -l`: lists the releases.
- `git -C ~/.xaden checkout v<version>`: switches to the release you choose. Switch back with `git -C ~/.xaden checkout main` before the next `git pull`.

A project that pins a Xaden version needs that release installed by `xaden project fetch`, not the clone; a clone is never accepted when a team requires signed releases
([Verify releases](../admin/verify-releases.md)).

## Uninstall

```bash
~/.xaden/scripts/install.sh --uninstall
rm -r ~/.xaden
```

- `~/.xaden/scripts/install.sh --uninstall`: removes the `xaden` link, but only if it points to a Xaden.
- `rm -r ~/.xaden`: deletes the Xaden folder.

## Next

[Work on Xaden](work-on-xaden.md).
