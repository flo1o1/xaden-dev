---
id: REQ-029
type: job
epic: security
priority: should
status: done
updated: 2026-10-11
---

# Security checklist covers common gaps precisely

## Job

When an assistant writes security-relevant code, I want a precise checklist of common gaps, so I can avoid well-known vulnerabilities.

## Acceptance criteria

- security.md covers CSRF beyond SameSite, SSRF redirects and private ranges, archive and symlink traversal, upload limits, object and tenant authorization tests, session expiry and revocation, password reset, rate and resource limits, safe parsing, data retention and logging
- web-only items marked
