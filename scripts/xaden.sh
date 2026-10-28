#!/usr/bin/env bash
# The `xaden` command (REQ-056): one entry point for the scaffold's scripts and the current
# project's own scripts, usable from any directory. scripts/install.sh links it onto PATH.
# Usage: xaden <command> [args...]   (`xaden help` lists the commands)
#
# A project that adopted Xaden (xaden/xaden.conf, REQ-066) keeps no copy of the tooling: the
# project commands run the installed Xaden, and the version pinned in xaden/xaden.conf decides
# which installed version that is (REQ-070, REQ-071). A pinned version that is not installed is
# never downloaded without a person's yes (REQ-072; fetch.sh asks).
set -euo pipefail

# resolve_link <path>: follows symbolic links to the real file (older macOS has no readlink -f).
resolve_link() {
  local path=$1 target
  while [ -L "$path" ]; do
    target="$(readlink "$path")"
    case "$target" in
      /*) path=$target ;;
      *) path="$(dirname "$path")/$target" ;;
    esac
  done
  printf '%s' "$path"
}

SCAFFOLD_ROOT="$(cd "$(dirname "$(resolve_link "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=SCRIPTDIR/../template/scripts/lib.sh
source "$SCAFFOLD_ROOT/template/scripts/lib.sh"
# shellcheck source=SCRIPTDIR/scaffold-lib.sh
source "$SCAFFOLD_ROOT/scripts/scaffold-lib.sh"
# shellcheck source=SCRIPTDIR/../template/scripts/update-check-lib.sh
source "$SCAFFOLD_ROOT/template/scripts/update-check-lib.sh"

TOOLS="$SCAFFOLD_ROOT/template/scripts"

usage() {
  cat <<'EOF'
Usage: xaden <command> [args...]
       xaden <core|project|aidd> <command> [args...]

Namespaces (`xaden <namespace> help` lists the commands of one):
  core               Xaden itself, on this machine: upgrade, version, fetch, doctor, ignore-list,
                     completion, help
  project            one project and the Xaden version it uses: create, adopt, remove, pin, rules,
                     add-preset, setup, release, persona, check, req, help
  aidd               the AI-Driven Development framework, pinned per project: enable, status, disable, pin, help

Short spellings and daily commands (anywhere inside a project):
  check [...]        same as `project check`: static analysis (--staged, --strict)
  req [...]          same as `project req`: requirements: list, show, new, index
  version            same as `core version`: print the installed Xaden version
  context            rule IDs, requirement counts and the CONTEXT CHECK fingerprint
  verify-commits --ci
                     check the commit messages a CI run introduces (adopted projects; advises only while commit-convention is other)
  prompt <name> [--run [assistant]]
                     print a task prompt (kickoff, feature, bugfix, ...); --run starts claude or codex with it
  doc <name>         print a guide (clean-code, security, optional-tools, local-llm)
  help               show this list
EOF
}

usage_core() {
  cat <<'EOF'
Usage: xaden core <command> [args...]

  upgrade [--check [--if-due]] [version]
                     update Xaden itself to the newest release or to <version> (asks first; older versions stay installed);
                     --check only reports: the newest Xaden and, in a project, its outdated dependencies
  version            print the installed Xaden version
  fetch <version>    install the pinned version if it is missing (asks first)
  doctor             compare the installed version with the pinned one (no network)
  ignore-list        print the paths Xaden owns, for .dockerignore and archive excludes (inside a project)
  completion bash    print a bash completion script: eval "$(xaden core completion bash)" in ~/.bashrc
  help               list these commands
EOF
}

usage_project() {
  cat <<'EOF'
Usage: xaden project <command> [args...]

Start and keep (any directory):
  create <name> [dir]
                     create a project in ./<name>, or in <dir>, with the xaden/ layout
  create --autopilot --stack python|node <name>
                     create it with the recommended setup after one confirmation
  adopt [--scan|--plan]
                     add Xaden to the repository you are in, on a branch (scan and plan change nothing)
  remove             take Xaden out of the repository you are in

Inside a project that adopted Xaden:
  pin [--check] [version]
                     move the project to another Xaden version on a branch for a pull request
  rules              regenerate xaden/RULES.md from the pinned version
  add-preset <python|node>
                     add Xaden's preset for a stack and map its checks
  setup              activate git hooks, report missing tools
  release <part>     cut a release: major, minor or patch
  persona new <name> create a user persona
  check [...]        static analysis (--staged, --strict)
  req [...]          requirements: list, show, new, index
  help               list these commands
EOF
}

usage_aidd() {
  cat <<'EOF'
Usage: xaden aidd <command> [args...]

  enable             switch the AI-Driven Development framework on at a pinned version (asks before it downloads)
  status             show whether it is on, the pins and whether they hold
  disable            switch it off and remove what enable added
  pin                move the project to another pinned release of the framework
  help               list these commands
EOF
}

# project_root: the top of the git project around the current directory; dies outside one.
project_root() {
  git rev-parse --show-toplevel 2>/dev/null || die "$NO_REPOSITORY_MESSAGE"
}

# is_adopted <root>: true if the project keeps its settings in xaden/xaden.conf.
is_adopted() { [ -f "$1/xaden/xaden.conf" ]; }

# running_version: the version of the Xaden that runs this command.
running_version() { tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION"; }

# require_signed_installation <conf> <pinned>: the Xaden that runs for the project must match the pinned
# checksum; with "require-signature = true" the Xaden that runs for
# the project must be exactly what the maintainer signed and what the project pins (REQ-103). An
# invalid value of the setting stops here too. A pinned version that is not installed is fetch.sh's
# business: it refuses unsigned downloads itself.
require_signed_installation() {
  local dir pinned
  load_signature_policy "$1"
  if [ "$2" = "$(running_version)" ]; then dir="$SCAFFOLD_ROOT"; else dir="$(versions_dir)/$2"; fi
  [ -d "$dir" ] || return 0
  # The copy that runs is the one the project pinned (REQ-138). A git checkout is the maintainer's own and has no pin to match.
  pinned="$(conf_get "$1" checksum)"
  if [ -n "$pinned" ] && [ ! -e "$dir/.git" ] && ! checksum_matches "$dir" "$pinned"; then
    die "Xaden $2 in $dir does not match the checksum pinned in xaden/xaden.conf (changed files?). Install it again with: xaden core fetch $2"
  fi
  [ "$SIGNATURE_REQUIRED" = 1 ] || return 0
  installation_authenticated "$2" "$dir" "$(conf_get "$1" checksum)" ||
    die "this project requires signed releases (require-signature = true), and Xaden $2 in $dir has no matching signature on record. Verify it once with: xaden core fetch $2"
}

# select_pinned_version <root> <args...>: runs the Xaden version the project pins. When it is
# not the running one, hands over to the installed copy with the arguments as typed (ORIGINAL_ARGS);
# when it is not installed, asks before anything downloads.
select_pinned_version() {
  local root=$1 conf pinned
  shift
  conf="$root/xaden/xaden.conf"
  pinned="$(conf_get "$conf" version)"
  is_semver "$pinned" || die "xaden/xaden.conf: version must look like 1.2.3 (got: ${pinned:-nothing})"
  require_signed_installation "$conf" "$pinned"
  [ "$pinned" != "$(running_version)" ] || return 0
  [ -z "${XADEN_HANDED_OVER:-}" ] || die "Xaden $(running_version) was started for a project that pins $pinned"
  if [ -x "$(versions_dir)/$pinned/scripts/xaden.sh" ]; then
    XADEN_HANDED_OVER=1 exec "$(versions_dir)/$pinned/scripts/xaden.sh" "${ORIGINAL_ARGS[@]}"
  fi
  info "this project pins Xaden $pinned; this machine has $(running_version)"
  # fetch.sh shows version, source and checksum, asks, and downloads only after a yes
  "$SCAFFOLD_ROOT/scripts/fetch.sh" fetch "$pinned" || exit $?
  XADEN_HANDED_OVER=1 exec "$(versions_dir)/$pinned/scripts/xaden.sh" "${ORIGINAL_ARGS[@]}"
}

# run_tool_script <root> <script> [args...]: runs one of the installed tooling scripts on the project.
run_tool_script() {
  local root=$1 script=$2
  shift 2
  cd "$root"
  PROJECT_ROOT="$root" exec "$TOOLS/$script" "$@"
}

# report_leftover_dist <root>: names the <file>-dist files a pin left to merge (REQ-100).
report_leftover_dist() {
  local file
  find "$1" \( -name .git -o -name node_modules -o -name .venv -o -name worktrees \) -prune -o \
    -type f -name '*-dist' -print | sort | while IFS= read -r file; do
    warn "merge or delete this leftover of a pin: ${file#"$1"/}"
  done
}

# doctor_main: compares the installed version with the pinned one. Reads two files; no network.
doctor_main() {
  local root conf pinned checksum
  root="$(project_root)"
  report_leftover_dist "$root"
  is_adopted "$root" || die "$NOT_ADOPTED_MESSAGE"
  conf="$root/xaden/xaden.conf"
  load_signature_policy "$conf"
  pinned="$(conf_get "$conf" version)"
  checksum="$(conf_get "$conf" checksum)"
  info "installed $(running_version), project pinned $pinned"
  if [ "$pinned" = "$(running_version)" ]; then
    if checksum_matches "$SCAFFOLD_ROOT" "$checksum"; then
      ok "the installed Xaden is the pinned one (checksum matches)"
    else
      warn "the installed Xaden $pinned does not match the pinned checksum (local changes in the Xaden folder?)"
      exit 1
    fi
  elif [ -x "$(versions_dir)/$pinned/scripts/xaden.sh" ]; then
    ok "Xaden $pinned is installed in $(versions_dir)/$pinned and is used for this project"
    if [ "$(newest_version "$pinned" "$(running_version)")" != "$pinned" ]; then
      info "Xaden $(running_version) is installed; move the project with: xaden project pin $(running_version)"
    fi
  else
    warn "Xaden $pinned is not installed. Install it with: xaden core fetch $pinned"
    exit 1
  fi
  print_update_check "$root"
}

# print_update_check <root>: the update-check setting in effect and the cached result. No network.
print_update_check() {
  local setting
  setting="$(update_check_setting "$1/xaden/xaden.conf")"
  info "update check: ${setting% *} (${setting#* })"
  update_check_print_cached "$1"
}

# hook_main <root> <name> <args...>: what the git hooks of an adopted project run.
hook_main() {
  local root=$1 name=$2 convention
  shift 2
  convention="$(conf_get "$root/xaden/xaden.conf" commit-convention conventional)"
  case "$name" in
    pre-commit) run_tool_script "$root" check.sh --staged ;;
    commit-msg)
      if [ "$convention" = "conventional" ]; then
        PROJECT_ROOT="$root" exec "$TOOLS/hooks/commit-msg" "$@"
      fi
      # Another commit convention: the Refs: checks only advise until the team opts in (REQ-068).
      PROJECT_ROOT="$root" "$TOOLS/verify-refs.sh" "$@" || warn "commit references: advisory only while commit-convention is '$convention'"
      ;;
    *) die "unknown hook: $name (pre-commit or commit-msg)" ;;
  esac
}

# verify_commits_main <root> <args...>: the commit-msg checks on commits that exist already; CI runs it
# because a hook can be skipped (REQ-107). Another commit convention only advises (REQ-068).
verify_commits_main() {
  local root=$1 convention status
  shift
  convention="$(conf_get "$root/xaden/xaden.conf" commit-convention conventional)"
  # REQ-109 the history before the adoption is not Xaden's: start after the commit that added xaden.conf
  VERIFY_COMMITS_AFTER="$(git -C "$root" log --diff-filter=A --format=%H -- xaden/xaden.conf | tail -n 1)"
  export VERIFY_COMMITS_AFTER
  if [ "$convention" = "conventional" ]; then run_tool_script "$root" verify-commits.sh "$@"; fi
  status=0
  (cd "$root" && PROJECT_ROOT="$root" "$TOOLS/verify-commits.sh" "$@") || status=$?
  # status 2: the run could not read what it had to check; that is no advice-only finding
  if [ "$status" -eq 2 ]; then exit 2; fi
  if [ "$status" -ne 0 ]; then warn "commit references: advisory only while commit-convention is '$convention'"; fi
}

# setup_main <root>: hooks and tools for one clone of an adopted project.
setup_main() {
  local root=$1 manager
  PROJECT_ROOT="$root" "$TOOLS/setup.sh" --tools-only || true
  # shellcheck source=SCRIPTDIR/adopt-scan.sh
  source "$SCAFFOLD_ROOT/scripts/adopt-scan.sh"
  # shellcheck source=SCRIPTDIR/adopt-lib.sh
  source "$SCAFFOLD_ROOT/scripts/adopt-lib.sh"
  scan_hooks "$root"
  manager=$SCAN_HOOKS
  case "$manager" in
    husky) info "husky hooks are part of the repository; nothing to install" ;;
    unsupported*) warn "hook setup not supported ($manager); call 'xaden hook pre-commit' and 'xaden hook commit-msg \"\$1\"' from your hooks yourself" ;;
    *) install_local_hooks "$root"; info "Xaden is chained into the git hooks of this clone ($manager)" ;;
  esac
}

# ignore_list_main <root>: the paths Xaden owns (REQ-075). Reads the repository, changes nothing.
ignore_list_main() {
  local root=$1
  is_adopted "$root" || die "$NOT_ADOPTED_MESSAGE"
  printf 'xaden/\nAGENTS.md\n'
  if [ -f "$root/CLAUDE.md" ]; then printf 'CLAUDE.md\n'; fi
}

# The assistants Xaden starts with a prompt as their first message (REQ-162). Copilot, Vibe and chat windows are not started.
STARTABLE_ASSISTANTS="claude codex"
PROMPT_ASSISTANT=""

# prompt_text <root> <name>: the text of the prompt, the team's own first. Called inside $(...), where set -e is off: the
# `|| exit 1` makes an unknown prompt an error (REQ-162).
prompt_text() {
  # shellcheck disable=SC1091 # layout.sh is part of the tooling
  (PROJECT_ROOT="$1"; layout_init "$1"; file="$(resolve_prompt "$2")" || exit 1; cat "$file"; case "$file" in "$TEAM_DIR"/*) ;; *) rm -f "$file" ;; esac)
}

# prompt_candidates <root>: the startable assistants the project names in xaden.conf, else all of them, that are on the PATH.
prompt_candidates() {
  local listed name pool=""
  listed="$(conf_get "$1/xaden/xaden.conf" assistants | tr ',' ' ')"
  for name in $STARTABLE_ASSISTANTS; do
    case " $listed " in *" $name "*) pool="$pool $name" ;; esac
  done
  for name in ${pool:-$STARTABLE_ASSISTANTS}; do
    if has_command "$name"; then printf '%s\n' "$name"; fi
  done
}

# choose_prompt_assistant <root> <asked>: sets PROMPT_ASSISTANT; returns 1 when none is to be started. Asked (--run)
# means the person already said yes, so one candidate is taken without a question.
choose_prompt_assistant() {
  local candidates count
  candidates="$(prompt_candidates "$1")"
  count="$(printf '%s' "$candidates" | grep -c .)"
  PROMPT_ASSISTANT=""
  if [ "$count" -eq 0 ]; then
    [ -z "$2" ] || die "none of $STARTABLE_ASSISTANTS is installed; copy the text of the prompt into your assistant instead"
    return 1
  fi
  if [ "$count" -eq 1 ]; then
    PROMPT_ASSISTANT=$candidates
    [ -n "$2" ] || ask "Run it in $candidates now?" y || return 1
    return 0
  fi
  ask_text "Run it in which assistant ($(printf '%s' "$candidates" | tr '\n' ' ')or skip)?" "$(printf '%s' "$candidates" | head -n 1)" || return 1
  [ "$ASK_TEXT_ANSWER" != skip ] || return 1
  printf '%s\n' "$candidates" | grep -qx -- "$ASK_TEXT_ANSWER" || die "'$ASK_TEXT_ANSWER' is not one of: $(printf '%s' "$candidates" | tr '\n' ' ')"
  PROMPT_ASSISTANT=$ASK_TEXT_ANSWER
}

# prompt_main <root> <name> [--run [assistant]]: prints the prompt. In a terminal it also says what the text is for and offers to
# start an assistant with it (REQ-162); output that is not a terminal gets the text and nothing else.
prompt_main() {
  local root=$1 name=$2 run="" assistant="" text
  shift 2
  if [ "${1:-}" = "--run" ]; then run=1; shift; if [ $# -gt 0 ]; then assistant=$1; shift; fi; fi
  [ $# -eq 0 ] || die "usage: xaden prompt <name> [--run [assistant]]"
  text="$(prompt_text "$root" "$name")"
  if [ -n "$assistant" ]; then
    case " $STARTABLE_ASSISTANTS " in *" $assistant "*) ;; *) die "cannot start '$assistant' with a prompt (can start: $STARTABLE_ASSISTANTS); copy the text of 'xaden prompt $name' into it instead" ;; esac
    has_command "$assistant" || die "$assistant is not installed (not on the PATH)"
  fi
  if [ -z "$run" ]; then
    printf '%s\n' "$text"
    has_terminal || return 0
    printf '\n==> This text is an instruction for an AI assistant, not for you. Either start the assistant with it:\n      xaden prompt %s --run\n    or copy it into your assistant (Claude Code, Codex, ChatGPT, ...).\n' "$name" >&2
  elif ! has_terminal; then
    die "--run needs a terminal; nothing was started. Copy the text of 'xaden prompt $name' into your assistant instead"
  fi
  if [ -z "$assistant" ]; then
    choose_prompt_assistant "$root" "$run" || return 0
    assistant=$PROMPT_ASSISTANT
  fi
  info "Starting $assistant with the $name prompt"
  # The text starts with "---", so it follows "--" and is never read as an option.
  (cd "$root" && exec "$assistant" -- "$text")
}

# adopted_project_command <command> <root> <args...>
adopted_project_command() {
  local command=$1 root=$2 name file
  shift 2
  select_pinned_version "$root" "$command" "$@"
  case "$command" in
    setup) setup_main "$root" ;;
    check) run_tool_script "$root" check.sh "$@" ;;
    req) run_tool_script "$root" req.sh "$@" ;;
    context) run_tool_script "$root" context-status.sh "$@" ;;
    persona) run_tool_script "$root" persona.sh "$@" ;;
    release) run_tool_script "$root" release.sh "$@" ;;
    hook) hook_main "$root" "${1:-}" "${@:2}" ;;
    verify-commits) verify_commits_main "$root" "$@" ;;
    prompt)
      name="${1:-}"
      [ -n "$name" ] || die "usage: xaden prompt <name> [--run [assistant]]"
      prompt_main "$root" "$name" "${@:2}" ;;
    doc)
      name="${1:-}"
      case "$name" in
        clean-code | security | optional-tools | local-llm) cat "$SCAFFOLD_ROOT/template/docs/$name.md" ;;
        rules-*) render_rule_topic "${name#rules-}" ;;
        *) die "usage: xaden doc <clean-code|security|optional-tools|local-llm|rules-<topic>>" ;;
      esac ;;
    rules)
      layout_init "$root"
      render_rules >"$root/xaden/RULES.md"
      ok "xaden/RULES.md regenerated from Xaden $(running_version); review the diff and commit it" ;;
    ignore-list) ignore_list_main "$root" ;;
    aidd) "$SCAFFOLD_ROOT/scripts/aidd.sh" "$root" "$@" ;;
    add-preset) preset_main "$root" "${1:-}" ;;
  esac
}

# preset_main <root> <stack>: Xaden's preset for a stack in an adopted project: the configuration
# files at the root (never overwriting yours) and the check commands in xaden/xaden.conf.
preset_main() {
  local root=$1 stack=$2
  case "$stack" in python | node) ;; *) die "usage: xaden project add-preset <python|node>" ;; esac
  # shellcheck source=SCRIPTDIR/adopt-scan.sh
  source "$SCAFFOLD_ROOT/scripts/adopt-scan.sh"
  # shellcheck source=SCRIPTDIR/adopt-lib.sh
  source "$SCAFFOLD_ROOT/scripts/adopt-lib.sh"
  SCAN_GAPS="test lint typecheck audit"
  [ "$stack" != python ] || SCAN_GAPS="$SCAN_GAPS security"
  apply_preset "$root" "$stack"
  ok "the $stack preset is in place; review it with git diff, then install its tools yourself:"
  echo "  $(preset_install_command "$stack")"
}

# is_scaffold <root>: the Xaden scaffold checkout itself (REQ-085); no project has both marker files.
is_scaffold() { [ -f "$1/template/AGENTS.md" ] && [ -f "$1/scripts/check-scaffold.sh" ]; }

# scaffold_command <command> <root> <args...>: maintainers run the project commands on the scaffold.
scaffold_command() {
  local command=$1 root=$2
  shift 2
  case "$command" in check | req | context) ;; *) return 0 ;; esac
  cd "$root"
  case "$command" in
    check) exec "$root/scripts/check-scaffold.sh" "$@" ;;
    req) PROJECT_ROOT=. exec "$root/template/scripts/req.sh" "$@" ;;
    context) PROJECT_ROOT=. RULES_FILE=template/AGENTS.md exec "$root/template/scripts/context-status.sh" "$@" ;;
  esac
}

CORE_COMMANDS="upgrade version fetch doctor ignore-list completion"
PROJECT_COMMANDS="create adopt remove pin rules add-preset setup release persona check req"
AIDD_COMMANDS="enable status disable pin"
TOP_LEVEL_COMMANDS="core project aidd check req version context verify-commits prompt doc"

# completion_main <shell>: the completion script of a shell on stdout; its command lists are the ones above (REQ-135).
completion_main() {
  case "$*" in bash) ;; *) usage_core >&2; exit 2 ;; esac
  local prompts="" file name
  for file in "$SCAFFOLD_ROOT"/template/prompts/*.md; do
    name=${file##*/}
    name=${name%.md}
    [ "$name" = 00-index ] || prompts="$prompts $name"
  done
  printf '_xaden() {\n  local top="%s help" core="%s help" project="%s help" aidd="%s help" prompts="%s"\n' \
    "$TOP_LEVEL_COMMANDS" "$CORE_COMMANDS" "$PROJECT_COMMANDS" "$AIDD_COMMANDS" "$prompts"
  cat <<'COMPLETION'
  local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]} command=${COMP_WORDS[1]:-} words=""
  case "$command" in core | project | aidd) command=${COMP_WORDS[2]:-} ;; esac
  if [ "$COMP_CWORD" -eq 1 ]; then
    words=$top
  elif [ "$COMP_CWORD" -eq 2 ]; then
    case "${COMP_WORDS[1]}" in core) words=$core ;; project) words=$project ;; aidd) words=$aidd ;; esac
  fi
  if [ -z "$words" ]; then
    case "$prev" in
      --stack) words="python node" ;;
      *)
        case "$cur:$command" in
          -*:upgrade) words="--check --if-due" ;;
          -*:pin) words="--check" ;;
          -*:create) words="--autopilot --stack" ;;
          *:add-preset) words="python node" ;;
          *:prompt) words=$prompts ;;
          *:doc) words="clean-code security optional-tools local-llm" ;;
        esac ;;
    esac
  fi
  COMPREPLY=($(compgen -W "$words" -- "$cur"))
}
complete -F _xaden xaden
COMPLETION
}

