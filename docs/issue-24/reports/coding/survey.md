# issue-24 current-state survey

Subject: issue-24. Scope: strip routing-side vocabulary (wake, board-as-routing-device,
WAKES-ON, downstream roles, pointers to wake-routing.md) from this rulebook; restate
record obligations as pure record-format requirements. Historical docs untouched.

## Scan

`grep -rIn -iE "WAKES-ON|wake-routing|board-as-routing|downstream role|the board|woken|waking"`
across the tree (excluding `.git`) hits:

- `README.md:19-20` — "Which role a `verdict: go` wakes is canon at
  [on-the-record `docs/specs/wake-routing.md`](...), not this rulebook." A pointer to the
  routing spec, in scope for removal per the issue ("pointers ... also go").
- `feasibility/hooks/directive.sh:64-71` — the "YOUR RECORD IS THE BOARD" block: "WAKES-ON
  reads docs/issue-<n>/reports/feasibility.md ONLY", "the board never saw your work and no
  downstream role can ever be woken by it", "machine wake-up dead". This is the injected
  role directive (SessionStart hook output) — in scope.
- `docs/issue-21/reports/coding.md`, `docs/issue-21/proposals/wake-routing-migration.md`,
  `docs/proposals/2026-07-26-contract-v2-conformance.md`, `docs/issue-21/reports/coding/survey.md`
  — historical docs/issue-* and docs/proposals trees. Issue says these stay untouched.

No hits in `.claude/`, `docs/specs/`, `docs/handbooks/`, skills, or gate scripts beyond the
two files above.

## Write set (frozen)

- `README.md` — drop the wake-routing pointer sentence in "What `feasibility` decides".
  Keep the rest of that section (constraint list / verdict / measurement design already
  routing-free). The existing "Record vocabulary" section is already pure record-format
  (path, loop_state values, probe field vocabulary) — no change needed there.
- `feasibility/hooks/directive.sh` — reword the "YOUR RECORD IS THE BOARD" heading and body
  to a record-format-only requirement: record path, write-first-in-phase-2, update
  loop_state every transition, must be committed on branch. Drop WAKES-ON, "board",
  "woken"/"wake-up", "downstream role".

No other files change. No new dependency, env var, schema, or migration.

## Scout-directive skip record

Skip condition: pure text/vocabulary edit restating existing obligations in different
words — no design decision is open (the target record fields, paths, and phase
boundaries are already fixed by contract v3 and this repo's existing "Record vocabulary"
section). Scouting is not applicable; skipped under the "spec literally leaves no design
decision open" condition.
