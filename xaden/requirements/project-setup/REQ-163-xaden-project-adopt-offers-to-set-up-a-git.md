---
id: REQ-163
type: job
epic: project-setup
priority: should
status: approved
updated: 2026-11-02
paths: scripts/adopt.sh
---

# xaden project adopt offers to set up a Git repository when there is none

## Job

When I adopt Xaden in a folder that is not a Git repository yet, I want to be asked whether Xaden should set one up, so I can go on without running `git init` first.

## Acceptance criteria

- Given a terminal, no repository and no `--init`, then `adopt` names the folder and asks `Set up a Git repository in <folder> now?`; yes runs `git init -b main` in the current folder and the adoption goes on as in an empty repository, no changes nothing and ends with the earlier error that names `git init`.
- Given `--init`, then nothing is asked and the repository is set up, with or without a terminal and with `--yes`. Given no terminal and no `--init`, then nothing is set up and the earlier error stays.
- Given the setup, then Xaden only runs `git init`: it makes no commit, adds no remote, pushes nothing and leaves the files that are there untracked; the closing hint names `git remote add origin <url>`.
- Given the current folder is the home folder or `/`, then no repository is set up and `adopt` stops with the earlier error, because a repository there would cover everything below it.
- Given `git init` fails, then the adoption stops with git's message and changes nothing else. Given a folder inside a repository, then nothing changes.
- Given `--scan` or `--plan` and no repository, then nothing is asked and no repository is set up: both stay previews and end with the earlier error.
- Given the change, then the Reference and the guides name the question and `--init`.
