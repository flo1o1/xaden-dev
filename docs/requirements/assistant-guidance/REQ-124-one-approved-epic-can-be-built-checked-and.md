---
id: REQ-124
type: job
epic: assistant-guidance
priority: must
status: approved
updated: 2026-10-19
---

# One approved epic can be built, checked and reviewed requirement by requirement

## Job

When an epic has several approved requirements, I want the assistant to work through them in order with a check after each and one review at the end, so I can approve once and not start every requirement by hand.

## Acceptance criteria

- Given an epic whose requirements are all `approved`, when I ask for the loop, then the assistant lists them in order and waits for my go (approval point: the list and the order, before the first change)
- Given the loop, then each requirement is a normal change as today: its own branch and worktree, `scripts/check.sh` green, its own commit with `Refs:`; never several requirements in one commit
- Given a failing check, an approval point of the normal flow, or a change of size (REQ-123), then the loop stops; it never continues past a red check, and the retry rule of REQ-119 applies before a second attempt
- Given an acceptance criterion that turns out to be wrong during the loop, then the assistant stops and asks; it does not edit an approved requirement on its own
- Given the end of the loop, then the assistant gives a short retro in the chat: for each requirement what was harder than it said and which acceptance criteria were wrong, with proposed edits to requirements as drafts only
- Given the loop, then it never pushes to `main` and never merges a pull request (REQ-110): one pull request per change, CI green before the person merges
- Given a tool without a shell or without sub-agents, then the prompt still works step by step
- Given the smoke test (area `assistant-guidance`), then it finds the loop text and checks that it names its approval point and its stop conditions

## Notes

Approved 2026-10-19 for release 0.6.0 with REQ-123 and REQ-125. Build it after REQ-123 is merged: the loop stops on a size change, which needs that rule.

Open questions for the approval: does the loop live in a prompt only, or does it need a script (`scripts/epic.sh`) that lists the next approved requirement of an epic? A script is cheap; unattended running is not, because the approval points exist for a reason (`template/AGENTS.md` §10). Does the loop open the pull requests itself or leave them to the person?

Idea sources, in shape only and no code: BMAD-METHOD skills `bmad-build-auto` (one iteration is one unit with a frozen intent; Xaden's equivalent is the approved requirement) and `bmad-retrospective` (compares the acceptance criteria with the diff and writes action items as drafts only). The opt-in AIDD framework add-on (REQ-118, decision 0001) has its own one-command cycle; this loop stays prompt-only and tool-agnostic, and where both are installed the project's rules win (decision 0001, point 5).
