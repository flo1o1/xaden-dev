---
id: REQ-135
type: job
epic: project-setup
priority: could
status: approved
updated: 2026-10-20
---

# I complete Xaden commands with the Tab key

## Job

When I type `xaden`, I want Tab to offer the namespaces, their commands and the options of a command, so I do not read `xaden help` to remember a spelling.

## Acceptance criteria

- Given `xaden core completion bash`, then it prints a bash completion script to stdout and changes nothing on disk; the use is `eval "$(xaden core completion bash)"` in `~/.bashrc`, or the output saved to a file in a bash-completion directory. Given any other shell name or none, then it prints the usage text and exits 2. Other shells are not part of this requirement.
- Given `xaden <Tab>`, then bash offers the namespaces (`core`, `project`, `aidd`) and the commands that stay at top level (`check`, `req`, `version`, `context`, `hook`, `verify-commits`, `prompt`, `doc`, `help`).
- Given `xaden core <Tab>`, `xaden project <Tab>` or `xaden aidd <Tab>`, then bash offers exactly that namespace's commands, `help` included; a moved or removed spelling is never offered.
- Given `xaden prompt <Tab>` and `xaden doc <Tab>`, then bash offers the names those commands accept.
- Given a command with options (`upgrade --check`, `pin --check`, `create --autopilot --stack`), then Tab after a dash offers them; `--stack` and `add-preset` offer `python` and `node`.
- Given a command added to a namespace, then the script offers it without a second edit: the lists come from `scripts/xaden.sh`, and a smoke test fails when the script and `xaden <namespace> help` differ.
- Given macOS bash 3.2 and a Linux bash, then the script works without the `bash-completion` package and without GNU tools (`complete -F` and `COMPREPLY` only).
- Given completion is not installed, then no Xaden command, hook or CI step behaves differently, and Xaden never edits a shell startup file.
