#!/usr/bin/env bash
# Scaffold-level helpers shared by create.sh, fetch.sh, the adopt scripts and xaden.sh. Source it.
# Requires template/scripts/lib.sh to be sourced first.

# The two answers every project-scoped command gives when there is no project to act on (REQ-132).
# shellcheck disable=SC2034 # read by xaden.sh, fetch.sh and aidd.sh
NO_REPOSITORY_MESSAGE="run this inside a project (no git repository here); start one with: xaden project create <name>, or adopt an existing repository with: xaden project adopt"
# shellcheck disable=SC2034 # read by xaden.sh, fetch.sh and aidd.sh
NOT_ADOPTED_MESSAGE="this repository has not adopted Xaden; run: xaden project adopt"

# is_project_name <name>: true for a safe directory/package name (lowercase letters, digits,
# hyphens; starts with a letter; 2-51 characters).
is_project_name() { printf '%s' "$1" | grep -Eq '^[a-z][a-z0-9-]{1,50}$'; }

# --- versions and checksums (REQ-071, REQ-072) ------------------------------------------

# sha256_stdin: filter; the SHA-256 (hex) of stdin.
sha256_stdin() {
  if has_command sha256sum; then sha256sum | awk '{ print $1 }'; else shasum -a 256 | awk '{ print $1 }'; fi
}

# tree_checksum <dir>: SHA-256 over the paths and contents of the files of an Xaden tree.
# A git checkout counts the files its last commit puts into a release archive (maintainer files are
# export-ignored, REQ-094), an extracted release all files; both give the same value for the same
# release. The CI workflow of an adopted project recomputes it with the same find, sed, sort and
# sha256 steps (scripts/adopt/ci.yml).
tree_checksum() {
  local dir=$1 staging="" checksum
  if [ -e "$dir/.git" ]; then
    staging="$(mktemp -d)"
    git -C "$dir" archive HEAD | tar -x -C "$staging" || { rm -rf "${staging:?}"; return 1; }
    dir=$staging
  fi
  checksum="$(
    cd "$dir" || exit
    find . -type f | sed 's|^\./||' |
      LC_ALL=C sort |
      while IFS= read -r file; do printf '%s  %s\n' "$(sha256_stdin <"$file")" "$file"; done |
      sha256_stdin
  )"
  [ -z "$staging" ] || rm -rf "${staging:?}"
  printf '%s\n' "$checksum"
}

# The installed versions of Xaden besides the one that runs: one folder per version.
xaden_home() { printf '%s' "${XADEN_HOME:-${XDG_DATA_HOME:-${HOME:?HOME is not set}/.local/share}/xaden}"; }
versions_dir() { printf '%s/versions' "$(xaden_home)"; }

# --- signed releases only (REQ-103) ------------------------------------------------------

# load_signature_policy <conf>: sets SIGNATURE_REQUIRED to 1 when the project says
# "require-signature = true", else 0. A key that is absent means false; a key that is present with
# any other value, an empty one included, dies: the control must not turn off by a typo.
# Not a command substitution on purpose: die has to end the calling script.
SIGNATURE_REQUIRED=0
# shellcheck disable=SC2034 # SIGNATURE_REQUIRED is read by scripts/fetch.sh and scripts/xaden.sh
load_signature_policy() {
  local value
  SIGNATURE_REQUIRED=0
  conf_keys "$1" require-signature | grep -qx require-signature || return 0
  value="$(conf_get "$1" require-signature)"
  case "$value" in
    true) SIGNATURE_REQUIRED=1 ;;
    false) SIGNATURE_REQUIRED=0 ;;
    *) die "xaden/xaden.conf: require-signature must be true or false (got: $value)" ;;
  esac
}

# signed_record <version>: where the checksum the maintainer signed for an installed version is kept.
# Next to the versions folder, not inside it: the folder's checksum must stay the release's.
signed_record() { printf '%s/%s.signed' "$(versions_dir)" "$1"; }

