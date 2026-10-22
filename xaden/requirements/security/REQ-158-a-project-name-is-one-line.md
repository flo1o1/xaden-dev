---
id: REQ-158
type: quality
epic: security
priority: must
status: approved
updated: 2026-10-22
---

# A project name is one line

## Quality goal

`xaden project create` accepts only a name that is entirely a valid name. `is_project_name` piped the name to `grep -Eq '^...$'`, which matches per line, so a value such as `ab` followed by a newline and any text passed. The name is then used in a `sed` expression and in the target path, so a newline can leave the working directory or inject `sed` commands (pre-release security review 2026-10-22, finding 5). This holds since 0.5.0.

## Acceptance criteria

- Given a name that holds a newline, a carriage return or any other control character, then `is_project_name` refuses it and `xaden project create` creates nothing.
- Given every name that was valid before, then it is still valid.
- Given the check, then it matches the whole value (a `case` pattern or `[[ =~ ]]`), not line by line.
