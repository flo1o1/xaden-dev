# Threat model and requirements

What Xaden protects, what it accepts as a risk, and where its requirements live. The full documents are in the repository; this page summarises them.

## What Xaden is, for the threat model

Bash scripts and Markdown files. Maintainers and users run the scripts on their own machines (Linux, macOS) to generate projects, update them and check them. The same scripts run in
GitHub Actions for Xaden and for every generated project. There is no server, no network service and no stored user data.

## What is protected

- **Integrity of generated projects:** only reviewed template content, and hooks that really check.
- **Users' machines and CI runners:** the scripts run with the user's rights on every commit.
- **Secrets near Xaden or a project** (`.env`, keys) must never be copied or committed.
- **Trust in the gates:** a green check, a valid `Refs:` trailer and a release tag mean what they say.

Xaden stores no sensitive data. Its scripts read git metadata (author names and emails in commits) and may meet secrets in the working tree (`.env`, `inbox/`), which they must not copy, commit or print.

## Accepted risks

- `xaden check` and the hooks run the commands listed in `xaden/xaden.conf`, with the same trust as running the repository's own test and lint scripts. A pull request that changes `xaden.conf` needs the same review as one that changes a build script. The adoption pull request and every `xaden pin` show the change.
- A release without a signature, or while `release-signers` holds no key, is pinned by the checksum of the archive just downloaded (trust on first use). The person sees the checksum and the team reviews it in the pull request. A stolen signing key, or a maintainer who signs something malicious, is not covered.
- `xaden setup`, `check`, `req` and `release` run the current repository's own `scripts/*.sh`, with the same trust as running them by hand. Use them only in projects you trust.
- `xaden update` changes a project's Claude Code permissions (`.claude/settings.json`) only when the project left the file unchanged; edited files are kept.
- The macOS CI job installs the current versions of shellcheck, semgrep, ruff and gitleaks without pinning; the Linux job is the pinned reference. semgrep and ruff are pinned by version, not by hash.

## The full documents

- The threat model lists every entry point, trust boundary and abuse case with the control and the test that covers it: `docs/threat-model.md` in the [`docs` folder](https://github.com/flo1o1/xaden-dev/tree/main/docs). Update it when a change adds an entry point, a downloaded tool or a new place the scripts write to.
- Xaden's own requirements are one file per requirement in epic folders: [`docs/requirements/`](https://github.com/flo1o1/xaden-dev/tree/main/docs/requirements), with an index in `INDEX.md`. Functional requirements are jobs to be done ("When ..., I want to ..., so I can ..."), quality requirements are measurable goals. Look one up with `xaden req show REQ-nnn`.
- Security reviews of releases are recorded in [`docs/security-reviews/`](https://github.com/flo1o1/xaden-dev/tree/main/docs/security-reviews).
