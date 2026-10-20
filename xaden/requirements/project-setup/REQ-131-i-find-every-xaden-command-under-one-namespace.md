---
id: REQ-131
type: job
epic: project-setup
priority: should
status: approved
updated: 2026-10-20
---

# I find every Xaden command under one namespace that says what it acts on

## Job

When I look for a command, I want it grouped by what it changes (Xaden itself, a project, my daily work), so I can guess its name without reading the whole list.

## Acceptance criteria

- Given `xaden core <upgrade|version|fetch|doctor|ignore-list>`, then each does what the top-level command of that name did, with the same options, exit codes and prompts. `fetch` installs a Xaden version, `doctor` compares the installed Xaden with the pinned one and `ignore-list` prints the paths Xaden owns; none of them changes the project.
- Given `xaden project <create|adopt|remove|pin|rules|add-preset|setup|release|persona>`, then each does what the top-level command of that name did (`add-preset` was `preset`), with the same options, exit codes and prompts.
- Given an old top-level spelling of a moved command (`xaden create`, `xaden pin`, `xaden upgrade`, ...) or of a command that moved again (`xaden project fetch`, `xaden project doctor`, `xaden project ignore-list`, `xaden project preset`), then Xaden answers like for any unknown command and prints the usage text that lists the namespaces; no alias or notice stays behind.
- Given `check`, `req`, `context`, `hook`, `verify-commits`, `prompt`, `doc`, `help`, `version` and `aidd`, then they stay where they are and print no notice.
- Given `xaden core help`, `xaden project help` and `xaden aidd help` (and `-h` or `--help` in place of `help`), then each lists that namespace's commands and exits 0; every namespace usage text lists `help`, and `help` is a reserved command name in each namespace.
- Given `xaden help`, `xaden -h`, `xaden --help` or `xaden` without arguments, then it lists the namespaces and the daily commands; `xaden help` takes no namespace, so `xaden help core` fails as an unknown command with the usage text, and no alias or notice stays behind.
- Given `xaden core` or `xaden project` without a command, then it prints that namespace's commands and exits non-zero.
- Given `core`, `project` and every top-level command, then they are reserved names a later plugin cannot take; no plugin lookup exists yet.
- Given a git hook, a generated CI workflow or an `xaden/RULES.md` written before this change, then the commands they call (`hook`, `verify-commits`, `check`, `req`, `context`) work unchanged; a rule text that names a moved command is replaced by `xaden project rules` or the next `xaden project pin`.
- Given a project that pins a Xaden version older than this change, then the commands that stay at top level still run on that version; a moved command is handed over as typed and that version answers that it does not know it, and `xaden project pin` moves the project.

Requirement files written before this change name the old spellings of the moved commands: read `xaden pin` as `xaden project pin`, `xaden upgrade` as `xaden core upgrade`, and so on.

Read `xaden project fetch` as `xaden core fetch` (`doctor` and `ignore-list` the same way), `xaden project preset` as `xaden project add-preset`, and `xaden help <namespace>` as `xaden <namespace> help`.

Plugins (the mechanism: where a plugin lives, who may install one, how a project pins it, the threat model entry) are not part of this requirement.
