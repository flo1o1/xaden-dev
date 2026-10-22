#!/usr/bin/env bash
# xaden aidd: switch the AI-Driven Development framework on or off in a project that adopted Xaden (REQ-118).
# Usage: xaden aidd enable [--ai <ids>]            install the framework at the pinned version
#        xaden aidd status                          pinned and installed versions
#        xaden aidd disable                         remove what enable added
#        xaden aidd pin <cli-version> <release>     move the pin on a branch for a pull request
#
# The framework (https://github.com/ai-driven-dev/framework, MIT) installs itself through its own CLI,
# @ai-driven-dev/cli. Xaden calls that CLI with an exact version and an exact release tag, never "latest",
# and refuses to run it when the pin cannot be held: before it runs, npm must still answer the integrity
# the pin records for the CLI version and the release tag must still point at the pinned commit
# (aidd-integrity, aidd-commit; REQ-153). Nothing is copied from the framework into Xaden.
# This is the only script besides fetch.sh that reaches the network, and only after a person's yes in a
# terminal (REQ-072): there is no --yes, and an assistant never answers the question for the person.
set -euo pipefail

SCAFFOLD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=SCRIPTDIR/../template/scripts/lib.sh
source "$SCAFFOLD_ROOT/template/scripts/lib.sh"
# shellcheck source=SCRIPTDIR/../template/scripts/layout.sh
source "$SCAFFOLD_ROOT/template/scripts/layout.sh"
# shellcheck source=SCRIPTDIR/scaffold-lib.sh
source "$SCAFFOLD_ROOT/scripts/scaffold-lib.sh"
# shellcheck source=SCRIPTDIR/adopt-lib.sh
source "$SCAFFOLD_ROOT/scripts/adopt-lib.sh"

# The pin a project gets on its first enable. Xaden changes a project's pin only on request (aidd pin).
# The integrity is npm's dist.integrity of the CLI version, the commit is what the release tag points at.
AIDD_DEFAULT_CLI="5.5.0"
AIDD_DEFAULT_RELEASE="v5.12.0"
AIDD_DEFAULT_INTEGRITY="sha512-+sWxo7SvDLhwBDmSunEHwj1aTCgoJzqtVaCZIB/q1G3eDDTQ7IyN+PO6+IVWaxNL3pfiNhmO4WsGu5LivpOwNg=="
AIDD_DEFAULT_COMMIT="0768b9edc4c30ad5c98ad2f09a377782ed7ba65a"
AIDD_NODE_MIN="22.12"
AIDD_SOURCE="https://github.com/ai-driven-dev/framework"
AIDD_BEGIN='<!-- xaden:aidd:begin -->'
AIDD_END='<!-- xaden:aidd:end -->'
# The assistants the framework installs for, and how Xaden names them (vibe has no counterpart).
AIDD_TOOLS="claude cursor copilot codex opencode kilo"

# aidd_run <cli-version> <args...>: the framework's CLI at an exact version. XADEN_AIDD_RUNNER replaces
# npx in tests. Install scripts stay off and the CLI's own self-update check is skipped.
aidd_run() {
  local version=$1
  shift
  if [ -n "${XADEN_AIDD_RUNNER:-}" ]; then
    XADEN_AIDD_CLI_VERSION=$version "$XADEN_AIDD_RUNNER" "$@"
  else
    npm_config_ignore_scripts=true AIDD_SKIP_UPDATE_CHECK=1 npx --yes "@ai-driven-dev/cli@$version" "$@"
  fi
}

# aidd_integrity <cli-version>: the integrity npm answers for the CLI version, or nothing. The
# registry is read only here; XADEN_AIDD_NPM_VIEW replaces the call in tests and gets the version (REQ-153).
aidd_integrity() {
  local version=$1
  if [ -n "${XADEN_AIDD_NPM_VIEW:-}" ]; then
    XADEN_AIDD_CLI_VERSION=$version "$XADEN_AIDD_NPM_VIEW" "$version"
  else
    npm view "@ai-driven-dev/cli@$version" dist.integrity 2>/dev/null || true
  fi
}

# aidd_tag_commit <release>: the commit the release tag points at, or nothing. The tag is read
# only here; XADEN_AIDD_LS_REMOTE replaces the call in tests and gets the release (REQ-153).
aidd_tag_commit() {
  local release=$1
  if [ -n "${XADEN_AIDD_LS_REMOTE:-}" ]; then
    XADEN_AIDD_RELEASE=$release "$XADEN_AIDD_LS_REMOTE" "$release"
  else
    git ls-remote "$AIDD_SOURCE" "refs/tags/$release" | awk 'NR == 1 { print $1 }'
  fi
}

