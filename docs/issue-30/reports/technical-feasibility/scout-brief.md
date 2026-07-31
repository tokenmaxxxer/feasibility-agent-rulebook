# Scout brief — technical-feasibility rulebook maturation (issue-30)

Stages used: 2 (1: repo current-state survey via Explore sub-agent; 2: one
parallel web sweep, 4 angles, single message). Wall clock: well under the
3-minute budget. Saturation judged reached after the single sweep — all
four angles returned convergent, well-documented, non-contradictory
material from multiple independent sources each; a second round would not
have changed the adopted set.

## Angle (a) — TELOS / classic feasibility study structure

Textbook systems-analysis feasibility studies use the TELOS mnemonic:
Technical, Economic, Legal, Operational, Scheduling. The "technical"
axis alone asks whether current technology/expertise/resources can
deliver the requirement. This repo's `feasibility` role plugin already
runs a **superset** of TELOS (`technical`, `prior_art`, `legal_regulatory`,
`threat_model` probes) — `prior_art`+`legal_regulatory` split what TELOS
calls "Legal", `threat_model` is TELOS's operational-risk axis pushed to a
formal method (STRIDE), and "Economic"/"Schedule" are out of this role's
seat (product/ops own those). issue-30's "technical-feasibility domain" is
therefore the **technical probe specifically** — TELOS's narrowest axis —
not a re-derivation of the whole four-probe role.

## Angle (b) — ADR formats (Nygard, MADR)

Nygard's original ADR: Title / Status / Context / Decision /
Consequences — minimal, no mandatory alternatives list. MADR extends it
with an explicit "Considered Options" section plus per-option
pros/cons, for exactly the case where a choice among named alternatives
needs to be shown, not just asserted. Both are short, numbered/dated,
one-decision-per-file documents.

## Angle (c) — spike / PoC norms and dependency health scoring

Spike norms (already encoded in this repo's `spike-report` skill):
question + timebox agreed before work, acceptance criteria written
before work, timestamp discipline against post-hoc rationalization.
OpenSSF Scorecard: ~18 automated checks (branch protection, CI, code
review, vulnerability reporting, maintained-signal, cryptographic
signing) scored 0-10 per check, -1 for inconclusive — the industry
reference point for "per-dependency health evidence" already named in
`feasibility/hooks/directive.sh`'s `prior_art` probe.

## Angle (d) — build-vs-buy / vendor evaluation

Convergent multi-vector scoring: strategic differentiation vs.
commodity, total cost of ownership (3-5yr horizon, not sticker price),
time-to-market, integration cost, resourcing — each vector weighted and
scored, summed to a ranked verdict, not a single-factor call.

## Must-bes (carried into the proposal)

- A verdict is never asserted without named alternatives considered
  (MADR's contribution over bare Nygard).
- A spike/PoC always carries a pre-committed timebox + acceptance
  criteria (already enforced by this repo's `spike-report` skill —
  proposal must not weaken this, only cite it).
- Dependency/vendor health is evidence-scored (OpenSSF-Scorecard-style
  or equivalent), never asserted from familiarity/hype.
- Reversibility (one-way vs. two-way door) scales the evidence bar —
  already a first-class field via `reversibility-tag`; the proposal
  keeps it, does not reinvent it.

## Performance axes surfaced across all four angles

Evidence traceability (every claim cites a source/check, not "seems
fine"), alternatives-considered (not a single foregone option),
timeboxing discipline, and a mechanical (not vibes-based) verdict rule.

## Adopt / skip

- Adopt: MADR-style "considered options" section for the phase-2 record;
  Nygard's minimal Title/Context/Decision/Consequences skeleton as the
  record's spine; OpenSSF-Scorecard-style evidence citation for any
  dependency claim; spike-report's pre-commit timebox discipline
  (already present, reference not re-derive).
- Skip: full TELOS re-derivation (out of this probe's scope — economic/
  schedule axes belong to product/ops roles); a bespoke build-vs-buy
  scoring rubric invented from scratch (the existing `build-vs-buy`
  skill already exists in this repo and is referenced, not replaced).

## Gap line

This repo already has skills (`spike-report`, `reversibility-tag`,
`build-vs-buy`, `license-scan`, `stride-table`) that operationalize most
of the scouted methodology at the *skill* level. What is missing is the
**rulebook-level norm**: what phase-1 proposal documents and phase-2
`feasibility.md` records must structurally contain (mandatory sections,
citation format) so that a proposal/record is checkable independent of
which skill produced its evidence. That gap is what this proposal fills.

Sources:
- [How to Do a TELOS Feasibility Study — Mindtools](https://www.mindtools.com/afr89t8/how-to-do-a-telos-feasability-study/)
- [TELOS Feasibility Analysis — ResearchGate](https://www.researchgate.net/publication/396978584_TELOS_Feasibility_Analysis_for_Application_Development_Project_using_System_Dynamics_Approach)
- [Documenting Architecture Decisions — Cognitect (Nygard)](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [MADR — Use Markdown Architectural Decision Records](https://adr.github.io/madr/decisions/0000-use-markdown-architectural-decision-records.html)
- [ADR Templates — adr.github.io](https://adr.github.io/adr-templates/)
- [OpenSSF Scorecard — GitHub](https://github.com/ossf/scorecard)
- [OpenSSF Scorecard — openssf.org](https://openssf.org/projects/scorecard/)
- [Build vs. Buy Software Decision Framework — BETSOL](https://www.betsol.com/blog/build-vs-buy-software-decision-framework/)
- [ThoughtWorks — Build vs. Buy strategic framework (PDF)](https://www.thoughtworks.com/content/dam/thoughtworks/documents/e-book/tw_ebook_build_vs_buy_2022.pdf)
