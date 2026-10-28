---
id: REQ-162
type: job
epic: assistant-guidance
priority: should
status: approved
updated: 2026-10-28
---

# A prompt printed in a terminal says what to do with it and offers to start my assistant

## Job

When I run `xaden prompt <name>` in a terminal and do not know what the output is for, I want Xaden to say what to do with it and offer to start my AI assistant with it, so I can begin without copying text around.

## Acceptance criteria

- Given `xaden prompt <name>` with output that is not a terminal (a pipe or a file), then it prints the prompt text and nothing else, as before
- Given `xaden prompt <name>` in a terminal, then it prints the prompt text and, on stderr, a short note that the text is an instruction for an AI assistant, not for me, with the two ways to use it: `xaden prompt <name> --run` and copying the text into the assistant
- Given `xaden prompt <name> --run [assistant]` or the answer yes to the question `Run it in <assistant> now? [Y/n]`, then Xaden starts that assistant with the prompt as its first message; the prompt text never reaches the assistant as an option
- Given several assistants, then the choice comes from `assistants` in `xaden/xaden.conf`, else from the programs found on the PATH; with more than one candidate Xaden asks which, with exactly one it asks `[Y/n]`, with none it keeps to the note
- Given an assistant Xaden cannot start with a prompt (Copilot, Vibe, a chat window), then it is never started and the note says to copy the text
- Given no terminal, then Xaden never starts an assistant and never asks
- Given the `kickoff` prompt and an idea that is still the placeholder `{{...}}`, then the assistant asks me for the idea first
- Given `xaden project create` and the README of the new project, then each says in one line what to do after `xaden prompt kickoff`
- Given the user guide, then it documents the note, `--run` and the choice of the assistant
- Given the smoke test, then it covers piped output unchanged, the note in a terminal, the choice with two assistants, no start without a terminal, and a prompt starting with `-` passed as text

## Notes

Reported by the maintainer on 2026-10-28 after a new project: `xaden prompt kickoff` printed the template, with no hint that an assistant is meant to run it and with the idea left as `{{describe ...}}`.

Out of scope: a wizard with questions of Xaden's own (the assistant interviews me, as the kickoff prompt already says), and launching Copilot, Vibe or a chat UI. How `claude` and `codex` take a first message is checked against `--help` when this is built.
