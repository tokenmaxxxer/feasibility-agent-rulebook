# Current-state survey — issue-39 (methodology enforcement depth)

Phase 1 only. No execution. This survey covers the `feasibility` plugin's
existing depth (directive, gates, tests) against issue #39's ask: turn the
domain methodology adopted in issue-30 into an actual enforcement
mechanism (directive depth + machine gate + gate tests + agents/
checklists), benchmarked against `implementation-rulebook`'s hook-machine
rigor.

## 1. What issue #39 actually asks (verbatim reading of `gh issue view 39`)

Title: "플러그인 심화: 채택 방법론을 강제 장치로 직접 구현
(implementation-rulebook 수준)" — "Plugin deepening: implement the adopted
methodology directly as an enforcement mechanism, to implementation-
rulebook's level."

Problem statement: the previous maturation round (issue-30) adopted a
domain methodology, but it landed only as one directive line (a PRODUCES
summary) and documentation — no enforcement. `implementation-rulebook`'s
hook machine (400+ lines) mechanically enforces its own norms via
progress gates and state tracking; this rulebook has no such device.

Four asks:
1. **Directive deepening**: phase 1 / phase 2 each need concrete
   instructions for the methodology's steps, judgment criteria, and
   prohibitions — no one-line summaries, executable level per facet.
2. **Methodology gate**: a `PreToolUse` gate that mechanically verifies
   the required components of the approved `produces` norm, on the
   record/proposal write surface (references `pricing-rulebook`'s
   `methodology-gate.sh`). If the methodology has an order constraint
   (e.g. investigate → evidence → adopt), enforce it via state tracking.
3. **Gate tests**: pass/reject cases under the repo-root `tests/`.
4. **Agents/checklists**: if the methodology requires a repeated
   procedure, capture it as `agents/` or a checklist.

Constraints: canon scripts are referenced only, never copied (`core
canon-scripts.md`); role boundaries and `write_scope` are unchanged; the
prior maturation issue's adoption-rationale document is the source of
norms (i.e. issue-30's proposal, not a fresh derivation).

## 2. Prior art on this same repo

### issue-30 — technical-feasibility rulebook maturation (methodology source)

- `docs/issue-30/proposals/2026-07-31-technical-feasibility-rulebook-maturation.md`
  is the accepted methodology-adoption proposal issue-39 must treat as its
  norm source. It defines: phase-1 proposal mandatory sections
  (`## Question`, `## Candidates considered`, `## Timebox and acceptance
  criteria`, `## Evidence format`, `## Reversibility`) and phase-2 ADR-
  style record components (Title, Status, Context, Options considered,
  Decision, Consequences, Risks) for the `technical` probe specifically,
  plus 5 gate conditions in its section (d) — explicitly deferred to
  "a future, separately-approved, canon-referenced proposal" as
  **human-review convention, not automated**.
- `docs/issue-30/reports/technical-feasibility.md` (the phase-2 record)
  confirms the reflection that actually landed: only a text edit inside
  `feasibility/hooks/directive.sh`'s `technical:` bullet (two required-
  field callouts: candidates-considered-plural and the citation format).
  Its own "Next steps" section explicitly states: "If a future issue
  wants a mechanical field-presence gate for the ADR-style record
  components, that is its own canon-referenced proposal... not a
  continuation of this one." **Issue #39 is that future issue.**
- The open questions section of the issue-30 proposal left two questions
  unresolved by the approval: (1) inline vs. separate-file ADR record —
  resolved by the record to inline-by-default; (2) whether gate
  enforcement becomes automated later — explicitly left open, "not in
  this pass." Issue #39 is squarely aimed at resolving open question 2.

### issue-34 — stub-check.sh reclaim (canon-reference precedent)

- `docs/issue-34/proposals/2026-07-31-stub-check-reclaim.md` and
  `docs/issue-34/reports/implementation.md` establish the operative
  precedent for "canon scripts referenced, never copied": this plugin
  once vendored a copy of `core/hooks/tests/stub-check.sh` (added in
  issue-31) and issue-34 deleted the local copy, replacing it with a
  path-referenced invocation against `core`'s install root
  (`"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" feasibility`).
  This is the direct precedent any issue-39 gate design must follow: no
  new file under `feasibility/hooks/` should duplicate logic that
  already exists in `core/hooks/`.

### Canon docs referenced by both

