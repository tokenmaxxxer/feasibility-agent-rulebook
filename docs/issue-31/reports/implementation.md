# Record — issue-31 (implementation)

loop_state: landed

## Why

Issue #31: core landed a single canon for warrant-hunt (core #63) and the
three role-agnostic gates + shared directive boilerplate (core #66). Every
rulebook carrying its own vendored copies is drift risk (core #66's survey
found 38/40 unique hashes across 43 rulebooks). This repo's copies are
replaced with canon references per the approved proposal, closing that
drift surface for `feasibility/` and unblocking this repo's own "rulebook
maturation" phase-2 work, which must not touch `directive.sh` or a gate
file before this transition lands (issue's order constraint).

## Upstream basis

- core issue #63 (`tokenmaxxxer-core`): warrant-hunt canon plugin.
- core issue #66 (`tokenmaxxxer-core`): `core/hooks/{trailer,record-fields,handbook-trigger}-gate.sh` + `core/hooks/lib/role-directive.sh` + `core/hooks/tests/stub-check.sh`, all registered globally in `core/hooks/hooks.json`.
- `docs/issue-31/proposals/2026-07-31-core-canon-reference-transition.md` (this repo, phase 1, approved).
- `docs/issue-31/reports/implementation/survey.md` (this repo, phase 1).

## What was done

Executed the approved proposal's items 1-5 in one batch:

1. `agents/warrant-hunter.md`: confirmed no-op (no such file, no `agents/` dir in this repo). No-op recorded, not silently skipped.
2. Deleted `feasibility/hooks/trailer-gate.sh`, `record-fields-gate.sh`, `handbook-trigger-gate.sh`. Removed `feasibility/hooks/hooks.json`'s `PreToolUse` block entirely — core's `core/hooks/hooks.json` (`matcher: ".*"`) already fires all three globally. `SessionStart` entry kept, pointing at the rewritten `directive.sh`.
3. Replaced `feasibility/hooks/directive.sh` with a lib-call stub: sources `core/hooks/lib/role-directive.sh`, calls `core_role_directive` once with the role's four values. All five original directive sections preserved verbatim, refit into the four slots per the proposal's mapping (`you_decide` / `use_when`=RESEARCH / `produces`=CURRENT-STATE SURVEY+PROPOSAL / `hand_off`=EXECUTION JUDGMENT+RECORD REQUIREMENTS).
   - **Deviation from the proposal's draft, found during execution**: the proposal's draft stub wrapped the `core_role_directive` call in `trap`/`set -uo pipefail` lines and a multi-line call spanning several shell lines. Checked against the actual working precedent (`data-engineering-rulebook`'s already-migrated `directive.sh`, and `core/hooks/tests/stub-check.sh`'s own structural check): `stub-check.sh` rejects any line that doesn't match shebang / comment / blank / a line containing `role-directive.sh` or `core_role_directive` / a plain `VAR=value` assignment. A `trap` line, a `set` line, or a `core_role_directive` call whose arguments span multiple *physical* lines all fail this check (continuation lines don't contain the literal string `core_role_directive`). The precedent stub is shebang + one source line + one single-physical-line `core_role_directive` call, using `$'...'`-quoted arguments with literal `\n` escapes for internal line breaks. Built this role's stub the same way, confirmed by running `stub-check.sh` directly rather than by inspection alone.
4. `RECORD_FIELDS_TERMINAL_STATES="verdict scope-approved"` set as a top-level `"env"` key in `feasibility/hooks/hooks.json` (sibling to `"hooks"`), preserving this role's non-default terminal-state behavior (`{"verdict","scope-approved"}` vs core's `{"landed"}` default) now that `record-fields-gate.sh` runs exclusively from core's globally-registered entry.
5. Ran `core/hooks/tests/stub-check.sh feasibility` (copied into this repo at `feasibility/hooks/tests/stub-check.sh`, same distribution pattern as `parse-check.sh`). **Pass**, full output:

   ```
   stub-check: ok — no vendored 'trailer-gate.sh' under feasibility
   stub-check: ok — no vendored 'record-fields-gate.sh' under feasibility
   stub-check: ok — no vendored 'handbook-trigger-gate.sh' under feasibility
   stub-check: ok — no vendored 'parse-check.sh' under feasibility
   stub-check: ok — feasibility/hooks/directive.sh is a role-directive stub
   ```

## Preserved (role-unique, unchanged)

- `feasibility/.claude-plugin/plugin.json` — untouched.
- All five directive sections' actual text — carried into the stub verbatim (content unchanged; only quoting/line-joining mechanics changed to satisfy `stub-check.sh`'s structural cap).
- `feasibility/hooks/hooks.json`'s `SessionStart` entry — untouched.
- The `{"verdict", "scope-approved"}` terminal-state behavior — preserved via `RECORD_FIELDS_TERMINAL_STATES`, not a hardcoded local copy (placement caveat below).

## Open findings

1. **`RECORD_FIELDS_TERMINAL_STATES` placement is not verified against the
   harness (resolution path: pending).** The proposal flagged this as an
   open question; the approver's bare `APPROVE issue-31/implementation`
   gave no further direction, so this was resolved as a judgment call
   during execution. Core issue #66's own record names two candidate
   placements — "its own `hooks.json` env for the gate, or in its
   `directive.sh`/session env." The `directive.sh`/session-env route is
   confirmed *not* to work mechanically: a `SessionStart` hook's plain
   `export` does not persist into the separate subprocess that later runs
   `record-fields-gate.sh` on a `Write`/`Edit` call (different
   subprocess, no shared environment). Chose the `hooks.json` top-level
   `"env"` key as the more literal reading of core issue #66's suggested
   wording. No test in this repo or in the sibling `tokenmaxxxer-core`
   checkout exercises a plugin-level `hooks.json` `"env"` key end-to-end —
   this repo is the first rulebook to actually need a non-`landed`
   terminal state post-cutover, so there was no working precedent to copy
   verbatim. If the harness does not honor this key, the gate silently
   reverts to `landed`-only, which would silently regress this role's
   terminal-state behavior. Recommended follow-up: once this PR lands,
   confirm in a live session that `record-fields-gate.sh` actually reads
   `RECORD_FIELDS_TERMINAL_STATES` as `"verdict scope-approved"` (e.g. by
   observing gate behavior against a record with `loop_state: verdict`);
   file a core-side or repo-side follow-up issue if it does not.

## Scope note

Per the issue's order constraint, this transition lands before this repo's own "rulebook maturation" phase-2 work touches `directive.sh` or a gate file — noted, not mechanically enforced here.