# in_list <word> <list>: true if the word is one of the space separated words.
in_list() { case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# run_namespace <core|project> [<command> <args...>]: the command after the namespace, or the namespace's commands.
run_namespace() {
  local namespace=$1 command=${2:-}
  if [ "$#" -gt 1 ]; then shift 2; else shift; fi
  if [ -z "$command" ]; then
    "usage_$namespace" >&2
    exit 2
  fi
  case "$command" in help | -h | --help) "usage_$namespace"; return 0 ;; esac
  case "$namespace" in
    core) in_list "$command" "$CORE_COMMANDS" || { usage_core >&2; die "unknown command: xaden core $command"; } ;;
    project) in_list "$command" "$PROJECT_COMMANDS" || { usage_project >&2; die "unknown command: xaden project $command"; } ;;
  esac
  run_command "$command" "$@"
}

# run_command <command> <args...>: one command by its own name; main() decides which names a person can type.
run_command() {
  local command=$1 root
  shift
  case "$command" in
    create)
      exec "$SCAFFOLD_ROOT/scripts/create.sh" "$@"
      ;;
    adopt) exec "$SCAFFOLD_ROOT/scripts/adopt.sh" "$@" ;;
    remove) exec "$SCAFFOLD_ROOT/scripts/adopt.sh" __remove "$@" ;;
    version) tr -d '[:space:]' <"$SCAFFOLD_ROOT/VERSION" && echo ;;
    doctor) doctor_main ;;
    completion) completion_main "$@" ;;
    fetch) exec "$SCAFFOLD_ROOT/scripts/fetch.sh" fetch "$@" ;;
    upgrade) exec "$SCAFFOLD_ROOT/scripts/fetch.sh" upgrade "$@" ;;
    pin) exec "$SCAFFOLD_ROOT/scripts/fetch.sh" pin "$@" ;;
    setup | check | req | context | persona | release | hook | verify-commits | prompt | doc | rules | ignore-list | add-preset | aidd)
      root="$(project_root)"
      if is_scaffold "$root"; then scaffold_command "$command" "$root" "$@"; fi # the Xaden repository adopts itself (REQ-134)
      if is_adopted "$root"; then
        adopted_project_command "$command" "$root" "$@"
      elif [ "$command" = "hook" ]; then
        exit 0 # a clone whose branch does not carry Xaden yet: nothing to check
      else
        die "$NOT_ADOPTED_MESSAGE"
      fi
      ;;
  esac
}

# main <args...>: a person types the namespaces `core` and `project` (REQ-131) or one of the daily commands;
# a moved command under its old top-level name is unknown.
main() {
  ORIGINAL_ARGS=("$@")
  local command=${1:-help}
  [ "$#" -gt 0 ] && shift
  case "$command" in
    core | project) run_namespace "$command" "$@" ;;
    help | -h | --help)
      [ "$#" -eq 0 ] || { usage >&2; die "unknown command: xaden help $1 (the commands of a namespace: xaden <namespace> help)"; }
      usage ;;
    check | req) run_command "$command" "$@" ;; # aliases of `xaden project check` and `xaden project req` (REQ-132)
    version) run_command version "$@" ;; # alias of `xaden core version`
    aidd)
      case "${1:-}" in help | -h | --help) usage_aidd ;; *) run_command aidd "$@" ;; esac ;;
    context | hook | verify-commits | prompt | doc) run_command "$command" "$@" ;;
    *)
      usage >&2
      die "unknown command: $command"
      ;;
  esac
}

main "$@"
