# shellcheck shell=bash
# Smoke test area "requirements" (docs/requirements/requirements). Sourced by tests/smoke.sh, which
# defines the helpers and creates the demo project first.

# write_requirements_table <root>: a project in the old single-table format.
write_requirements_table() {
  mkdir -p "$1/docs/requirements"
  printf '%s\n' '# Requirements — legacy' '' \
    '| ID      | Requirement | Priority | Status | Acceptance criteria | Updated |' \
    '|---------|-------------|----------|--------|---------------------|---------|' \
    '| REQ-001 | Users export data as CSV | must | done | CSV has a header row | 2026-01-02 |' \
    '| REQ-002 | Pages load fast | should | draft | Start page under 1 s | 2026-02-03 |' \
    '' '## Change log' '' '- 2026-01-02 REQ-001 added: first export.' >"$1/docs/requirements/REQUIREMENTS.md"
}

# REQ-046 functional requirements as jobs to be done, quality requirements as goals
test_job_stories() {
  local check="$PROJECT/scripts/check-requirements.sh"
  assert_fails_with "a job without a job story is rejected" 'When …, I want to …, so I can …' \
    "$check" "$(requirements_variant feature-text 's/^TODO: When .*/Export invoices as PDF./')"
  assert "a job story is accepted" "$check" "$(requirements_variant job-story \
    's/^TODO: When .*/When I close a month, I want to export all invoices, so I can send them to my accountant./')"
  assert_fails_with "a quality requirement needs a quality goal" 'Quality goal' \
    "$check" "$(requirements_variant quality-without-goal 's/^type: job/type: quality/')"
  assert "a quality requirement with a goal is accepted" "$check" "$(requirements_variant quality-goal \
    's/^type: job/type: quality/; s/^## Job/## Quality goal/; s/^TODO: When .*/95 % of searches answer within one second./')"
  assert "a natural job story with 'I want a' is accepted" "$check" "$(requirements_variant want-a \
    's/^TODO: When .*/When I close a month, I want a PDF of all invoices, so I can send it to my accountant./')"
  assert "TODO text only warns outside a release" bash -c "'$check' 2>&1 | grep -q 'contains TODO text'"
  assert "the word TODO in real content is no marker" bash -c "! '$check' '$(requirements_variant todo-word \
    's/^TODO: When .*/When TODOs pile up, I want a list of them, so I can plan the work./; s/^- TODO: .*/- Given open TODOs, when I list them, then all are shown./')' 2>&1 | grep -q 'REQ-001-.*contains TODO'"
  assert_fails_with "unknown requirement type rejected" 'type must be one of' \
    "$check" "$(requirements_variant bad-type 's/^type: job/type: story/')"
  # REQ-049 the scaffold uses the format it prescribes
  assert "scaffold's own requirements are finished job and quality files" \
    "$PROJECT/scripts/check-requirements.sh" --release "$SCAFFOLD_ROOT/docs/requirements"
  assert "AGENTS.md defines the job story format" grep -q 'When <situation>, I want to <motivation>, so I can <expected' "$PROJECT/AGENTS.md"
  assert "kickoff writes requirements as jobs" grep -q 'Find the jobs my users hire the software for' "$PROJECT/prompts/kickoff.md"
  # REQ-006: requirement history comes from git, not from a hand-kept change log
  assert "AGENTS.md points to git for requirement history" grep -q 'git log -- docs/requirements' "$PROJECT/AGENTS.md"
  assert "no hand-kept requirements change log in new projects" bash -c "! grep -qi 'change.log' '$PROJECT/AGENTS.md' '$PROJECT/docs/requirements/README.md' '$PROJECT/prompts/requirements-update.md' '$PROJECT/prompts/feature.md'"
}

