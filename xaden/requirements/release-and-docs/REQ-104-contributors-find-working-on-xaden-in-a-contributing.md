---
id: REQ-104
type: job
epic: release-and-docs
priority: should
status: done
updated: 2026-10-19
---

# Contributors find working on Xaden in a Contributing section, apart from using it

## Job

When I want to contribute to or maintain Xaden, I want one Contributing section next to the guides with installing from git, the architecture, the maintainer workflow, releasing and signing, and the threat model and requirements, so I can find it without reading the guides for people who only use Xaden.

## Acceptance criteria

- Given `docs/guide/contributing/`, then it holds the pages `install-with-git.md`, `architecture.md`, `work-on-xaden.md`, `release-and-signing.md` and `threat-model-and-requirements.md`, and each is listed in `docs/site-pages.txt`
- Given `docs/guide/admin/install-xaden.md`, then it has no section about installing with git and none about downloading, verifying and extracting the zip by hand; it does not mention the clone
- Given `docs/guide/admin/update-xaden.md`, `docs/guide/admin/uninstall.md` and `docs/guide/admin/install-xaden.md`, then none describes or links to installing with git, because a clone is for maintainers and not a supported way to use Xaden; the clone steps live only in `docs/guide/contributing/install-with-git.md`
- Given the guides, `GETTING-STARTED.md` and the scripts' messages, then none describes downloading and extracting the release zip by hand as a way to install; the zip is named only as the file the installer downloads and verifies
- Given the contributing pages, then each is made from files of this repository (README, AGENTS.md, `docs/release-signing.md`, `docs/threat-model.md`, `docs/requirements/`), names no path of a maintainer's machine, and links to the full file on GitHub where it only summarises
- Given `docs/guide/developer/release-a-version.md` and `join-a-project.md`, then they stay in the developer guide, because they serve people who use Xaden in their own projects
