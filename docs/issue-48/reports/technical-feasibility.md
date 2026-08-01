---
subject: issue-48
role: technical-feasibility
loop_state: verdict
---

# Record — A+ 인증 마감: 인증 감사 차단 사유 해소 (phase 2)

## Status

accepted

## Decision

go

## Context

Issue #48's 2026-08-01 re-audit named one blocker: `tests/run-gate-tests.sh`'s core-canon cases `record-complete` and `foreign-path` (both `want=allow`) read red because `run()` invoked the gate subprocess with only `CLAUDE_PROJECT_DIR` set, never `CLAUDE_ROLE` — source: docs/issue-48/proposals/technical-feasibility.md, "Current-state survey". `record-fields-gate.sh` denies unconditionally when `CLAUDE_ROLE` is unset — source: docs/issue-48/proposals/technical-feasibility.md, "Current-state survey" (citing installed core `record-fields-gate.sh:34,37`). The approved phase-1 proposal committed to exporting `CLAUDE_ROLE=technical-feasibility` on that one subprocess invocation, matching the role literal `REC` already hardcodes at `tests/run-gate-tests.sh:20` (fixed under issue-45) — source: docs/issue-48/proposals/technical-feasibility.md, "Candidates considered" item 1.

Requirement 2 ("sales만 해당") does not apply to this role/repo, per the phase-1 proposal's own scope note — source: docs/issue-48/proposals/technical-feasibility.md, "Scope note (issue #48 requirement 2)".

## Why

The chosen fix is the smaller, symmetric completion of issue-45's own `REC` fix: issue-45 corrected the path half of the gate's two required inputs, this issue closes the role half — source: docs/issue-48/proposals/technical-feasibility.md, "Rationale". No new gate logic or design was needed, a pure literal insertion against an already-established value — source: docs/issue-48/proposals/technical-feasibility.md, "Verdict".

## Upstream basis

Phase 2 opened via issue-level comment `APPROVE issue-48/technical-feasibility` posted by an approvers.md account (single-account mode) — source: gh issue view 48 comment, this session's own read. The approved proposal is docs/issue-48/proposals/technical-feasibility.md — source: docs/issue-48/proposals/technical-feasibility.md.

## What was done

`tests/run-gate-tests.sh`'s `run()` helper's gate-subprocess invocation now exports `CLAUDE_ROLE=technical-feasibility` alongside `CLAUDE_PROJECT_DIR` — source: tests/run-gate-tests.sh:27. No other line changed; `core/hooks/record-fields-gate.sh` itself was not touched, referenced only per `docs/handbooks/canon-scripts.md`'s reference-not-copy rule — source: docs/issue-48/proposals/technical-feasibility.md, "Out of scope".

## Confirmation (issue #48 requirement 3)

`bash tests/run-gate-tests.sh` run from repo root, this session, post-fix — source: this session's own `bash tests/run-gate-tests.sh` run:

```
ok     record-complete                    allow
ok     record-empty                       deny
ok     open-no-backlog                    deny
ok     foreign-path                       allow
ok     commit-no-trailer                  deny
ok     commit-with-trailer                allow
ok     commit-non-issue                   allow
== 19 passed, 0 failed == (root + madr-options)
== 16 passed, 0 failed == (nygard-adr-spine)
== 22 passed, 0 failed == (evidence-citation)
== 10 passed, 0 failed, 0 skipped == (aggregate)
```

`record-complete` and `foreign-path` — the two cases issue #48 named — now report `ok`/`allow`, matching their `want=allow` expectation; `record-empty` and `open-no-backlog` remain `ok`/`deny`, unchanged — source: this session's own `bash tests/run-gate-tests.sh` run (verbatim capture above). All three plugin suites (madr-options, nygard-adr-spine, evidence-citation) also report `0 failed`, and the aggregate line reports `10 passed, 0 failed, 0 skipped` — source: same run.

## What did not work

Nothing was reverted or abandoned — the single planned one-line change was sufficient; no follow-on defect surfaced, unlike issue-45's `GOOD`-fixture follow-up — source: this record's own "What was done" section above.

## Consequences

Reversibility: two-way — a single environment-variable export inside this repo's own test harness, fully reversible, no external dependency — source: docs/issue-48/proposals/technical-feasibility.md, "Verdict".

The root suite now reports `record-complete` and `foreign-path` as `ok`, closing the exact defect issue #48 named, with no new failures elsewhere in the same run — source: this session's own `bash tests/run-gate-tests.sh` run.

## Risks

- accepted — the fix hardcodes the role literal `technical-feasibility` in `run()` rather than reading it from the invoking shell's environment; this repeats the same literal-over-indirection choice already made and accepted for the sibling `REC` fixture, rejected candidate 3 in phase 1 — source: docs/issue-48/proposals/technical-feasibility.md, "Candidates considered" item 3. Accepted for consistency with the already-landed sibling decision; no new information changes that judgment.

## Options considered

1. **Export `CLAUDE_ROLE=technical-feasibility` on the gate subprocess invocation at `tests/run-gate-tests.sh:27` (chosen).** Delivered as scoped — matches the role literal `REC` already hardcodes, gives the gate its one required input, no gate-logic change needed — source: docs/issue-48/proposals/technical-feasibility.md, "Candidates considered" item 1; confirmed green by this session's own `bash tests/run-gate-tests.sh` run above.
2. **Delete or restructure the `record-complete`/`foreign-path` cases instead ("케이스 정리") (dropped).** Rejected in phase 1 for hiding the gate's `allow`-path coverage behind restructuring rather than fixing the integration gap, the same failure issue-45's proposal rejected for its analogous case — source: docs/issue-48/proposals/technical-feasibility.md, "Candidates considered" item 2. Not revisited in phase 2; no new information changed that judgment.
3. **Read `CLAUDE_ROLE` from the outer test-runner's own environment via `${CLAUDE_ROLE:?}` instead of hardcoding the literal (dropped).** Rejected in phase 1 for reproducing the "role-agnostic fixture hides drift" trade already rejected for `REC` under issue-45, and for consistency with that sibling decision — source: docs/issue-48/proposals/technical-feasibility.md, "Candidates considered" item 3. Not revisited in phase 2; carried forward as this record's own accepted risk above.

## Next steps

None — verdict is terminal; the one named defect is fixed and confirmed green, and no new failures were introduced — source: this session's own `bash tests/run-gate-tests.sh` run.

## Open findings

None open — this record's one Risks entry above already carries a terminal disposition, accepted — source: this record, "Risks" section. This is the open-finding resolution path: no further action pending.

## Evidence format

Citation format used throughout this record: `<claim> — <source: URL | path:line | check-name score>`. Claims about pre-fix state are carried forward from docs/issue-48/proposals/technical-feasibility.md rather than re-derived; claims about this session's own test run are cited to `tests/run-gate-tests.sh` and this session's own execution of it.