# REQ-047 one file per requirement, epic folders, global IDs, generated index
test_requirement_files() {
  local check="$PROJECT/scripts/check-requirements.sh" variant
  assert_fails_with "epic must match the folder" 'does not match folder' \
    "$check" "$(requirements_variant wrong-epic 's/^epic: .*/epic: other/')"
  assert_fails_with "id must match the file name" 'file name must start with' \
    "$check" "$(requirements_variant wrong-id 's/^id: REQ-001/id: REQ-002/')"
  variant="$(requirements_variant duplicate 's/x/x/')"
  cp "$(req_file "$WORKDIR/variants/duplicate" REQ-001)" "$variant/first-epic/REQ-001-copy.md"
  PROJECT_ROOT="$WORKDIR/variants/duplicate" "$PROJECT/scripts/req.sh" index >/dev/null
  assert_fails_with "duplicate IDs rejected" 'duplicate id' "$check" "$variant"
  variant="$(requirements_variant no-epic 's/x/x/')"
  rm "$variant/first-epic/EPIC.md"
  assert_fails_with "every epic folder needs EPIC.md" 'missing EPIC.md' "$check" "$variant"
  variant="$(requirements_variant stale-index 's/x/x/')"
  edit_file "$(req_file "$WORKDIR/variants/stale-index" REQ-001)" 's/^# .*/# Renamed job/'
  assert_fails_with "a stale index is rejected" 'stale' "$check" "$variant"
  variant="$(requirements_variant old-table 's/x/x/')"
  printf '| ID |\n' >"$variant/REQUIREMENTS.md"
  assert_fails_with "the old table format is rejected with a migration hint" 'migrate-requirements.sh' "$check" "$variant"
  assert "req.sh new creates the next ID in a new epic" bash -c "PROJECT_ROOT='$WORKDIR/variants/stale-index' \
    '$PROJECT/scripts/req.sh' new billing job 'Export invoices' | grep -q 'docs/requirements/billing/REQ-002-export-invoices.md'"
  assert "req.sh new adds the epic and updates the index" bash -c "test -f '$WORKDIR/variants/stale-index/docs/requirements/billing/EPIC.md' \
    && grep -q '| REQ-002 | job | should | draft | Export invoices |' '$WORKDIR/variants/stale-index/docs/requirements/INDEX.md'"
  assert "req.sh show prints the requirement file" bash -c "'$PROJECT/scripts/req.sh' show REQ-001 | grep -q '^## Acceptance criteria'"
  assert "CLAUDE.md imports the requirements index" grep -qx '@docs/requirements/INDEX.md' "$PROJECT/CLAUDE.md"
  # REQ-003: the CC summary loads every session; the details are read when code is written or reviewed
  assert_fails "CLAUDE.md does not import the clean-code details" grep -qx '@docs/clean-code.md' "$PROJECT/CLAUDE.md"
  assert_fails "Aider does not preload the clean-code details" grep -q 'docs/clean-code.md' "$PROJECT/.aider.conf.yml"
  local prompt
  for prompt in feature bugfix refactor code-review; do
    assert "$prompt prompt points to the clean-code details" grep -q 'docs/clean-code.md' "$PROJECT/prompts/$prompt.md"
  done
  # REQ-002: rules already loaded by the tool are not read again at session start
  assert "session start skips a requirements index the tool already loaded" grep -q 'skip it when your tool already loaded it' "$PROJECT/AGENTS.md"
}

# REQ-048 migration from the requirements table
test_requirements_migration() {
  local legacy="$WORKDIR/legacy" crafted="$WORKDIR/crafted" migrated
  write_requirements_table "$legacy"
  assert "table migrates to requirement files" env PROJECT_ROOT="$legacy" "$PROJECT/scripts/migrate-requirements.sh"
  migrated="$(req_file "$legacy" REQ-001)"
  assert "migration keeps id, status, priority and date" bash -c "grep -qx 'status: done' '$migrated' \
    && grep -qx 'priority: must' '$migrated' && grep -qx 'updated: 2026-01-02' '$migrated' && grep -qx 'epic: unsorted' '$migrated'"
  assert "migration keeps text and acceptance criteria" bash -c "grep -qx '# Users export data as CSV' '$migrated' \
    && grep -qx -- '- CSV has a header row' '$migrated'"
  assert "migration names the file after the text" test -f "$legacy/docs/requirements/unsorted/REQ-002-pages-load-fast.md"
  assert "migration moves the change log" grep -q 'REQ-001 added: first export.' "$legacy/docs/requirements/README.md"
  assert "migration removes the table" test ! -e "$legacy/docs/requirements/REQUIREMENTS.md"
  assert "migrated requirements validate (TODO job stories warn)" "$PROJECT/scripts/check-requirements.sh" "$legacy/docs/requirements"
  assert_fails_with "migrated TODO job stories block a release" 'before a release' \
    "$PROJECT/scripts/check-requirements.sh" --release "$legacy/docs/requirements"
  write_requirements_table "$legacy"
  assert_fails_with "migration never overwrites requirement files" 'already exist' \
    env PROJECT_ROOT="$legacy" "$PROJECT/scripts/migrate-requirements.sh"

  # A crafted ID must not turn into a path outside docs/requirements (review 2026-10-11-audit-fixes #1).
  write_requirements_table "$crafted"
  mkdir -p "$crafted/docs/requirements/unsorted/REQ-"
  printf '%s\n' '| REQ-/../../../../escaped | Pwn | must | done | x | 2026-01-02 |' >>"$crafted/docs/requirements/REQUIREMENTS.md"
  assert_fails_with "migration rejects an ID that is not REQ-nnn" 'invalid requirement ID' \
    env PROJECT_ROOT="$crafted" "$PROJECT/scripts/migrate-requirements.sh"
  assert "nothing written outside docs/requirements" test -z "$(find "$crafted" -name 'escaped*')"
  assert "no requirement file written before the bad row was found" test -z "$(find "$crafted" -name 'REQ-001-*')"
}