# hold_pin <where> <cli> <release> <integrity> <commit>: the framework's CLI runs only when npm
# still answers the pinned integrity for the CLI version and the release tag still points at the
# pinned commit (REQ-153). A pin without both values cannot be checked, so the CLI does not run.
hold_pin() {
  local where=$1 cli=$2 release=$3 integrity=$4 commit=$5 found
  # the pin is read from a file a pull request can edit: an npm alias or a URL is not a version (REQ-159)
  is_semver "$cli" || die "$where: aidd-cli in xaden/xaden.conf must be a version like 5.5.0 (got: ${cli:-nothing}), so the framework's CLI does not run"
  printf '%s' "$release" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || die "$where: aidd-release in xaden/xaden.conf must look like v5.12.0 (got: ${release:-nothing}), so the framework's CLI does not run"
  if [ -z "$integrity" ] || [ -z "$commit" ]; then
    die "$where: the pin of CLI $cli, release $release has no aidd-integrity or no aidd-commit in xaden/xaden.conf (it was recorded before REQ-153), so the framework's CLI does not run; move the pin once to record them: xaden aidd pin $cli $release"
  fi
  found="$(aidd_integrity "$cli")"
  [ -n "$found" ] || die "$where: npm answered no integrity for @ai-driven-dev/cli@$cli, so the framework's CLI does not run"
  [ "$found" = "$integrity" ] ||
    die "$where: npm answers $found for @ai-driven-dev/cli@$cli, not the pinned integrity (the package changed after the pin was set), so the framework's CLI does not run"
  found="$(aidd_tag_commit "$release")"
  [ -n "$found" ] || die "$where: $AIDD_SOURCE answers no commit for the release tag $release, so the framework's CLI does not run"
  [ "$found" = "$commit" ] ||
    die "$where: the release tag $release points at $found, not the pinned commit $commit (the tag moved after the pin was set), so the framework's CLI does not run"
}

# read_pin <cli> <release>: the integrity and the commit a moved pin records, read from npm and
# from the framework's repository after the person's yes. Sets PIN_INTEGRITY and PIN_COMMIT.
read_pin() {
  local cli=$1 release=$2
  PIN_INTEGRITY="$(aidd_integrity "$cli")"
  printf '%s' "$PIN_INTEGRITY" | grep -q '^sha512-' ||
    die "xaden aidd pin: npm answered no sha512 integrity for @ai-driven-dev/cli@$cli, so the pin does not move"
  PIN_COMMIT="$(aidd_tag_commit "$release")"
  printf '%s' "$PIN_COMMIT" | grep -Eq '^[0-9a-f]{40,64}$' ||
    die "xaden aidd pin: the release tag $release points at no commit (got: ${PIN_COMMIT:-nothing}), so the pin does not move"
}

# version_at_least <found> <minimum>: both "major.minor[.patch]", compared as numbers.
version_at_least() {
  local a=${1#v} b=$2
  awk -v a="$a" -v b="$b" 'BEGIN { split(a, x, "."); split(b, y, ".")
    for (i = 1; i <= 3; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 } exit 0 }'
}

# need_prerequisites: Node (for the framework's CLI), npx and git. Stops before anything is installed.
need_prerequisites() {
  local found
  command -v node >/dev/null 2>&1 || die "the framework's CLI needs Node $AIDD_NODE_MIN or later; node was not found"
  found="$(node --version 2>/dev/null || true)"
  version_at_least "$found" "$AIDD_NODE_MIN" || die "the framework's CLI needs Node $AIDD_NODE_MIN or later; found ${found:-no version}"
  command -v git >/dev/null 2>&1 || die "the framework's CLI needs git; git was not found"
  if [ -z "${XADEN_AIDD_RUNNER:-}" ]; then command -v npx >/dev/null 2>&1 || die "the framework's CLI runs through npx, which was not found (it comes with Node)"; fi
}

