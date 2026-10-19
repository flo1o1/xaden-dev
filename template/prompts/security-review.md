---
title: Security review
type: prompt
status: stable
version: 1.2.0
works-with: [claude-code, chatgpt, local-llm]
tags: [prompt, security, review]
---

# Security review

## Goal
Find exploitable weaknesses in the changed code, ranked by risk, with fixes.
Works with any assistant; Claude Code runs it as `/xaden-security`.

## Inputs
- Scope: {{changed files, or whole project}}

## Steps
1. Read `docs/threat-model.md` and `docs/security.md`. Confirm the entry points (HTTP routes,
   CLI args, files, env, message queues) and trust boundaries against the code; if the code has
   ones the threat model lacks, update the threat model and say so.
2. For each entry point, trace untrusted data to sinks and check (OWASP WSTG categories):
   - Input validation (server repeats client checks, parameter pollution) and output encoding
   - Injection: SQL, NoSQL, OS command, LDAP, XPath, template/expression language, mail and
     HTTP headers (CR/LF), file inclusion, ReDoS
   - Authentication: user enumeration, brute force and lockout, default accounts, password
     change and reset, MFA, out-of-band notifications
   - Sessions: expiry, revocation, new ID on login and privilege change, no tokens in URLs,
     "remember me", parallel sessions
   - Authorization: server-side checks per request, per object and per tenant (IDOR), vertical
     privilege escalation, routes without a rule; default deny; negative tests exist
   - Cryptography and TLS; randomness; hard-coded and client-side secrets; secrets in logs;
     encryption at rest
   - File upload/download (counts, frequency, serving origin, download authorization), archive
     extraction, path and symlink traversal, SSRF (redirects, private addresses, DNS rebinding),
     safe parsing, deserialization
   - Web only: XSS (reflected, stored, DOM), CSRF (not SameSite alone), clickjacking, CORS,
     HSTS and headers, cookie scope, open redirects, exposed files and HTTP methods, request
     smuggling, `postMessage` origins, tokens in web storage
   - Business-logic abuse (workflow order, race conditions, replay, rate and resource limits,
     anti-automation, `LIKE` wildcards, mass assignment, segregation of duties, audit trail)
   - Test data in production and production data in test; card data (provider or PCI DSS)
   - Data retention, deletion and what gets logged
   - Error handling and information leakage; debug flags
   - Dependencies: new or outdated packages, known CVEs, install scripts
   Look beyond the changed lines: callers, configuration, permissions and dependencies the
   change relies on.
3. Run `scripts/check.sh` (secret scan, SAST, dependency audit) and include its findings.
   A skipped scanner is a limitation, not a pass.
4. Write the report from `docs/security-reviews/0000-template.md` to
   `docs/security-reviews/<date>-<scope>.md`: scope (and what is out of scope), evidence
   (commands, results, tests), limitations, findings, remediation status.
   Each finding: `severity (critical|high|medium|low)` · location `file:line` ·
   what an attacker does · minimal fix as code.
5. Only claim what you verified in the code. Mark guesses as "unverified". A completed
   checklist is not proof of security; say so in the limitations.
6. **Approval point:** show me the findings and proposed fixes. Then apply fixes with a
   regression test each; commit `fix(security): <summary>`. Update each finding's status in
   the report.
7. For a finding that is not fixed in this change, offer the three routes of AGENTS.md §9 (Findings not fixed now): fix now, ask me, or defer. A finding you accept with an owner and an expiry goes to `docs/security-exceptions.md`, not to the deferred work.

## Done when
- [ ] Every entry point reviewed or explicitly out of scope
- [ ] Report saved with scope, evidence, limitations, findings and status
- [ ] Critical/high findings fixed, or accepted by me with owner and expiry
- [ ] Completion report given (AGENTS.md §5): checks run, checks skipped, unresolved findings, acceptance evidence
