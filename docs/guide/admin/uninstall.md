# Uninstall

Remove Xaden from one repository, or from a machine. Do the repositories first: `xaden remove` needs the command.

## Remove Xaden from a repository

```bash
xaden remove
```

- `xaden remove`: deletes `xaden/` and undoes exactly the paths listed in `xaden/footprint.txt`: the marked block in `AGENTS.md`, `CLAUDE.md` if Xaden created it, the workflow and the hook blocks. Review the result with `git status`, then commit.

Your build, tests, documentation and other workflows were never changed, so there is nothing else to undo.

## Remove Xaden from a machine

If you installed with the one command or from the zip, remove the link with the `install.sh` of any Xaden version, then delete the Xaden folder:

```bash
~/.local/share/xaden/current/scripts/install.sh --uninstall
rm -r ~/.local/share/xaden
```

- `~/.local/share/xaden/current/scripts/install.sh --uninstall`: removes the `xaden` link, but only if it points to a Xaden.
- `rm -r ~/.local/share/xaden`: deletes every installed version. If you set `XADEN_HOME`, delete that folder instead. Delete a downloaded `xaden-<version>.zip` and `.zip.sig` and the extracted folder too, if you kept them.

If you installed with git:

```bash
~/.xaden/scripts/install.sh --uninstall
rm -r ~/.xaden
```

- `~/.xaden/scripts/install.sh --uninstall`: removes the `xaden` link, but only if it points into that folder.
- `rm -r ~/.xaden`: deletes the Xaden folder.

Projects created with Xaden keep working without it, except that their hooks print `xaden not found` and skip the checks until you remove
the hook blocks (`xaden remove` does that).
