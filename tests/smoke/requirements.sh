# shellcheck shell=bash
# Smoke test area "requirements" (docs/requirements/requirements). Sourced by tests/smoke.sh, which
# defines the helpers and creates the demo project first.

# demo_variant <name> <sed-expression>: a copy of the adopted demo project's requirements with REQ-001 edited.
demo_variant() { requirements_variant "$1" "$2" "$DEMO"; }

# demo_check <args...>: check-requirements.sh on the adopted demo project.
demo_check() { env PROJECT_ROOT="$DEMO" "$SCAFFOLD_ROOT/template/scripts/check-requirements.sh" "$@"; }

# demo_req <args...>: req.sh on the adopted demo project.
demo_req() { env PROJECT_ROOT="$DEMO" "$SCAFFOLD_ROOT/template/scripts/req.sh" "$@"; }

# demo_rules_text: a file holding the rules an assistant of the adopted demo project reads: xaden/RULES.md and every
# rules topic as `xaden doc rules-<topic>` prints it.
demo_rules_text() {
  local file topic
  file="$(mktemp "$WORKDIR/demo-rules.XXXXXX")"
  cat "$DEMO/xaden/RULES.md" >"$file"
  for topic in "$SCAFFOLD_ROOT"/template/docs/rules/*.md; do
    x_in "$DEMO" doc "rules-$(basename "$topic" .md)" && cat "$XOUT" >>"$file"
  done
  printf '%s' "$file"
}

# REQ-046 functional requirements as jobs to be done, quality requirements as goals
test_job_stories() {
  local rules
  assert_fails_with "a job without a job story is rejected" 'When …, I want to …, so I can …' \
    demo_check "$(demo_variant feature-text 's/^TODO: When .*/Export invoices as PDF./')"
  assert "a job story is accepted" demo_check "$(demo_variant job-story \
    's/^TODO: When .*/When I close a month, I want to export all invoices, so I can send them to my accountant./')"
  assert_fails_with "a quality requirement needs a quality goal" 'Quality goal' \
    demo_check "$(demo_variant quality-without-goal 's/^type: job/type: quality/')"
  assert "a quality requirement with a goal is accepted" demo_check "$(demo_variant quality-goal \
    's/^type: job/type: quality/; s/^## Job/## Quality goal/; s/^TODO: When .*/95 % of searches answer within one second./')"
  assert "a natural job story with 'I want a' is accepted" demo_check "$(demo_variant want-a \
    's/^TODO: When .*/When I close a month, I want a PDF of all invoices, so I can send it to my accountant./')"
  assert "TODO text only warns outside a release" bash -c "PROJECT_ROOT='$DEMO' '$SCAFFOLD_ROOT/template/scripts/check-requirements.sh' 2>&1 | grep -q 'contains TODO text'"
  assert "the word TODO in real content is no marker" bash -c "! '$SCAFFOLD_ROOT/template/scripts/check-requirements.sh' '$(demo_variant todo-word \
    's/^TODO: When .*/When TODOs pile up, I want a list of them, so I can plan the work./; s/^- TODO: .*/- Given open TODOs, when I list them, then all are shown./')' 2>&1 | grep -q 'REQ-001-.*contains TODO'"
  assert_fails_with "unknown requirement type rejected" 'type must be one of' \
    demo_check "$(demo_variant bad-type 's/^type: job/type: story/')"
  # REQ-049 the scaffold uses the format it prescribes
  assert "scaffold's own requirements are finished job and quality files" \
    demo_check --release "$(requirements_dir "$SCAFFOLD_ROOT")"
  rules="$(demo_rules_text)"
  assert "the rules define the job story format" grep -q 'When <situation>, I want to <motivation>, so I can <expected' "$rules"
  x_in "$DEMO" prompt kickoff
  assert "kickoff writes requirements as jobs" grep -q 'Find the jobs my users hire the software for' "$XOUT"
  # REQ-006: requirement history comes from git, not from a hand-kept change log
  assert "the rules point to git for requirement history" grep -q 'git log -- xaden/requirements' "$rules"
  x_in "$DEMO" prompt requirements-update && cp "$XOUT" "$WORKDIR/prompt-requirements-update.txt"
  x_in "$DEMO" prompt feature && cp "$XOUT" "$WORKDIR/prompt-feature.txt"
  assert "no hand-kept requirements change log in new projects" \
    bash -c "! grep -qi 'change.log' '$rules' '$WORKDIR/prompt-requirements-update.txt' '$WORKDIR/prompt-feature.txt'"
}

