---
id: REQ-061
type: job
epic: assistant-guidance
priority: should
status: done
updated: 2026-10-12
---

# Assistants check solutions against the project's user personas

## Job

When I develop software with an assistant, I want 3 to 5 user personas in the project that the assistant checks every solution against, so I can catch features, texts and flows that fail the real people who will use them before they ship.

## Acceptance criteria

- Given a project, when I run `scripts/persona.sh new "<name>"`, then `docs/personas/<slug>.md` is created from `docs/personas/0000-template.md` with the name and date filled in and every section prefilled with guiding placeholder text.
- Given a persona with that file name already exists, when I create it again, then the script refuses and leaves the file unchanged.
- Given 5 personas already exist, when I create another one, then the file is created and a warning recommends 3 to 5 personas.
- Given Claude Code, when I run `/persona <short description>`, then the assistant creates the file with the script and drafts its content from the description and the project's requirements, marking facts it lacks as assumptions to verify.
- Given AGENTS.md, the kickoff, feature and code-review prompts, when an assistant proposes or reviews a solution, then it checks it against every persona in `docs/personas/` and names the persona a solution fails.
- Given an existing project, when it updates the scaffold, then it receives the persona template, script and prompt, and its own persona files stay untouched.
