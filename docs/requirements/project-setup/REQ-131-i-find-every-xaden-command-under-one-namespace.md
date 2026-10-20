---
id: REQ-131
type: job
epic: project-setup
priority: should
status: approved
updated: 2026-10-19
---

# I find every Xaden command under one namespace that says what it acts on

## Job

When I look for a command, I want it grouped by what it changes (Xaden itself, a project, my daily work), so I can guess its name without reading the whole list.

## Acceptance criteria

- Given `xaden core upgrade [--check [--if-due]]` and `xaden core version`, then they do what `xaden upgrade` and `xaden version` did, with the same options, exit codes and prompts.
- Given `xaden project <create|adopt|remove|pin|fetch|doctor|rules|preset|setup|release|persona|ignore-list>`, then each does what the top-level command of that name did, with the same options, exit codes and prompts.
- Given an old top-level spelling of a moved command (`xaden create`, `xaden pin`, `xaden upgrade`, ...), then Xaden answers like for any unknown command and prints the usage text that lists the namespaces; no alias or notice stays behind.
- Given `check`, `req`, `context`, `hook`, `verify-commits`, `prompt`, `doc`, `help`, `version` and `aidd`, then they stay where they are and print no notice.
- Given `xaden help`, then it lists the namespaces with their commands; `xaden help core` and `xaden help project` list one namespace; an unknown first word still fails with the usage text.
- Given `xaden core` or `xaden project` without a command, then it prints that namespace's commands and exits non-zero.
- Given `core`, `project` and every top-level command, then they are reserved names a later plugin cannot take; no plugin lookup exists yet.
- Given a git hook, a generated CI workflow or an `xaden/RULES.md` written before this change, then the commands they call (`hook`, `verify-commits`, `check`, `req`, `context`) work unchanged; a rule text that names a moved command is replaced by `xaden project rules` or the next `xaden project pin`.
- Given a project that pins a Xaden version older than this change, then the commands that stay at top level still run on that version; a moved command is handed over as typed and that version answers that it does not know it, and `xaden project pin` moves the project.

Requirement files written before this change name the old spellings of the moved commands: read `xaden pin` as `xaden project pin`, `xaden upgrade` as `xaden core upgrade`, and so on.

Plugins (the mechanism: where a plugin lives, who may install one, how a project pins it, the threat model entry) are not part of this requirement.
