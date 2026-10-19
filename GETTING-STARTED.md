# Getting started

From zero to a released first version. The detailed guides are in [`docs/guide/`](docs/guide/); they are also the source of
the pages on https://xaden.dev. Nothing here assumes a particular person's machine or private skills.

## The short path

1. [Check the requirements](docs/guide/admin/requirements-and-platforms.md): Linux or macOS with git and bash (Windows: WSL).
2. [Install Xaden](docs/guide/admin/install-xaden.md): one command that asks first, checks the signature of the release and installs it.
3. [Create a project](docs/guide/developer/create-a-project.md) with `xaden create my-app`, or [add Xaden to a repository](docs/guide/developer/add-xaden-to-a-repository.md) with `xaden adopt`.
4. [Kick off with your assistant](docs/guide/developer/kick-off-with-your-assistant.md): `xaden prompt kickoff`.
5. [Build features](docs/guide/developer/build-features.md) and [release a version](docs/guide/developer/release-a-version.md).

## Developer guide

- [Create a project](docs/guide/developer/create-a-project.md)
- [Add Xaden to a repository](docs/guide/developer/add-xaden-to-a-repository.md)
- [Check modes and baselines](docs/guide/developer/check-modes-and-baselines.md)
- [What Xaden checks](docs/guide/developer/what-xaden-checks.md)
- [Kick off with your assistant](docs/guide/developer/kick-off-with-your-assistant.md)
- [Build features](docs/guide/developer/build-features.md)
- [Release a version](docs/guide/developer/release-a-version.md)
- [Join a project that uses Xaden](docs/guide/developer/join-a-project.md)
- [Use Xaden with other assistants and local models](template/docs/local-llm.md)

## Admin guide

- [Requirements and platforms](docs/guide/admin/requirements-and-platforms.md)
- [Install Xaden](docs/guide/admin/install-xaden.md)
- [Update Xaden](docs/guide/admin/update-xaden.md)
- [Pin one Xaden version per project](docs/guide/admin/pin-one-version-per-project.md)
- [Verify releases](docs/guide/admin/verify-releases.md)
- [Optional tools and assistant plugins](template/docs/optional-tools.md)
- [Uninstall](docs/guide/admin/uninstall.md)

## Contributing

Working on Xaden itself, not just using it:

- [Install with git](docs/guide/contributing/install-with-git.md)
- [Architecture](docs/guide/contributing/architecture.md)
- [Work on Xaden](docs/guide/contributing/work-on-xaden.md)
- [Release and sign Xaden](docs/guide/contributing/release-and-signing.md)
- [Threat model and requirements](docs/guide/contributing/threat-model-and-requirements.md)

## Security

[How Xaden helps keep a project secure](template/docs/security.md) is the checklist every project follows. Security review quality:
`xaden prompt security-review` follows the OWASP Web Security Testing Guide and works with any model; use a strong model for reviews
before releases.
