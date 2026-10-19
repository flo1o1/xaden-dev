# Deferred work

Review findings that are real but not fixed in the change that found them (REQ-125). The assistant adds a row
only after you agree to defer; it never defers silently. The file is append only: a row leaves it only when it
becomes a requirement or is dropped, in a commit whose message says which. Decisions and lessons go to
`docs/decisions/`, accepted vulnerabilities with an owner and expiry go to `docs/security-exceptions.md`.

Every row needs a source (a requirement ID or a branch), a one-sentence summary, and evidence: why it is real, or
for an unverified finding what would prove it. `scripts/check-deferred-work.sh` fails on a row without one of them
and on a `REQ-nnn` that does not exist.

| Source | Summary | Evidence |
|--------|---------|----------|

<!-- Example row:
| REQ-012 | Export ignores the time zone of the user | `tests/export_test.py::test_zone` fails when the zone is not UTC |
-->
