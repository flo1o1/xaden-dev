---
id: REQ-023
type: job
epic: assistant-guidance
priority: must
status: dropped
updated: 2026-10-15
---

# Context pack contains all mandatory guidance and is written safely

## Job

When I use a chat assistant without file access, I want a context pack with all mandatory guidance written safely, so I can give it the same rules as tools with file access.

## Acceptance criteria

- Pack includes the security checklist and the Unreleased changelog and lists its contents
- an invalid prompt name keeps the previous pack
- docs call the fingerprint a consistency aid, not proof
- Given `scripts/pack-context.sh --brief REQ-nnn <prompt>`, when it runs, then the pack holds the rules, the security checklist, the personas, the requirements index, only the named requirement files and the prompt, its header names what it leaves out, an unknown ID keeps the previous pack, and every run prints the estimated size in tokens with a warning above 12,000.

Dropped by REQ-079: Xaden supports only assistants with file access, so there is no context pack.
