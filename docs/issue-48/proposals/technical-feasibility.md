---
subject: issue-48
role: technical-feasibility
---

# Proposal — A+ 인증 마감: 감사 차단 사유 해소 (phase 1 design)

Phase 1 only. No execution in this PR — `tests/run-gate-tests.sh` is not
edited here.

files touched in phase 2: `tests/run-gate-tests.sh` (`run()`'s gate
invocation, one line).

## Current-state survey

market_argument_supplied: false — this proposal reads issue #48's single
named defect on its own terms (a re-audit finding), not through any
argument that fixing it unlocks value; the issue text carries no market
argument to withhold.

Issue #48's blocker: "루트 `tests/run-gate-tests.sh`의 core canon
케이스에 `CLAUDE_ROLE` 설정(record-complete/foreign-path 2케이스 붉음
해소) 또는 케이스 정리" — the two core-canon cases that expect `allow`
currently come back red.

`tests/run-gate-tests.sh`'s `run()` helper invokes the gate script as a
bare subprocess with only `CLAUDE_PROJECT_DIR` set —
`| env CLAUDE_PROJECT_DIR="$td" /bin/bash "$gate" >/dev/null 2>&1` —
`tests/run-gate-tests.sh:27`. `CLAUDE_ROLE` is never exported into that
environment anywhere in the file — grepping `tests/run-gate-tests.sh`
for `CLAUDE_ROLE` returns zero hits, this session's own read of the full
file.

The gate this harness drives, core canon `record-fields-gate.sh`, denies
unconditionally when `CLAUDE_ROLE` is unset: `role="${CLAUDE_ROLE:-}"`
then `[ -n "$role" ] || deny "record-fields-gate: no CLAUDE_ROLE in the
environment; the gate cannot resolve which record is this role's own."`
— `record-fields-gate.sh:34,37` (installed core checkout at
`/home/jwjung/.claude/plugins/marketplaces/tokenmaxxxer/runs/rulebooks/
tokenmaxxxer-core/core/hooks/record-fields-gate.sh`, `deny()` exits 2).
With `CLAUDE_ROLE` empty, every one of the four `record-fields-gate.sh`
cases in `tests/run-gate-tests.sh:20-33` gets `got=exit-2`/`deny`
regardless of content: the two cases that `want=deny`
(`record-empty`, `open-no-backlog`) happen to match and read green, but
the two that `want=allow` (`record-complete`, `foreign-path`) mismatch
and read red — exactly the two cases and only those two the issue names.
This is the same "role-token not threaded into the harness's own
subprocess environment" class as issue-45's `REC`-fixture defect —
`docs/issue-45/reports/technical-feasibility/survey.md:20-44` — just on
the env-var side of the same gate integration rather than the path
literal.

This repo's own live, enforced role for this session is confirmed
`CLAUDE_ROLE=technical-feasibility` — the same value `REC` at
`tests/run-gate-tests.sh:20` (`docs/issue-7/reports/
technical-feasibility.md`) already encodes post-issue-45, and the same
value `README.md:8-9` documents as the contract's enforced role/record
naming.

