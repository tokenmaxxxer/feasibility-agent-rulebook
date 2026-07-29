# issue-21 current-state survey

Scope: audit every WAKES-ON/wake mention in this repo's rulebook files
(excluding docs/issue-*) and strip or repoint anything naming which role
a state summons.

Scout: skipped — pure mechanical grep-and-edit task, no design decision
open (scout-directive skip condition 1).

## Grep results (`grep -ril wake . --include='*.md'`, minus docs/issue-*)

- `README.md:19` — "A `verdict: go` is what wakes coding." Names the
  downstream role explicitly. WRITE SET: repoint to on-the-record
  `docs/specs/wake-routing.md` canon.
- `docs/proposals/2026-07-26-contract-v2-conformance.md` — multiple
  wake/WAKES-ON mentions. This is a dated historical proposal (decision
  archive of what v2 conformance changed), not live rulebook behavior;
  out of scope — proposals are point-in-time records, not something the
  role re-executes.
- `feasibility/hooks/directive.sh:64-71` — "YOUR RECORD IS THE BOARD ...
  WAKES-ON reads docs/issue-<n>/reports/feasibility.md ONLY". This is a
  statement about THIS role's own record file/format (what gets read),
  not a statement of which OTHER role gets summoned. Keep, per issue
  text ("keep statements about this role's own record states/format").

No other `.claude-plugin` manifests, skills, or tests reference wake
routing.

Write set: `README.md` only.
