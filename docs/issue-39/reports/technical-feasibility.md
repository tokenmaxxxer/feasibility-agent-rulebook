# technical-feasibility — issue-39 phase 2 record

loop_state: verdict

Upstream basis: `docs/issue-39/proposals/2026-07-31-technical-feasibility-methodology-enforcement.md`
(restructured to the plugin-set shape after the human's PR-review
correction, see that file's "Revision note"), approved via the
single-account exact-string issue comment `APPROVE
issue-39/technical-feasibility` (contract v3 s19; the account is listed
in `docs/specs/approvers.md`). PR #40 carried phase 1 and is merged;
this record is phase-2 execution on the same branch,
`issue-39/technical-feasibility`.

## Status

accepted

## Context

Issue-39 asked that the methodology adopted in issue-30 — MADR
candidates/options discipline, Nygard's minimal ADR spine, and
mandatory evidence citation — stop living only in directive prose and
become a machine-enforced part of the plugin system, "룰북당 여러 개"
(several plugins per rulebook), the way `core` registers `freelunch`
and `scout` as independent siblings rather than one monolithic plugin
— source: `.claude-plugin/marketplace.json:2` (core marketplace shape
referenced, not copied) and the human's PR-review correction quoted
verbatim in the phase-1 proposal's "Revision note" section.

## Decision

go — build three sibling methodology plugins (`madr-options`,
`nygard-adr-spine`, `evidence-citation`), each self-contained (own
`plugin.json`, own `hooks/hooks.json`, own gate, own kill switch, own
tests, own README), each registered in `.claude-plugin/marketplace.json`
next to `feasibility` — source:
`.claude-plugin/marketplace.json` (three new entries added).

## Options considered

The phase-1 proposal (`docs/issue-39/proposals/2026-07-31-technical-
feasibility-methodology-enforcement.md`) flagged, as its open question
1, exactly one undecided design point carried into phase-2 execution:
how a non-role methodology plugin's directive text and gate reach the
`feasibility` role plugin's session, given only `feasibility` calls
`core_role_directive`.

- **Candidate A — static text-splice into `feasibility/hooks/directive.sh`**
  (the proposal's own tentative default, proposal lines 88–102):
  concatenate each plugin's `directive-fragment.md` into
  `directive.sh`'s heredoc arguments at authoring time via a marked
  insertion point. Rejected: this would make every methodology plugin's
  content changes require an edit to `feasibility`'s own file, breaking
  the "self-contained, sibling, no other plugin's files need editing"
  requirement from the human's PR-review correction — source: issue
  #39 comment (승인자) "각 플러그인 = 자기완결(...)... 명확한 단일
  방법론 담당" (quoted in the proposal's "Revision note").
- **Candidate B — independent per-plugin `hooks.json` composition**
  (adopted): each methodology plugin ships its own `SessionStart` hook
  (`cat "${CLAUDE_PLUGIN_ROOT}/directive-fragment.md"`) and its own
  `PreToolUse` gate, registered only in its own `hooks/hooks.json`.
  Claude Code fires every enabled plugin's `hooks.json` independently —
  verified directly by running the built gates as real subprocesses
  against the write-surface regex, all passing without any edit to
  `feasibility/hooks/hooks.json` or `directive.sh` — source:
  `tests/run-gate-tests.sh` (root harness folding in
  `madr-options/tests/run-gate-tests.sh`,
  `nygard-adr-spine/tests/run-gate-tests.sh`,
  `evidence-citation/tests/run-gate-tests.sh`; run output: "3 passed, 0
  failed, 7 skipped"). Chosen because it resolves the proposal's own
  open question 1 in the direction the human's correction already
  pointed (self-containment over splicing) and needs zero changes to
  `feasibility/`'s files, so the three new plugins carry no coupling to
  the role plugin at all.
- **Candidate C — a runtime `source` of fragment files from
  `directive.sh` itself** (the proposal's alternative under open
  question 1, proposal lines 388–393): rejected for the same reason as
  Candidate A (couples `feasibility`'s own file to every methodology
  plugin's presence) and adds a runtime dependency ordering concern
  Candidate B does not have.

## Why

The human's PR-review correction on issue #39 required "룰북당 여러 개"
(several independent plugins per rulebook, each self-contained) rather
than one deepened directive or one monolithic gate. Independent
per-plugin `hooks.json` composition (Options considered, Candidate B
above) is the only option of the three considered that satisfies
self-containment literally: no sibling plugin's file needs an edit for
a new methodology plugin to take effect, matching the freelunch/scout
precedent the correction named. The static-splice alternatives
(Candidates A and C) were both rejected for the same reason — they
recouple every methodology plugin to `feasibility`'s own files, which
is exactly the shape the correction asked to move away from.

## Consequences

Two-way door: each plugin's gate carries its own kill switch
(`MADR_OPTIONS_GATE_OFF`, `NYGARD_ADR_SPINE_GATE_OFF`,
`EVIDENCE_CITATION_GATE_OFF`, each `1|true|yes|on` to disable — source:
`madr-options/hooks/options-gate.sh`,
`nygard-adr-spine/hooks/spine-gate.sh`,
`evidence-citation/hooks/citation-gate.sh`), and removing a plugin from
`.claude-plugin/marketplace.json` fully un-registers it with no data
migration. `feasibility/hooks/directive.sh` and
`feasibility/hooks/hooks.json` are untouched by this change — reverting
is deleting three directories and three marketplace entries, nothing
else.

## What was done

- Three new plugins built, each independently verified passing:
  `madr-options/` (8/8 tests), `nygard-adr-spine/` (6/6 tests),
  `evidence-citation/` (7/7 tests) — source:
  `tests/run-gate-tests.sh` run output.
- `.claude-plugin/marketplace.json` gained three sibling entries
  (`madr-options`, `nygard-adr-spine`, `evidence-citation`), matching
  the existing `feasibility` entry's shape (`name`/`source`/
  `description`) — source: `.claude-plugin/marketplace.json`.
- `tests/run-gate-tests.sh` (confirmed broken by the phase-1 survey,
  0/7 passing, all exit-127) fixed: gate paths for the two core-canon
  gates (`record-fields-gate.sh`, `trailer-gate.sh`) now resolve via a
  `CORE` variable using the same `CLAUDE_PLUGIN_ROOT_CORE`-style
  sibling-path fallback `feasibility/hooks/directive.sh` already uses
  (source: `feasibility/hooks/directive.sh:2`), rather than the
  hardcoded `feasibility/hooks/$3` that no longer resolves after
  issue-31 moved those two gates into core. Cases against a
  not-checked-out core now report `SKIP` (an unmet external dependency,
  not this repo's own regression) instead of a false `exit-127` FAIL —
  source: `tests/run-gate-tests.sh` run output ("7 skipped"). The
  harness also now runs each new plugin's own standalone test script
  and folds its pass/fail into the totals, so one command exercises
  every gate in the repo.
- No canon script was copied: the three new gates are original code,
  referencing (never vendoring) the fail-closed bash+python3 pattern
  already visible in this repo's own git history at commit `4e1b916`'s
  `feasibility/hooks/record-fields-gate.sh` (trap-based EXIT handler,
  `deny()`/`allow()` python helpers) — each new gate reimplements that
  pattern for its own, different check logic.

## Verdict

verdict: go — all three methodology plugins built, tested, registered;
no blocking condition outstanding.

## Risks

- Heuristic document-shape parsing (section/heading detection instead
  of a formal grammar) can false-positive-deny a compliant-but-oddly-
  formatted record, or false-negative-allow a field name that appears
  in unrelated prose — disposition: accepted (documented explicitly in
  each gate's own header comment, per the proposal's own stated
  tolerance for this class of gate; kill switches exist as the escape
  hatch).
- `evidence-citation`'s phase-2 "new uncited claim" detection is,
  by design, the highest false-positive-risk check in the set (the
  proposal's own open question 2) — disposition: accepted, biased
  toward allow on ambiguity per the built gate's documented leniency
  rule, matching the proposal's stated risk tolerance rather than
  silently tightening it.
- The two core-canon gate test cases (`record-fields-gate.sh`,
  `trailer-gate.sh`) cannot be exercised in this checkout because
  `core` is referenced, not vendored, and is not present on disk here
  — disposition: accepted as a pre-existing, out-of-scope condition
  (confirmed already broken before this issue by the phase-1 survey);
  mitigated by making the harness report it as `SKIP` rather than
  hiding it as a false pass or false fail.
- `madr-options`'s phase-2 candidate-carry-forward check reads a second
  file (the phase-1 proposal) by best-effort string match — disposition
  accepted, per the proposal's own open question 3, as a PR-review-
  augmenting heuristic rather than a guaranteed cross-file consistency
  proof.

## Open findings

- Open questions 4–6 from the phase-1 proposal (gate execution order
  across plugins when more than one composes on the same write; whether
  an onboarding checklist skill is wanted for any of the three; whether
  the `tests/run-gate-tests.sh` harness fix belongs to this issue or a
  narrower separate one) were not answered by the approval comment (a
  bare exact-string match, per contract v3 s19, carries no prose) —
  resolved by the proposal's own stated defaults in the absence of an
  override: independent per-plugin hooks fire without a declared cross-
  plugin order (Claude Code does not guarantee one across sibling
  plugins' own `hooks.json` files, and none of the three gates depends
  on another's having already run); no checklist skill added (single
  document-shape disciplines, not repeated procedures); the harness fix
  landed inside this issue since it now blocks three new gates' tests,
  not just the pre-existing ones.

## Next steps

None required to close this issue. A future issue may still choose to
add the heavier session-level state tracker discussed in the proposal's
"Order constraint discussion" (comparable to
`implementation-rulebook`'s `hunt-state.sh`) if the document-shape-
implies-order check proves insufficient in practice — that is its own
canon-referenced proposal, not a continuation of this one.

## Resolution path

No open finding remains open on this record; nothing routes forward.
