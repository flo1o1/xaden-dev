---
id: REQ-126
type: quality
epic: assistant-guidance
priority: must
status: approved
updated: 2026-10-19
---

# The always-loaded context stays small however many requirements a project has

## Quality goal

The files an assistant loads at the start of every session stay under a fixed byte budget, and the rest is read only when a task needs it (AIDD manifesto P05). The budgets are bytes, not tokens: the tokenizer of each assistant differs, and 4 characters per token is only an estimate.

## Acceptance criteria

- Given a generated project, when `AGENTS.md` is measured, then it is at most 10240 bytes (18.6 KB on `main` at 2026-10-19)
- Given a project with 500 requirements of which at most 50 are neither `done` nor `dropped`, when the imported `docs/requirements/INDEX.md` is measured, then it is at most 6144 bytes
- Given the index, when a requirement is `done` or `dropped`, then it appears only in the count of its epic; every other status is listed individually
- Given `AGENTS.md` names a topic moved to `docs/rules/<topic>.md`, then it states the trigger ("before any commit: read `docs/rules/git.md`") and the moved text keeps its rule IDs and wording
- Given §0 grounding, §1 session start, §3 `CC-01` to `CC-09`, §10 trust and approvals, "Judgment stays with the human" and the size table, then they stay in `AGENTS.md`, and so does every line that names an approval point (merging, pushing, releasing, dependencies, secrets): a trigger line can be ignored, a safety rule must not rest on one
- Given `scripts/req.sh show REQ-nnn --brief`, then it prints ID, status, title and acceptance criteria only; `show` without the flag is unchanged
- Given `scripts/req.sh list --epic <epic>` or `--status <status>`, then it filters; the full table moves to a generated `docs/requirements/INDEX-full.md` that no tool imports
- Given a hook or check that enforces a moved rule, when it fails, then its message names the file holding the rule
- Given `scripts/context-status.sh`, then its fingerprint covers `docs/rules/*.md`
- Given the smoke test generates a project, then it fails when `AGENTS.md` or the index exceeds its budget
- Given `xaden upgrade` on a project with the old layout, then the new files are added, the text is not duplicated and an edited file is kept (REQ-100)

## Notes

Measured 2026-10-19 on `template/AGENTS.md` (18.6 KB): §0 1.0 KB, §1 0.65, §2 1.6, §3 1.5, §4 0.4, §5 2.2, §6 1.2, §7 2.9, §8 0.8, §9 4.0, §10 2.1. The sections that stay add up to about 7.3 KB with the judgment subsection and the size table, so 7 KB was never reachable; 10 KB leaves room for the trigger lines and the approval points of §7. Index rows average 98 bytes: 500 rows are about 49 KB today and 117 of the 122 rows of this repository are `done`, so 6 KB holds the per-epic counts and about 50 open requirements.

Trade-off accepted: a model may skip a trigger line; hooks and checks catch it at commit or at "done", not before the work is written. The moved text changes files the website renders (REQ-064), which needs a site follow-up after the release.

Origin: AIDD manifesto P05, row of the mapping table `docs/guide/developer/xaden-and-the-aidd-manifesto.md`; update it when this is done. Out of scope: a generated code map and an MCP query layer; scoped lookup is REQ-127.
