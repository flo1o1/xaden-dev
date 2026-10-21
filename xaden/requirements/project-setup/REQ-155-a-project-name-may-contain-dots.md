---
id: REQ-155
type: job
epic: project-setup
priority: should
status: draft
updated: 2026-10-21
paths: scripts/scaffold-lib.sh, scripts/create.sh
---

# A project name may contain dots

## Job

When I create a project that carries a dotted name, like the domain of a website (`xaden project create mywebsite.com`), I want Xaden to accept the name, so I can keep the folder named like I and everyone else name the project.

## Acceptance criteria

- Given `xaden project create mywebsite.com` (with a target directory or without), then the project is created in the folder `mywebsite.com` exactly as a name without dots would be: same layout, first commit, and `README.md`, `SECURITY.md` and `xaden/threat-model.md` carry the name with its dot.
- Given a name whose dots sit between lowercase letters, digits and hyphens (`my-site.dev2`), then it is accepted like any other name.
- Given a name that ends with a dot, holds an empty dot part (`my..website`) or would start with one, then creation is refused with a message that names use lowercase letters, digits, hyphens and dots, and nothing is created; the same limits as before keep holding (starts with a letter, 2-51 characters).
- Given a name with any other character (uppercase letters, spaces, slashes, shell, `sed` or path characters), then it is refused as before, so the threat model's control "project name with shell, `sed` or path characters" keeps holding (row updated to the dots-allowing rule).
