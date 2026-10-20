---
id: REQ-132
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-20
---

# I run check and req as project commands and keep the short spellings

## Job

When I run the checks or the requirements of a project, I want to find the commands in the namespace of the project and still type `xaden check` and `xaden req`, so I can look for a command where it belongs and git hooks, CI workflows and assistant rules keep working.

## Acceptance criteria

- Given `xaden project check` and `xaden project req`, then they do what `xaden check` and `xaden req` did, with the same options, output and exit codes.
- Given `xaden check` and `xaden req`, then they are aliases of `xaden project check` and `xaden project req`: the same output and exit codes, no notice. No other command gets an alias (REQ-131).
- Given `xaden version`, then it is an alias of `xaden core version`.
- Given `xaden help`, then it lists `core`, `project` and `aidd` as namespaces; `xaden help aidd` lists the commands of `aidd`; `xaden help project` lists `check` and `req`.
- Given a project-scoped command (a `project` command that needs a project, `check`, `req`, `context`, `prompt`, `doc`, `aidd`) outside a git repository, then it fails with a message that says so and names `xaden project create <name>` and `xaden project adopt`.
- Given the same command in a git repository that has not adopted Xaden, then every one of them prints the same message, `this repository has not adopted Xaden; run: xaden project adopt`, and none of them names the old spelling of a command or a copy of the tooling.

Requirement REQ-131 says that `check` and `req` stay where they are: read that as this requirement amends it.
