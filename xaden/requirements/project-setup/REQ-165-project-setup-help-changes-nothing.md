---
id: REQ-165
type: job
epic: project-setup
priority: should
status: done
updated: 2026-11-05
paths: scripts/xaden.sh
---

# `xaden project setup --help` shows help and changes nothing

## Job

When I call `xaden project setup --help` or mistype an option, I want to read the usage or an error and nothing else to happen, so I can look at the command without my git hooks being rewritten.

## Acceptance criteria

- Given `xaden project setup --help` or `-h`, when it runs, then it prints a usage that starts with `xaden project setup`, exits with 0 and changes no file in `.git/hooks`
- Given `xaden project setup` with any other argument, when it runs, then it exits with 2, prints the usage and writes nothing
- Given `xaden project setup` without arguments, then it behaves as before

Refs: issue 115. Not covered: `xaden hook --help` and the `--help` of the other commands.
