# Proposal — technical-feasibility domain rulebook maturation (issue-30)

Phase 1 only. No execution in this PR. Survey:
`docs/issue-30/reports/technical-feasibility/survey.md`. Scout brief:
`docs/issue-30/reports/technical-feasibility/scout-brief.md`.

This proposal covers the technical probe of the `feasibility` role only
(TELOS's narrowest axis — see scout-brief angle (a)); it does not
re-derive `prior_art`, `legal_regulatory`, or `threat_model`, which already
have their own skills and are out of this issue's scope.

## (a) Phase-1 PROPOSAL norms for the technical-feasibility domain

A phase-1 technical-feasibility proposal (the document that, for some
future issue, proposes how a specific technical question will be
resolved) must follow this methodology and mandatory-section skeleton,
modeled on this repo's own established proposal shape
(issue-31/issue-34) plus MADR's "considered options" discipline:

**Methodology**: state the question as a single answerable claim (not a
broad area — spike-report's existing discipline), name the candidate
approaches/technologies under consideration (plural — never a single
foregone option), and commit a timebox + acceptance criteria BEFORE
investigation starts (spike-report's timestamp discipline, unchanged).

**Mandatory sections:**
1. `## Question` — the single technical claim being tested.
2. `## Candidates considered` — every option evaluated, including ones
   rejected early, each with a one-line reason (MADR's "Considered
   Options," not Nygard's silent-rejection style — this repo needs the
   rejected options visible because a later reader must be able to tell
   "did we look at X" without re-running the investigation).
3. `## Timebox and acceptance criteria` — agreed before work starts,
   timestamped (spike-report skill, referenced not duplicated).
4. `## Evidence format` — every factual claim about a candidate
   (maintenance health, license, security posture, production track
   record) must cite a source: a URL, a repo path + line, or an
   OpensSF-Scorecard-style automated check output. A claim with no
   citation is not evidence — the proposal may not assert "X is well
   maintained" without a check or link.
5. `## Reversibility` — one-way vs. two-way door tag for the eventual
   decision (reversibility-tag skill, referenced not duplicated).

Citation format required in `## Evidence format`: `<claim> — <source:
URL | path:line | check-name score>`. No bare assertions.

## (b) Phase-2 RECORD norms

The phase-2 deliverable is the actual `docs/issue-<n>/reports/
feasibility.md` record's technical-probe field, expanded per this
rulebook to always point at (or inline, if short) a structured record —
modeled on Nygard's ADR spine with MADR's options section grafted in:

**Mandatory components** (the ADR-style record):
1. **Title** — one line, the technical question resolved.
2. **Status** — `proposed | accepted | superseded`, mirroring the
   feasibility record's own `pass|fail|blocked` vocabulary at the
   probe-field level (the ADR's `Status` field is distinct from and sits
   alongside, never replaces, the probe resolution field already
   required by `feasibility/hooks/directive.sh`).
3. **Context** — why this question needed resolving now (the pressure
   that made it a probe rather than an assumption).
4. **Options considered** — every candidate from the phase-1 proposal's
   `## Candidates considered`, carried forward verbatim or updated with
   what was actually learned; each option's evidence citations carried
   forward too (no unsourced re-assertion in phase 2).
5. **Decision** — which option, and the mechanical verdict class it
   maps to per `feasibility/hooks/directive.sh`'s existing verdict
   selection criteria (go / conditional / no-go) — this proposal does
   not change that mechanical rule, only requires the record to state
   which class applied and why.
6. **Consequences** — what becomes easier/harder, and the
   reversibility tag (one-way/two-way) carried from the phase-1
   proposal or updated if the investigation changed it.
7. **Risks** — enumerated, each disposed `mitigated | accepted |
   deferred` (borrowing the STRIDE-table row-disposition discipline
   already established for the threat-model probe, applied here to
   technical risk so the two probes share one disposition vocabulary
   instead of inventing a second one).

## (c) Rationale for each adopted choice

- **MADR's "Candidates/Options considered" over bare Nygard**: Nygard's
  template does not require listing rejected alternatives. This repo's
  own commit history (issue-31, issue-34 proposals) already shows
  reviewers need to verify "was X considered and rejected, or just never
  looked at" — a silent-rejection ADR cannot answer that. Adopted because
  it matches this repo's existing verification culture (approvers reading
  a record must be able to tell scope was actually surveyed, not
  assumed) rather than because MADR is newer.
- **Nygard's minimal spine (Title/Context/Decision/Consequences) as the
  record's base, not MADR's full annotated template**: this repo already
  keeps its records short (see `docs/issue-31/reports/implementation.md`,
  `docs/issue-34/reports/implementation.md` — a handful of headed
  sections, no elaborate scoring tables in the record itself, scoring
  detail lives in the supporting spike report / evidence files). Adopting
  MADR's full template (with numeric pros/cons weighting per option)
  would duplicate what `build-vs-buy`'s own skill already does at the
  evidence layer; the record only needs to carry the *outcome* of that
  scoring, not re-host it.
- **OpenSSF-Scorecard-style evidence citation, mandatory, not optional**:
  This repo's own `feasibility/hooks/directive.sh` already names
  "OpenSSF-Scorecard-or-equivalent" for the `prior_art` probe. Requiring
  the same citation discipline for the technical probe's evidence keeps
  one evidence standard across probes instead of a stricter one for
  dependency claims and a looser one for architecture claims — since
  both are frequently the same underlying claim (e.g., "this library
  is production-ready" touches both probes).
- **Reversibility tag carried, not re-derived**: `reversibility-tag`
  already exists as a cross-probe field ("a field on every finding,
  never a fifth probe" — the skill's own words). This proposal treats
  it as a load-bearing input to the phase-2 record's `Consequences`
  section rather than inventing a second reversibility concept —
  avoiding the exact "same words, different concepts" trap
  `feasibility/hooks/directive.sh` already had to warn about for
  `verdict_provisional`.
- **Risk disposition vocabulary shared with `stride-table`
  (mitigated/accepted/deferred)**: adopted so a reader scanning any of
  this role's four probe outputs sees one disposition vocabulary, not
  four bespoke ones — reduces the review burden of learning
  probe-specific risk language.
- **TELOS's Economic and Schedule axes explicitly NOT adopted into this
  domain**: those belong to the product/ops roles per this repo's own
  role-scoping (`docs/reports/research/2026-07-27-role-interaction/
  feasibility.md`); re-deriving them here would duplicate another role's
  seat, which contract v3's role-separation already forbids.

## (d) Plugin reflection plan

This section names WHERE the norms above land in the plugin, by path —
none of the following is executed in this PR (phase 1 only).

**Directive (`feasibility/hooks/directive.sh`)**: the technical-probe
paragraph of the `RESEARCH` argument to `core_role_directive` gains two
required-field callouts (still a single physical line per the
`stub-check.sh` structural-check constraint — see
`docs/handbooks/canon-scripts.md` in the core checkout): (1) "candidates
considered, plural, each with a cited reason" and (2) "evidence citation
format: `<claim> — <source>`, no bare assertions." Phase 2 implements
this as a text edit to the existing heredoc string only — no new file,
no vendored logic, canon-referenced `core_role_directive` call signature
unchanged.

**Record fields**: no change to `RECORD_FIELDS_TERMINAL_STATES` in
`feasibility/hooks/hooks.json` (`verdict scope-approved` already covers
the terminal states this proposal's record norms plug into). The ADR-
style mandatory components in (b) are enforced as a **documentation
convention checked at PR review time**, not a new automated gate in this
pass — no new `PreToolUse` hook is proposed. If a future issue wants a
mechanical field-presence gate (e.g., a `record-fields-gate.sh`-style
check for "Options considered" / "Risks" headings), that is out of
scope here and should be its own canon-referenced proposal, per the
issue-31/issue-34 precedent of adding gates by referencing `core`'s
canon scripts rather than hand-writing repo-local ones.

**Gate conditions for phase-2 record completeness** (used at PR-review
time by the human approver, not automated in this pass):
1. All four `## Candidates considered` items from the accepted phase-1
   proposal appear in the phase-2 record's `Options considered`, or a
   stated reason explains why one was dropped.
2. Every evidentiary claim in the record carries a citation per the
   `<claim> — <source>` format; a claim with no citation fails the gate.
3. The technical-probe field in `feasibility.md` resolves to
   `pass|fail|blocked` with evidence (already required by
   `feasibility/hooks/directive.sh`, unchanged) AND the ADR-style record
   exists (inline in `feasibility.md` or linked from it) with all seven
   components from (b) present.
4. Every risk in `Risks` carries a disposition
   (`mitigated|accepted|deferred`); no risk left without one.
5. The reversibility tag is present and consistent with (not
   contradicting) the phase-1 proposal's tag, or the record states why
   it changed.

Canon references only (no copies made or proposed): `core/hooks/lib/
role-directive.sh`, `core/hooks/tests/stub-check.sh`, `docs/handbooks/
canon-scripts.md` (core repo) — per the constraint that
`warrant-hunter`/canon scripts are referenced by path against core's
install root, never vendored (core issue #63/#69 precedent, already
applied to this same `feasibility` plugin by issue-31 and issue-34).

## Open questions for the approver

1. Should the phase-2 ADR-style record be a **separate file**
   (e.g. `docs/issue-<n>/reports/technical-feasibility-adr.md`,
   analogous to a `docs/decisions/` entry) or **inlined** into the
   existing single `feasibility.md` record under the technical-probe
   section? This proposal recommends inline-by-default (fewer files to
   keep in sync, matches the existing "record lives at
   `docs/issue-<n>/reports/feasibility.md` and nowhere else" directive
   language) but flags it as a real design choice, not a foregone one.
2. Should gate condition enforcement (in (d)) become an automated
   `PreToolUse` check in a later issue, or stay a human-review
   convention indefinitely? This proposal takes no position beyond
   "not in this pass."

## Order constraint

No sequencing dependency on any other open issue. This proposal is
independent of and does not touch the `prior_art`, `legal_regulatory`,
or `threat_model` probes' existing skills or directive text.
