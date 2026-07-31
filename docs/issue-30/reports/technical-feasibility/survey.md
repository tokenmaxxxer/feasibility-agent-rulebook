# Current-state survey — technical-feasibility rulebook maturation (issue-30)

Scout: not skipped — see `docs/issue-30/reports/technical-feasibility/scout-brief.md` (2 stages).

## What this repo is

This repo (`tokenmaxxxer-feasibility` marketplace, `feasibility` plugin at
`feasibility/`) is the **feasibility role rulebook** on contract v3: four
probes — `technical`, `prior_art`, `legal_regulatory`, `threat_model` —
each resolved to `pass|fail|blocked` with evidence before a
go/no-go/conditional verdict. Issue-30's "technical-feasibility domain" is
this role's **technical probe** specifically (the narrowest of the four,
mapping to TELOS's "T" — see scout-brief angle (a)).

## What already exists (skills — the mechanism layer)

- `feasibility/skills/spike-report/SKILL.md` (+ `templates/spike-report-template.md`):
  the timeboxed-investigation methodology for the technical probe.
  Field skeleton: Spike Title, Description/Goal, Type, Estimated Timebox,
  Acceptance Criteria (pre-committed, timestamp-disciplined),
  Tasks/Activities, Outcomes/Learnings, Recommendation, Open questions.
- `feasibility/skills/reversibility-tag/SKILL.md`: one-way/two-way door
  classification, a field on every finding (not a fifth probe).
- `feasibility/skills/build-vs-buy/SKILL.md`, `license-scan/SKILL.md`,
  `stride-table/SKILL.md`: cover the other three probes.

## What already exists (rulebook/directive layer)

- `feasibility/hooks/directive.sh` sources
  `core/hooks/lib/role-directive.sh`'s `core_role_directive` function
  (canon-referenced, not vendored — the pattern established by issue-31
  "core canon reference transition" and issue-34 "reclaim vendored
  stub-check.sh"). It already states, at a high level: the technical
  probe needs "a spike-report or ATAM-style summary, plus a reversibility
  classification"; the record lives at `docs/issue-<n>/reports/feasibility.md`
  and nowhere else; all four probes must resolve `pass:<evidence> |
  fail:<evidence> | blocked:<evidence>` before a verdict.
- `feasibility/hooks/hooks.json`: `RECORD_FIELDS_TERMINAL_STATES=
  "verdict scope-approved"`; only a `SessionStart` hook (no `PreToolUse`
  gates vendored locally — those are canon-referenced from core).

## What is missing (the gap issue-30 exists to close)

The directive gives a one-paragraph *sketch* of the technical probe's
evidence bar ("a spike-report or ATAM-style summary, plus a reversibility
classification") but there is no rulebook-level document specifying:

1. What a **phase-1 technical-feasibility proposal** must structurally
   contain as a document (mandatory sections, citation format) —
   as opposed to what evidence a spike report skill produces internally.
2. What a **phase-2 technical-feasibility record** must structurally
   contain — beyond "resolves to pass/fail/blocked with evidence," there
   is no mandated options-considered / comparison-criteria / decision /
   risks skeleton analogous to an ADR.
3. No `docs/decisions/` ADR template exists yet (directory is an empty
   placeholder — `docs/decisions/README.md` says "Empty at initial
   build").
4. No `docs/specs/state-machine.md` exists yet — referenced as
   authoritative by `docs/specs/README.md` but not yet written; out of
   scope for this issue, noted only so the proposal does not assume its
   contents.

## Prior phase-1 proposals as structural template

`docs/issue-31/proposals/2026-07-31-core-canon-reference-transition.md`
and `docs/issue-34/proposals/2026-07-31-stub-check-reclaim.md` establish
this repo's phase-1 proposal shape: H1 title, an unlabeled
survey-pointer sentence ("Phase 1 only. No execution in this PR. Survey:
`<path>`."), `## Scope`, `## Preserved (...)`, `## Open questions for the
approver`. This proposal (docs/issue-30/proposals/) follows that shape,
adapted for a rulebook-maturation proposal rather than a mechanical
file-move, per the issue's own four required sections (a)-(d).

## No existing technical-feasibility.md records

No `docs/issue-*/reports/feasibility.md` exists yet anywhere in this
repo — this is the first rulebook-maturation pass before any real
phase-2 feasibility record has been produced under it. There is nothing
to reconcile against; this proposal is greenfield for the record format.
