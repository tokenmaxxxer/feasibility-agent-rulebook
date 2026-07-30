# Proposal: strip routing-side vocabulary from the feasibility rulebook

files: `README.md`, `feasibility/hooks/directive.sh`

## Request (paraphrased intent, secrets stripped)

The rulebook currently leaks routing-mechanism knowledge (wake, board-as-routing-device,
WAKES-ON, downstream-role reads, a pointer to on-the-record's wake-routing.md spec) into
the feasibility role's own directive. Restate every record obligation as a plain
record-format requirement instead: path, kind, loop_state vocabulary, required fields,
write the record first in phase 2, update loop_state on every transition, commit it on
the branch. Do not mention wake, waking, board-as-routing, WAKES-ON, downstream roles, or
who reads the record, and drop the wake-routing.md pointer.

## Constraints

- Historical docs (`docs/issue-*`, `docs/proposals/`, `docs/reports/`) stay untouched —
  they are a record of past decisions, not live rulebook text.
- The record-format substance itself (path `docs/issue-<n>/reports/feasibility.md`,
  loop_state values, write-first-in-phase-2, update-every-transition, commit-on-branch)
  must survive the edit — only the routing framing is removed.
- No change to gate scripts' enforced behavior (`record-fields-gate.sh`,
  `trailer-gate.sh`, `handbook-trigger-gate.sh`) — this is a wording change to the
  SessionStart directive and the README, not a behavior change.

## What will be done

1. `README.md`: remove the sentence "Which role a `verdict: go` wakes is canon at
   [on-the-record `docs/specs/wake-routing.md`](...), not this rulebook." from the "What
   `feasibility` decides" section. The section still states the role's deliverables
   (constraint list, verdict, measurement design) with no routing mention.
2. `feasibility/hooks/directive.sh`: reword the "YOUR RECORD IS THE BOARD" block to a
   record-format-only requirement, e.g.:

   > RECORD REQUIREMENTS (do not skip this): the record lives at
   > docs/issue-<n>/reports/feasibility.md and nowhere else — research files, surveys, and
   > proposals are not the record. Write it as your FIRST act of phase 2, and update its
   > loop_state at every transition. Ending phase 2 without your record committed on the
   > branch means the required record was never delivered.

   This drops WAKES-ON, "the board", "woken"/"wake-up", and "downstream role" while
   keeping every enforceable obligation (path, write-first, loop_state updates, must be
   committed).

## Out of scope

- `docs/issue-21/**` and `docs/proposals/2026-07-26-contract-v2-conformance.md` (historical,
  explicitly excluded by the issue).
- Any change to `docs/specs/wake-routing.md` itself (owned by on-the-record, not this repo).
- Any behavior change to gates/tests — `tests/run-gate-tests.sh` and
  `tests/parse-check.sh` must still pass unmodified.

## How it'll be known to work

- `grep -rIn -iE "WAKES-ON|wake-routing|board-as-routing|downstream role|woken|waking"`
  over `README.md` and `feasibility/hooks/directive.sh` returns nothing.
- `bash tests/parse-check.sh` and `bash tests/run-gate-tests.sh` still pass (directive.sh
  remains valid bash, gate behavior unchanged).
- The reworded block still names: record path, write-first-in-phase-2, loop_state-update-
  every-transition, and committed-on-branch — verified by reading the diff.
