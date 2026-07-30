status: landed
loop_state: landed
code_under_review: (this commit, README.md + feasibility/hooks/directive.sh routing-vocabulary strip)

## What was done

- `README.md` — removed the sentence "Which role a `verdict: go` wakes
  is canon at on-the-record `docs/specs/wake-routing.md`, not this
  rulebook." from the "What `feasibility` decides" section.
- `feasibility/hooks/directive.sh` — reworded the "YOUR RECORD IS THE
  BOARD" block to "RECORD REQUIREMENTS", dropping WAKES-ON, "the board",
  "woken"/"wake-up", and "downstream role" while keeping the record path
  (`docs/issue-<n>/reports/feasibility.md`), write-first-in-phase-2,
  loop_state-update-every-transition, and must-be-committed-on-branch.

## Why

Issue #24, approved proposal `docs/issue-24/proposals/strip-routing-vocabulary.md`,
approved via merged PR #25 (mergedAt 2026-07-30T00:25:55Z).

## What did not work

None — both edits landed cleanly on the first pass, matching the
proposal's literal wording.

## Scope

Per the approved proposal's frozen write set: `README.md`,
`feasibility/hooks/directive.sh`. No other files touched. Historical
docs (`docs/issue-*`, `docs/proposals/`, `docs/reports/`) and
`docs/specs/wake-routing.md` itself left untouched, per the proposal's
constraints.

## Open findings

None open.

## Hunt

Dispatched coding:warrant-hunter, stance: gate scripts/tests may grep
removed routing vocabulary and break silently. NO FINDING — recorded at
`docs/reports/2026-07-30-hunt-strip-routing-vocabulary.md`.

## closed_checks

- grep-no-routing-vocabulary — code_sha: (this commit); ran
  `grep -rIn -iE "WAKES-ON|wake-routing|board-as-routing|downstream role|woken|waking" README.md feasibility/hooks/directive.sh`,
  no matches.
- parse-check — code_sha: (this commit); `bash tests/parse-check.sh`
  passed (4 files under /bin/bash).
- gate-tests — code_sha: (this commit); `bash tests/run-gate-tests.sh`
  passed all 7 cases.
- warrant-hunt-gate-vocabulary-dependency — code_sha: (this commit); see
  Hunt section above, NO FINDING.

## Next steps

None — phase 2 complete, ready for PR.

## Open finding resolution path

No open findings.
