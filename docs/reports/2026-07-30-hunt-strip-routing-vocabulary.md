---
proposal: docs/proposals/2026-07-30-strip-routing-vocabulary.md
---

# Hunt record — strip-routing-vocabulary

## after-proposal — stance 1: gate scripts/tests may grep removed vocabulary, breaking silently

Verdict: NO FINDING
Seed: uncommitted diff to README.md and feasibility/hooks/directive.sh removing WAKES-ON/wake-routing/board-as-routing/downstream-role/woken/waking wording, replacing "YOUR RECORD IS THE BOARD" with "RECORD REQUIREMENTS" while keeping the record path, write-first-in-phase-2, loop_state-update, must-be-committed-on-branch requirements.

Checked `grep -rniE "wakes-on|wake-routing|board-as-routing|downstream role|woken|waking|YOUR RECORD IS THE BOARD" tests/run-gate-tests.sh feasibility/hooks/handbook-trigger-gate.sh feasibility/hooks/trailer-gate.sh feasibility/hooks/record-fields-gate.sh` -- no matches in any gate script or test file (only doc/proposal/survey files reference the phrases, as expected). Ran `bash tests/run-gate-tests.sh` -- all 7 tests pass (record-complete, record-empty, open-no-backlog, foreign-path, commit-no-trailer, commit-with-trailer, commit-non-issue). The gate scripts key off structural content (record path, field names, trailer format) rather than the routing-vocabulary prose, so the reword does not touch any load-bearing string. The record path, write-first-in-phase-2, loop_state-update-every-transition, and must-be-committed-on-branch requirements are all preserved verbatim in the reworded block.
