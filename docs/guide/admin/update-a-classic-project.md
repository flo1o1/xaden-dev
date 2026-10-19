# Update a classic project

Bring a project created with `xaden create --classic` to a newer Xaden. Such a project keeps its own copy of the scripts, prompts and guides.
A project with an `xaden/` folder pins its version instead; see [Pin one Xaden version per project](pin-one-version-per-project.md). To move a
classic project to that layout, run `xaden adopt` in it ([details](../developer/add-xaden-to-a-repository.md)).

## Update

```bash
git -C ~/.xaden pull
xaden update
xaden update --apply
```

- `git -C ~/.xaden pull`: gets the newest Xaden (with the one-command install it is `xaden upgrade`; see [Update Xaden](update-xaden.md)).
- `xaden update`: run inside the project, it is a dry run that lists what would change.
- `xaden update --apply`: stages the changes. Review them with `git diff --cached`, merge any `*-dist` files it reports, then commit `chore(scaffold): update to vX.Y.Z`.

Only files Xaden manages (scripts, prompts, presets, rules, commands, Claude Code permissions in `.claude/settings.json`) are updated.
Your code, requirements, guides, README and changelog are never touched, and your local edits are never overwritten: where you and Xaden both
changed a file, the new version is written next to yours as `<file>-dist`. Projects updated before that name existed may still hold `*.scaffold-new` files; `xaden doctor` names both kinds. Each project records its version in `.scaffold/`.

## Update from before 0.6.0: rules folder and short index

`xaden update --apply` adds `docs/rules/` (the rule sections that moved out of `AGENTS.md`) and regenerates `docs/requirements/INDEX.md`
in its short form, with the full table beside it in `INDEX-full.md`; both are staged with the rest. If you edited `AGENTS.md`, your file stays and the
new one comes as `AGENTS.md-dist`: until you merge it, your `AGENTS.md` still holds the old text that `docs/rules/` now repeats.

## A project with an old requirements table

A project that keeps its requirements in one `docs/requirements/REQUIREMENTS.md` table runs `scripts/migrate-requirements.sh` after
updating. It converts every row into a requirement file (job stories are left as `TODO` for you to rewrite), and the checks then accept the
new format.
