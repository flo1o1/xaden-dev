#!/usr/bin/env bash
# Writes scripts/adopt/semgrep.lock (REQ-146): semgrep and its dependencies as wheels for Linux x86_64 and
# Python 3.12, with the SHA-256 of each, so the CI of an adopted project installs exactly these files.
# Maintainers run it when SEMGREP_VERSION in scripts/adopt/ci.yml changes; review the diff like code. Needs
# python3 and network access. The hashes are of what PyPI serves now: the lock records them, it does not vouch for them.
# Usage: scripts/semgrep-lock.sh [semgrep-version]    (default: SEMGREP_VERSION of scripts/adopt/ci.yml)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-$(sed -n 's/^  SEMGREP_VERSION: "\(.*\)"$/\1/p' "$ROOT/scripts/adopt/ci.yml")}"
[ -n "$VERSION" ] || { echo "ERROR: no semgrep version" >&2; exit 1; }
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK:?}"' EXIT

python3 -m pip download "semgrep==$VERSION" -d "$WORK" -q --only-binary=:all: --python-version 3.12 --implementation cp \
  --platform manylinux2014_x86_64 --platform manylinux_2_17_x86_64 --platform manylinux_2_28_x86_64 --platform manylinux_2_34_x86_64 \
  --platform any --abi cp312 --abi abi3 --abi none
python3 -I - "$WORK" "$VERSION" >"$ROOT/scripts/adopt/semgrep.lock" <<'PY'
import hashlib, os, re, sys, zipfile
folder, version = sys.argv[1], sys.argv[2]
print(f"# semgrep {version} and what it needs, wheels for Linux x86_64 and Python 3.12 (REQ-146).")
print("# Regenerate with scripts/semgrep-lock.sh when SEMGREP_VERSION in scripts/adopt/ci.yml changes.")
rows = []
for name in os.listdir(folder):
    path = os.path.join(folder, name)
    with zipfile.ZipFile(path) as wheel:
        meta = wheel.read([n for n in wheel.namelist() if n.endswith(".dist-info/METADATA")][0]).decode()
    package = re.search(r"^Name: (.+)$", meta, re.M).group(1).lower().replace("_", "-")
    release = re.search(r"^Version: (.+)$", meta, re.M).group(1)
    rows.append(f"{package}=={release} --hash=sha256:{hashlib.sha256(open(path, 'rb').read()).hexdigest()}")
print("\n".join(sorted(rows)))
PY
