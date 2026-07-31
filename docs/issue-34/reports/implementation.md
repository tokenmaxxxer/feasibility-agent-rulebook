# Record — issue-34 (implementation)

loop_state: landed

## Why

core #69 confirmed canon: `stub-check.sh` runs from core's installed copy
(`core/hooks/tests/stub-check.sh`) only; a vendored copy in any rulebook
is itself a stub-check violation. This repo carried a vendored copy of
`stub-check.sh` from issue-31's execution (a distribution-pattern
deviation at the time). Removing it closes that drift surface for
`feasibility/`, per the approved phase-1 proposal.

## Upstream basis

- core issue #69 (`tokenmaxxxer-core`): stub-check canon rollout, adds a
  check that a rulebook carries no vendored `stub-check.sh` copy.
- `docs/handbooks/canon-scripts.md` / `docs/handbooks/role-gates-tests.md`
  (canon-reference invocation convention).
- `docs/issue-34/proposals/2026-07-31-stub-check-reclaim.md` (this repo,
  phase 1, approved via issue comment `APPROVE issue-34/implementation`).
- `docs/issue-34/reports/implementation/survey.md` (this repo, phase 1).

## What was done

Executed the approved proposal's items 1-3:

1. Deleted `feasibility/hooks/tests/stub-check.sh` (the vendored copy;
   removed the now-empty `tests/` directory alongside it).
2. `feasibility/hooks/hooks.json`: no change. Re-confirmed per the survey
   — `stub-check.sh` was never registered there (only a `SessionStart`
   entry pointing at `directive.sh` exists); nothing to remove.
3. Ran stub-check via core's canon-referenced invocation (no local copy):

   ```
   bash <core-plugin-root>/hooks/tests/stub-check.sh feasibility
   ```

   **Pass**, full output:

   ```
   stub-check: ok — no vendored 'trailer-gate.sh' under feasibility
   stub-check: ok — no vendored 'record-fields-gate.sh' under feasibility
   stub-check: ok — no vendored 'handbook-trigger-gate.sh' under feasibility
   stub-check: ok — no vendored 'parse-check.sh' under feasibility
   stub-check: ok — no vendored 'stub-check.sh' under feasibility
   stub-check: ok — feasibility/hooks/directive.sh is a role-directive stub
   ```

   Includes the core #69 item-2 check (no vendored `stub-check.sh`) that
   motivated this reclaim.

## Preserved (unchanged)

- `feasibility/hooks/directive.sh`, `feasibility/hooks/hooks.json`'s
  `SessionStart` entry, `RECORD_FIELDS_TERMINAL_STATES` env — untouched.

## Open findings

None. Mechanical deletion plus a canon-referenced re-run, matching the
proposal exactly; no design axis was open.
