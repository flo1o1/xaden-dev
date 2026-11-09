---
id: REQ-170
type: job
epic: assistant-guidance
priority: should
status: approved
updated: 2026-11-09
paths: template/docs/rules/git.md
---

# Rules for parallel branches and resources that exist once per machine

## Job

When several branches or assistant sessions work on one project at the same time, I want the rules to say when a pull request is opened and how a resource that exists once per machine is shared, so I can have CI feedback early and no session recreates the local stack of another.

## Acceptance criteria

- Given `template/docs/rules/git.md`, when an assistant reads it before it pushes, then it says to open a draft pull request from the first testable commit, so CI and any test environment start early.
- Given a resource that exists once per machine (a local container stack, a fixed port), when a change would recreate or stop it, then the rules say it is changed only through a lock that names its owner, and the owner is checked before the change.
- Given `template/AGENTS.md` and the `xaden/RULES.md` an adopted project renders from it, then both stay within the size budget (REQ-126); the new text lives in `docs/rules/git.md` only.
- Given a project adopted earlier, when it takes the next Xaden version, then no file it owns changes except through the usual `xaden project pin` step.

Refs: issue 122, part C. Not covered: tooling for the lock (the rule is text), changelog fragments, the generated requirement index and the question about `footprint.txt` (parts A, B and D of the issue).
