# Optional tools and assistant plugins

Extra checks that make code more robust where they fit. None is required. `xaden check`
(full run) prints a `TIP:` line for each one that fits this project and is not adopted yet; tips
never change the result. Once adopted, the check runs it and its findings fail the run like any
other check. Ask the user before installing anything (the rules in AGENTS.md require it).

## Extra quality checks

| Tool | Fits when | Catches | Adopt | `xaden check` then |
|------|-----------|---------|-------|-------------------------|
| [actionlint](https://github.com/rhysd/actionlint) | `.github/workflows/` exists | Workflow syntax and expression errors before CI runs them | Install the binary | Lints workflow files (also before each commit) |
| [zizmor](https://github.com/zizmorcore/zizmor) | `.github/workflows/` exists | Workflow security problems: template injection, leaked credentials, cache poisoning | Install the binary | Audits workflow files offline (also before each commit) |
| [jscpd](https://github.com/kucherenko/jscpd) | Source code exists | Copy-pasted code (CC-03) | Install jscpd (global or dev dependency) and add `.jscpd.json` | Fails when duplication exceeds `threshold` |
| [vulture](https://github.com/jendrikseipp/vulture) | Python | Unused functions, classes, variables, imports | Add to `requirements-dev.txt`; add `[tool.vulture]` to `pyproject.toml` | Runs `vulture` with that configuration |
| [knip](https://knip.dev) | Node | Unused files, exports and dependencies | `npm install --save-dev knip`; `npm pkg set scripts.deadcode=knip` | Runs `npm run deadcode` |
| [Hypothesis](https://hypothesis.readthedocs.io) | Python | Edge cases example tests miss (property-based tests) | Add to `requirements-dev.txt`; write property tests | Runs them with the other tests |
| [fast-check](https://fast-check.dev) | Node | Same, for JavaScript and TypeScript | `npm install --save-dev fast-check` | Runs them with the other tests |
| [mutmut](https://github.com/boxed/mutmut) | Python | Tests that run code but check too little (mutation testing) | Add to `requirements-dev.txt` | Nothing (slow): run `mutmut run` before releases |
| [StrykerJS](https://stryker-mutator.io) | Node | Same, for JavaScript and TypeScript | `npm init stryker` | Nothing (slow): run `npx stryker run` before releases |

Starting configurations (adjust paths to the project):

```toml
# pyproject.toml
[tool.vulture]
paths = ["src", "tests"]
min_confidence = 80
```

```json
{ "threshold": 5, "ignore": ["**/node_modules/**", "**/.venv/**"] }
```

The second block is `.jscpd.json`: the run fails when more than 5 % of the code is duplicated.
Lower the threshold as duplication goes down; raising it needs the user's approval (AGENTS.md §5).
False positives of vulture go into a whitelist file (`vulture --make-whitelist`) listed in `paths`.

When to use which test technique: `docs/clean-code.md` → Tests.

## Assistant plugins (Claude Code)

Public plugins that add depth to reviews. They are optional, and this project's `AGENTS.md`
takes precedence over them (§10). Install from the named sources only.

| Plugin | Adds | Install |
|--------|------|---------|
| Anthropic `code-review`, `security-guidance`, `pr-review-toolkit` | Parallel review agents for logic and edge cases; security review of diffs | `/plugin install code-review@claude-plugins-official` (same for the others) |
| [Trail of Bits](https://github.com/trailofbits/skills) | Security analysis by an audit firm: CodeQL and semgrep workflows, SARIF parsing, GitHub Actions auditing | `/plugin marketplace add trailofbits/skills`, then pick plugins in `/plugin` |
| [Ponytail](https://github.com/DietrichGebert/ponytail) | Smallest complete change: reuse before writing, one test for risky logic | `/plugin marketplace add DietrichGebert/ponytail`, then `/plugin install ponytail@ponytail` |
| [Caveman](https://github.com/JuliusBrussee/caveman) | Shorter replies, fewer output tokens; code, commits and project files stay in normal prose | `/plugin marketplace add JuliusBrussee/caveman`, then `/plugin install caveman@caveman` |
| [Token Optimizer](https://github.com/alexgreensh/token-optimizer) | Smaller context: compresses command, search and tool output; context audits. License: PolyForm Noncommercial (small-business permission), not open source | `/plugin marketplace add alexgreensh/token-optimizer`, then `/plugin install token-optimizer@alexgreensh-token-optimizer` |
| [claude-mem](https://github.com/thedotmack/claude-mem) | Memory of past sessions: records sessions, compresses them with a model and adds relevant memories to new ones. License: Apache-2.0 | `/plugin marketplace add thedotmack/claude-mem`, then `/plugin install claude-mem` |
| [impeccable](https://github.com/pbakaus/impeccable) | For a web UI: design guidance, critique and 59 deterministic checks for AI-generated frontend design (`npx impeccable detect` runs them without a model). License: Apache-2.0 | `/plugin marketplace add pbakaus/impeccable`, then `/plugin install impeccable@impeccable` |
| [obsidian-skills](https://github.com/kepano/obsidian-skills) | Obsidian Flavored Markdown, Bases, JSON Canvas and the Obsidian CLI, for editing the prompt library in `prompts/` (an Obsidian vault). License: MIT | `/plugin marketplace add kepano/obsidian-skills`, then `/plugin install obsidian@obsidian-skills` |
| [AI-Driven Dev framework](https://github.com/ai-driven-dev/framework) | The full AI-Driven Development workflow: skills and agents from spec to review, next to Xaden's rules and checks. Needs Node 22.12 or later. License: MIT | `xaden aidd enable` (pinned version; asks before it downloads) |

Before installing one, read its notes:

- **Ponytail**: its hooks need `node` on your PATH. Other tools (Codex, Copilot CLI, Cursor):
  follow the project's `INSTALL.md`; tools that only read a rules file can use its `AGENTS.md`.
  Do not replace this project's `AGENTS.md` with it. Sources: `DietrichGebert/ponytail` on GitHub,
  `@dietrichgebert/ponytail` on npm.
- **Caveman**: its hooks need `node` on your PATH; other tools follow its `INSTALL.md`. It switches
  back to full sentences for security warnings and irreversible actions.
  Keep project files in normal prose: do not run its `/caveman-compress` on `AGENTS.md`,
  `CLAUDE.md`, requirements or guides, and do not commit the always-on rule files
  `/caveman-init` writes.
- **Token Optimizer**: run `/token-optimizer` once after installing to set up its hooks. License:
  PolyForm Noncommercial 1.0.0 plus a written small-business permission (fewer than 5 people and
  under $20k monthly revenue, counted for the whole company); other commercial use needs a paid
  license, so check that your use qualifies. It keeps full tool output on disk in your home
  directory (private file permissions; credentials removed by pattern only), so never print
  secrets in a session.
- **Output compression** (Caveman, Token Optimizer): compressed output is a summary. A completion
  report must quote failing lines from the full output (rerun the check or expand the archived
  result). Use one output-compression plugin at a time.
- **claude-mem**: other tools install with `npx claude-mem install --ide <tool>`. It installs Bun
  and uv if missing, runs a local worker service and stores sessions in `~/.claude-mem`, so never
  print secrets in a session (use its `<private>` tags for sensitive text). Its installer offers a
  hosted memory service (the claude-mem observer, sign-in required) that receives session content:
  choose your Anthropic plan or your own model key when code must not leave your assistant's
  provider, or set `CLAUDE_MEM_ONLINE_OPTIN=false`. Its memories are context: requirements and
  rules are still looked up in the files (`AGENTS.md` §0).
- **obsidian-skills**: Codex, OpenCode and others follow its README. Use Obsidian syntax in
  `prompts/` only; `AGENTS.md`, requirements and guides
  stay plain Markdown, because other assistants and the check scripts read them. Web pages its `defuddle` part extracts are
  untrusted content (`AGENTS.md` §10).
- **impeccable**: other tools install with `npx impeccable install`. It runs a binary engine
  that is downloaded once to `~/.impeccable/bin/`. Both routes add an assistant hook that checks
  UI files after each edit; the project install writes it into the project's tool folders
  (`.claude/` and others), so committing them gives it to every contributor. Skip it with
  `npx impeccable install --no-hooks`. Starting a new design always asks impeccable.style for
  design options and by default records which one was chosen (anonymous; no project files or
  code). Opt out per machine with `DO_NOT_TRACK=1`, or for everyone with `"telemetry": false`
  in `.impeccable/config.json`. Its findings are suggestions; this project's checks decide.

Not recommended: frameworks that bring their own complete workflow (for example Superpowers,
with its own brainstorm, plan, TDD and review phases). They duplicate the workflow in
`AGENTS.md` and `prompts/`, and two workflows give the assistant conflicting instructions.
