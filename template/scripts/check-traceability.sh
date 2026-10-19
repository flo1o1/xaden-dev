#!/usr/bin/env bash
# Traceability between requirements and tests.
# Fails when a `done` requirement is not referenced by any test file, or when a test cites a
# requirement ID that does not exist. Tests reference requirements by writing the ID
# (e.g. a comment `# REQ-003` or a test name containing it). Lines containing
# `traceability: ignore` are skipped (for deliberately invalid IDs in test data).
# Usage: scripts/check-traceability.sh            check
#        scripts/check-traceability.sh --matrix   print requirement → tests → commits table
set -euo pipefail

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(cd "$SCRIPTS/.." && pwd)}"
# shellcheck source=SCRIPTDIR/lib.sh
source "$SCRIPTS/lib.sh"
layout_init "$ROOT"
cd "$ROOT"

# Test files: anything under a tests/test/__tests__ directory, or named *_test.*, *.test.*,
# *.spec.*, test_*.
TEST_FILE_PATTERN='(^|/)(tests?|__tests__)/|(^|/)test_[^/]*$|_test\.[^/]+$|\.(test|spec)\.[^/]+$'

# requirement_rows: "ID STATUS" for every requirement.
requirement_rows() {
  "$SCRIPTS/req.sh" list | sed -E 's/^(REQ-[0-9]+) \[([^,]*),.*/\1 \2/'
}

# test_files: tracked (incl. staged) test files, one per line.
test_files() { list_project_files | tr '\0' '\n' | grep -E "$TEST_FILE_PATTERN" || true; }

# tests_citing <REQ-nnn>: test files that mention the ID (word match), comma-separated.
# Skips "traceability: ignore" lines, like cited_ids.
tests_citing() {
  test_files | while IFS= read -r file; do
    if grep -v 'traceability: ignore' "$file" 2>/dev/null | grep -qE "(^|[^0-9A-Za-z-])$1([^0-9]|$)"; then
      printf '%s\n' "$file"
    fi
  done | paste -sd, - || true
}

# cited_ids: every requirement ID the test files mention, one per line, sorted. One pass over
# the tests, so the pre-commit hook stays fast with many requirements.
cited_ids() {
  test_files | while IFS= read -r file; do
    grep -v 'traceability: ignore' "$file" 2>/dev/null | grep -oE 'REQ-[0-9]{3,}' || true
  done | sort -u
}

# check_done_requirements_are_tested <requirement-rows> <cited-ids>: every done requirement
# appears in a test.
check_done_requirements_are_tested() {
  local id status
  while read -r id status; do
    if [ "$status" = "done" ] && ! grep -qx "$id" <<<"$2"; then
      warn "$id is done but no test references it (rule: $(rule_file_hint requirements))"
      FAILURES=$((FAILURES + 1))
    fi
  done <<<"$1"
}

# check_tests_cite_known_requirements <requirement-rows> <cited-ids>: no invented IDs in tests.
check_tests_cite_known_requirements() {
  local id
  while IFS= read -r id; do
    if [ -n "$id" ] && ! grep -q "^$id " <<<"$1"; then
      warn "tests cite $id, which is not in docs/requirements (rule: $(rule_file_hint requirements))"
      FAILURES=$((FAILURES + 1))
    fi
  done <<<"$2"
}

# print_matrix: markdown table requirement | status | tests | commits.
print_matrix() {
  local id status tests commits
  echo "| Requirement | Status | Tests | Commits |"
  echo "|-------------|--------|-------|---------|"
  while read -r id status; do
    tests="$(tests_citing "$id")"
    commits="$(git log --oneline --grep="Refs:.*$id" 2>/dev/null | wc -l | tr -d ' ')"
    printf '| %s | %s | %s | %s |\n' "$id" "$status" "${tests:-—}" "$commits"
  done < <(requirement_rows)
}

if [ "${1:-}" = "--matrix" ]; then
  print_matrix
  exit 0
fi
ROWS="$(requirement_rows)"
CITED="$(cited_ids)"
check_done_requirements_are_tested "$ROWS" "$CITED"
check_tests_cite_known_requirements "$ROWS" "$CITED"
[ "$FAILURES" -eq 0 ] || exit 1
echo "traceability OK"