# REQ-047 one file per requirement, epic folders, global IDs, generated index
test_requirement_files() {
  local variant
  assert_fails_with "epic must match the folder" 'does not match folder' \
    demo_check "$(demo_variant wrong-epic 's/^epic: .*/epic: other/')"
  assert_fails_with "id must match the file name" 'file name must start with' \
    demo_check "$(demo_variant wrong-id 's/^id: REQ-001/id: REQ-002/')"
  variant="$(demo_variant duplicate 's/x/x/')"
  cp "$(req_file "$WORKDIR/variants/duplicate" REQ-001)" "$variant/first-epic/REQ-001-copy.md"
  PROJECT_ROOT="$WORKDIR/variants/duplicate" "$SCAFFOLD_ROOT/template/scripts/req.sh" index >/dev/null
  assert_fails_with "duplicate IDs rejected" 'duplicate id' demo_check "$variant"
  variant="$(demo_variant no-epic 's/x/x/')"
  rm "$variant/first-epic/EPIC.md"
  assert_fails_with "every epic folder needs EPIC.md" 'missing EPIC.md' demo_check "$variant"
  variant="$(demo_variant stale-index 's/x/x/')"
  edit_file "$(req_file "$WORKDIR/variants/stale-index" REQ-001)" 's/^# .*/# Renamed job/'
  assert_fails_with "a stale index is rejected" 'stale' demo_check "$variant"
  assert "req.sh new creates the next ID in a new epic" bash -c "PROJECT_ROOT='$WORKDIR/variants/stale-index' \
    '$SCAFFOLD_ROOT/template/scripts/req.sh' new billing job 'Export invoices' | grep -q 'xaden/requirements/billing/REQ-002-export-invoices.md'"
  assert "req.sh new adds the epic and updates the index" bash -c "test -f '$WORKDIR/variants/stale-index/xaden/requirements/billing/EPIC.md' \
    && grep -q '| REQ-002 | job | should | draft | Export invoices |' '$WORKDIR/variants/stale-index/xaden/requirements/INDEX.md'"
  assert "req.sh show prints the requirement file" bash -c "PROJECT_ROOT='$DEMO' '$SCAFFOLD_ROOT/template/scripts/req.sh' show REQ-001 | grep -q '^## Acceptance criteria'"
  # REQ-003: the CC summary is loaded every session; the details are read when code is written or reviewed
  local prompt
  for prompt in feature bugfix refactor code-review; do
    x_in "$DEMO" prompt "$prompt"
    assert "$prompt prompt points to the clean-code details" grep -q 'xaden doc clean-code' "$XOUT"
  done
  # REQ-002: rules already loaded by the tool are not read again at session start
  assert "session start skips a requirements index the tool already loaded" grep -q 'skip it when your tool already loaded it' "$(demo_rules_text)"
}

# REQ-016 traceability
test_traceability() {
  set_status REQ-001 "done" "$DEMO"
  assert_fails "done requirement without test fails" env PROJECT_ROOT="$DEMO" "$SCAFFOLD_ROOT/template/scripts/check-traceability.sh"
  mkdir -p "$DEMO/tests"
  printf 'data = "REQ-001"  # traceability: ignore\n' >"$DEMO/tests/test_ignored.py"
  git -C "$DEMO" add tests/test_ignored.py
  assert_fails "ignored line does not count as a test" env PROJECT_ROOT="$DEMO" "$SCAFFOLD_ROOT/template/scripts/check-traceability.sh"
  assert "matrix skips ignored lines like the check" grep -q '^| REQ-001 | done | — |' <(env PROJECT_ROOT="$DEMO" "$SCAFFOLD_ROOT/template/scripts/check-traceability.sh" --matrix)
  printf '# REQ-001\n' >"$DEMO/tests/test_first.py"
  git -C "$DEMO" add tests/test_first.py
  assert "done requirement with test passes" env PROJECT_ROOT="$DEMO" "$SCAFFOLD_ROOT/template/scripts/check-traceability.sh"
  assert "matrix lists the test" grep -q 'tests/test_first.py' <(env PROJECT_ROOT="$DEMO" "$SCAFFOLD_ROOT/template/scripts/check-traceability.sh" --matrix)
  printf '# REQ-123\n' >"$DEMO/tests/test_ghost.py" # traceability: ignore
  git -C "$DEMO" add tests/test_ghost.py
  assert_fails "test citing unknown requirement fails" env PROJECT_ROOT="$DEMO" "$SCAFFOLD_ROOT/template/scripts/check-traceability.sh"
  git -C "$DEMO" reset -q --hard && git -C "$DEMO" clean -qfd
}