# installation_authenticated <version> <dir> [pinned-checksum]: true when the files in <dir> are
# exactly what the maintainer signed for <version> (and, when given, what the project pins). A git
# checkout or worktree never is: tree_checksum hashes its last commit, not the files that run.
installation_authenticated() {
  local record signed
  [ ! -e "$2/.git" ] || return 1
  record="$(signed_record "$1")"
  [ -f "$record" ] || return 1
  signed="$(tr -d '[:space:]' <"$record")"
  [ "$(tree_checksum "$2")" = "$signed" ] || return 1
  [ -z "${3:-}" ] || [ "$3" = "$signed" ]
}

# The version that runs when you type `xaden`: a link to one folder of versions/ (REQ-097). The
# `xaden` command links to current/scripts/xaden.sh, so an upgrade only moves this one link.
current_link() { printf '%s/current' "$(xaden_home)"; }

# switch_current <version>: points `current` at an installed version; nothing else changes, so a
# failed download or check before this call leaves the old version active.
# shortcut: ln -sfn replaces the link in two steps (not one rename), fine for a command nobody runs
# in the same microsecond; upgrade to a rename if that ever bites.
switch_current() {
  [ -x "$(versions_dir)/$1/scripts/xaden.sh" ] || die "Xaden $1 is not installed in $(versions_dir)"
  ln -sfn "versions/$1" "$(current_link)"
}

# is_xaden_link <path>: true for a symbolic link to some Xaden's scripts/xaden.sh (this layout or an older one).
is_xaden_link() { [ -L "$1" ] && case "$(readlink "$1")" in */scripts/xaden.sh) true ;; *) false ;; esac; }

# newest_version <version...>: the highest MAJOR.MINOR.PATCH of those given.
newest_version() { printf '%s\n' "$@" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1; }

# --- what an adopted project records outside xaden/ (REQ-073, REQ-080) ---------------------

FOOTPRINT_FILE="xaden/footprint.txt"

# note_footprint <dir> <kind> <path>: records a path outside xaden/ so `xaden project remove` can undo it.
note_footprint() {
  mkdir -p "$1/xaden"
  grep -qxF "$2 $3" "$1/$FOOTPRINT_FILE" 2>/dev/null || printf '%s %s\n' "$2" "$3" >>"$1/$FOOTPRINT_FILE"
}

# command_name <prompt>: the slash command that starts a prompt. Every Xaden command carries the
# xaden- prefix (REQ-087), so it is told apart from the commands of other tools.
command_name() {
  case "$1" in
    code-review) echo xaden-review ;;
    security-review) echo xaden-security ;;
    requirements-update) echo xaden-requirements ;;
    documentation) echo xaden-docs ;;
    *) echo "xaden-$1" ;;
  esac
}

# command_kinds <assistants>: the command file layouts a comma separated list of assistants needs
# (REQ-080, REQ-081). Layouts checked against the vendors' documentation on 2026-10-16:
#   claude   .claude/commands/<name>.md          (REQ-080)
#   copilot  .github/prompts/<name>.prompt.md    https://code.visualstudio.com/docs/copilot/customization/prompt-files
#            front matter description/argument-hint; input is written ${input:task:...}; run as /<name>
#   skills   .agents/skills/<name>/SKILL.md      Mistral Vibe: https://docs.mistral.ai/vibe/code/cli/skills
#            (user-invocable, default true; the folder must be trusted); Codex CLI: https://learn.chatgpt.com/docs/build-skills
#            (name and description required; run as $<name> or /skills). Both read the same files.
# Codex documents no repository level custom slash commands or prompts, so a skill is its only mechanism.
command_kinds() {
  local kinds="" assistant kind
  for assistant in $(printf '%s' "$1" | tr ',' ' '); do
    case "$assistant" in
      claude) kind=claude ;;
      copilot) kind=copilot ;;
      vibe | codex) kind=skills ;;
      *) continue ;;
    esac
    case " $kinds " in *" $kind "*) ;; *) kinds="$kinds $kind" ;; esac
  done
  printf '%s' "${kinds# }"
}

# command_path <kind> <name>: where the command file of that layout lives.
command_path() {
  case "$1" in
    claude) echo ".claude/commands/$2.md" ;;
    copilot) echo ".github/prompts/$2.prompt.md" ;;
    skills) echo ".agents/skills/$2/SKILL.md" ;;
  esac
}

