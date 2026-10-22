---
id: REQ-161
type: job
epic: project-setup
priority: should
status: done
updated: 2026-10-22
paths: scripts/create.sh, scripts/scaffold-lib.sh
---

# `xaden project create` offers to connect a remote

## Job

When I create a project, I want Xaden to ask for the remote Git URL, so I can have the project connected to a repository from the start.

## Acceptance criteria

- Given a terminal and no `--remote`, then `create` asks for the remote Git URL after it made the project; an answer that is a valid URL runs `git remote add origin <url>`, and an empty answer (or `skip`) adds none and the closing hint names `git remote add origin <url>`.
- Given `--remote <url>`, then nothing is asked and the remote is added. Given no terminal and no flag, nothing is asked and no remote is added.
- Given the remote, then Xaden only runs `git remote add`: it never pushes, fetches or contacts the URL, and the closing hint names the push command for the person to run.
- Given a URL, then it is valid only as `https://host/path`, `ssh://host/path` or `user@host:path`, with letters, digits and `. _ ~ : / @ % + = ? # , -` only, a host that does not start with `-`, and no `user:password@` part in the address; `ext::`, `file:`, `-`-prefixed values, spaces, control characters and newlines are refused.
- Given an invalid `--remote`, then `create` stops before it creates anything and names the rule. Given an invalid typed answer, then the project is still created, without a remote, and a warning says why.
- Given `xaden project adopt`, then nothing changes: the repository already has its remotes.
- Given the change, then the threat model has a row for the URL as an input, and the Reference and the guides name `--remote` and the question.
