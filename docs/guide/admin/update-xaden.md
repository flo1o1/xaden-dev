# Update Xaden

Move the Xaden on your machine to a newer version. This changes your machine only. A project that pins its Xaden version is not
affected until the team moves it with `xaden pin` ([Pin one Xaden version per project](pin-one-version-per-project.md)).

## Update with the command

```bash
xaden upgrade
```

- `xaden upgrade`: asks before it looks for the newest release on github.com, then shows the version, source and checksum and asks again before it downloads. It verifies the signature and the checksum, installs the release next to the others in `~/.local/share/xaden/versions`, and only then switches `current`. It prints what changed since your version. A failed download or check leaves the old version active.

```bash
xaden upgrade --check
```

- `xaden upgrade --check`: only tells you whether a newer release exists.

Older versions stay installed, because projects that pin them use them. Nothing in an installed version folder is ever edited, so there is
nothing to overwrite. Without a terminal nothing downloads and the command exits with code 3.

If `xaden upgrade` says your Xaden does not live in `~/.local/share/xaden`, you installed it before this layout existed: install once
with [the one command](install-xaden.md), then use `xaden upgrade` from then on.

## Read what changed

`CHANGELOG.md` in the Xaden folder lists the changes of every version. Projects created with `xaden create --classic` are updated with
`xaden update` ([Update a classic project](update-a-classic-project.md)).
