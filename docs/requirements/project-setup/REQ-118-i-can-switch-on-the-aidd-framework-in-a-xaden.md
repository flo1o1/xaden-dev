---
id: REQ-118
type: job
epic: project-setup
priority: should
status: approved
updated: 2026-10-19
---

# I can switch on the AIDD framework in a Xaden project with one command

## Job

When my environment supports it and I want full AI-Driven Development in a project made or adopted with Xaden, I want one command that installs the AIDD framework at a pinned version and tells me what it changed, so I can work with its workflow without wiring it by hand and without surprises from a newer release.

## Acceptance criteria

- Given a Xaden project (classic or adopted), when I run `xaden aidd enable` (command name open until implementation), then it installs the framework through its own CLI (`@ai-driven-dev/cli`, today `aidd setup --ai <assistants> --plugins recommended`) for the assistants the project already uses (REQ-081), and prints the files it added or changed before and after
- Given the pin, then the exact CLI version is recorded in `xaden/xaden.conf` (adopted) or the project's own Xaden config (classic), the CLI is always called with that exact version and never `@latest`, and `xaden aidd status` shows the pinned version next to the installed one
- Given the framework cannot be held to the pin (the plugins would follow the catalog's current version), then `enable` stops before it installs anything and says why; it never installs something unpinned
- Given a prerequisite is missing (Node 22.12 or later, `git`, or the assistant's own executable the framework needs), then `enable` stops before it installs anything and names the prerequisite and the version found
- Given an assistant the framework does not support, then it is skipped with a line saying so, and `enable` fails only when none of the project's assistants is supported
- Given the project's rules file, then `enable` adds a short, marked block that maps the framework's steps to Xaden's gates (requirement as the spec, `xaden check` as the validation step, `Refs:` trailers, the person merges) and says that Xaden's rules win on a conflict (`template/AGENTS.md` §10); `disable` removes the block
- Given a pinned version and a newer release, then Xaden changes the pin only on my request, in a pull request that shows the framework's changelog entry range (like REQ-071 for Xaden itself); no check, hook or `xaden upgrade` bumps it silently
- Given `xaden aidd disable`, then it runs the framework's own removal (`aidd clean`) and removes the pin and the rules block, and it leaves every file Xaden or I own untouched
- Given the framework is not enabled, then no Xaden check, script or document depends on it; Xaden itself stays bash-only and works for every supported assistant (REQ-045, REQ-079)
- Given the smoke test, then a fixture project runs `enable`, `status` and `disable` against a stub of the framework CLI, and a stub that cannot be pinned, a missing Node and an unsupported assistant each stop the command without writing a file
- Given the guide `docs/guide/developer/`, then a page explains what the add-on is, how to enable and disable it, how the pin works and how to move it, and names the framework's license (MIT) and source (REQ-113)