# pick_tools <conf> <override>: the framework's ids for this project's assistants, one per line on stdout;
# the assistants it cannot serve are named on stderr.
pick_tools() {
  local conf=$1 override=$2 list name picked=""
  list="${override:-$(conf_get "$conf" assistants)}"
  if [ -z "$list" ] || [ "$list" = none ]; then die "no assistant is recorded in xaden/xaden.conf; name them with --ai, for example --ai claude"; fi
  for name in $(printf '%s' "$list" | tr ',' ' '); do
    case " $AIDD_TOOLS " in
      *" $name "*) picked="$picked${picked:+,}$name" ;;
      *) info "skipped $name: the framework does not support it" >&2 ;;
    esac
  done
  [ -n "$picked" ] || die "none of the assistants ($list) is supported by the framework ($AIDD_TOOLS)"
  printf '%s' "$picked"
}

# releases_installed <root>: the release tags the installed plugins come from, from the CLI's own manifest.
releases_installed() {
  [ -f "$1/.aidd/manifest.json" ] || return 0
  sed -n -E 's/^[[:space:]]*"ref": *"([^"]*)".*/\1/p' "$1/.aidd/manifest.json" | sort -u
}

# pin_holds <root> <release>: every installed plugin comes from the pinned release (and at least one is installed).
pin_holds() {
  local found
  found="$(releases_installed "$1")"
  [ -n "$found" ] && [ "$found" = "$2" ]
}

# changed_files <root>: the porcelain status of the repository, to show what a step changed.
changed_files() { git -C "$1" status --porcelain --untracked-files=all | sort; }

