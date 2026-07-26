---
status: approved
files:
  - feasibility-cycle/hooks/state-gate.sh
  - feasibility-cycle/hooks/transition-rules.md
  - feasibility-cycle/hooks/run-gate-tests.sh
  - docs/proposals/2026-07-27-gate-subject-scoped-ownership.md
---

## Intent

Under contract-v2 the blackboard lives at `docs/reports/records/<subject>/<role>.md`;
each role's gate must (a) enforce §11 path-ownership against the
SUBJECT-SCOPED path (a role may write only its own `<role>.md` under any
subject), not a hardcoded flat record name, and (b) resolve its own
`transition-rules.md` / contract file REPO-LOCALLY from the current git root,
never via `CLAUDE_PLUGIN_ROOT` or a plugin-install layout. That is the frozen
norm this proposal conforms the gate to.

The defect this proposal fixes surfaced live in the full-gate relay
(`docs/reports/2026-07-27-full-gate-relay-simulation.md` in the relay-sim-v2
repo): `feasibility-cycle/hooks/state-gate.sh` resolves `transition-rules.md`
via `CLAUDE_PLUGIN_ROOT`, which fails to find the file when the guarded repo
has a flat/own layout — so the gate stands down / cannot obtain a clean
owned-path ALLOW, i.e. it does not actually enforce feasibility's process
steps in a real work repo.

## Constraints

- The gate may resolve exactly one root: the git root of the session's
  current working directory (`git rev-parse --show-toplevel`), the same
  repo-local resolution norm already established for the handoff contract in
  `docs/proposals/2026-07-26-repo-local-contract.md`.
- `CLAUDE_PLUGIN_ROOT` and any plugin-install-layout assumption must not be
  used to locate `transition-rules.md` or any other contract material the
  gate depends on to decide ALLOW/REFUSE.
- The owned-path check (§11) must target the subject-scoped path
  `docs/reports/records/<subject>/feasibility.md`, not a hardcoded flat
  record name — this is already the existing behavior per the code at
  `feasibility-cycle/hooks/state-gate.sh` lines ~117-213 and must not
  regress while the resolution logic changes.
- Absence of `transition-rules.md` at the repo-local location is an honest
  failure ("transition rules could not be loaded" or equivalent), not a
  silent pass.

## What will be done

- `feasibility-cycle/hooks/state-gate.sh`: change the rules-file/contract
  resolution (currently `plugin_root="${CLAUDE_PLUGIN_ROOT:-}"` at line 81,
  used to locate `transition-rules.md`) to resolve repo-locally instead —
  compute the git root of the current working directory and look for
  `transition-rules.md` under this rulebook's own hooks directory relative
  to that repo-local resolution, mirroring the pattern already used for
  `docs/specs/role-handoff-contract.md` resolution. Confirm, without
  changing, that the existing subject-scoped owned-path check
  (`docs/reports/records/<subject>/feasibility.md`) continues to be the
  target of §11 enforcement after the resolution change.
- `feasibility-cycle/hooks/transition-rules.md`: adjust only if the
  resolution change requires moving, relocating, or re-referencing this file
  so it is discoverable from the new repo-local resolution path; no content
  change to the transition rules themselves.
- `feasibility-cycle/hooks/run-gate-tests.sh`: add/adjust test cases
  exercising the fix — a fresh repo with the contract present where
  feasibility's own subject-scoped record write ALLOWs, and a foreign-role
  write under the same subject REFUSEs — and remove any test scaffolding
  that depended on `CLAUDE_PLUGIN_ROOT` being set to locate rules.

## Out of scope

- The other five rulebook repos (coding, qa, product, ops, review).
- The deferred `status` -> `loop_state` rename.
- Any changes to the `relay-sim-v2` repo, including the simulation report
  that surfaced this defect.

## How we know it worked

In a fresh repo with the contract present, feasibility's own subject-scoped
record write (`docs/reports/records/<subject>/feasibility.md`) ALLOWs (exit
0), and a foreign-role write under the same subject (e.g.
`docs/reports/records/<subject>/coding.md` attempted by the feasibility
gate's identity) REFUSEs (exit 2) — in both cases with no "transition rules
could not be loaded" failure, i.e. the gate successfully resolves
`transition-rules.md` repo-locally regardless of whether `CLAUDE_PLUGIN_ROOT`
is set or matches a plugin-install layout.

## What did not work

- Literally implementing "git root of the session's current working
  directory via `git rev-parse --show-toplevel`" as stated in Constraints
  was tried first and abandoned: `state-gate.sh`'s root resolution is
  already anchored by walking UP from the hook script's OWN on-disk
  location to the nearest `.git` (not from `$PWD`/`CLAUDE_PROJECT_DIR`,
  which the script's own comments explicitly say must never be consulted).
  Switching to a literal cwd-based `git rev-parse --show-toplevel` would
  have silently changed that established, already-tested root-anchoring
  behavior (case (l) in `run-gate-tests.sh` exists specifically to pin it)
  as a side effect of this proposal, which only owns the rules-file
  resolution. Reused the existing `$root`/`$script_dir` anchor instead and
  pointed `rules_file` at `$script_dir/transition-rules.md`, which is
  repo-local and `CLAUDE_PLUGIN_ROOT`-independent without touching root
  resolution.
- `transition-rules.md` did not need to move, relocate, or be
  re-referenced: it already lives next to `state-gate.sh` in
  `feasibility-cycle/hooks/`, so the "adjust only if required" clause in
  the proposal's write set turned out to require no edit to that file at
  all.
- Attempted to run the new subject-scoped ALLOW/REFUSE cases directly
  against this rulebook checkout (reusing `new_work`/`run_gate`) before
  discovering that `state-gate.sh`'s root anchor is the hook script's own
  on-disk location, not the test's `$work` scratch directory — so a case
  seeded only under `$work` would silently resolve against this repo's own
  root instead and prove nothing. Had to add a `new_fresh_repo` harness
  that `git init`s a real throwaway repo and copies the gate script and
  `transition-rules.md` into it, so the copy's own on-disk location
  becomes the root being tested.
- Left the seven pre-existing failures in `run-gate-tests.sh` (cases
  (b)(c)(g)(h)(i)(j)(k)) unfixed: they all stem from this rulebook repo's
  own `docs/specs/role-handoff-contract.md` being absent, which is a
  pre-existing gap orthogonal to rules-file resolution and outside this
  proposal's frozen file set — confirmed identical failure count before
  and after this change, i.e. no regression introduced.
