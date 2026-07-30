# issue-26 current-state survey

Scope: pin verdict-field semantics (`go`/`no-go`/`conditional`) in this
rulebook — selection criteria per condition class, the bare-value-only
field rule, and the `verdict_provisional` naming convention.

Scout: skipped — the issue text fully specifies the mapping to pin
(three condition classes -> three dispositions, field-vs-body split,
convention name); no design decision is left open
(scout-directive skip condition 2).

## Where verdict semantics currently live

- `feasibility/hooks/directive.sh` PROPOSAL section: "promise ... the
  verdict (go|no-go|conditional, with a conditions: list when
  conditional)" — states the enum and that `conditional` carries a
  `conditions:` list, but gives no criteria for WHICH condition class
  maps to which value.
- `feasibility/hooks/directive.sh` EXECUTION JUDGMENT section: defines
  `verdict-provisional` (hyphenated) as a **loop_state** value — draft
  disposition before the human's PR-Approve act (`feasible /
  infeasible / feasible-with-conditions`). This is a distinct concept
  from the issue's `verdict_provisional` (underscore) convention: the
  issue's convention is a **body-level marker on a `go` verdict**
  recording an in-repo-resolvable prerequisite, per controller #89
  precedent — not the phase-1-vs-accepted loop_state distinction
  already documented here. Both will coexist; naming them identically
  in prose would collide, so the new text must name the field-level
  convention explicitly as `verdict_provisional` and note it is
  separate from the `verdict-provisional` loop_state.
- `README.md` "What `feasibility` decides" section: "Produces ...
  a `verdict: go|no-go|conditional`" — same gap, no selection
  criteria.
- `README.md` "Record vocabulary" section: lists `status`/`loop_state`
  values including `verdict-provisional`, and the four probe fields.
  No verdict-field selection-criteria text exists here either.
- `feasibility/hooks/record-fields-gate.sh`: gates on `status`
  (loop_state), not on the `verdict` field's value or narrative
  placement — enforcing the field-carries-bare-value rule here would be
  a second gate, out of scope for a docs-only semantics pin (issue asks
  to pin semantics in the rulebook text, not to add enforcement).

No other file in this repo (`feasibility/skills/**`, `tests/**`)
mentions the verdict enum or its selection criteria.

## Write set

- `feasibility/hooks/directive.sh` — PROPOSAL and EXECUTION JUDGMENT
  sections.
- `README.md` — "What `feasibility` decides" and "Record vocabulary"
  sections.

No dependency, env var, or migration surface is touched; this is a
prose-only rulebook change to two existing files.
