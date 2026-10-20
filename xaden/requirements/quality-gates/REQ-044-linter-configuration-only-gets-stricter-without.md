---
id: REQ-044
type: job
epic: quality-gates
priority: should
status: done
updated: 2026-10-11
---

# Linter configuration only gets stricter without user approval

## Job

When an assistant meets a linter finding, I want it to fix the code instead of loosening the configuration without my approval, so I can keep the quality bar.

## Acceptance criteria

- AGENTS.md: loosening rules or thresholds is an approval point
- adopting linters on existing code uses a baseline that may only shrink