# REQ-126 the index an assistant loads in every session follows the open work, not the history
test_context_budget_index() {
  local big="$WORKDIR/big-project" n epic status id
  mkdir -p "$big/xaden/requirements" && cp "$DEMO/xaden/xaden.conf" "$big/xaden/"
  (
    export PROJECT_ROOT="$big"
    # shellcheck source=SCRIPTDIR/../../template/scripts/requirements-lib.sh
    source "$SCAFFOLD_ROOT/template/scripts/requirements-lib.sh"
    for n in $(seq 1 500); do
      epic="epic-$((n % 5))"
      status="done"
      [ "$n" -gt 50 ] || status=draft
      id="$(printf 'REQ-%03d' "$n")"
      write_epic "$big/xaden/requirements/$epic" "Epic $epic" "The big job of this epic."
      write_requirement "$big/xaden/requirements/$epic/$id-job-number-$n.md" "$id" job "$epic" should "$status" 2026-10-19 \
        "Users can export invoice number $n as a PDF file" "When I close a month, I want export $n, so I can send it." \
        "Given a month, when I export, then I get a PDF."
    done
  )
  assert "REQ-126 the scaffold writes the index and the full table" bash -c "PROJECT_ROOT='$big' '$SCAFFOLD_ROOT/template/scripts/req.sh' index >/dev/null \
    && test -f '$big/xaden/requirements/INDEX-full.md'"
  assert "REQ-126 the index of 500 requirements with 50 open stays under 6144 bytes" \
    test "$(wc -c <"$big/xaden/requirements/INDEX.md")" -le 6144
  assert "REQ-126 a done requirement is only counted in the index" bash -c "grep -q '90 done' '$big/xaden/requirements/INDEX.md' \
    && ! grep -q '| REQ-50[0] |' '$big/xaden/requirements/INDEX.md' && grep -q '| REQ-001 | job | should | draft |' '$big/xaden/requirements/INDEX.md'"
  assert "REQ-126 the full table lists every requirement" test "$(grep -c '^| REQ-' "$big/xaden/requirements/INDEX-full.md")" -eq 500
  assert "REQ-126 list --epic and --status filter" bash -c "test \"\$(PROJECT_ROOT='$big' '$SCAFFOLD_ROOT/template/scripts/req.sh' list --epic epic-1 --status draft | wc -l)\" -eq 10"
  assert_fails_with "REQ-126 list rejects an unknown status" 'status must be one of' env PROJECT_ROOT="$big" "$SCAFFOLD_ROOT/template/scripts/req.sh" list --status finished
  assert "REQ-126 show --brief prints goal and criteria only" bash -c "out=\"\$(PROJECT_ROOT='$big' '$SCAFFOLD_ROOT/template/scripts/req.sh' show REQ-077 --brief)\"; \
    printf '%s' \"\$out\" | grep -q '^## Acceptance criteria' && printf '%s' \"\$out\" | grep -q '^status: done' && ! printf '%s' \"\$out\" | grep -q '^updated:'"
  assert "REQ-126 show without --brief is unchanged" bash -c "PROJECT_ROOT='$big' '$SCAFFOLD_ROOT/template/scripts/req.sh' show REQ-077 | grep -q '^updated: 2026-10-19'"
  echo "stale" >>"$big/xaden/requirements/INDEX-full.md"
  assert_fails_with "REQ-126 a stale full table is rejected" 'stale' "$SCAFFOLD_ROOT/template/scripts/check-requirements.sh" "$big/xaden/requirements"
}