No spike or open design question is involved — the fix shape is fully
determined by the gate's own visible requirement (`record-fields-gate.
sh:34,37`) and this repo's own already-established role literal
(`tests/run-gate-tests.sh:20`); nothing here is a one-way door or an
unresolved technical unknown, so no reversibility tag applies to this
proposal's scope.

## Timebox and acceptance criteria

Phase 2 timebox: one focused session, a single-line change — the defect
is already located to `tests/run-gate-tests.sh:27` and the fix is
"export the same role literal the fixture path already uses," not open
design work. Acceptance: `bash tests/run-gate-tests.sh` (root, with
`CLAUDE_PLUGIN_ROOT_CORE` resolved to an installed core checkout) reports
`record-complete` and `foreign-path` as `ok` (want=allow got=allow);
`record-empty` and `open-no-backlog` remain `ok` (want=deny got=deny,
unchanged); no new fail count anywhere else in the same run; the fix
touches only `tests/run-gate-tests.sh`'s `run()` environment line, no
gate script under `core/hooks/**` is edited (referenced only, per
`docs/handbooks/canon-scripts.md`'s reference-not-copy rule, same
constraint issue-42 and issue-45 applied). The phase-2 record cites the
actual green run's output per issue #48 requirement 3.

## Candidates considered

1. **Export `CLAUDE_ROLE=technical-feasibility` on the gate subprocess
   invocation at `tests/run-gate-tests.sh:27` (chosen).** Matches the
   role literal `REC` already hardcodes at `tests/run-gate-tests.sh:20`
   (fixed under issue-45), gives the gate the one input it requires to
   resolve `RECORDS_RE` (`record-fields-gate.sh:109`), and needs no
   change to gate logic — the four cases already send the right
   content/path, only the environment was incomplete.
2. **Delete or restructure the `record-complete`/`foreign-path` cases
   instead ("케이스 정리", the issue's named alternative) (rejected).**
   Would turn the harness green by removing coverage rather than fixing
   the integration gap — these two cases are the only ones in the file
   that assert the gate's `allow` path at all (the other two assert
   `deny`); deleting them would leave `record-fields-gate.sh`'s
   allow-path behavior completely unverified by this repo's own harness,
   the same "coverage hidden behind restructuring" failure issue-45's
   proposal already rejected for its analogous case — `docs/issue-45/
   proposals/2026-08-01-gate-a-plus-final-remediation.md:36-44`
   ("Candidates considered" item 2). Rejected: a real, one-line
   environment fix is available and the issue itself frames
   `CLAUDE_ROLE` setting as the default resolution ("케이스 정리" appears
   second, joined by "또는").
3. **Read `CLAUDE_ROLE` from the outer test-runner's own environment via
   `${CLAUDE_ROLE:?}` instead of hardcoding the literal in `run()`
   (rejected).** Would make the harness resilient to a future role
   rename without editing this file again, but reproduces exactly the
   "role-agnostic fixture hides drift" trade issue-45 already rejected
   for `REC` — `docs/issue-45/proposals/2026-08-01-gate-a-plus-final-
   remediation.md:36-44` ("Candidates considered" item 2): the file's
   own stated purpose is exercising *this repo's actual, current* role
   — `tests/run-gate-tests.sh:4-11` header comment — and a literal keeps
   that assertion self-documenting and readable without depending on the
   invoking shell's environment being correctly set. Rejected for
   consistency with the sibling `REC` decision already landed in this
   file.

## Rationale

The chosen fix is the smaller, symmetric completion of issue-45's own
`REC` fix: issue-45 corrected the *path* half of the gate's two required
inputs (`RECORDS_RE` needs both a role-scoped path and a resolved
`CLAUDE_ROLE` to match against it — `record-fields-gate.sh:109`); this
issue closes the *role* half, which issue-45's survey and proposal did
not touch — `docs/issue-45/reports/technical-feasibility/survey.md:20-127`
scopes its four defects to the `REC` literal, the `hooks.json` matcher,
the `missing-core` case, and README prose; `CLAUDE_ROLE` in `run()`'s
subprocess environment is not among them. Both fixes point at the same
underlying gate requirement from different sides, and both are pure
literal insertions against an already-established value, not new logic.

## Verdict

verdict: go

This is a two-way, in-repo-resolvable prerequisite — a one-line
environment-variable addition inside this repo's own test harness, fully
reversible, with no external dependency and no open design question —
`record-fields-gate.sh:34,37` fully determines what value is required
and `tests/run-gate-tests.sh:20` already establishes the literal to use.
verdict_provisional: yes — the fix itself (`tests/run-gate-tests.sh:27`)
has not landed yet; phase 2 lands it and the phase-2 record cites the
resulting green run per issue #48 requirement 3.

## Scope note (issue #48 requirement 2)

Requirement 2 ("sales만 해당") does not apply to this role/repo — this
is the `technical-feasibility` rulebook, not `sales` — issue #48's core
#78 dependency is scoped explicitly to `sales`'s own `stub-check` case,
per the issue body's own "sales만 해당" qualifier. No action taken here
on that requirement.

## Out of scope

- Any change to `core/hooks/record-fields-gate.sh` itself — referenced
  only, per `docs/handbooks/canon-scripts.md`'s reference-not-copy rule.
- Any other defect class in `tests/run-gate-tests.sh` beyond the two
  named cases — issue #48 names exactly one blocker, and a broader
  pre-audit is disproportionate to a single-line fix and would duplicate
  issue-45's already-closed remediation pass.

## Evidence format

Citation format used throughout this proposal:
`<claim> — <source: path:line | URL | check-name score>` —
`docs/handbooks/canon-scripts.md` conventions applied.

## How you'll know it worked

- This proposal PR is open against `main`, referencing `#48` (plain, not
  Closes/Fixes), with this proposal committed under `docs/issue-48/`.
- On Approve, phase 2 lands the one-line `CLAUDE_ROLE=technical-feasibility`
  export in `tests/run-gate-tests.sh:27`: `bash tests/run-gate-tests.sh`
  reports `record-complete` and `foreign-path` as `ok` (currently `FAIL`),
  with the other two core-canon cases unchanged and no new failures
  elsewhere in the run.
