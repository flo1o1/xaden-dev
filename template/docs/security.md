# Secure coding checklist

Baseline: the OWASP ASVS level chosen in `docs/threat-model.md` says *what* to build;
the OWASP Web Security Testing Guide (WSTG) says *how* to test it; the OWASP Top 10 names the
most common failures. Applies to AI-generated code at least as much as to hand-written code.
Sections marked *(web)* apply only to software with a browser client.
Local semgrep rules (`.semgrep/rules.yml`, run by `scripts/check.sh`) catch simple forms of some
items — shell and code injection, SQL strings, unsafe deserialization and XML, open redirects,
regexes from input, weak randomness and password hashes, cookie flags, disabled TLS checks, `os.system`, unverified
JWTs, wildcard CORS, and request data reaching an outgoing URL (SSRF) or a file path (path traversal).
They cover Python, JavaScript/TypeScript, Go, Java, PHP, Ruby and Rust only. Pattern rules miss data that flows through other functions or
files; everything else needs review and tests.
CI also runs semgrep's registry rules (`--config p/default`), which are not pinned: they change
when semgrep publishes new rules, so CI can report a finding without a code change. Fix it, or
suppress that line with a `nosemgrep: <rule-id>` comment and a one-line reason (AGENTS.md section 5).

## All applications

- **Input**: validate on the server/boundary — type, length, range, format; allow-list over deny-list.
  Client-side validation is a convenience; the server repeats every check. Decide how repeated
  parameters (`?id=1&id=2`) are handled instead of leaving it to the framework (parameter pollution).
- **Injection**: parameterized queries only; never build SQL/shell/HTML/paths by string concatenation.
  Avoid `eval`, `exec`, `shell=True`. The same holds for every interpreter: NoSQL query objects,
  LDAP filters, XPath, template engines and expression languages, mail headers (SMTP), and
  HTTP headers (strip CR/LF to prevent header injection and response splitting).
- **Safe parsing**: limit input size, nesting depth and element count before parsing; disable XML
  external entities and DTDs; no unsafe deserialization (`pickle`, `yaml.load`, Java/PHP native
  serialization) of untrusted data. Never build regular expressions from input, and avoid nested
  quantifiers on input you match (ReDoS).
- **Mass assignment**: bind request data to an explicit allow-list of fields; never let a request
  set `role`, `owner`, `price` or similar fields by naming them.
- **Authentication**: use a vetted library; hash passwords with Argon2id/bcrypt/scrypt; rate-limit
  logins; offer MFA where the ASVS level asks for it. Login, sign-up and reset give the same
  response for known and unknown accounts (no user enumeration). No default or shared accounts
  in production. Changing a password or e-mail address requires the current password; notify
  the user by a second channel about password changes and lockouts. Lockouts slow attackers
  down without letting them lock out arbitrary users.
- **Sessions and tokens**: idle and absolute expiry; issue a new session ID on login and on
  privilege change; revoke sessions and tokens on logout, password change and account removal;
  short-lived access tokens. Never put session tokens in URLs. Decide whether parallel sessions
  are allowed and let users see and end them. "Remember me" uses a separate, revocable token.
- **Password reset**: single-use, random, short-lived tokens stored hashed; the same response for
  known and unknown accounts; existing sessions revoked after a reset; rate-limited.
- **Authorization**: check server-side on every request and every object; deny by default.
  Multi-tenant data is filtered by tenant in the query, not after loading. Every route has an
  explicit access rule, including ones only an admin page links to (missing authorization).
  Tests: for each protected operation, negative tests prove that user A cannot read or change
  user B's object, that tenant A cannot reach tenant B's data (IDOR), and that a normal user
  cannot call admin operations (vertical privilege escalation).
- **Rate and resource limits**: limit login, reset and other expensive operations per client and
  per account; cap request body size, page size, query cost, upload size and processing time.
  Anti-automation (rate limits, CAPTCHA) where bots can abuse a feature (sign-up, contact forms).
  Escape `%` and `_` in user input used in SQL `LIKE` so wildcards cannot force full scans.
- **Business logic**: enforce workflow order and limits on the server (no skipping steps, no
  negative quantities, no replaying one-time actions); use transactions or locks against races.
  Separate duties where one person must not both request and approve (payments, permissions).
  Keep an audit trail of security-relevant actions that users cannot alter (non-repudiation).
- **Secrets**: only from environment/secret store; never in code, logs, URLs, or git.
  `.env` is gitignored; keep `.env.example` with fake values. Anything shipped to a client
  (JavaScript bundles, mobile apps, HTML comments) is public: no secrets there.
- **Crypto**: no home-made crypto; TLS everywhere; modern algorithms; secure random for tokens
  (`secrets` in Python, `crypto.randomBytes`/`crypto.randomUUID` in Node, never `random` or
  `Math.random`). Encrypt sensitive data at rest where the threat model asks for it.
- **Files and uploads**: enforce a size limit before reading the whole file; limit file count and
  upload frequency per user; check content, not the extension or client-supplied type; generate
  server-side names; store outside the web root; apply the same authorization to downloads as to
  the data they belong to. Scan for malware where users share files with each other.
