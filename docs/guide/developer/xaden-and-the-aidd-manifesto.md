# Xaden and the AI-Driven Development Manifesto

Xaden follows the ideas of the [AI-Driven Development Manifesto](https://ai-driven-development.org) (v1.1.1): a developer works with AI as a deliberate partner and stays accountable for what ships. This page shows, value by value and principle by principle, which Xaden rule implements it and where it falls short. Check the claims yourself: each row names the rule or requirement behind it.

Xaden implements the manifesto as far as the table says. The manifesto is not a certification, Xaden is not affiliated with its authors, and nobody has reviewed this table but the Xaden maintainers.

The full workflow of the manifesto's reference framework is an optional add-on: [use the AIDD framework](use-the-aidd-framework.md).

## Status

| Key | Manifesto item | Status | Xaden rule |
|-----|----------------|--------|------------|
| V1 | Method over Model | met | The same rules and checks for every assistant that can read and write files: `template/AGENTS.md`, REQ-045, REQ-081 |
| V2 | Ownership over Delegation | partly | A human approves and merges every change (REQ-110); a signed-off commit is optional, see "Signed-off-by" below |
| V3 | Understanding over Acceptance | partly | The assistant explains a non-trivial change and one way to check it before you accept it (REQ-111); nothing checks that you understood it |
| V4 | Outcome over Output | partly | Requirements are jobs to be done with acceptance examples (REQ-046); Xaden does not measure results after release |
| P01 | Ship in verified increments | met | Requirement, test, review and a completion report with evidence before "done" (REQ-036, REQ-035) |
| P02 | Start from a clear spec | met | One requirement file per behaviour, with acceptance criteria that become tests (REQ-046, REQ-047) |
| P03 | Plan before generation | partly | A requirement is approved before work starts (REQ-082) and the assistant plans briefly (`template/AGENTS.md`); a written plan is not required |
| P04 | Decompose until delegable | met | The assistant sizes each task as small, normal or large; a large one is split into steps that are each a normal change (REQ-123) |
| P05 | Craft context with care | partly | Rules, prompts and requirements are files under version control, and a context check line shows stale rules (REQ-085); no limit on the size of the always-loaded context, planned |
| P06 | Capture learning for reuse | met | The assistant proposes a decision record for what later work needs (REQ-111) and, with your agreement, records a review finding it does not fix in the deferred work file of the project, with its source and evidence (REQ-125) |
| P07 | Own every shipped change | met | The assistant opens the pull request and stops; the person merges (REQ-110, REQ-112) |
| P08 | Do not delegate what you cannot evaluate | partly | The assistant says what it cannot judge and asks (REQ-111); its security review is a checklist, not proof (REQ-005) |
| P09 | Improve the system before forcing the model | met | Before a retry the assistant names which of scope, names, tests or context it will change (REQ-119) |
| P10 | Rebuild context when coherence drops | partly | The assistant says when a session lost coherence and proposes a fresh one; the files are enough to resume (REQ-120); nothing detects it automatically |
| P11 | Treat AI failure as a signal | met | After a second failed attempt the assistant stops, reports and inspects scope, context, assumptions and tests (REQ-111) |
| P12 | Make the practice transferable | met | One rule file, the same prompts as slash commands in each supported assistant (REQ-045, REQ-055, REQ-081) |

"Planned" means a draft exists that is not yet a requirement, or, where a REQ ID is named, an approved requirement that is not yet implemented.

## Signed-off-by

The manifesto's second value suggests that a human signs every commit. Xaden documents `git commit -s` (`Signed-off-by:`) as optional and neither requires nor generates it: the sign-off says who accepted the commit, and Xaden's rule is that a human merges the pull request.

## Source and license

The titles and wording of the manifesto's values and principles come from the [AI-Driven Development Manifesto](https://ai-driven-development.org), version 1.1.1, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The table, the statuses and the Xaden rules are Xaden's own work. Xaden uses no logo or badge of the manifesto.
