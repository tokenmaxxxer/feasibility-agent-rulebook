---
status: approved
files:
  - docs/specs/role-handoff-contract.md
  - feasibility-cycle/hooks/run-gate-tests.sh
  - docs/proposals/2026-07-27-repo-local-contract-file.md
---

## Intent

The 2026-07-26 repo-local-contract change made the gate resolve exactly one
root — this repo's own git root — and check it for
`docs/specs/role-handoff-contract.md` before allowing any handoff-protocol
action, refusing with "this repo has no collaboration contract yet" when the
file is absent. That file has never been created in this repo, so the gate
refuses every call unconditionally, and every subject-scoped ownership test
that exercises a handoff action is red for the same single reason: no
contract to check against. This repo needs its own copy of the v2 handoff
contract so Rule 0 (contract-presence) can pass and the tests that depend on
it can actually exercise ownership logic instead of dying at the presence
check.

## Constraints

- The contract content must be the v2 conformance version, not drafted fresh
  — `coding-agent-rulebook` at tag `v2-conformance` is the canonical source
  for this generation of the contract.
- The file must land at exactly the path the gate already checks:
  `docs/specs/role-handoff-contract.md`, resolved from this repo's git root.
- This change only supplies the missing file. It does not touch gate logic
  (already fixed on the `gate-fix` branch, out of scope here) and does not
  touch any other repo.
- No push, no `gh`, no cross-repo write.

## What will be done

- `docs/specs/role-handoff-contract.md`: create it in this repo by taking the
  content of `docs/specs/handoff-protocol.md` from
  `/home/jwjung/tokenmaxxxer/coding-agent-rulebook` as it exists at the
  `v2-conformance` tag (`git show v2-conformance:docs/specs/handoff-protocol.md`)
  and placing it here under the `role-handoff-contract.md` name. Note for the
  implementer: that source file is titled "Handoff protocol" and, in its own
  body, describes itself as coding's role section that behaves *against*
  `docs/specs/role-handoff-contract.md` rather than as the contract itself —
  the wording will need a pass to retitle and reframe it as the contract
  proper (or a different v2-conformance file that is the actual contract
  should be located first) so the landed file does not read as circular.
- `feasibility-cycle/hooks/run-gate-tests.sh`: no logic change; update any
  fixture setup or comments that currently assume the contract file is
  missing, so the test harness reflects the new fixed state rather than
  scaffolding around its absence.
- This proposal file itself.

## Out of scope

- Any repo other than `feasibility-agent-rulebook`.
- Merging the `gate-fix` branch or touching gate logic in `state-gate.sh`.
- Any push or remote operation, and any `gh` usage.
- Editing `coding-agent-rulebook` (read-only source via `git show`).

## How you'll know it worked

Rule 0 (contract-presence) no longer refuses handoff-protocol calls in this
repo: running the gate against a handoff action succeeds past the presence
check instead of returning "this repo has no collaboration contract yet".
The subject-scoped ownership test cases in
`feasibility-cycle/hooks/run-gate-tests.sh` that were previously red purely
because the contract file was absent now pass, since the gate can read
`docs/specs/role-handoff-contract.md` and evaluate ownership logic on its
merits.

## What did not work

- **Sourcing verbatim from `coding-agent-rulebook`'s `v2-conformance` tag as
  the constraints section literally instructs did not work.**
  `git show v2-conformance:docs/specs/handoff-protocol.md` in
  `coding-agent-rulebook` returns coding's own role section, not the
  contract. Its own body says so explicitly: "This document describes only
  how the coding role behaves against whatever
  `docs/specs/role-handoff-contract.md` the work repo carries — it does not
  itself define or certify enforcement of that contract," and its closing
  scope note repeats "it does not amend the contract itself." Landing that
  text verbatim under the `role-handoff-contract.md` name would have been
  circular (a file that is the contract, quoting language that says it is
  not the contract and points at a file of its own name). Per this
  proposal's own implementer note, a different v2-conformance file that is
  the actual contract was located instead: `coding-agent-rulebook`'s own
  `docs/proposals/2026-07-26-contract-v2-conformance.md` cites "the root
  `tokenmaxxxer` repo, landed at commit `b240ec4`, `status: final`" as the
  authoritative source. That file exists at
  `/home/jwjung/tokenmaxxxer/docs/specs/role-handoff-contract.md`
  (`git show b240ec4:docs/specs/role-handoff-contract.md`), titled "Role
  handoff contract (v2: blackboard/event model)," is self-contained, and is
  not framed against a further file of the same name. That content — not
  coding-agent-rulebook's role section — was used as the source for this
  repo's `docs/specs/role-handoff-contract.md`.
- **Making all of `run-gate-tests.sh`'s previously-passing cases pass under
  the strict expectation table did not work, and was not attempted as a
  fix.** Once the contract file lands, cases (a), (d), (e2), (g), (h), (i)
  newly fail (exit 0 instead of the expected deny). This is not a
  contract-presence regression: it is `state-gate.sh`'s owned-path check
  (`docs/reports/records/<subject>/feasibility.md` or
  `.../spikes/<slug>.md` only) never matching these cases' root-level
  `feasibility-record.md` fixture path, because `state-gate.sh` (already
  changed on `gate-fix`, out of scope here) resolves the repo root from its
  own on-disk location only and never consults `$work`/`CLAUDE_PROJECT_DIR`
  — so these fixtures, written under a temp dir, were never reaching the
  gate's owned-path check at all even before this change; the
  contract-presence deny was previously masking that mismatch by firing
  first, for the wrong reason, and coincidentally matching those cases'
  expected "deny" outcome. Rewriting fixtures (a)-(l) to target
  subject-scoped paths would fix this but reaches into `gate-fix`'s own
  test-fixture debt, which this proposal's constraints explicitly place out
  of scope ("does not touch gate logic ... out of scope here"). Left
  unfixed and reported here rather than silently patched or masked again.
