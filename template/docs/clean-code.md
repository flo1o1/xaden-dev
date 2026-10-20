# Clean code rules

Rule IDs (CC-nn) are defined in AGENTS.md section 3; this file explains them.

Goal: code anyone on the team understands quickly. Understandability buys
changeability and keeps the cost of change low. Apply the rules in proportion to the
code: a 20-line script needs less structure than a service with many contributors.

## Design (CC-01, CC-04)
- Single Responsibility: one reason to change per unit. Keep things that change together
  in one module (cohesion); keep unrelated things apart.
- Dependency direction: core logic does not import I/O, frameworks or the clock; adapters at
  the edge depend on the core, not the other way round.
- Side effects are visible: a function that writes files, sends requests or mutates shared
  state says so in its name or signature. No side effects behind a getter.
- Inject dependencies through constructors/parameters; no globals or hidden singletons.
- Abstractions earn their place: add an interface or wrapper when there are two real
  implementations, a test needs a seam, or a boundary needs a contract. Not to satisfy SOLID
  vocabulary.
- Composition root: one place (the entry point) builds the objects and wires them together; only
  it touches globals such as environment, clock, OS or browser APIs. Everything else receives them.
- A unit either does work (an algorithm) or coordinates other units, not both.
- Behaviour that varies by type or mode lives in polymorphic objects (strategies), not in the
  same `switch`/`if` chain repeated in several places.
- Make order dependencies visible: if B needs A first, let A return what B needs instead of
  relying on call order (hidden temporal coupling).
- Talk to direct collaborators only (Law of Demeter): avoid chains like `a.b().c().d()`.
- Symmetric operations look symmetric (load/save, open/close, encode/decode).
- Size heuristics for review (presets enforce function limits): a class beyond ~100 lines or a
  function beyond ~30 lines usually does more than one thing.
- Keep constructors simple. Prefer composition over inheritance.

## Naming (CC-02)
- Name says *what/why*, not *how*. Pronounceable, searchable, no encodings.
- Same concept → same word everywhere. Booleans read as predicates (`is_valid`).
- Name length follows scope: short names in a three-line loop, descriptive names for anything
  that lives long or travels far. Names match the abstraction level of their unit.
- Replace magic numbers/strings with named constants.

## Functions (CC-01, CC-03)
- Small; do one thing; one abstraction level; ≤ 3 parameters ideally.
- No flag arguments, no output parameters.
- Early returns instead of deep nesting.
- Wrap complex conditions in a well-named function (`if should_delete(timer)`); prefer positive
  conditions over negated ones.
- Declare variables close to their first use (vertical separation).

## Duplication (CC-03)
- DRY is about knowledge, not text: two places that must change together are duplication.
- Code that looks alike but serves different concepts may stay separate; merging it couples
  things that will diverge.
- Extract when the shared concept is clear (often on the third occurrence), not on the first
  resemblance.

## Errors and input (CC-05, CC-07)
- Use the language's idiom: exceptions (Python, Java, JS), result types (Rust, Go errors,
  typed `Result` objects) or option types. Whatever the form, failures are explicit,
  specific and handled deliberately.
- Fail fast. Never return `null`/`None` or a magic value to signal failure.
- Never swallow errors; log once at the boundary, with context but no secrets.
- Validate all external input at the system boundary: type, range, length, format.

## Comments (CC-06)
- Document public classes/functions and anything non-obvious: purpose, parameters and data
  formats, contracts at module boundaries, invariants, errors, surprising behaviour.
- Skip docstrings that only restate the name of a small private helper.
- Explain *why*, never *what*. Delete dead code (git remembers).
- Warnings earn a comment: thread safety, performance traps, security consequences.
- A wrong comment is worse than none: update or delete comments in the same change as the code.
- One language for code, comments and commit messages; English unless the project records
  another choice in `docs/decisions/`.