- `docs/handbooks/canon-scripts.md` (this repo) is currently a stub —
  "Empty at initial build; see `.gitkeep`." The real content lives in
  the `core` plugin's checkout at
  `docs/handbooks/canon-scripts.md` (verified locally at
  `/tmp/claude-1000/core-canon2/docs/handbooks/canon-scripts.md`,
  the core marketplace checkout used to resolve `CLAUDE_PLUGIN_ROOT_CORE`
  at runtime): "Canon scripts are referenced, never copied... A
  rulebook's own tree never contains a second copy of a core canon
  file... `core/hooks/tests/stub-check.sh` enforces this mechanically...
  a rulebook tree containing a copy of any manifest-listed file fails
  that rulebook's own test run." Any new gate this issue proposes must
  either (a) be genuinely role-specific (technical-feasibility's own
  produces-fields) and live under `feasibility/hooks/`, referencing core
  only for shared machinery, or (b) if it duplicates an existing core
  gate shape, be justified as a role-specific instance rather than a
  copy — matching `pricing-rulebook`'s own `methodology-gate.sh`, which
  is explicitly documented in its own header as sitting "on top of
  (never instead of) the core canon record-fields-gate.sh's generic §20
  fields," not a replacement for it.
- `docs/specs/approvers.md` (this repo, read-only per task constraint):
  a single-account approver list (`JiwonJung94`); the approval mechanism
  is the PR-review Approve action or the exact-string issue comment
  `APPROVE issue-<n>/<role>`, per contract v3 s19 (as already exercised
  by issue-30: `APPROVE issue-30/technical-feasibility`).

## 3. Current directive depth (`feasibility/hooks/directive.sh`)

The whole role directive is one file, ~40 lines of heredoc arguments
passed to `core_role_directive` (sourced, never copied, from
`${CLAUDE_PLUGIN_ROOT_CORE}/hooks/lib/role-directive.sh`):

- The `RESEARCH` argument (phase 1) already carries the four-probe
  structure (`technical`, `prior_art`, `legal_regulatory`,
  `threat_model`), each with an evidence bar and skill pointer. The
  `technical:` bullet (lines ~9-15 of the heredoc) is exactly the one
  issue-30 densified with the two required-field callouts.
- **What's missing relative to issue-39's ask**: this bullet still names
  *what* the technical probe must contain (candidates + citations) but
  does not name the issue-30-adopted proposal SKELETON (the five
  `##`-headed mandatory sections: Question / Candidates considered /
  Timebox and acceptance criteria / Evidence format / Reversibility) nor
  the phase-2 ADR-style record's seven components (Title / Status /
  Context / Options considered / Decision / Consequences / Risks). The
  directive tells the agent *what evidence quality* is required but not
  *what document shape* is required — that shape currently lives only in
  the issue-30 proposal doc, never surfaced to the acting agent at
  session start. This is precisely the "directive one line + doc only"
  gap issue #39 names.
- No PROHIBITIONS are stated per facet beyond the four-probe structure
  itself (e.g., nothing prohibits skipping straight to a verdict without
  the timebox-before-work-starts step, nothing prohibits writing a
  phase-2 Options-considered section that drops phase-1 candidates
  silently).

## 4. Current gate state (mechanical enforcement)

`feasibility/hooks/hooks.json` registers exactly one hook: `SessionStart`
→ `directive.sh`. **There is no `PreToolUse` hook registered in this
plugin at all.** `env.RECORD_FIELDS_TERMINAL_STATES = "verdict
scope-approved"` is set, which is consumed by `core`'s
`record-fields-gate.sh` — but that gate is never wired into this
plugin's own `hooks.json`; the env var is set with no corresponding
`PreToolUse` entry invoking the gate. (Verified: `hooks.json` has one
top-level key under `"hooks"`, `SessionStart`, nothing else — read in
full above.)

Concretely, at the moment, nothing in this plugin's own `hooks.json`
mechanically checks that a write to `docs/issue-<n>/reports/
feasibility.md` or a technical-feasibility proposal doc contains any of
the issue-30-adopted required sections/fields. Enforcement of the
issue-30 methodology is 100% PR-review-time human convention today,
exactly as `docs/issue-30/reports/technical-feasibility.md`'s "Gate"
section states it chose to leave it.

### The `pricing-rulebook` benchmark named by the issue