# REQ-127 requirements are found by the files a change touches, and by words, without reading them all
test_scoped_lookup() {
  local scoped="$WORKDIR/scoped-project" req="$SCAFFOLD_ROOT/template/scripts/req.sh" check="$SCAFFOLD_ROOT/template/scripts/check-requirements.sh"
  mkdir -p "$scoped/xaden/requirements/billing" "$scoped/src/billing" "$scoped/tests" "$scoped/legacy"
  printf '# Billing\n\n## Goal\n\nWhen I bill, I want invoices, so I can get paid.\n' >"$scoped/xaden/requirements/billing/EPIC.md"
  scoped_requirement() { # <id> <title> <paths line or empty> <text>
    printf -- '---\nid: %s\ntype: job\nepic: billing\npriority: should\nstatus: done\nupdated: 2026-10-19\n%s---\n\n# %s\n\n## Job\n\nWhen I close a month, I want %s, so I can send it.\n\n## Acceptance criteria\n\n- Given a month, when I close it, then it is done.\n' \
      "$1" "$3" "$2" "$4" >"$scoped/xaden/requirements/billing/$1-$(printf '%s' "$2" | tr -c 'a-z\n' '-' | cut -c1-20).md"
  }
  scoped_requirement REQ-001 "Export invoices" $'paths: src/billing/, tests/*.py\n' "a PDF of all invoices"
  scoped_requirement REQ-002 "Read the old ledger" $'paths: legacy/ledger.csv, ./nothing/here.c\n' "the ledger"
  scoped_requirement REQ-003 "Print receipts" "" "a receipt for each payment"
  cp "$DEMO/xaden/xaden.conf" "$scoped/xaden/"
  touch "$scoped/src/billing/pdf.py" "$scoped/tests/test_pdf.py" "$scoped/legacy/ledger.csv"
  PROJECT_ROOT="$scoped" "$req" index >/dev/null
  assert "REQ-127 req.sh for matches a file below a folder entry" bash -c "[ \"\$(PROJECT_ROOT='$scoped' '$req' for src/billing/pdf.py)\" = 'REQ-001 [done, should] Export invoices' ]"
  assert "REQ-127 req.sh for matches a glob entry" bash -c "PROJECT_ROOT='$scoped' '$req' for tests/test_pdf.py | grep -q '^REQ-001 '"
  assert "REQ-127 req.sh for matches a file entry and a ./ path" bash -c "PROJECT_ROOT='$scoped' '$req' for ./legacy/ledger.csv | grep -q '^REQ-002 '"
  assert "REQ-127 req.sh for names each requirement once for several files" bash -c "test \"\$(PROJECT_ROOT='$scoped' '$req' for src/billing/pdf.py tests/test_pdf.py | wc -l)\" -eq 1"
  assert "REQ-127 a requirement without paths never matches" bash -c "! PROJECT_ROOT='$scoped' '$req' for src/billing/pdf.py tests/test_pdf.py legacy/ledger.csv | grep -q REQ-003"
  assert "REQ-127 a folder name is no prefix match of a longer name" bash -c "test -z \"\$(PROJECT_ROOT='$scoped' '$req' for src/billing-old/x.py)\""
  assert "REQ-127 req.sh find lists requirements holding every word, ignoring case" bash -c "[ \"\$(PROJECT_ROOT='$scoped' '$req' find INVOICES pdf)\" = 'REQ-001 [done, should] Export invoices' ]"
  assert "REQ-127 req.sh find prints one line, not the file" bash -c "test \"\$(PROJECT_ROOT='$scoped' '$req' find ledger | wc -l)\" -eq 1"
  assert_fails_with "REQ-127 req.sh for needs a path" 'usage: scripts/req.sh for' env PROJECT_ROOT="$scoped" "$req" for
  assert "REQ-127 a stale paths entry is named and only warns" bash -c "out=\"\$(PROJECT_ROOT='$scoped' '$check' '$scoped/xaden/requirements' 2>&1)\"; \
    printf '%s' \"\$out\" | grep -q 'REQ-002: paths entry \"nothing/here.c\" matches no file or folder' && ! printf '%s' \"\$out\" | grep -q 'REQ-001: paths' && PROJECT_ROOT='$scoped' '$check' '$scoped/xaden/requirements' >/dev/null 2>&1"
  assert "REQ-127 req.sh new leaves paths out" bash -c "PROJECT_ROOT='$scoped' '$req' new billing job 'Refund a payment' >/dev/null && ! grep -q '^paths:' '$scoped'/xaden/requirements/billing/REQ-004-*.md"
  assert "REQ-127 the session start asks for req for and a folder's own AGENTS.md" bash -c "grep -q 'xaden req for <files you plan to change>' '$(demo_rules_text)' && grep -q 'In a folder with its own .AGENTS.md., read that too' '$(demo_rules_text)'"
}

test_job_stories
test_requirement_files
test_traceability
test_context_budget_index
test_scoped_lookup
