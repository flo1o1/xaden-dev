# Rules: requirements and tests

Moved from `AGENTS.md` (REQ-126), rule IDs and wording unchanged. `AGENTS.md` says when to read this file.

## 2. Requirements tracking (mandatory)

- Every behaviour the user asks for has a requirement `REQ-nnn`: one file
  `docs/requirements/<epic>/REQ-nnn-<slug>.md`, grouped by topic (epic). Each epic folder has an
  `EPIC.md` whose goal states the big job the epic serves.
- Functional requirements are **jobs to be done** (`type: job`), written from the user's
  situation, not as a feature: *"When <situation>, I want to <motivation>, so I can <expected
  outcome>."* Non-functional requirements are measurable **quality goals** (`type: quality`).
  Acceptance criteria are concrete examples (*Given … when … then …*) that become tests.
- When the user adds, changes, or drops something during a session:
  **update the requirement files first, then write code.** Create new ones with
  `scripts/req.sh new <epic> <job|quality> "<title>"`; after edits run `scripts/req.sh index`.
  A new requirement is drafted in the chat first and becomes a file only after the user approves it (§7).
- IDs are global and stable. Never delete, reuse or renumber; set status `dropped` instead.
  Moving a requirement to another epic keeps its ID (move the file, change `epic:`).
- History: `git log -- docs/requirements`. Say in the commit message what changed and why.
- Run `scripts/check-requirements.sh` after editing; it validates front matter, job stories,
  acceptance criteria and the index. TODO text is a warning and blocks releases.
- Lifecycle: `draft` (idea) → `approved` by the user → `in-progress` → `done` (with a citing test).
  `feat`/`fix` commits may only reference approved, in-progress or done requirements.


## 4. Tests

- Follow CC-08. Test first when feasible.
- Every requirement has acceptance criteria; they become tests.
- Tests cite the requirement they verify (`# REQ-nnn` or in the test name). A requirement may only
  be set to `done` when a test references it; `scripts/check-traceability.sh` enforces this and
  rejects tests citing unknown IDs. `--matrix` prints requirement → tests → commits.