## Smells to refuse (CC-03)
Duplicated knowledge · long methods · god classes · long parameter lists · feature envy ·
primitive obsession · divergent change (one class changes for many reasons) · shotgun surgery
(one change touches many classes) · speculative generality · dead code · inconsistent naming ·
hidden dependencies between calls · surprising behaviour (least astonishment).

## Refactoring (CC-09)
Refactor with a purpose: when it makes the change at hand easier or safer, or when the user
asks for it. Small steps, tests green after each. Leave code you touch cleaner than found;
do not reorganise code the change does not touch.
- Feature: refactor first only if the feature would otherwise be hard to add.
- Bug fix: regression test first, smallest fix, then refactor if needed.

Techniques that keep the system running between steps:
- Parallel implementation: build the new path next to the old one, switch callers, then delete
  the old path.
- Format changes: read old and new representation for a while, migrate, then remove the old one.
  Stored data follows the migration rules in `docs/architecture.md` (versioned formats, automatic
  migration, no silent data loss).
- Code without tests: first pin current behaviour with characterization or acceptance tests,
  introduce seams at boundaries, then decide per component: refactor, rewrite or keep.

## Tests, FIRST (CC-08)
Fast · Isolated · Repeatable · Self-validating · Timely. Arrange–Act–Assert.
One behaviour per test; test names state the behaviour.
- Tiny steps: little code between red and green.
- Test through the public interface; check results and state rather than which calls were made
  (interaction checks only where the call is the behaviour, e.g. sending an e-mail).
- No `if` or loops that compute expectations inside tests; a test that cannot fail is a defect.
- Long setup or many test doubles mean the unit does too much: split it.
- Flaky tests are bugs; fix the cause (shared state, time, order, network) instead of re-running.
- Test doubles replace what crosses a boundary (I/O, clock, network, randomness). Prefer simple
  hand-written fakes when several tests share them. Assert on the unit, not on the double.
- Pyramid: many unit tests, fewer integration and acceptance tests, few end-to-end tests,
  plus exploratory testing by a human.
- Acceptance criteria become examples (Given / When / Then) and then acceptance tests.
- Parsers, conversions and calculations: add property-based tests (Hypothesis, fast-check) that
  check a rule for many generated inputs, e.g. "decode(encode(x)) == x" or "total never negative".
- Coverage shows what ran, not what was checked. Mutation testing (mutmut, StrykerJS) makes small
  changes to the code and reports those no test notices; use it before releases on risky modules.
  Setup: `docs/optional-tools.md`.

## How each rule is enforced

The rules are instructions to assistants; where a tool can check them, `scripts/check.sh`
does (presets: `xaden project add-preset python|node`). Tools catch size, naming patterns
and obvious error-handling mistakes. Design, cohesion, dependency direction and good names
need human review; no prompt or linter guarantees architectural quality.
Configurations only get stricter without the user's approval; existing violations live in a
baseline that may only shrink (AGENTS.md §5).

| Rule | Python (ruff preset) | JS/TS (ESLint preset) | Otherwise |
|------|----------------------|-----------------------|-----------|
| CC-01 | C901 complexity ≤ 8, PLR0913 args ≤ 4, PLR0912/0915 branches/statements | complexity ≤ 8, max-params 4, max-lines-per-function 40 | review |
| CC-02 | N naming, PLR2004 magic values | camelcase, no-magic-numbers | review |
| CC-03 | ERA commented code, RET/SIM early return, F unused, max-nested-blocks 3 | max-depth 3, no-else-return, no-unused-vars | review |
| CC-04 | — | — | review |
| CC-05 | BLE blind except, TRY, S110 swallowed exceptions | no-empty | review |
| CC-06 | D docstrings for public API (Google style) | — | review |
| CC-07 | S (bandit), local semgrep rules | local semgrep rules | security review |
| CC-08 | pytest must run; `tests/` must exist | `test` script must exist and pass | traceability check |
| CC-09 | — | — | review |

Based on R. C. Martin, *Clean Code*, and K. Beck, *Test-Driven Development by Example*.
