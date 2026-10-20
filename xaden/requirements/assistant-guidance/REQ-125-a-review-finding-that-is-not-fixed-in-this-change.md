---
id: REQ-125
type: job
epic: assistant-guidance
priority: must
status: done
updated: 2026-10-19
---

# A review finding that is not fixed in this change is recorded, not lost in the chat

## Job

When a review turns up a real problem that this change did not cause or that is too big to fix now, I want it written down with its evidence, so I can decide later instead of forgetting it (AIDD manifesto P06).

## Acceptance criteria

- Given a finding of the prompts code-review or security-review, or of the quick review of REQ-123, that is not fixed in this change, then the assistant offers three routes (fix now, ask me, defer) and defers only after I agree
- Given a fix that would change rules, `AGENTS.md` or requirements, then the assistant never applies it silently: it asks or defers
- Given a deferred finding, then it is one entry in `docs/deferred-work.md` with its source (a requirement ID or a branch), a one-sentence summary and its evidence (why it is real; for an unverified finding, what would prove it)
- Given `docs/deferred-work.md`, then it is append only; an entry leaves it only when it becomes a requirement or is dropped, in a commit whose message says which
- Given an entry without source, summary or evidence, or one that cites an unknown `REQ-nnn`, then the check names the entry and fails
- Given `docs/security-exceptions.md`, then it is unchanged and stays separate: an exception is a decision with an owner and an expiry, a deferral is not
- Given the smoke test (area `assistant-guidance`), then it finds the routing in the review prompts and the entry format in a project made from the scaffold

## Notes

Today a finding that is not fixed lives only in the chat. Row P06 of the AIDD mapping table says "no home for findings that are not fixed now, planned"; update it when this is done (`docs/guide/developer/xaden-and-the-aidd-manifesto.md`, checked by `scripts/check-aidd-mapping.sh`).

A decision or a lesson that later work needs goes to `docs/decisions/` (REQ-111); a finding that is not fixed goes here. The two stay apart.

Open questions for the approval: which script runs the format check (an own script or part of `scripts/check.sh`), and whether `xaden adopt` creates the file or the first deferral does. Idea source: BMAD-METHOD, skill `bmad-retrospective`, which keeps deferred work; shape only, no code.
