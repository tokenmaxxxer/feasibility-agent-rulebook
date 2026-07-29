status: landed
loop_state: landed
code_under_review: 26f6551

## What was done

- `README.md:19` — replaced "A `verdict: go` is what wakes coding." with
  a repoint to on-the-record `docs/specs/wake-routing.md` as canon for
  wake routing, per issue-21.

## Why

Wake-routing ownership migration step 3 (operator decision 2026-07-30):
canon for which role a state summons now lives at on-the-record
`docs/specs/wake-routing.md`; this rulebook must contain nothing that
names which role a state summons. Upstream basis: issue #21, and core
contract s3's WAKES-ON table removal (tokenmaxxxer-core#36).

## What did not work

(none — single-line repoint, no false starts)

## Scope

Only `README.md` needed a change. `feasibility/hooks/directive.sh`'s
"YOUR RECORD IS THE BOARD" section was surveyed and kept: it states
this role's own record-file location, names no downstream role.
`docs/proposals/2026-07-26-contract-v2-conformance.md` is a dated
historical decision archive, out of scope.

## Open findings

None open.

## Hunt

Skipped — mechanical single-line doc repoint, no execution surface
(no code, no runtime behavior change) for the warrant-hunter to probe.
