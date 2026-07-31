# Proposal — enforce the technical-feasibility methodology mechanically (issue-39)

Phase 1 only. No execution in this PR — no gate script, no hook
registration, no `directive.sh` edit lands here. Survey:
`docs/issue-39/reports/technical-feasibility/survey.md`. Scout: skipped;
reasoning recorded in the survey's section 7 (no external field to
benchmark — the named exemplars are sibling rulebooks in the same repo
family, already inspected directly).

Norm source (per issue-39's own constraint): the methodology adopted in
`docs/issue-30/proposals/2026-07-31-technical-feasibility-rulebook-maturation.md`
sections (a) and (b) — this proposal does not re-derive the methodology,
only proposes how to make it self-enforcing. Rigor benchmark: the
issue's own named exemplar, `pricing-rulebook`'s
`pricing/hooks/methodology-gate.sh` (verified in the survey, 231 lines,
sits "on top of, never instead of," `core`'s `record-fields-gate.sh`),
and `implementation-rulebook`'s multi-file hook machine
(`coding/hooks/{directive,hunt-state,hunt-guard,state,coding-progress-gate}.sh`,
verified to exist and to describe a progress gate + hunt-cadence state
tracker in `coding/hooks/directive.sh`'s own text — file internals beyond
`directive.sh` were not read in this pass, so this proposal cites only
what was directly verified: the file inventory and the directive's
description of what those files do, not their line-by-line logic).

## (a) Directive deepening

`feasibility/hooks/directive.sh`'s `RESEARCH` (phase 1) and `CURRENT-
STATE SURVEY`/`PROPOSAL` (phase 1) arguments already carry the four-probe
evidence-quality bars from issue-30. This proposal adds, to the
`technical:` bullet specifically, the DOCUMENT-SHAPE requirement that
issue-30 defined but never surfaced to the acting agent at session
start:

**Phase-1 addition** (to the `RESEARCH` argument's `technical:` bullet):
name the five mandatory section headers verbatim — `## Question`,
`## Candidates considered`, `## Timebox and acceptance criteria`,
`## Evidence format`, `## Reversibility` — and the ORDER constraint:
timebox and acceptance criteria must be agreed with the human BEFORE
investigation work starts (issue-30 proposal (a), "commit a timebox +
acceptance criteria BEFORE investigation starts"). State the prohibition
explicitly: a technical-feasibility proposal that starts investigating
before the timebox section exists is out of order and must be corrected,
not retroactively backfilled.

**Phase-2 addition** (to the `EXECUTION JUDGMENT` argument): name the
seven ADR-style record components verbatim — Title, Status
(`proposed|accepted|superseded`), Context, Options considered, Decision
(with the mechanical verdict-class mapping already required),
Consequences, Risks (each disposed `mitigated|accepted|deferred`) — and
the two judgment rules issue-30 (b) states but does not currently appear
in `directive.sh`: (1) every phase-1 `## Candidates considered` entry
must be carried into phase-2 `Options considered` or the record must
state why one was dropped — no silent drops; (2) no unsourced
re-assertion in phase 2 — a phase-1 citation is carried forward, not
re-derived from memory.

**Prohibitions, stated per facet** (currently implicit or absent,
proposed to become directive-level text, matching the executable-level
bar the issue asks for — "no one-line summaries"):
- Phase 1: no verdict-shaped language in the phase-1 proposal (the
  proposal states a question and candidates, not a decision — the
  decision is phase 2's act).
- Phase 1: no candidate list of length 1 (issue-30's "plural, never a
  single foregone option," already in `directive.sh` for the probe's
  evidence bar, restated here as a document-shape check target for the
  gate below, not just prose).
- Phase 2: no record transition to a terminal `loop_state` while any of
  the four probes (not just `technical`) is unresolved (already implied
  by "No verdict until ALL FOUR probes resolve," made an explicit
  per-facet prohibition here for the `technical` document-shape check).
- Phase 2: no risk left without a disposition in the `Risks` section.

This is a **text-edit-only** change to the existing heredoc strings in
`feasibility/hooks/directive.sh`, matching issue-30's own precedent
(same file, same mechanism, still sourced unmodified from
`core_role_directive`) — no new file, no vendored logic. Not executed in
this PR.

## (b) Methodology gate design

### Placement and non-duplication

New file: `feasibility/hooks/technical-feasibility-gate.sh`. This is a
role-specific `PreToolUse` gate, additive to (never a replacement for)
`core`'s canon-referenced `record-fields-gate.sh` — the same relationship
`pricing-rulebook`'s `methodology-gate.sh` documents in its own header.
Per `core canon-scripts.md`'s reference-not-copy rule, this file:
- does NOT reimplement §20's generic fields (what-was-done / why /
  upstream-basis / loop_state / open-findings) — those stay
  `record-fields-gate.sh`'s job, invoked via
  `${CLAUDE_PLUGIN_ROOT_CORE}/hooks/record-fields-gate.sh` (canon path,
  never copied — closing the gap the survey found: `hooks.json` already
  sets `RECORD_FIELDS_TERMINAL_STATES` but never wires the gate in;
  wiring the existing canon gate is part of this proposal's `hooks.json`
  change, not a new gate).
- ADDS only technical-feasibility-domain document-shape checks: the five
  phase-1 section headers, the seven phase-2 ADR components, the
  citation format `<claim> — <source: URL | path:line | check-name
  score>`, and the candidates-plural / no-verdict-in-phase-1 /
  risk-disposition prohibitions from (a) above.

### Write-surface targeting

Two regexes, mirroring `pricing-rulebook`'s pattern:
- `^docs/issue-[0-9]+/proposals/.*technical-feasibility.*\.md$` (phase-1
  proposal)
- `^docs/issue-[0-9]+/reports/feasibility\.md$` (phase-2 record — the
  gate inspects only the technical-probe-relevant content within it,
  since this is a shared four-probe record file, not a technical-only
  one; the gate's checks fire only when the record's content indicates
  the technical probe section is present/being written, to avoid denying
  writes that are legitimately about `prior_art`/`legal_regulatory`/
  `threat_model` only).

Anything else: pass through (`exit 0`) — not this gate's business,
exactly as both reference gates already do.

### Checks (fail-closed, deny with a specific missing-element list)

Phase-1 proposal writes:
1. All five section headers present (`## Question`, `## Candidates
   considered`, `## Timebox and acceptance criteria`,
   `## Evidence format`, `## Reversibility`).
2. `## Candidates considered` names 2+ items (a naive heuristic: 2+
   list-item markers or 2+ named-option sub-headers under that section —
   exact parsing logic is an implementation-time decision, not fixed
   here).
3. Citation format present at least once when `## Evidence format`
   contains prose (a bare `## Evidence format` with zero `—` /
   `source:`-shaped citations denies).
4. No verdict-shaped keyword (`go`, `no-go`, `conditional`, `verdict:`)
   appears outside a clearly-quoted/future-tense context — this check is
   the highest false-positive risk in the design and is flagged as an
   open question below rather than specified exactly.

Phase-2 record writes (technical-probe section only):
5. Seven ADR components present, matched by header/keyword (Title is the
   probe's own claim line, so checked as "a `Status:` field exists" plus
   "a `Decision:` field exists" etc., not a literal `## Title` header,
   since issue-30 (b) describes fields more than fixed headers for this
   part — implementation should decide exact matching against the
   accepted issue-30 text, not against this proposal's paraphrase).
6. Every phase-1 candidate name found in `Options considered`, OR an
   explicit "dropped: <reason>" note per missing one (best-effort string
   match against the phase-1 proposal file this record's technical
   section should reference — cross-file checks add real complexity;
   flagged as an open question below).
7. Every `Risks` entry carries `mitigated|accepted|deferred`.

Kill switch: `TECHNICAL_FEASIBILITY_METHODOLOGY_GATE_OFF=1`, matching the
naming convention both reference gates use.

### State tracking for the order constraint

Issue-30's only genuine ORDER constraint is: timebox + acceptance
criteria agreed BEFORE investigation work starts (phase 1 only; phase 2
has no order constraint beyond "record as first act," already covered by
`record-fields-gate.sh`'s general "record must exist" pressure). This is
a single before/after check, not a multi-stage state machine — unlike
`implementation-rulebook`'s `coding-progress-gate.sh` +
`hunt-state.sh`/`hunt-guard.sh`, which track a genuinely multi-step
build/hunt cadence across an entire phase 2.

Proposed mechanism: **no separate state file**. The order constraint is
checked structurally within a single document write: a proposal write
that contains `## Candidates considered` content (i.e., candidates
already named/evaluated, implying investigation happened) but omits
`## Timebox and acceptance criteria` fails check 1 above already — the
missing-section check IS the order enforcement, because issue-30's
document shape puts the timebox section ahead of the evidence section
positionally, and a same-write gate that requires all five sections
present by the time a proposal is written already prevents "investigate
first, backfill the timebox section later" as a *committed* artifact.
What it cannot catch is investigation happening in the agent's own
tool-call history before any document write at all (e.g., web searches
run before the timebox is agreed, with the timebox document written
only afterward) — catching that would need a session-level tool-call
transcript check, which is a materially heavier mechanism than a
`PreToolUse` content gate and is NOT proposed here. This is stated as a
known limitation, not silently glossed: the gate enforces the DOCUMENT's
order, not the AGENT's actual investigation order. Closing that fully
would require the kind of session-state tracker `implementation-
rulebook`'s `hunt-state.sh` implements for its own hunt cadence — out of
scope for this proposal unless the approver wants that heavier
mechanism; flagged as an open question.

### `hooks.json` change (named, not executed here)

Add a `PreToolUse` entry (matcher `Write|Edit|MultiEdit`) invoking, in
order: (1) the canon-referenced `record-fields-gate.sh` (wiring the
already-set `RECORD_FIELDS_TERMINAL_STATES` env var to an actual gate —
closing a survey-found gap that predates this issue), then (2) the new
`feasibility/hooks/technical-feasibility-gate.sh`. Both fail-closed
independently; either denying blocks the write.

## (c) Gate test design

Extend `tests/run-gate-tests.sh` (or add a sibling
`tests/technical-feasibility-gate-tests.sh` — naming is an implementation
choice) with cases for the new gate, following the existing `run()`
helper's shape (synthesize a `tool_input` JSON payload on stdin, invoke
the gate binary as a subprocess, assert `allow`/`deny` by exit code
0/2). Minimum case set:
- allow: phase-1 proposal with all five sections, 2+ candidates, cited
  evidence.
- deny: phase-1 proposal missing `## Timebox and acceptance criteria`.
- deny: phase-1 proposal with a single candidate.
- deny: phase-1 proposal with an evidence claim carrying no citation.
- allow: phase-2 record with all seven ADR components, all risks
  disposed.
- deny: phase-2 record with a `Risks` entry carrying no disposition.
- allow: foreign path (e.g. `docs/issue-7/reports/verify.md`) — pass
  through regardless of content.
- allow (kill switch): gate off via
  `TECHNICAL_FEASIBILITY_METHODOLOGY_GATE_OFF=1`, any content.

**Fix the pre-existing broken harness as part of implementation, not as
a new problem this proposal introduces**: the survey found
`tests/run-gate-tests.sh` already references `record-fields-gate.sh` and
`trailer-gate.sh` as same-directory local files under
`feasibility/hooks/`, neither of which exists there (0/7 passing today,
all `exit-127`). Any implementation of this proposal must either (i)
change the harness to resolve canon-referenced gates via
`CLAUDE_PLUGIN_ROOT_CORE`-style path resolution instead of a hardcoded
`$HOOKS/$3`, matching issue-34's reference-not-copy fix for
`stub-check.sh`, or (ii) if the approver decides those two gates should
in fact be wired in as role-local invocations for this plugin (a design
question this proposal does not resolve), fix the invocation
accordingly. Leaving the harness silently broken while adding a new gate
next to it would contradict the issue's own request for a working gate
+ test pair.

## (d) Agents / checklists

The technical-feasibility methodology (per issue-30) does not have a
genuinely repeated multi-step procedure comparable to
`implementation-rulebook`'s hunt cadence (dispatch-a-hunter-at-two-fixed-
points, re-cleared each time) — it is a single document-shape discipline
per issue, applied once in phase 1 and once in phase 2. **This proposal
recommends no new `agents/` directory and no dedicated checklist agent**:
the directive text (a) plus the gate (b) already cover the full
methodology; a checklist agent would duplicate the gate's own checks in
prose form with no additional enforcement value, and the existing
`spike-report`/`reversibility-tag`/`stride-table`/`license-scan`/
`build-vs-buy` skills already serve as the checklist-equivalent reference
material for each probe. This is a recommendation, not a foregone
conclusion — flagged as an open question below in case the approver
wants a lighter checklist skill purely for onboarding readability (not
enforcement).

## Open questions for the approver

1. **Verdict-shaped-language check (phase-1 check 4)**: is a keyword-
   presence heuristic (denying `go`/`no-go`/`conditional`/`verdict:` in
   a phase-1 proposal) acceptable given its false-positive risk (e.g. a
   candidate's own name or a quoted exemplar could contain "go"), or
   should this check be dropped from the gate and left as directive-text
   + PR-review only, the way issue-30 itself deferred looser judgment
   calls to human review?
2. **Cross-file candidate-carry-forward check (phase-2 check 6)**:
   worth the complexity of a gate that reads a second file (the phase-1
   proposal) to verify carry-forward, or should this stay a PR-review
   convention (as issue-30's own gate-condition 1 already assumed it
   would)?
3. **Order-constraint depth**: is the document-shape-implies-order
   enforcement in (b) sufficient, or does the approver want a genuine
   session-level state tracker (à la `hunt-state.sh`) to catch
   investigation happening before the timebox document exists? This is
   the single biggest scope/complexity fork in this proposal — a state
   tracker would materially change (c)'s test design and add new files
   analogous to `implementation-rulebook`'s `state.sh`/`hunt-state.sh`.
4. **`tests/run-gate-tests.sh` harness fix**: confirmed broken today
   (0/7, pre-existing, not caused by this proposal) — approve fixing its
   canon-reference path resolution as part of this issue's execution, or
   should that be its own separate, narrower issue given it affects
   gates beyond just the new one this proposal adds?
5. **Agents/checklist recommendation in (d)**: confirm "none needed" or
   request a lightweight onboarding checklist skill despite the
   no-additional-enforcement-value argument above.

## Order constraint (for this issue itself)

No sequencing dependency on any other currently-open issue. Depends only
on issue-30's already-merged, already-accepted proposal as its norm
source (a closed dependency, not an open one).
