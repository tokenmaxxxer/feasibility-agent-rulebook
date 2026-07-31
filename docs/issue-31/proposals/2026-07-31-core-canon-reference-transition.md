# Proposal — transition to core canon references (core #63/#66 rollout)

Phase 1 only. No execution in this PR. Survey: `docs/issue-31/reports/implementation/survey.md`.

## Scope

Issue #31's five items, mapped 1:1 to this repo's `feasibility/` tree.

1. **`feasibility/agents/warrant-hunter.md`: no-op.** The survey confirms no
   such file, and no `agents/` directory, exists in this repo. Nothing to
   delete. Recorded explicitly so item 1 isn't silently skipped.

2. Delete `feasibility/hooks/trailer-gate.sh`,
   `feasibility/hooks/record-fields-gate.sh`,
   `feasibility/hooks/handbook-trigger-gate.sh`. Replace
   `feasibility/hooks/hooks.json`'s `PreToolUse` block, currently:

   ```json
   "PreToolUse": [
     { "matcher": "Write|Edit|MultiEdit|NotebookEdit",
       "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/record-fields-gate.sh" }] },
     { "matcher": "Bash",
       "hooks": [
         { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/handbook-trigger-gate.sh" },
         { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/trailer-gate.sh" }
       ] }
   ]
   ```

   with no `PreToolUse` block at all — core's `core/hooks/hooks.json`
   (`matcher: ".*"`) already fires all three globally, matching the shape
   every other core-canon-registered rulebook converges on. `SessionStart`
   stays, pointing at the (rewritten) `directive.sh`.

3. Replace `feasibility/hooks/directive.sh` with a stub sourcing
   `core/hooks/lib/role-directive.sh` and calling `core_role_directive`
   with this role's four values. Unlike the simpler precedent repos
   (data-engineering-rulebook: 4 short source lines fit `core_role_directive`'s
   4 slots directly), this role's current directive carries five full
   sections. Proposed fit — **flagged below as the one real judgment call
   in this proposal**:

   - `you_decide` = the existing "YOU DECIDE: ..." paragraph, verbatim.
   - `use_when` = the existing "RESEARCH (phase 1, ...)" section
     (the four probes + evidence bars + exemplars line), verbatim.
   - `produces` = "CURRENT-STATE SURVEY (phase 1): ..." +
     "PROPOSAL (phase 1): ..." sections, concatenated verbatim — both
     describe phase-1 *output* this role produces.
   - `hand_off` = "EXECUTION JUDGMENT (phase 2, quality bar): ..." +
     the closing "RECORD REQUIREMENTS (do not skip this): ..." paragraph,
     concatenated verbatim — the record-requirements text is genuinely
     richer than `core_role_directive`'s auto-generated closing
     `RECORD: docs/issue-<n>/reports/${role}.md, phase-gated per contract
     v3 s19` line (it additionally specifies *when* to write it — "as your
     FIRST act of phase 2" — and the loop_state-update-at-every-transition
     rule), so it is preserved rather than dropped, folded into the last
     slot the same way data-engineering-rulebook folded its overflow
     `WRITE_SCOPE: []` line into `hand_off`.

   ```bash
   #!/usr/bin/env bash
   trap 'rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then exit 2; fi' EXIT
   set -uo pipefail
   . "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
   core_role_directive \
     "YOU DECIDE: whether the specification CAN be built and MAY be built — the
   lead-engineer feasibility seat plus legal, regulatory, and threat-model
   risk. You prevent late discovery of a blocker, and instrumentation added
   too late to measure what it needed to measure." \
     "RESEARCH (phase 1, scout protocol + the four probes, each with its
   evidence bar):
   - technical: a spike-report or ATAM-style summary, plus a reversibility
     classification (skills: spike-report, reversibility-tag)
   - prior_art: a build-vs-buy comparison with per-dependency health
     evidence, OpenSSF-Scorecard-or-equivalent (skill: build-vs-buy)
   - legal_regulatory: a per-dependency license verdict (scan evidence) and
     a regulatory-applicability note, DPIA-before-processing pattern
     (skill: license-scan)
   - threat_model: a STRIDE table, one row per (element, category, trust
     boundary), EVERY row carrying a disposition mitigated|accepted|deferred
     — nothing left \"in progress\" (skill: stride-table)
   Exemplars: ADRs, spike reports, risk registers, threat models of
   comparable systems." \
     "CURRENT-STATE SURVEY (phase 1): read the specification DELIBERATELY
   WITHOUT the market argument that motivated it — a verdict argued from
   \"but this will make money\" is not a feasibility verdict. Record
   market_argument_supplied: false explicitly: the record must SAY the
   argument was withheld, not merely omit it. Survey the current
   architecture's capacity to absorb the spec, and enumerate the
   deploy/runtime config surface (env var names the build must honor)
   whenever foreseeable (contract s17).

   PROPOSAL (phase 1): promise the constraint list, the verdict
   (go|no-go|conditional, with a conditions: list when conditional), and
   the MEASUREMENT DESIGN — what events get collected and where.
   Verdict selection criteria (mechanical, per condition class): a blocking
   condition that cannot proceed until resolved EXTERNALLY (outside this
   repo's own work) -> verdict: conditional, the blocking condition in the
   conditions: list; a prerequisite that is two-way (reversible) and
   resolvable WITHIN the repo's own work -> verdict: go, with the
   prerequisite recorded via the verdict_provisional convention (below) in
   the record body, never in conditions:; a scope constraint only (no
   blocking or resolvable prerequisite, just a boundary on what was
   evaluated) -> verdict: go, the constraint stated in the record body. The
   verdict field itself carries the bare enum value only — every
   condition, prerequisite, or constraint narrative lives in the record
   body, never appended to or encoded in the field.
   Spike proposals carry: question, timebox (1-3 days, agreed with the
   human BEFORE work starts), acceptance criteria written before work,
   and a reversibility tag." \
     "EXECUTION JUDGMENT (phase 2, quality bar):
   - No verdict until ALL FOUR probes resolve to pass:<evidence> |
     fail:<evidence> | blocked:<evidence>. An empty or in-progress field
     is not a resolution.
   - verdict-provisional (feasible / infeasible / feasible-with-conditions)
     is distinct from the accepted verdict: acceptance is the human's PR
     act. Silence is not consent; a compliant-looking file is not consent.
   - verdict_provisional (underscore) is a DIFFERENT, body-level convention:
     it marks a go verdict's in-repo-resolvable prerequisite (controller #89
     precedent) — not the phase-1-vs-accepted loop_state distinction above.
     Same words, different concepts; both are kept.
   - Reversibility scales evidence: a one-way door needs more before its
     probe may pass; a two-way door may pass on less. It is a field on
     every finding, never a fifth probe.
   - A timebox that expires without a conclusive answer STOPS and puts
     extend-vs-stop to the human — never silently continues.
   - Once at verdict, refuse to revise without a new probe finding.

   RECORD REQUIREMENTS (do not skip this): the record lives at
   docs/issue-<n>/reports/feasibility.md and nowhere else — research files,
   surveys, and proposals are not the record. Write it as your FIRST act of
   phase 2, and update its loop_state at every transition. Ending phase 2
   without your record committed on the branch means the required record
   was never delivered."

   trap - EXIT
   exit 0
   ```

   The `trap`/`set -uo pipefail` pair stays outside the sourced function
   per core issue #66's own record (a trap inside a sourced function does
   not catch the sourcing script's abnormal exit) — matching the
   data-engineering-rulebook precedent's structure, which additionally
   closes with `trap - EXIT; exit 0` after the call (this role's current
   `directive.sh` already ends the same way; kept).