# REQ-016 traceability
test_traceability() {
  set_status REQ-001 "done"
  assert_fails "done requirement without test fails" "$PROJECT/scripts/check-traceability.sh"
  mkdir -p "$PROJECT/tests"
  printf 'data = "REQ-001"  # traceability: ignore\n' >"$PROJECT/tests/test_ignored.py"
  git -C "$PROJECT" add tests/test_ignored.py
  assert_fails "ignored line does not count as a test" "$PROJECT/scripts/check-traceability.sh"
  assert "matrix skips ignored lines like the check" grep -q '^| REQ-001 | done | — |' <("$PROJECT/scripts/check-traceability.sh" --matrix)
  printf '# REQ-001\n' >"$PROJECT/tests/test_first.py"
  git -C "$PROJECT" add tests/test_first.py
  assert "done requirement with test passes" "$PROJECT/scripts/check-traceability.sh"
  assert "matrix lists the test" grep -q 'tests/test_first.py' <("$PROJECT/scripts/check-traceability.sh" --matrix)
  printf '# REQ-123\n' >"$PROJECT/tests/test_ghost.py" # traceability: ignore
  git -C "$PROJECT" add tests/test_ghost.py
  assert_fails "test citing unknown requirement fails" "$PROJECT/scripts/check-traceability.sh"
  git -C "$PROJECT" reset -q --hard && git -C "$PROJECT" clean -qfd
}

# REQ-126 the index an assistant loads in every session follows the open work, not the history
test_context_budget_index() {
  local big="$WORKDIR/big-project" n epic status id
  mkdir -p "$big/docs/requirements"
  (
    export PROJECT_ROOT="$big"
    # shellcheck source=SCRIPTDIR/../../template/scripts/requirements-lib.sh
    source "$SCAFFOLD_ROOT/template/scripts/requirements-lib.sh"
    for n in $(seq 1 500); do
      epic="epic-$((n % 5))"
      status="done"
      [ "$n" -gt 50 ] || status=draft
      id="$(printf 'REQ-%03d' "$n")"
      write_epic "$big/docs/requirements/$epic" "Epic $epic" "The big job of this epic."
      write_requirement "$big/docs/requirements/$epic/$id-job-number-$n.md" "$id" job "$epic" should "$status" 2026-10-19 \
        "Users can export invoice number $n as a PDF file" "When I close a month, I want export $n, so I can send it." \
        "Given a month, when I export, then I get a PDF."
    done
  )
  assert "REQ-126 the scaffold writes the index and the full table" bash -c "PROJECT_ROOT='$big' '$PROJECT/scripts/req.sh' index >/dev/null \
    && test -f '$big/docs/requirements/INDEX-full.md'"
  assert "REQ-126 the index of 500 requirements with 50 open stays under 6144 bytes" \
    test "$(wc -c <"$big/docs/requirements/INDEX.md")" -le 6144
  assert "REQ-126 a done requirement is only counted in the index" bash -c "grep -q '90 done' '$big/docs/requirements/INDEX.md' \
    && ! grep -q '| REQ-50[0] |' '$big/docs/requirements/INDEX.md' && grep -q '| REQ-001 | job | should | draft |' '$big/docs/requirements/INDEX.md'"
  assert "REQ-126 the full table lists every requirement" test "$(grep -c '^| REQ-' "$big/docs/requirements/INDEX-full.md")" -eq 500
  assert "REQ-126 list --epic and --status filter" bash -c "test \"\$(PROJECT_ROOT='$big' '$PROJECT/scripts/req.sh' list --epic epic-1 --status draft | wc -l)\" -eq 10"
  assert_fails_with "REQ-126 list rejects an unknown status" 'status must be one of' env PROJECT_ROOT="$big" "$PROJECT/scripts/req.sh" list --status finished
  assert "REQ-126 show --brief prints goal and criteria only" bash -c "out=\"\$(PROJECT_ROOT='$big' '$PROJECT/scripts/req.sh' show REQ-077 --brief)\"; \
    printf '%s' \"\$out\" | grep -q '^## Acceptance criteria' && printf '%s' \"\$out\" | grep -q '^status: done' && ! printf '%s' \"\$out\" | grep -q '^updated:'"
  assert "REQ-126 show without --brief is unchanged" bash -c "PROJECT_ROOT='$big' '$PROJECT/scripts/req.sh' show REQ-077 | grep -q '^updated: 2026-10-19'"
  echo "stale" >>"$big/docs/requirements/INDEX-full.md"
  assert_fails_with "REQ-126 a stale full table is rejected" 'stale' "$PROJECT/scripts/check-requirements.sh" "$big/docs/requirements"
}

test_job_stories
test_requirement_files
test_requirements_migration
test_traceability
test_context_budget_index
