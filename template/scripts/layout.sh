#!/usr/bin/env bash
# Where a project keeps its files (REQ-070). Sourced by lib.sh; do not execute it.
# Two layouts, one set of scripts:
#   classic  the scaffold copied scripts, prompts and guides into the project; requirements and
#            reviews live in docs/. This is what `xaden create` creates.
#   adopted  the team content lives in the visible folder xaden/ (requirements, personas,
#            security reviews, baselines, xaden.conf); the tooling stays in the installed Xaden
#            and is selected by the version pinned in xaden/xaden.conf.
# shellcheck disable=SC2034 # the variables below are used by the scripts that source this file

TEAM_DIR_NAME="xaden"
CONF_NAME="xaden.conf"

# layout_init <project-root>: sets LAYOUT and the locations the scripts read and write.
layout_init() {
  local root=$1
  if [ -f "$root/$TEAM_DIR_NAME/$CONF_NAME" ]; then
    LAYOUT=adopted
    TEAM_DIR="$root/$TEAM_DIR_NAME"
    REQ_DIR="$TEAM_DIR/requirements"
    PERSONAS_DIR="$TEAM_DIR/personas"
    REVIEWS_DIR="$TEAM_DIR/security-reviews"
    EXCEPTIONS_FILE="$TEAM_DIR/security-exceptions.md"
    DEFERRED_FILE="$TEAM_DIR/deferred-work.md"
    THREAT_MODEL_FILE="$TEAM_DIR/threat-model.md"
    RULES_FILE="${RULES_FILE:-$TEAM_DIR/RULES.md}"
    CLEAN_CODE_FILE="$TOOLS_DIR/docs/clean-code.md"
    SECURITY_GUIDE_FILE="$TOOLS_DIR/docs/security.md"
  else
    LAYOUT=classic
    TEAM_DIR="$root/docs"
    REQ_DIR="$root/docs/requirements"
    PERSONAS_DIR="$root/docs/personas"
    REVIEWS_DIR="$root/docs/security-reviews"
    EXCEPTIONS_FILE="$root/docs/security-exceptions.md"
    DEFERRED_FILE="$root/docs/deferred-work.md"
    THREAT_MODEL_FILE="$root/docs/threat-model.md"
    RULES_FILE="${RULES_FILE:-$root/AGENTS.md}"
    CLEAN_CODE_FILE="$(dirname "$RULES_FILE")/docs/clean-code.md"
    SECURITY_GUIDE_FILE="$root/docs/security.md"
  fi
}

# TOOLS_DIR: the template folder the running scripts belong to (the installed Xaden, or the
# project itself in a classic layout).
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- xaden.conf: "key = value" lines, "#" comments. Parsed, never sourced. -------------

# conf_get <file> <key> [default]: the value of a key, or the default.
conf_get() {
  local value
  value="$(awk -v key="$2" '
    /^[ \t]*#/ { next }
    { at = index($0, "="); if (!at) next
      name = substr($0, 1, at - 1); gsub(/^[ \t]+|[ \t]+$/, "", name)
      if (name != key) next
      value = substr($0, at + 1); gsub(/^[ \t]+|[ \t]+$/, "", value); print value; exit }' "$1" 2>/dev/null)"
  printf '%s' "${value:-${3:-}}"
}

# conf_keys <file> <prefix>: the keys that start with the prefix, one per line.
conf_keys() {
  awk -v prefix="$2" '
    /^[ \t]*#/ { next }
    { at = index($0, "="); if (!at) next
      name = substr($0, 1, at - 1); gsub(/^[ \t]+|[ \t]+$/, "", name)
      if (index(name, prefix) == 1) print name }' "$1"
}

# conf_set <file> <key> <value>: replaces the key's line, or appends it.
conf_set() {
  local file=$1 key=$2 value=$3 tmp
  tmp="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    { at = index($0, "=")
      name = at ? substr($0, 1, at - 1) : ""; gsub(/^[ \t]+|[ \t]+$/, "", name)
      if (!/^[ \t]*#/ && name == key) { print key " = " value; done = 1; next }
      print }
    END { if (!done) print key " = " value }' "$file" >"$tmp" && cat "$tmp" >"$file"
  rm -f "$tmp"
}

# The modes of the checks (REQ-068).
CHECK_MODES="advisory changed-files strict"

# project_mode <project-root>: the mode of the checks. A classic project is always strict.
project_mode() {
  local mode
  [ "$LAYOUT" = "adopted" ] || { printf 'strict'; return 0; }
  mode="$(conf_get "$1/$TEAM_DIR_NAME/$CONF_NAME" mode strict)"
  case " $CHECK_MODES " in *" $mode "*) printf '%s' "$mode" ;; *) die "xaden/xaden.conf: mode must be one of: $CHECK_MODES (got: $mode)" ;; esac
}

