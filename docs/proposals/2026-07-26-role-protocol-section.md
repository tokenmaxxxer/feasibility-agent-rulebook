---
status: landed
files:
  - README.md
  - feasibility-cycle/hooks/state-gate.sh
---

# Role protocol section for feasibility

## Intent

A feasibility session currently has to read the full shared
`docs/specs/role-handoff-contract.md` to find the one row it needs — what
`hypothesis` it may accept, and where its own `feasibility-record` and
`spike-report` land. This proposal adds a "Handoff protocol" section to
`README.md` carrying only feasibility's rows, so the session reads one page
scoped to its own role.

## Constraints that change what gets built

- Excerpt only, from `docs/specs/role-handoff-contract.md` at
  `2affe5db7dfb285abaa2860d3004edb3f97c9aec` (root `tokenmaxxxer` repo) —
  feasibility's rows from sections 2, 3, and 7, plus its reading of
  sections 1 and 4.
- The section header pins that SHA; `feasibility-cycle/hooks/state-gate.sh`,
  which already gates feasibility-cycle state transitions, gains a check
  that refuses to proceed when the pinned SHA no longer matches the
  contract's current SHA.
- Per-role path ownership (section 7) is enforced by this same gate, since
  warrant's write-set gate deliberately does not constrain writes under
  `docs/` and section 7 assigns that enforcement to each rulebook.

## What will be done

Add "Handoff protocol" to `README.md` with four parts:

1. **ACCEPTS** — `hypothesis` (the spec to assess; the market argument is
   withheld regardless of what the input contains, per this role's own
   "given to start" rule); refuses `build-proposal`, `qa-state`,
   `review-record`, `ops-state`.
2. **WHERE UPSTREAM LIVES** — `docs/proposals/<date>-<slug>.md` for
   `hypothesis`.
3. **PRODUCES** — `feasibility-record` at
   `docs/reports/records/<subject>/feasibility.md`, required fields: role
   status (`idle,scoped,probing,verdict`), `market_argument_supplied: false`,
   `technical`/`prior_art`/`legal_regulatory`/`threat_model` (each
   `unresolved|pass:<evidence>|fail:<evidence>|blocked:<evidence>`),
   `verdict: go|no-go|conditional` (required once status reaches
   `verdict`), `measurement_design: <description or pointer>` (required
   alongside `verdict`), plus the common header including `handoff_status`;
   and `spike-report` at
   `docs/reports/records/<subject>/spikes/<spike-slug>.md`, required
   fields: Spike Title, Description/Goal, Type, Timebox, Acceptance
   Criteria, Tasks, Outcomes, Recommendation, Open questions, Reversibility
   tag.
4. **STOPS** — upstream stale at role entry (recorded `sha` for the
   `hypothesis` path against its current `sha`); an existing record already
   at a path feasibility does not own under `docs/reports/records/`
   (refuse, report, never overwrite); input carrying
   `handoff_status: provisional` when feasibility is not permitted to treat
   it as final baseline for its verdict.

Also add the SHA-pin check to `feasibility-cycle/hooks/state-gate.sh`.

## Out of scope

Changing `docs/specs/role-handoff-contract.md`. Changing warrant's
`scope-gate.sh` (not present in this repo). The other five rulebook repos.
Starting any feasibility-cycle build work.

## How you will know it worked

A feasibility session can answer, from `README.md` alone, what kind it
accepts, where to find it, what it produces and where, and its three stop
conditions. `state-gate.sh` refuses to proceed when the pinned SHA no
longer matches the contract's current SHA, and refuses a write to a
`docs/reports/records/` path feasibility does not own.
