# Proposal — reclaim vendored stub-check.sh (core #69 canon rollout)

Phase 1 only. No execution in this PR. Survey:
`docs/issue-34/reports/implementation/survey.md`.

## Scope

1. Delete `feasibility/hooks/tests/stub-check.sh` — a vendored copy added
   in issue-31's execution, now stale relative to core's current
   `core/hooks/tests/stub-check.sh` (which additionally checks for a
   vendored copy of itself, per core issue #69 item 2).
2. **No `hooks.json` change.** Surveyed in full: `stub-check.sh` was never
   registered in `feasibility/hooks/hooks.json` (run manually per issue-31's
   proposal, not wired into `PreToolUse`/`SessionStart`). Nothing to
   remove there.
3. Re-run stub-check via core's canon-referenced invocation (not a local
   copy), per `docs/handbooks/canon-scripts.md` /
   `docs/handbooks/role-gates-tests.md`:

   ```
   "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" feasibility
   ```

   Confirm pass, record only the invocation and result in
   `docs/issue-34/reports/implementation.md` — never a second copy of the
   file.

## Preserved (unchanged)

- `feasibility/hooks/directive.sh`, `feasibility/hooks/hooks.json`'s
  `SessionStart` entry, `RECORD_FIELDS_TERMINAL_STATES` env — all
  untouched; this issue only reclaims the one vendored test script.

## Open questions for the approver

None — mechanical deletion plus a path-referenced re-run, no design axis.
