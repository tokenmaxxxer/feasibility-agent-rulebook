# Current-state survey — issue-34

Scout: skipped. Skip condition: spec leaves no open design decision — this
is a delete-and-reference-by-path mechanical action, not a build with a
design axis.

## Findings

- `feasibility/hooks/tests/stub-check.sh` exists — a vendored copy, added in
  issue-31's phase-2 execution (commit 44b8bb2, PR #33). Diffed against
  core's current `core/hooks/tests/stub-check.sh`
  (`tokenmaxxxer-core-issue-69-implementation` checkout): the two have
  diverged. Core's version now also checks for a vendored copy of
  **itself** (`stub-check.sh` was added to `core/hooks/tests/canon-manifest.txt`,
  issue-69 item 2) and derives `CANON_GATES` from that manifest file rather
  than a hardcoded list. This repo's copy predates both changes — it is
  itself the exact drift `core #69` targets.
- `feasibility/hooks/hooks.json` — checked in full. No `stub-check.sh`
  entry anywhere (no `PreToolUse`, no `SessionStart` reference). It is run
  manually per issue-31's proposal item 5, not wired as a hook. **Nothing
  to remove from `hooks.json`.**
- Core canon reference (`docs/handbooks/canon-scripts.md`,
  `docs/handbooks/role-gates-tests.md` in the core repo): "Canon scripts
  are referenced, never copied." The documented invocation line for a
  rulebook:

  ```
  "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" "$(dirname "$0")/.."
  ```

  — path resolved against core's install root, rulebook's own directory
  passed as scan target, script binary never copied.
- `docs/issue-31/reports/implementation.md:32` already records the prior
  (now-superseded) pattern: "Ran `core/hooks/tests/stub-check.sh feasibility`
  (copied into this repo at `feasibility/hooks/tests/stub-check.sh` ...)".
  That copy is exactly what issue-34 reclaims.

## Scope for phase 2

1. Delete `feasibility/hooks/tests/stub-check.sh`.
2. No `hooks.json` change (nothing registered there).
3. Re-run stub-check via core-referenced path (not a local copy) against
   `feasibility`, confirm pass, record the invocation and result in
   `docs/issue-34/reports/implementation.md` — noting only the invocation
   and pass/fail, never re-adding a copy.