`pricing-rulebook`'s `pricing/hooks/methodology-gate.sh` (verified at
`/home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/methodology-gate.sh`,
231 lines) is a real, working example of the pattern issue #39 asks for:
a `PreToolUse` gate on `Write|Edit|MultiEdit`, fail-closed on internal
error (`trap __fc EXIT` + `_fc_rc` pattern), that:
- resolves the tool-call's target path and the resulting post-write text
  (handling `Write` full-content, `Edit` old/new-string substitution, and
  `MultiEdit` sequential substitution — refusing when it cannot determine
  the resulting content rather than guessing),
- matches only the role's own write surfaces via regex
  (`docs/issue-<n>/proposals/*pricing*.md`, `docs/issue-<n>/reports/
  pricing.md`) and passes through (`exit 0`) anything else,
- checks for six required methodology elements via keyword/phrase
  presence (method named or an explicit early-exit, family named when
  conjoint language appears, inputs-needed stated, a gate-check result
  present, numeric verdicts carrying a label, a residual/what-this-
  cannot-answer list), and denies (`exit 2`) with a specific message
  naming exactly which elements are missing when any is absent.
- Its own header states explicitly it sits "on top of (never instead of)
  the core canon record-fields-gate.sh's generic §20 fields" — i.e. the
  role gate is additive to, not a replacement for, the already-canon
  `record-fields-gate.sh`.

`core/hooks/record-fields-gate.sh` (verified at
`/tmp/claude-1000/core-canon2/core/hooks/record-fields-gate.sh`, 232
lines) is the generic §20 gate `pricing-rulebook`'s gate sits on top of:
it checks a role's own record (`docs/issue-<n>/reports/${CLAUDE_ROLE}.md`)
for five generic fields (what-was-done, why, upstream-basis, loop_state,
open-findings), plus next-steps/resolution-path when `loop_state` is
non-terminal (terminal states configurable via
`RECORD_FIELDS_TERMINAL_STATES`, which `feasibility/hooks/hooks.json`
already sets to `verdict scope-approved` — set, but currently unused by
this plugin, because no `PreToolUse` hook invokes any gate here at all).

### `implementation-rulebook` benchmark named by the issue

Verified at `/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook`
(a separate, real rulebook repo). Its `coding/hooks/` directory contains
`hunt-state.sh`, `hunt-guard.sh`, `state.sh`, `coding-progress-gate.sh`,
and `directive.sh` — i.e. dedicated state-tracking files plus a
progress-gate, matching the issue's "400+ lines of hook machine, progress
gates and state tracking" description; `coding/hooks/directive.sh`
itself (read in full above, 17 lines of shell wrapping ~4 dense heredoc
arguments) names a `coding-progress gate` that "blocks further build
commits until your record carries the resolved_findings entry and the
finder re-clears," and a "hunt cadence" requirement enforced by
`hunt-guard.sh`/`hunt-state.sh`. This confirms the issue's characterization
is not invented: `implementation-rulebook` genuinely has a multi-file
state-tracking + progress-gate apparatus that `feasibility` currently has
no counterpart to. (I did not open `coding-progress-gate.sh`,
`hunt-guard.sh`, or `hunt-state.sh` line-by-line in this pass — the
`directive.sh` text plus file inventory is sufficient to confirm the
benchmark exists and is real, without importing implementation detail
into this survey; a full line count was not taken and is not claimed.)

## 5. Current gate tests (`tests/`)

`tests/run-gate-tests.sh` (65 lines, this repo) already contains test
cases for `record-fields-gate.sh` (5 cases: record-complete,
record-empty, open-no-backlog, foreign-path, plus two dead `true ||`
guarded cases) and `trailer-gate.sh` (3 cases), invoked as
`"$HOOKS/$3"` where `HOOKS="$HERE/../feasibility/hooks"`.

