---
id: REQ-082
type: job
epic: assistant-guidance
priority: should
status: done
updated: 2026-10-16
---

# A requirement is approved before any branch or worktree exists

## Job

When I ask my assistant for a change in a large code base, I want to approve the requirement first and have the branch and worktree created only afterwards, so I can reject or reshape an idea without a full copy of the repository on my disk.

## Acceptance criteria

- Given a new change, then the assistant shows the requirement draft in the chat or saves it in the git-ignored `inbox/`; it creates no branch, no worktree and no commit before I say yes.
- Given I approve the draft, then the assistant assigns the next free ID from the branch it starts from, creates branch `<type>/req-nnn-<slug>` and its worktree, and the first commit holds the requirement with status `approved`.
- Given I reject or change the draft, then there is nothing to clean up: no branch, worktree or file outside `inbox/`.
- Given a worktree is created for the requirement commit, then it starts as a sparse checkout of the requirements folder and the scripts that check it (`template/scripts/` in the scaffold, `scripts/` in a project), not of the full tree; the assistant widens it to the full tree when implementation starts.
- Given several drafts are open at once, then they cost no checkout space, because only approved changes get a worktree.
- Given `template/AGENTS.md` §7, the feature, bugfix and requirements-update prompts, and REQ-060, then they state this order instead of "branch first".
- Given the smoke tests, then a test fails when AGENTS.md or a prompt tells the assistant to create the branch before the requirement is approved.
