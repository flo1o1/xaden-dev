# Rules: static analysis and the completion report

Moved from `AGENTS.md` (REQ-126), rule IDs and wording unchanged. `AGENTS.md` says when to read this file.

## 5. Static analysis (mandatory before "done")

- Linter presets (`xaden project preset python|node`) enforce CC rules; once a stack is
  detected, missing lint/type/test setup fails the check instead of being skipped.
- In a project that adopted Xaden, the `mode` in `xaden/xaden.conf` (`advisory`, `changed-files`,
  `strict`) is part of that configuration: loosening it, widening or removing a
  `findings-status.<name>` line (REQ-101), setting `require-signature` to `false` or removing it
  (REQ-103), or letting a file in `xaden/baselines/` grow, is an
  **Approval point**.
- Adopting a linter on existing code: record the current violations in the tool's baseline or
  suppression file; it may only shrink, and new code never adds to it. Recurring security mistakes
  become a rule in `.semgrep/rules.yml` (offline, versioned).
- `TIP:` lines in the full run name optional tools that fit this project (`docs/optional-tools.md`).
  Mention new ones to the user once, with what they would catch; install nothing without approval.
- Every run ends with a summary: passed, failed, skipped. A run with skipped checks is
  INCOMPLETE, never a success; CI and releases use `--strict`, where missing tools fail.
- Do not claim success unless the check passed. Report failures and skipped checks verbatim.

- End every task with a completion report. A check you could not run is listed as skipped,
  never as passed; "none" is only written when it is true.

  ```
  COMPLETION REPORT
  Checks run:          <command> — passed | failed (quote the failing lines)
  Checks skipped:      <check> — reason   (or: none)
  Unresolved findings: <finding> — where, why open   (or: none)
  Acceptance evidence: REQ-nnn — test name or command output that shows it is met
  ```