**Ran it in this survey**: `bash tests/run-gate-tests.sh` →
`0 passed, 7 failed`, every case failing with `exit-127` ("command not
found"). Root cause: `feasibility/hooks/` contains only `directive.sh`
and `hooks.json` (confirmed via `ls`) — neither `record-fields-gate.sh`
nor `trailer-gate.sh` exists in this plugin's tree, local or otherwise.
The test harness invokes them as if they were local files under
`feasibility/hooks/`, which contradicts the canon-scripts.md
reference-not-copy rule the moment someone "fixes" the 127s by copying
the core scripts in. **This existing test file is itself evidence of
the gap issue #39 names**: tests were written anticipating gates that
were never wired in, and the harness's own path convention
(`$HOOKS/$3`, a same-directory local file) is incompatible with the
canon-reference pattern issue-34 already established for this same
plugin (`stub-check.sh` invoked via
`"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh"`).
Any gate design this proposal recommends must also fix (or explicitly
account for) how `run-gate-tests.sh` invokes canon-referenced gates
without vendoring them — a design question folded into the proposal's
gate-test section.

Also present: `deny-only-check.sh` and `parse-check.sh` — not read in
depth in this pass (out of scope for the technical-feasibility-domain
question this issue targets), noted only for completeness of the
`tests/` inventory.

## 6. Agents / checklists

`feasibility/` currently has no `agents/` directory (only `hooks/` and
`skills/`). The five `skills/` (`reversibility-tag`, `stride-table`,
`spike-report`, `license-scan`, `build-vs-buy`) are per-probe reference
material invoked by the directive, not repeated-procedure checklists in
the sense issue #39 asks about (ask 4: "if the methodology requires a
repeated procedure, capture it as agents/ or a checklist"). Whether
issue-30's technical-feasibility methodology has a genuinely repeated
multi-step procedure warranting a dedicated agent, versus being fully
covered by directive text + a gate + the existing `spike-report` skill,
is a design question left to the proposal.

## 7. Scouting decision (per this repo's `scout` plugin)

Per `scout/README.md` (verified at
`/tmp/claude-1000/core-canon2/scout/README.md`), scouting is skipped
only for two conditions: "a pure bugfix" or "the spec literally leaves
no design decision open." Issue #39 is neither — it does leave open
design decisions (gate strictness, state-tracking mechanism, agent vs.
checklist, how to reconcile canon-reference with local test invocation).
However, this issue's field is **not an external competitive product
category** — it is purely internal: implementing an enforcement
mechanism whose complete specification already exists inside this same
repo family (issue-30's adopted methodology, `pricing-rulebook`'s
`methodology-gate.sh` as the explicitly-named benchmark, `core`'s
`record-fields-gate.sh`, and `implementation-rulebook`'s hook machine —
all four already located and read directly in this survey, not through
web reconnaissance). There is no "category's best-in-class product" to
benchmark against externally; the benchmark is a sibling rulebook in the
same monorepo family, already inspected first-hand above. This matches
the precedent recorded at `docs/issue-21/reports/coding/survey.md:8` and
`docs/issue-26/reports/coding/survey.md:10`, both of which record a scout
skip citing the same "no design decision open to an external field"
reasoning style for internal-tooling issues in this repo.

**Decision: skip scouting**, on the following one-line reasoning: the
issue names its own benchmark exemplars (`pricing-rulebook`'s
`methodology-gate.sh`, `implementation-rulebook`'s hook machine) inside
the same tokenmaxxxer rulebook family, both directly readable from this
machine without web search, so a web-reconnaissance sweep would search
for a "best-in-class" that has already been named and located —
`docs/issue-39/reports/technical-feasibility/scout-brief.md` is
therefore not produced; this section is the recorded skip decision in
its place.

## 8. Summary of the gap issue #39 must close

| Facet | Exists today | Missing |
|---|---|---|
| Directive depth | Evidence-quality bullets for `technical:` probe (issue-30) | Document-shape requirements (5 phase-1 sections, 7 phase-2 ADR components); explicit prohibitions; order constraint (timebox agreed before work starts) not stated as a directive-level rule |
| Methodology gate | `RECORD_FIELDS_TERMINAL_STATES` env set, unused | No `PreToolUse` hook registered at all in `feasibility/hooks/hooks.json`; no role-specific gate analogous to `pricing`'s `methodology-gate.sh` |
| State tracking | None | issue-30's order constraint (question → candidates → timebox → evidence → reversibility, in phase 1; then phase-2 ADR referencing phase-1 candidates) has no mechanical sequencing check |
| Gate tests | `tests/run-gate-tests.sh` has test cases, but they reference gate files that do not exist in this plugin → 0/7 pass, all exit-127 | A working gate + tests that actually invoke it (whether canon-referenced or role-local) |
| Agents/checklists | None | Undetermined whether warranted — proposal's call |
