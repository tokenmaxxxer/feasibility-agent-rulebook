# issue-26 coding record

subject: issue-26
code_under_review: (this branch, HEAD after phase-2 commit)
loop_state: phase-2-complete

## Why

Phase-1 proposal (docs/issue-26/proposals/verdict-semantics.md) approved
via PR #27 merge (Approve on issue-26/coding). Issue #26 upstream basis:
three feasibility records used the `verdict` field inconsistently for the
same class of condition, costing orchestrator round-trips; this pins
selection semantics so the field maps mechanically.

## What was done

- `feasibility/hooks/directive.sh` PROPOSAL section: add the three-way
  selection criteria (blocking-external -> `conditional`;
  two-way-in-repo-resolvable -> `go` + `verdict_provisional`;
  scope-constraint-only -> `go` + body note) and the bare-value-only rule.
- `feasibility/hooks/directive.sh` EXECUTION JUDGMENT section: name
  `verdict_provisional` (underscore, body-level, per controller #89
  precedent) explicitly as distinct from the existing `verdict-provisional`
  (hyphenated) loop_state value already documented there.
- `README.md` "What `feasibility` decides": same selection-criteria pin.
- `README.md` "Record vocabulary": name `verdict_provisional` and
  distinguish it from `verdict-provisional`.

## What did not work

(none — straightforward prose edit)

## Open findings

None open. Resolution path: n/a — no findings addressed to this role are
outstanding.

## Next steps

None — commit, push, and PR are this turn's remaining steps, completed
alongside this record.

## closed_checks

- grep-verify: `grep -n "verdict_provisional" feasibility/hooks/directive.sh README.md`
  finds the convention named in both files. code_sha: (this branch HEAD)
