# MADR options-considered discipline

This project follows MADR's "Candidates/Options considered" discipline for
technical-feasibility work. It applies at two points in the lifecycle:

- **Phase 1 (proposal)**: the section must be named `## Candidates considered`
  verbatim.
- **Phase 2 (record)**: the section must be named `## Options considered`
  verbatim.

Rules that apply at both phases:

1. **Plural candidates required.** A list of exactly one candidate is not a
   comparison; it is a foregone conclusion presented as analysis. Every
   `## Candidates considered` / `Options considered` section must enumerate
   two or more candidates.
2. **One-line rejection reason per candidate.** Each candidate that is not the
   chosen option must carry a concrete, one-line reason it was rejected.
   "Not chosen" or similar content-free filler does not satisfy this — state
   the actual tradeoff or disqualifying fact.
3. **Carry-forward rule.** Every candidate named in the phase-1 proposal's
   `## Candidates considered` must reappear in the phase-2 record's
   `Options considered` section. A candidate may be dropped between phases
   only if the phase-2 record explicitly states `dropped: <reason>` for it.
   Silent disappearance of a phase-1 candidate is not permitted.

## Order constraint (owned by this gate)

The phase-1 write must also carry a `## Timebox and acceptance criteria`
section in the same document. This is a document-shape (ordering)
requirement, not a content-quality one: a feasibility proposal must commit to
a timebox and acceptance criteria before (or alongside) laying out the
candidates it will compare, so that "how long, how will we know" is decided
before comparison work can be used to justify running long. This plugin's
`PreToolUse` gate enforces this timebox-before-candidates check together with
the `## Candidates considered` check, on the same phase-1 write.
