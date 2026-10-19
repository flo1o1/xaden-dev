---
id: REQ-056
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-19
---

# Run Xaden as one command from anywhere

## Job

When I start or maintain a project somewhere on my machine, I want to type `xaden <command>` in any directory instead of the path to a script in the scaffold checkout, so I can create, update and check projects without remembering where the scaffold lives.

## Acceptance criteria

- Given the scaffold is cloned, when I run `scripts/install.sh`, then a `xaden` link to the checkout's `scripts/xaden.sh` exists in `~/.local/bin` (or the directory I pass), no other file outside the checkout is changed, and the script says how to add the directory to `PATH` when it is missing there
- Given `xaden` is installed, when I run `xaden create my-app` in any directory, then the project is created in `./my-app` exactly as `scripts/new-project.sh my-app ./my-app` would create it
- Given `xaden new my-app` (the former name of `xaden create`), then Xaden answers like for any unknown command (REQ-130)
- Given `xaden update`, then Xaden answers like for any unknown command (REQ-001)
- Given I am anywhere inside a generated project, when I run `xaden setup`, `xaden check`, `xaden req …` or `xaden release …`, then the project's own `scripts/<name>.sh` runs from the project root with my arguments unchanged
- Given I am not inside a git project, when I run a project command, then `xaden` exits non-zero and says it must run inside a project
- Given an unknown command, or `xaden help`, then `xaden` lists its commands and an unknown command exits non-zero
- Given `xaden version`, then it prints the scaffold version from the checkout it links to
- Given `scripts/install.sh --uninstall`, then the link is removed only if it points to this checkout
