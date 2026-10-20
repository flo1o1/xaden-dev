# shellcheck shell=bash
# shellcheck disable=SC2016 # bash -c programs are single-quoted on purpose
# Helpers and fixtures shared by the smoke areas adoption-setup, adoption-versions and adoption-checks (REQ-121).
# Sourced by each of them, not an area itself: tests/smoke.sh leaves it out of AREAS.

# Sourced once however many areas run.
[ -z "${ADOPTION_LIB_LOADED:-}" ] || return 0
ADOPTION_LIB_LOADED=1

# message_of <function> <args...>: what a lib.sh message helper prints on both streams.
message_of() { bash -c 'source "$1"; shift; "$@"' _ "$SCAFFOLD_ROOT/template/scripts/lib.sh" "$@" 2>&1 || true; }

XADEN="$SCAFFOLD_ROOT/scripts/xaden.sh"
# The git hooks of the fixtures call `xaden`: it must be this checkout's command, not one installed on the machine.
mkdir -p "$WORKDIR/bin" && ln -sf "$XADEN" "$WORKDIR/bin/xaden"
export PATH="$WORKDIR/bin:$PATH"
XOUT="$WORKDIR/xaden.out"
XRC=0

# x_in <dir> <args...>: runs the xaden command in a directory; output in $XOUT, status in $XRC.
# shellcheck disable=SC2034 # XRC is read by the areas
x_in() {
  local dir=$1
  shift
  XRC=0
  (cd "$dir" && env -u CI "$XADEN" "$@") >"$XOUT" 2>&1 || XRC=$? # CI=true would make the scope of a check unknown (REQ-102)
}

# x_answers <answer> <dir> <args...>: like x_in, with a test answer for every question.
x_answers() {
  local answer=$1
  shift
  XADEN_TEST_MODE=1 XADEN_TEST_ANSWER=$answer x_in "$@"
}

# make_repo <dir> <kind>: a repository with history. Kinds: shop (npm test, make lint, CI, an
# AGENTS.md that contradicts the rules), bare-python (no tests or linters), unittest-python, husky, empty.
make_repo() {
  local dir=$1 kind=$2
  rm -rf "$dir" && mkdir -p "$dir"
  git -C "$dir" init -q -b main
  case "$kind" in
    empty) return 0 ;;
    shop)
      mkdir -p "$dir/.github/workflows" "$dir/docs" "$dir/scripts"
      printf '{ "name": "shop", "scripts": { "test": "node --test" } }\n' >"$dir/package.json"
      printf 'lint:\n\techo lint\n' >"$dir/Makefile"
      printf '# Shop\n' >"$dir/README.md"
      printf '# Changelog\n' >"$dir/CHANGELOG.md"
      printf 'guide\n' >"$dir/docs/guide.md"
      printf 'name: ci\non: push\njobs:\n  build:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo hi\n' >"$dir/.github/workflows/ci.yml"
      printf '#!/bin/sh\necho $1\n' >"$dir/scripts/build.sh" # an unquoted variable: shellcheck SC2086
      printf '# Rules\n- Skip tests when in a hurry.\n- Never skip the linter.\n' >"$dir/AGENTS.md" ;;
    bare-python)
      printf '[project]\nname = "bare"\n' >"$dir/pyproject.toml"
      printf 'print(1)\n' >"$dir/app.py"
      printf '# Bare\n' >"$dir/README.md" ;;
    unittest-python)
      mkdir -p "$dir/tests"
      printf '[project]\nname = "ut"\n' >"$dir/pyproject.toml"
      printf 'def one():\n    return 1\n' >"$dir/app.py"
      printf 'import unittest\n\nimport app\n\n\nclass T(unittest.TestCase):\n    def test_one(self):\n        self.assertEqual(app.one(), 1)\n' >"$dir/tests/test_app.py"
      printf '# Ut\n' >"$dir/README.md" ;;
    pre-commit | lefthook)
      printf '{ "name": "m", "scripts": { "test": "node --test", "lint": "echo lint" } }\n' >"$dir/package.json"
      if [ "$kind" = pre-commit ]; then printf 'repos: []\n' >"$dir/.pre-commit-config.yaml"; else printf 'pre-commit:\n  commands: {}\n' >"$dir/lefthook.yml"; fi
      printf '# M\n' >"$dir/README.md" ;;
    husky)
      mkdir -p "$dir/.husky"
      printf '{ "name": "h", "scripts": { "test": "node --test", "lint": "echo lint" } }\n' >"$dir/package.json"
      printf '#!/usr/bin/env sh\nnpm run lint\n' >"$dir/.husky/pre-commit"
      printf '# H\n' >"$dir/README.md" ;;
  esac
  git -C "$dir" add -A
  git -C "$dir" commit -q -m "initial"
  git -C "$dir" commit -q --allow-empty -m "feat: second"
}

# adopted_copy <name>: an adopted shop in the work folder; prints the worktree with the adoption.
adopted_copy() {
  local repo="$WORKDIR/repos/$1"
  make_repo "$repo" shop
  x_in "$repo" project adopt --yes --assistants claude,copilot,vibe >/dev/null || true
  printf '%s' "$repo-adopt-xaden"
}

# fake_release <dir> <version>: a release folder with v<version>.tar.gz, built from this working tree.
fake_release() {
  local dir=$1 version=$2 tree="$1/build/xaden-$2"
  rm -rf "$dir" && mkdir -p "$tree"
  git -C "$SCAFFOLD_ROOT" ls-files -z | (cd "$SCAFFOLD_ROOT" && xargs -0 tar cf - 2>/dev/null) | tar xf - -C "$tree"
  # REQ-080 this version has a prompt more and a prompt less than the one under test
  rm -f "$tree/template/prompts/release.md"
  printf -- '---\ntitle: A new prompt\n---\n' >"$tree/template/prompts/newthing.md"
  printf '%s\n' "$version" >"$tree/VERSION"
  printf '## [%s] - 2099-01-01\n\n### Added\n- Something new in %s.\n\n' "$version" "$version" >"$WORKDIR/entry.md"
  { sed -n '1,/^## \[Unreleased\]/p' "$tree/CHANGELOG.md"; printf '\n'; cat "$WORKDIR/entry.md"; sed '1,/^## \[Unreleased\]/d' "$tree/CHANGELOG.md"; } >"$tree/CHANGELOG.md.new"
  mv "$tree/CHANGELOG.md.new" "$tree/CHANGELOG.md"
  tar czf "$dir/v$version.tar.gz" -C "$dir/build" "xaden-$version"
}

# stub_tool <dir> <name> <output>: a fake command that prints the output (npm, pip).
stub_tool() {
  mkdir -p "$1"
  printf '#!/bin/sh\nprintf "%%s\\n" "%s"\nexit 1\n' "$3" >"$1/$2"
  chmod +x "$1/$2"
}