- **Paths and archives**: resolve paths and verify they stay inside the intended base directory;
  do not follow symbolic links from untrusted sources. Never load templates, modules or code by
  a name or URL taken from input (local/remote file inclusion). When extracting archives, reject absolute
  paths, `..` segments, symbolic and hard links, and cap total size and file count (zip bombs).
- **Outbound requests (SSRF)**: allow-list destinations where possible. Otherwise resolve the host,
  reject loopback, private, link-local and cloud-metadata addresses (`127.0.0.0/8`, `10.0.0.0/8`,
  `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`, `::1`, `fc00::/7`, `fe80::/10`), and connect
  to the address you checked so DNS rebinding cannot swap it. Disable redirects or re-check every
  hop. Set timeouts and response size limits.
- **Errors and logging**: generic messages to users; details to logs; log security events
  (logins, permission denials, admin actions) without passwords, tokens or personal data.
- **Data retention**: collect the minimum; define how long each sensitive data type is kept
  (see the threat model); deletion covers copies, caches, exports and derived data; backups
  expire on a schedule.
- **Config**: debug off in production, least privilege for services and tokens. No test data or
  test accounts in production, and no production data in test environments.
- **Payments**: use a payment provider's hosted fields or checkout so card data never touches
  your servers; otherwise PCI DSS applies — ask the user before going there.

## Dependencies

- **Adding**: ask the user first (AGENTS.md §6). Prefer widely used, maintained packages; check
  the license, maintainer activity, download count and whether it runs install scripts
  (`postinstall`, `setup.py` code). Keep the set minimal.
- **Does it exist? (slopsquatting)**: assistants sometimes invent plausible package names, and
  attackers register them with malware. Before proposing a package, look up the exact name in the
  official registry (pypi.org, npmjs.com, …) and report its source repository, maintainers, age,
  downloads and last release. A package that is days or weeks old, barely downloaded, or one
  character away from a popular name is suspicious: say so and do not install it. Verify install
  commands copied from docs, issues or generated text the same way.
- **Lockfiles**: commit the lockfile (`package-lock.json`, `uv.lock`/`poetry.lock` or pinned
  `requirements*.txt`); install from it in CI (`npm ci`). Never edit it by hand.
- **Licenses**: record the allowed licenses for this project in `docs/decisions/`; ask before
  adding a copyleft (GPL, AGPL) or unknown license to software you distribute.
- **Updates**: apply security fixes promptly; review other updates at least monthly; read the
  changelog of major versions before upgrading; one dependency per commit when practical.
- **Audit**: `scripts/check.sh` runs the stack's audit tool. A known vulnerability that cannot be
  fixed yet is recorded in `docs/security-exceptions.md` with owner, reason and expiry; never
  silence the audit without such an entry.
- **Supply chain (optional)**: when you ship artifacts to others, consider a software bill of
  materials (SBOM, e.g. CycloneDX or SPDX) and build provenance. Ask the user before adding tools.

## Web applications *(web)*

- **Output**: context-aware encoding (HTML, JS, URL) against reflected, stored and DOM-based XSS;
  set a Content-Security-Policy and the usual security headers (`X-Content-Type-Options`,
  `Referrer-Policy`, `frame-ancestors` or `X-Frame-Options` against clickjacking).
- **Transport**: HTTPS only, HTTP redirects to HTTPS, `Strict-Transport-Security` set; credentials
  and session tokens never travel over plain HTTP.
- **Cookies**: `Secure`, `HttpOnly`, `SameSite`; prefer the `__Host-` prefix for session cookies
  (it forbids a `Domain` attribute and requires `Path=/`); otherwise keep `Domain` and `Path` as
  narrow as possible.
- **Redirects**: redirect only to relative paths or an allow-list of hosts; never to a URL taken
  unchecked from the request (open redirect).
- **Exposure**: the web server serves only the build output: no `.git/`, backups, `.env`, source
  maps you do not want public, or editor files (`.DS_Store`, `*.swp`). Admin interfaces are not
  reachable from the internet unless needed. Allow only the HTTP methods a route uses.
  Behind a proxy or load balancer, keep both on maintained versions and reject ambiguous
  requests (both `Content-Length` and `Transfer-Encoding`) to prevent request smuggling.
- **Uploads**: serve user-uploaded files from a separate origin or with
  `Content-Disposition: attachment` so they cannot run script in your origin.
- **Browser APIs**: check `event.origin` on every `postMessage` handler and name the target origin
  when sending; no tokens or personal data in `localStorage`/`sessionStorage`.
- **CSRF**: when the browser sends credentials automatically (cookies, HTTP auth), protect every
  state-changing request with a CSRF token or a strict `Origin`/`Sec-Fetch-Site` check.
  `SameSite` cookies are defence in depth, not a replacement: they do not stop same-site attacks
  from sibling subdomains and depend on browser behaviour. Never change state on `GET`.
  APIs that only accept tokens from an `Authorization` header are not exposed to CSRF.
- **CORS**: narrow allowed origins; never reflect an arbitrary `Origin` together with credentials.

Run a security review (`/xaden-security` in Claude Code, or `prompts/security-review.md`)
after each feature touching the above and before every release.