# command_text <kind> <name> <prompt> <title>: the whole file. Never the prompt text itself, so a
# team prompt in xaden/prompts/ is the one every assistant runs.
command_text() {
  local kind=$1 name=$2 prompt=$3 title=$4
  case "$kind" in
    claude)
      # shellcheck disable=SC2016 # $ARGUMENTS is text for the assistant, not for this shell
      printf -- '---\ndescription: %s\n---\n\nRun `xaden prompt %s` and follow it. Task input: $ARGUMENTS\n' "$title" "$prompt" ;;
    copilot)
      # shellcheck disable=SC2016 # ${input:...} is Copilot's variable syntax
      printf -- '---\ndescription: %s\nargument-hint: what the task is\n---\n\nRun `xaden prompt %s` and follow it. Task input: ${input:task:describe the task}\n' "$title" "$prompt" ;;
    skills)
      # shellcheck disable=SC2016 # the backticks are Markdown for the assistant, not command substitution
      printf -- '---\nname: %s\ndescription: %s. Use only when the user asks for it by name (%s).\n---\n\nRun `xaden prompt %s` and follow it. Task input: whatever the user wrote after the name.\n' \
        "$name" "$title" "$name" "$prompt" ;;
  esac
}

# sync_commands <dir> <tools-dir> <assistants> [old-tools-dir]: makes the command files of those
# assistants match the prompts of those tools (REQ-080, REQ-081). A file Xaden wrote and the person did
# not edit (it equals what the old tools would write) is brought up to date. An edited one stays as it
# is and the new text goes next to it as <file>-dist (REQ-100). A file Xaden did not write is left alone.
# Only the files the footprint lists as Xaden's own are removed when their prompt is gone.
sync_commands() {
  local dir=$1 tools=$2 assistants=$3 old=${4:-} kind prompt name file wanted="" stale new_text old_text current
  for kind in $(command_kinds "$assistants"); do
    for prompt in "$tools"/prompts/*.md; do
      prompt="$(basename "$prompt" .md)"
      [ "$prompt" != 00-index ] || continue
      name="$(command_name "$prompt")"
      file="$(command_path "$kind" "$name")"
      wanted="$wanted $file"
      new_text="$(command_text "$kind" "$name" "$prompt" "$(sed -n 's/^title: //p' "$tools/prompts/$prompt.md" | head -n 1)")"
      if [ -e "$dir/$file" ]; then
        if ! grep -qxF "file $file" "$dir/$FOOTPRINT_FILE" 2>/dev/null; then
          info "skipped $file: it exists already and stays as it is"
          continue
        fi
        current="$(cat "$dir/$file")"
        [ "$current" != "$new_text" ] || continue
        old_text=""
        if [ -n "$old" ] && [ -f "$old/prompts/$prompt.md" ]; then
          old_text="$(command_text "$kind" "$name" "$prompt" "$(sed -n 's/^title: //p' "$old/prompts/$prompt.md" | head -n 1)")"
        fi
        if [ "$current" = "$old_text" ]; then
          printf '%s\n' "$new_text" >"$dir/$file"
        else
          printf '%s\n' "$new_text" >"$dir/$file-dist"
          note_footprint "$dir" file "$file-dist"
          info "kept $file, which you edited; the new version is in $file-dist"
        fi
        continue
      fi
      mkdir -p "$dir/$(dirname "$file")"
      printf '%s\n' "$new_text" >"$dir/$file"
      note_footprint "$dir" file "$file"
    done
  done
  stale="$(grep -E '^file (\.claude/commands/[a-z0-9-]+\.md|\.github/prompts/[a-z0-9-]+\.prompt\.md|\.agents/skills/[a-z0-9-]+/SKILL\.md)$' "$dir/$FOOTPRINT_FILE" 2>/dev/null | cut -d' ' -f2 || true)"
  for file in $stale; do
    case " $wanted " in *" $file "*) continue ;; esac
    rm -f "${dir:?}/$file"
    (cd "$dir" && rmdir -p "$(dirname "$file")" 2>/dev/null) || true
    grep -vxF "file $file" "$dir/$FOOTPRINT_FILE" >"$dir/$FOOTPRINT_FILE.new" || true
    mv "$dir/$FOOTPRINT_FILE.new" "$dir/$FOOTPRINT_FILE"
  done
}
