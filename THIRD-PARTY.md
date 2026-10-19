# Third-party tools and works

Xaden is MIT licensed (see `LICENSE`). It runs and recommends the tools below, and its documents build on
the standards and works named at the end. Xaden **bundles none of the tools**: you install them, or the
CI workflow Xaden generates installs them, and Xaden only invokes them as separate programs. Each tool
keeps its own license and its authors' credit. Licenses can differ between versions; the license of the
version you install applies. This list is factual and not legal advice.

`scripts/check-third-party.sh` (part of `scripts/check-scaffold.sh`) fails when a tool named in the
stack files, the presets or the generated CI workflow has no line here with a link and a license.

## Security and review

| Tool | License | Notes |
|------|---------|-------|
| [ShellCheck](https://github.com/koalaman/shellcheck) | GPL-3.0 | Invoked as a separate program, never linked or bundled. Installed by the generated CI workflow. |
| [Gitleaks](https://github.com/gitleaks/gitleaks) | MIT | Secret scan. Installed by the generated CI workflow. |
| [Semgrep](https://github.com/semgrep/semgrep) | LGPL-2.1 | Installed by the generated CI workflow. The registry rules (`p/default`) at [semgrep-rules](https://github.com/semgrep/semgrep-rules) carry the Semgrep Rules License v1.0 ([text](https://semgrep.dev/legal/rules-license)), not LGPL. Xaden's own `.semgrep/rules.yml` is MIT like the rest of Xaden. |
| [actionlint](https://github.com/rhysd/actionlint) | MIT | Optional workflow linter. |
| [zizmor](https://github.com/zizmorcore/zizmor) | MIT | Optional workflow security audit. |
| [Bandit](https://github.com/PyCQA/bandit) | Apache-2.0 | Python security linter. |
| [pip-audit](https://github.com/pypa/pip-audit) | Apache-2.0 | Python dependency audit. |
| [npm](https://github.com/npm/cli) | Artistic-2.0 | `npm audit` and the npm scripts of the Node stack; ships with Node.js. |

## Python

| Tool | License | Notes |
|------|---------|-------|
| [Ruff](https://github.com/astral-sh/ruff) | MIT | Lint and format. |
| [mypy](https://github.com/python/mypy) | MIT | Type check. |
| [pytest](https://github.com/pytest-dev/pytest) | MIT | Tests. |

## JavaScript and TypeScript

| Tool | License | Notes |
|------|---------|-------|
| [ESLint](https://github.com/eslint/eslint) | MIT | Packages `eslint` and `@eslint/js`. |
| [typescript-eslint](https://github.com/typescript-eslint/typescript-eslint) | MIT | |
| [TypeScript](https://github.com/microsoft/TypeScript) | Apache-2.0 | |

## GitHub Actions in the generated workflow

| Action | License | Notes |
|--------|---------|-------|
| [actions/checkout](https://github.com/actions/checkout) | MIT | |
| [actions/setup-python](https://github.com/actions/setup-python) | MIT | |
| [actions/setup-node](https://github.com/actions/setup-node) | MIT | |

## Optional tips (`TIP:` lines, never installed by Xaden)

| Tool | License | Notes |
|------|---------|-------|
| [jscpd](https://github.com/kucherenko/jscpd) | MIT | Duplication. |
| [Vulture](https://github.com/jendrikseipp/vulture) | MIT | Dead code (Python). |
| [Hypothesis](https://github.com/HypothesisWorks/hypothesis) | MPL-2.0 | Property-based tests (Python). |
| [mutmut](https://github.com/boxed/mutmut) | BSD-3-Clause | Mutation tests (Python). |
| [Knip](https://github.com/webpro-nl/knip) | ISC | Unused files and exports (Node). |
| [fast-check](https://github.com/dubzzz/fast-check) | MIT | Property-based tests (Node). |
| [StrykerJS](https://github.com/stryker-mutator/stryker-js) | Apache-2.0 | Mutation tests (Node). |

## Assistant plugins recommended in `template/docs/optional-tools.md`

Never installed by Xaden; the user decides. Each plugin keeps its own license.

| Plugin | License | Notes |
|--------|---------|-------|
| [Trail of Bits skills](https://github.com/trailofbits/skills) | CC-BY-SA-4.0 | |
| [Ponytail](https://github.com/DietrichGebert/ponytail) | MIT | |
| [Caveman](https://github.com/JuliusBrussee/caveman) | Apache-2.0 | |
| [Token Optimizer](https://github.com/alexgreensh/token-optimizer) | PolyForm Noncommercial 1.0.0 plus a small-business permission | Not open source; read its license before use. |
| [claude-mem](https://github.com/thedotmack/claude-mem) | Apache-2.0 | |
| [impeccable](https://github.com/pbakaus/impeccable) | Apache-2.0 | |
| [obsidian-skills](https://github.com/kepano/obsidian-skills) | MIT | |
| [Anthropic plugins](https://github.com/anthropics/claude-plugins-official) | Apache-2.0 (repository) | `code-review`, `security-guidance`, `pr-review-toolkit`; a plugin in it can carry its own license. |

## Standards and works the documents build on

| Work | License | Notes |
|------|---------|-------|
| [OWASP WSTG](https://github.com/OWASP/wstg) | CC BY-SA 4.0 | Xaden names categories and copies no text. |
| [OWASP ASVS](https://github.com/OWASP/ASVS) | CC BY-SA 4.0 | Xaden names levels and copies no text. |
| [OWASP Top 10](https://github.com/OWASP/Top10) | CC BY-SA 4.0 | Xaden names categories and copies no text. |
| [Conventional Commits](https://github.com/conventional-commits/conventionalcommits.org) | MIT | |
| [Keep a Changelog](https://github.com/olivierlacan/keep-a-changelog) | MIT | |
| [Semantic Versioning](https://semver.org) | CC BY 3.0 | |
| [AI-Driven Development manifesto](https://ai-driven-development.org) v1.1.1 | CC BY 4.0 | Xaden's rules map to its principles. Xaden is not certified by it and uses no badge or logo. |

## Assistants

Claude Code, Codex, Cursor, Copilot and other assistants, and their names, belong to their owners. Xaden
says "works with" and nothing more.
