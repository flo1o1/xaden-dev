# shellcheck shell=bash
# Smoke test area "security" (docs/requirements/security). Sourced by tests/smoke.sh, which
# defines the helpers and creates the demo projects first. Runs against the adopted demo project (REQ-133).

# REQ-052 dependencies are verified before they are proposed
test_dependency_vetting() {
  x_in "$DEMO" doc security
  assert "xaden doc security prints the guide" test "$XRC" -eq 0
  assert "dependency policy names slopsquatting" grep -q 'slopsquatting' "$XOUT"
  assert "dependency policy requires a registry lookup" grep -q 'look up the exact name in the' "$XOUT"
  assert "suspicious packages are not installed" grep -q 'say so and do not install it' "$XOUT"
}

# REQ-057: an accepted security exception fails the full check once it has expired.
test_security_exceptions() {
  local file="$DEMO/xaden/security-exceptions.md" check="$SCAFFOLD_ROOT/template/scripts/check-security-exceptions.sh"
  local row='| SE-001 | GHSA-xxxx in lib@1.0.0 | not reachable | input never parsed | Dana | 2026-06-14 |'
  assert "no accepted exceptions pass" env PROJECT_ROOT="$DEMO" CHECK_DATE=2026-06-15 "$check"
  printf '%s\n' "$row" >"$file"
  assert_fails_with "expired exception fails" "SE-001" env PROJECT_ROOT="$DEMO" CHECK_DATE=2026-06-15 "$check"
  assert "exception expiring today passes" env PROJECT_ROOT="$DEMO" CHECK_DATE=2026-06-14 "$check"
  assert_fails_with "full check fails on an expired exception" "SE-001" \
    bash -c "cd '$DEMO' && CHECK_DATE=2026-06-15 xaden check"
  git -C "$DEMO" add xaden/security-exceptions.md
  assert "staged check ignores the expiry date" bash -c "cd '$DEMO' && CHECK_DATE=2026-06-15 xaden check --staged"
  git -C "$DEMO" reset -q
  printf '%s\n' "${row/Dana/ }" >"$file"
  assert_fails_with "exception without owner fails" "SE-001" env PROJECT_ROOT="$DEMO" CHECK_DATE=2026-06-01 "$check"
  printf '%s\n' "${row/2026-06-14/end of June}" >"$file"
  assert_fails_with "exception with an invalid date fails" "SE-001" env PROJECT_ROOT="$DEMO" CHECK_DATE=2026-06-01 "$check"
  printf '%s\n' "${row/2026-06-14/2026-13-01}" >"$file"
  assert_fails_with "exception with an impossible month fails" "SE-001" env PROJECT_ROOT="$DEMO" CHECK_DATE=2026-06-01 "$check"
  rm -f "$file"
}

# REQ-145: the adopted workflow installs the shellcheck release the Xaden repository's own CI pins, verified by hash.
test_adopted_ci_shellcheck_pin() {
  local ci="$SCAFFOLD_ROOT/scripts/adopt/ci.yml" pin="$SCAFFOLD_ROOT/.github/shellcheck.version"
  assert "REQ-145 the adopted workflow has the pinned shellcheck version and hash" \
    bash -c ". '$pin'; grep -qF \"SHELLCHECK_VERSION: \\\"\$SHELLCHECK_VERSION\\\"\" '$ci' && grep -qF \"SHELLCHECK_SHA256: \\\"\$SHELLCHECK_SHA256\\\"\" '$ci'"
  assert_fails "REQ-145 the adopted workflow does not install an unpinned shellcheck from apt" grep -q 'apt-get install.*shellcheck' "$ci"
  assert "REQ-145 the adopted workflow verifies the archive hash" grep -q 'SHELLCHECK_SHA256.*sha256sum -c' "$ci"
}

test_dependency_vetting
test_security_exceptions
test_adopted_ci_shellcheck_pin