rules_block() {
  cat <<EOF
$AIDD_BEGIN
## AI-Driven Development framework (added by \`xaden aidd enable\`)

The AIDD framework is installed (CLI $1, release $2). Its workflow and Xaden's rules work together:

| Framework step | Xaden gate |
|----------------|------------|
| frame, spec | An approved \`REQ-nnn\` in \`docs/requirements/\` is the spec; no work without one |
| plan, implement | Small steps, tests first; each commit cites \`Refs: REQ-nnn\` |
| validate, assert | \`xaden check\` is the validation step; no framework step replaces it |
| review | Review against these rules; findings you do not fix now are reported, not dropped |
| ship, merge | The assistant opens the pull request and stops; the person merges |

If a framework skill and these rules disagree, these rules win (AGENTS.md section on trusted instructions).
$AIDD_END
EOF
}

conf_unset() {
  local file=$1 key=$2 tmp
  tmp="$(mktemp)"
  awk -v key="$key" '{ at = index($0, "="); name = at ? substr($0, 1, at - 1) : ""; gsub(/^[ \t]+|[ \t]+$/, "", name)
    if (!/^[ \t]*#/ && name == key) next; print }' "$file" >"$tmp" && cat "$tmp" >"$file"
  rm -f "$tmp"
}

enabled() { [ -n "$(conf_get "$1/xaden/xaden.conf" aidd-cli)" ]; }

enable_main() {
  local root=$1 conf override="" cli release tools before after plan
  shift
  conf="$root/xaden/xaden.conf"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --ai) shift; override=${1:-} ;;
      *) die "usage: xaden aidd enable [--ai <ids>]" ;;
    esac
    shift
  done
  if enabled "$root"; then
    ok "the AIDD framework is enabled already (CLI $(conf_get "$conf" aidd-cli), release $(conf_get "$conf" aidd-release)); see: xaden aidd status"
    return 0
  fi
  cli=$AIDD_DEFAULT_CLI
  release=$AIDD_DEFAULT_RELEASE
  need_prerequisites
  tools="$(pick_tools "$conf" "$override")"
  plan="npx @ai-driven-dev/cli@$cli setup --source remote --ai $tools --plugins recommended --release $release --yes"
  info "Xaden will run the framework's installer, pinned (source: $AIDD_SOURCE, license: MIT):"
  echo "  $plan"
  echo "  On your yes, Xaden first checks that npm still answers the pinned integrity of CLI $cli and that"
  echo "  the release tag $release still points at the pinned commit; then npx downloads the CLI and asks"
  echo "  it whether it can hold the release (setup --help), and it installs."
  echo "  It writes .aidd/ and the assistant's own settings into this project, downloads the plugins of release $release"
  echo "  and, for Claude Code, registers the marketplace 'aidd-framework' in your Claude Code user settings (shared by every"
  echo "  project on this machine; 'xaden aidd disable' leaves that registration, like the framework's own clean)."
  ask "Install the AIDD framework now?" || die "nothing was installed (it needs your yes in a terminal)"
  # the pin must be enforceable: npm and GitHub must still answer what it records, and the pinned CLI
  # has to take a release tag. Both checks and running the CLI's --help run the framework's CLI
  # (npx downloads it), so they wait for the yes above (REQ-128).
  hold_pin "xaden aidd enable" "$cli" "$release" "$AIDD_DEFAULT_INTEGRITY" "$AIDD_DEFAULT_COMMIT"
  aidd_run "$cli" setup --help 2>/dev/null | grep -q -- '--release' ||
    die "the framework's CLI $cli cannot be held to release $release (its setup has no --release option); nothing was installed"
  before="$(changed_files "$root")"
  (cd "$root" && aidd_run "$cli" setup --source remote --ai "$tools" --plugins recommended --release "$release" --yes) ||
    die "the framework's installer failed; see its output above. Undo what it wrote with: xaden aidd disable"
  if ! pin_holds "$root" "$release"; then
    warn "the installed plugins do not all come from release $release (found: $(releases_installed "$root" | tr '\n' ' '))"
    (cd "$root" && aidd_run "$cli" clean --force) || true
    die "the pin did not hold, so the installation was removed again"
  fi
  conf_set "$conf" aidd-cli "$cli"
  conf_set "$conf" aidd-release "$release"
  conf_set "$conf" aidd-assistants "$tools"
  conf_set "$conf" aidd-integrity "$AIDD_DEFAULT_INTEGRITY"
  conf_set "$conf" aidd-commit "$AIDD_DEFAULT_COMMIT"
  set_block "$root/AGENTS.md" "$AIDD_BEGIN" "$AIDD_END" "$(rules_block "$cli" "$release")"
  after="$(changed_files "$root")"
  info "files added or changed by the AIDD framework (git status of this project):"
  comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed 's/^/  /'
  ok "AIDD framework enabled: CLI $cli, release $release, for $tools. Review with git diff, then commit."
}

status_main() {
  local root=$1 conf installed integrity commit
  conf="$root/xaden/xaden.conf"
  if ! enabled "$root"; then echo "AIDD framework: not enabled (xaden aidd enable)"; return 0; fi
  installed="$(releases_installed "$root" | tr '\n' ' ')"
  integrity="$(conf_get "$conf" aidd-integrity)"
  commit="$(conf_get "$conf" aidd-commit)"
  echo "AIDD framework: enabled for $(conf_get "$conf" aidd-assistants)"
  echo "  pinned:    CLI $(conf_get "$conf" aidd-cli), release $(conf_get "$conf" aidd-release)"
  if [ -n "$integrity" ] && [ -n "$commit" ]; then
    echo "  integrity: $integrity (what npm must answer for the pinned CLI)"
    echo "  tag:       $commit (what the release tag must point at)"
  else
    echo "  integrity: not recorded (the pin predates REQ-153); the framework's CLI is refused until the pin moves once"
  fi
  echo "  installed: release ${installed:-none}"
  if pin_holds "$root" "$(conf_get "$conf" aidd-release)"; then ok "the installed plugins match the pin"; else warn "the installed plugins do not match the pin; run: xaden aidd enable after xaden aidd disable"; return 1; fi
}

disable_main() {
  local root=$1 conf
  conf="$root/xaden/xaden.conf"
  enabled "$root" || { ok "the AIDD framework is not enabled; nothing to remove"; return 0; }
  ask "Remove what 'xaden aidd enable' added, using the framework's own clean? It runs CLI $(conf_get "$conf" aidd-cli), release $(conf_get "$conf" aidd-release), through npx, after Xaden checked the pin against npm and GitHub." || die "nothing was removed (it needs your yes in a terminal)"
  hold_pin "xaden aidd disable" "$(conf_get "$conf" aidd-cli)" "$(conf_get "$conf" aidd-release)" "$(conf_get "$conf" aidd-integrity)" "$(conf_get "$conf" aidd-commit)"
  (cd "$root" && aidd_run "$(conf_get "$conf" aidd-cli)" clean --force) || die "the framework's own clean failed; see its output above. The pin and the rules block are still in place"
  remove_block "$root/AGENTS.md" "$AIDD_BEGIN" "$AIDD_END"
  conf_unset "$conf" aidd-cli
  conf_unset "$conf" aidd-release
  conf_unset "$conf" aidd-assistants
  conf_unset "$conf" aidd-integrity
  conf_unset "$conf" aidd-commit
  ok "AIDD framework removed. A marketplace registered in your Claude Code user settings stays (it is shared by every project); remove it with: claude plugin marketplace remove aidd-framework"
}

# pin_main <root> <cli-version> <release>: the new pin on a branch of its own, with the installer run there.
pin_main() {
  local root=$1 cli=${2:-} release=${3:-} conf branch worktree base old_release old_cli
  conf="$root/xaden/xaden.conf"
  enabled "$root" || die "the AIDD framework is not enabled; start with: xaden aidd enable"
  is_semver "$cli" || die "usage: xaden aidd pin <cli-version> <release>   (for example: 5.5.0 v5.12.0)"
  printf '%s' "$release" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || die "the release must look like v5.12.0 (got: ${release:-nothing})"
  old_cli="$(conf_get "$conf" aidd-cli)"
  old_release="$(conf_get "$conf" aidd-release)"
  [ "$cli" != "$old_cli" ] || [ "$release" != "$old_release" ] || { ok "the project is pinned to CLI $cli, release $release already"; return 0; }
  need_prerequisites
  base="$(git -C "$root" symbolic-ref -q --short HEAD)" || die "check out a branch first"
  branch="chore/pin-aidd-$release"
  worktree="$(dirname "$root")/$(basename "$root")-pin-aidd-$release"
  [ ! -e "$worktree" ] || die "$worktree exists already; remove it first (git worktree remove)"
  ask "Run the framework's installer, CLI $cli at release $release, on a new branch? Xaden first reads the integrity of that CLI from npm and the commit of that release from GitHub, then npx downloads the CLI (setup --help) and installs from $AIDD_SOURCE" || die "nothing was changed"
  # the new pin records what npm and GitHub answered when it moved; a reviewer reads both in the
  # pull request, and every later run has to get the same answers again (hold_pin, REQ-153).
  read_pin "$cli" "$release"
  aidd_run "$cli" setup --help 2>/dev/null | grep -q -- '--release' || die "the framework's CLI $cli cannot be held to a release (its setup has no --release option); nothing was changed"
  git -C "$root" worktree add -q -b "$branch" "$worktree" "$base"
  (cd "$worktree" && aidd_run "$cli" setup --source remote --ai "$(conf_get "$conf" aidd-assistants)" --plugins recommended --release "$release" --yes) ||
    die "the framework's installer failed in $worktree; remove it with: git worktree remove --force $worktree"
  pin_holds "$worktree" "$release" || die "the pin did not hold in $worktree (found: $(releases_installed "$worktree" | tr '\n' ' ')); not committed"
  conf_set "$worktree/xaden/xaden.conf" aidd-cli "$cli"
  conf_set "$worktree/xaden/xaden.conf" aidd-release "$release"
  conf_set "$worktree/xaden/xaden.conf" aidd-integrity "$PIN_INTEGRITY"
  conf_set "$worktree/xaden/xaden.conf" aidd-commit "$PIN_COMMIT"
  set_block "$worktree/AGENTS.md" "$AIDD_BEGIN" "$AIDD_END" "$(rules_block "$cli" "$release")"
  git -C "$worktree" add -A
  git -C "$worktree" -c core.hooksPath=/dev/null commit -q -n -m "chore: pin the AIDD framework to $release" \
    -m "CLI $old_cli to $cli, release $old_release to $release. The framework's changes: $AIDD_SOURCE/compare/$old_release...$release" \
    -m "npm's integrity of the CLI and the commit the release tag points at are recorded next to the pin (REQ-153)."
  info "changes of this pin"
  git -C "$worktree" show --stat --format= HEAD
  info "the framework's changes between the releases: $AIDD_SOURCE/compare/$old_release...$release"
  ok "branch $branch is ready in $worktree; push it and open the pull request your team reviews"
}

aidd_main() {
  local root=$1 sub=${2:-}
  shift
  [ "$#" -eq 0 ] || shift
  [ -f "$root/xaden/xaden.conf" ] || die "$NOT_ADOPTED_MESSAGE"
  case "$sub" in
    enable) enable_main "$root" "$@" ;;
    status) status_main "$root" ;;
    disable) disable_main "$root" "$@" ;;
    pin) pin_main "$root" "$@" ;;
    *) die "usage: xaden aidd <enable|status|disable|pin>" ;;
  esac
}

aidd_main "$@"