4. **`RECORD_FIELDS_TERMINAL_STATES` — needed, placement is an open
   question (see below).** This role's own vendored
   `record-fields-gate.sh` currently hardcodes
   `TERMINAL = {"verdict", "scope-approved"}`
   (`feasibility/hooks/record-fields-gate.sh:139`), diverging from core's
   default `{"landed"}`. Per core issue #66's own record, this is exactly
   the case that env var exists for: *"any rulebook whose
   `record-fields-gate.sh` copy relied on a non-`landed` terminal state
   sets `RECORD_FIELDS_TERMINAL_STATES` in its own `hooks.json` env for
   the gate, or in its `directive.sh`/session env, before deleting its
   local copy — otherwise it silently regresses to the `landed`-only
   default."* Proposed value: `RECORD_FIELDS_TERMINAL_STATES="verdict scope-approved"`.

5. Once items 2-4 land (phase 2), run `core/hooks/tests/stub-check.sh
   feasibility` (dropped into this repo the same way `parse-check.sh` is
   already distributed) and record its pass in
   `docs/issue-31/reports/implementation.md`.

## Preserved (role-unique, unchanged)

- `feasibility/.claude-plugin/plugin.json` — untouched.
- All five directive sections' actual text — carried into the new stub
  verbatim, refit across four `core_role_directive` argument slots per
  item 3 above.
- `feasibility/hooks/hooks.json`'s `SessionStart` entry — untouched.
- The `{"verdict", "scope-approved"}` terminal-state behavior — preserved
  via `RECORD_FIELDS_TERMINAL_STATES`, not a hardcoded local copy.

## Open questions for the approver

1. **Where does `RECORD_FIELDS_TERMINAL_STATES` actually live once this
   repo's `hooks.json` no longer registers `record-fields-gate.sh` at
   all?** The gate now runs exclusively from core's own globally
   registered `hooks.json` entry, not this repo's. Core issue #66's
   record names two candidate locations ("its own `hooks.json` env for
   the gate, or in its `directive.sh`/session env") but neither this
   repo's nor any sibling checkout in `tokenmaxxxer-core` shows a working
   `"env"` key on a hook entry, and a `directive.sh`
   SessionStart-hook `export` would not persist into the separate
   subprocess that later runs `record-fields-gate.sh` on a `Write`/`Edit`
   call. This proposal does not resolve the mechanism; phase 2 will need
   either a confirmed `hooks.json` `env` key (if the harness supports one)
   or a different placement the approver directs. Flagging now since it
   blocks item 4, not deferring silently.
2. The five-section-into-four-slot directive fit (item 3) is a judgment
   call, not a mechanical 1:1 mapping like the simpler precedent repos
   had. If the approver prefers a different grouping (e.g. keeping
   CURRENT-STATE SURVEY separate from PROPOSAL by moving RESEARCH into
   `produces` instead), that's a same-shape edit to make in phase 2.

## Order constraint

Per the issue: this transition must land before this repo's own "rulebook
maturation" phase 2 touches `directive.sh` or a gate file. Noted for the
approver's sequencing, not enforced mechanically in this PR.
