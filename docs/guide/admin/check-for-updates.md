# Check for updates

Let Xaden tell you when a newer Xaden or newer dependencies exist, as often as you choose. Xaden only reports. It never installs or
changes anything because of what it finds.

The check is off until you turn it on. While it is off, Xaden makes no network call for it.

## Turn it on for a project

Add one line to `xaden/xaden.conf` and review it in a pull request like any other setting:

```text
update-check = 1d
```

- `update-check = off`: no check. This is the default.
- `update-check = 12h`, `1d`, `7d`: at most one check per interval. The interval is a whole number of hours (`h`) or days (`d`), at
  least `1h`. Anything else (`30m`, `1w`, `1.5d`) is refused and the message names the allowed forms.

`xaden create` and `xaden adopt` ask for the interval once when a terminal is attached. The default answer is `off`. Without a terminal
they set nothing.

## Turn it on for yourself only

```bash
export XADEN_UPDATE_CHECK=7d
```

- `XADEN_UPDATE_CHECK`: takes the same values and overrides the project value on your machine. The repository does not change.

## Look now

```bash
xaden upgrade --check
```

- `xaden upgrade --check`: asks, checks now whatever the interval and whatever the setting, and prints the result. It changes nothing, not even the cache.
  Outside a project it reports the `Xaden` line only.
- `xaden upgrade --check --if-due`: checks only when the interval has passed, writes the cache, prints nothing and exits 0 when the network is down.
  The setting decides here: `off` means no check.

The setting is still called `update-check` and the variable `XADEN_UPDATE_CHECK`; there is no command of that name.

## What it reports

```text
Xaden: pinned 0.2.3, installed 0.2.3, newest 0.3.0 (move the project with: xaden pin 0.3.0)
Dependencies: npm: left-pad, react (major); pip: up to date
```

- The `Xaden` line compares the version the project pins with the newest release on github.com. Move the project with
  `xaden pin`, on a branch and through a pull request ([Pin one Xaden version per project](pin-one-version-per-project.md)).
- The `Dependencies` line lists packages that `npm outdated` or `pip list --outdated` report for the project. Those updates stay yours:
  `xaden pin` never touches `package.json`, lockfiles or `requirements-dev.txt`.
- `(major)` marks a package whose newest version has a higher major number than the installed one. Such an update can break your project:
  read its release notes and update it in a pull request with your tests.
- A tool that is not installed shows as `not checked`, never as up to date.

The result is cached in the repository's git folder (`.git/xaden-update-check`), so it is never committed and every worktree shares it.
`xaden doctor` and `scripts/context-status.sh` print the cached result and the setting in effect (`update check: 1d (xaden/xaden.conf)`).
They, the commit hooks and the pre-commit checks never use the network.

## What is sent

One request for the newest release goes to the GitHub release API, the same one `xaden pin --check` and `xaden upgrade --check` use. `npm outdated` and
`pip list --outdated` contact the registries your project already uses. Nothing else leaves your machine.

Projects created with `xaden create --classic` have no `xaden/xaden.conf`; use `XADEN_UPDATE_CHECK` there.