# --- the rules and prompts of an adopted project --------------------------------------
# The tooling is not copied into the repository, so the texts that name project paths are
# rewritten to the commands and folders an adopted project has.

# shellcheck disable=SC2016 # backticks are Markdown, not command substitution
# adopted_text <project-name>: filter; the template's rules or prompts for an adopted project.
adopted_text() {
  sed -e "s/^# AGENTS.md — {{PROJECT_NAME}}$/# Xaden rules/" -e "s/{{PROJECT_NAME}}/$1/g" \
    -e 's#scripts/check-requirements\.sh#xaden check#g' \
    -e 's#scripts/check-traceability\.sh#xaden check#g' \
    -e 's#scripts/check-docs\.sh#xaden check#g' \
    -e 's#scripts/context-status\.sh#xaden context#g' \
    -e 's#scripts/apply-preset\.sh#xaden preset#g' \
    -e 's#scripts/persona\.sh#xaden persona#g' \
    -e 's#scripts/release\.sh#xaden release#g' \
    -e 's#scripts/req\.sh#xaden req#g' \
    -e 's#scripts/check\.sh#xaden check#g' \
    -e 's#--cone docs/requirements scripts#--cone docs/requirements#g' \
    -e 's#docs/requirements#xaden/requirements#g' \
    -e 's#docs/personas#xaden/personas#g' \
    -e 's#docs/security-reviews#xaden/security-reviews#g' \
    -e 's#docs/security-exceptions\.md#xaden/security-exceptions.md#g' \
    -e 's#docs/deferred-work\.md#xaden/deferred-work.md#g' \
    -e 's#docs/threat-model\.md#xaden/threat-model.md#g' \
    -e 's#docs/architecture\.md#xaden/architecture.md#g' \
    -e 's#docs/decisions/#xaden/decisions/#g' \
    -e 's#docs/clean-code\.md#`xaden doc clean-code`#g' \
    -e 's#docs/security\.md#`xaden doc security`#g' \
    -e 's#docs/optional-tools\.md#`xaden doc optional-tools`#g' \
    -e 's#`prompts/\([a-z0-9-]*\)\.md`#`xaden prompt \1`#g' \
    -e 's#prompts/\([a-z0-9-]*\)\.md#`xaden prompt \1`#g'
}

# shellcheck disable=SC2016 # backticks are Markdown, not command substitution
# render_rules: the content of xaden/RULES.md, from the rules of the Xaden that
# is running: the template's AGENTS.md for an adopted project. Sections that need files an
# adopted project does not have (the guides, the drop zone, the release script) are replaced.
render_rules() {
  printf '<!-- Generated from Xaden %s by `xaden adopt` and `xaden pin`. Generated, do not edit: change the rules by upgrading Xaden. -->\n\n' \
    "$(tr -d '[:space:]' <"$TOOLS_DIR/../VERSION" 2>/dev/null || tr -d '[:space:]' <"$TOOLS_DIR/VERSION")"
  awk '
    /^## 8\./ { skipping = 1
      print "## 8. Documentation (mandatory)\n"
      print "- Keep your own documentation (README, user and admin documentation, changelog) true"
      print "  in the same change as the code. Xaden requires no particular guides."
      print "- Never invent system requirements or commands; run what you document or mark it \"untested\".\n"
      next }
    /^## / { skipping = 0 }
    skipping { next }
    /^- Semantic Versioning in `VERSION`/ { getline; next }
    /^- Prompts live in `prompts\/`/ { getline
      print "- Task prompts: `xaden prompt <name>` prints one (kickoff, feature, bugfix, refactor, code-review,"
      print "  security-review, release, requirements-update, persona, documentation). A prompt of the same name in"
      print "  `xaden/prompts/` overrides the default. Follow the printed prompt."; next }
    /^- `inbox\/` is the user/ { getline; getline; next }
    { print }' "$TOOLS_DIR/AGENTS.md" | adopted_text "this project"
}

# resolve_prompt <name>: path of the prompt for an adopted project: the team's own in
# xaden/prompts/ first, else the installed default, rewritten for an adopted project (a temporary
# file the caller removes).
resolve_prompt() {
  local name=$1 file
  printf '%s' "$name" | grep -Eq '^[a-z0-9-]+$' || die "invalid prompt name: $name"
  if [ -f "$TEAM_DIR/prompts/$name.md" ]; then printf '%s' "$TEAM_DIR/prompts/$name.md"; return 0; fi
  [ -f "$TOOLS_DIR/prompts/$name.md" ] || die "no such prompt: $name"
  file="$(mktemp)"
  adopted_text "this project" <"$TOOLS_DIR/prompts/$name.md" >"$file"
  printf '%s' "$file"
}
