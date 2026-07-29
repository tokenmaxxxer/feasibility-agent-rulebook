## Request

Wake-routing ownership migration step 3: canon now lives at on-the-record
`docs/specs/wake-routing.md`. This rulebook must contain nothing about
which role wakes next; keep only statements about this role's own
record states/format.

## Constraints

- Only strip/repoint mentions that name which role a state summons.
- Keep this role's own record-state/format statements untouched.
- Historical dated proposals under `docs/proposals/` are decision
  archives, not live behavior — out of scope.

## What will be done

- `README.md:19` — replace "A `verdict: go` is what wakes coding." with
  a repoint to on-the-record `docs/specs/wake-routing.md` as the canon
  for wake routing.

## Out of scope

- `feasibility/hooks/directive.sh`'s "YOUR RECORD IS THE BOARD" section
  — states this role's own record file is what gets read, names no
  downstream role.
- `docs/proposals/2026-07-26-contract-v2-conformance.md` — historical
  record of a past migration, not live rulebook content.

## How it'll be verified

`grep -ril wake . --include='*.md'` (minus docs/issue-*) shows no
remaining role-naming wake statement outside the allowed exception.
