## Evidence citation

Every factual claim in a technical-feasibility proposal or record must
carry a citation in the following format, verbatim:

`<claim> — <source: URL | path:line | check-name score>`

A claim with no citation is not evidence. Do not write bare assertions
("X is fast", "Y is well-maintained", "Z scales") without a citation
attached in the format above — pick whichever of the three source
shapes actually applies: a URL for external material, a `path:line`
reference for something found in this repository, or a `check-name
score` for an automated check's output (e.g. an OpenSSF Scorecard
check name and its numeric score).

This applies across both phases of the technical-feasibility cycle:

- Phase 1 (the proposal, under `docs/issue-<n>/proposals/`): every
  claim in the `## Evidence format` section (and any other claim in the
  document) must carry a citation in the required format.
- Phase 2 (the record, under `docs/issue-<n>/reports/`): citations from
  phase 1 must be carried forward, not re-derived from memory. Phase 2
  may not restate a phase-1-cited claim without its citation, and may
  not introduce a new factual claim without a citation of its own. If a
  claim was cited in phase 1 and still holds in phase 2, carry the same
  citation forward rather than dropping it or paraphrasing it
  uncited.
