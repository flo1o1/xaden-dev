---
id: REQ-039
type: job
epic: security
priority: should
status: done
updated: 2026-10-11
---

# Security checklist and review cover the WSTG test areas missing so far

## Job

When code is reviewed for security, I want all relevant OWASP WSTG test areas covered, so I can avoid missing whole classes of vulnerabilities.

## Acceptance criteria

- security.md and the review prompt cover open redirect, parameter pollution, header injection and smuggling, further injection types, file inclusion, vertical privilege escalation, user enumeration, default credentials, session scope and URL tokens, HSTS, exposed files and methods, client-side secrets, encryption at rest, upload origin and counts, automation and wildcard DoS, ReDoS, audit trail, segregation of duties, postMessage and web storage, payments via a provider
- obsolete technologies left out
