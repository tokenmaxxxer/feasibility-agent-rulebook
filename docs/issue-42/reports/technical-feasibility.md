---
subject: issue-42
role: technical-feasibility
loop_state: verdict
---

# Record — gate A+ remediation (phase 2)

## Status

accepted

## Context

The 2026-08-01 code audit (issue #42) graded this repo's three
methodology gates (`citation-gate.sh`, `spine-gate.sh`, `options-gate.sh`)
at B: `citation-gate` Edit fail-open vs `spine-gate` Edit total-deny is a
same-write-surface contradiction — citation-gate.sh:101 (pre-migration)
reconstructed nothing and checked a bare `new_string` fragment while
spine-gate.sh:116-121 (pre-migration) denied every Edit/MultiEdit
outright — and the citation regex required an em-dash with no ASCII
fallback — citation-gate.sh:125 (pre-migration). Core issue #72 (the
gate-house standard) had already landed `core/hooks/lib/gate-lib.sh`/
`gate-lib.py` with the exact fail-closed trap, kill-switch check, path
normalization, and Edit/MultiEdit reconstruction this repo's three gates
each independently hand-rolled — grep -rn "gate-lib" evidence-citation/
nygard-adr-spine/ madr-options/ returned zero hits before this record —
docs/issue-42/reports/technical-feasibility/survey.md §3. The approved
phase-1 proposal (docs/issue-42/proposals/
2026-08-01-gate-a-plus-remediation.md) committed to closing every audited
defect by referencing that canon rather than re-deriving it a fourth time.

## Decision

go — migrated all three gates onto `core/hooks/lib/gate-lib.sh`/
`gate-lib.py`, fixed every defect the issue named, upgraded the semantic
checks from substring/whole-document presence to section/line-adjacency,
added the six mandatory test-case groups to each plugin's own test
script, and reconciled `README.md` with the real file/plugin/kill-switch
inventory, exactly as scoped in the approved proposal's "What will be
done" (a)-(i).

## What was done

**(a)/(b) Edit/MultiEdit reconstruction.** `citation-gate.sh` and
`spine-gate.sh` both now read the write target's current on-disk content
and call `gate_lib.gate_reconstruct_write(tool, tool_input,
current_content)` (`core/hooks/lib/gate-lib.py:96-146`) for Write/Edit/
MultiEdit, so both gates judge the real resulting document instead of a
bare fragment or blocking outright — evidence-citation/hooks/
citation-gate.sh, nygard-adr-spine/hooks/spine-gate.sh. `spine-gate.sh`'s
former unconditional `content = ti.get("content"); if not isinstance(...,
str): deny(...)` (spine-gate.sh:116-121 pre-migration) is gone; an Edit
against an already-complete record now allows when the reconstructed
result stays complete — confirmed by the `edit-replace-all-still-complete`
test case, nygard-adr-spine/tests/run-gate-tests.sh.

**(c)/(d) Kill-switch + fail-closed trap migration.** All three gates now
`. "${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/lib/gate-lib.sh"`, call
`gate_trap_fail_closed` as the first statement, and call
`gate_kill_switch_active` instead of a hand-rolled case statement —
evidence-citation/hooks/citation-gate.sh, nygard-adr-spine/hooks/
spine-gate.sh, madr-options/hooks/options-gate.sh. An unrecognized
kill-switch value now stays active (denies) in all three, confirmed by
the `kill-switch-unrecognized` test case added to each plugin's own test
script.

**(e) Path normalization.** `citation-gate.sh`'s naive
`path.replace("\\", "/").lstrip("/")` (citation-gate.sh:80 pre-migration)
and `options-gate.sh`'s inline normalization (options-gate.sh:79-108
pre-migration) are both replaced by `gate_lib.gate_normalize_path(root,
path)` (`core/hooks/lib/gate-lib.py:23-45`). An absolute path and a
`./`-prefixed relative path pointing at the same owned file now resolve
identically, confirmed by the `absolute-path-*`/`dot-prefixed-path-*`
test cases added to all three plugins' test scripts.

**(f) Citation regex ASCII fallback.** `CITATION_RE` now accepts `—`,
`--`, or a space-hyphen-space ` - ` as the claim/source separator
(evidence-citation/hooks/citation-gate.sh), confirmed by the
`ascii-dash-citation` test case.

**(g) Semantic upgrade — section/adjacency.** `citation-gate.sh`'s
phase-1 check no longer treats one citation anywhere in `## Evidence
format` as covering the whole section; it now splits the section into
claim-shaped lines (ends in `.`/`:`) and requires each such line to carry
a citation on the same or an immediately adjacent line, confirmed by the
`phase1-one-citation-five-claims` test case (one citation, five claims ->
deny). The phase-2 check applies the same line-adjacency test across the
whole record, with a carry-forward exception: a claim-shaped line with no
adjacent citation is still allowed if it appears verbatim (case-
insensitive substring) in the phase-1 proposal's own content — the same
cross-file lookup `options-gate.sh`'s phase-2 carry-forward check already
performed (madr-options/hooks/options-gate.sh) — so a claim genuinely
carried forward from phase 1 is not double-penalized here.

**(h) Mandatory test cases + full-suite green.** Each of the three
plugins' `tests/run-gate-tests.sh` gained: `Edit`/`MultiEdit` with
`replace_all` true/mixed against a multiply-occurring `old_string`;
malformed JSON (truncated/empty/non-object); kill-switch set to an
unrecognized value (stays active); absolute-path and `./`-prefixed-path
fixtures matching the same owned target; and a `Bash`-tool write reaching
the same owned target a `Write` call would hit (`gate_bash_write_targets`-
style token scan, added to all three gates — a net-new capability, since
no gate previously inspected `Bash` tool_input at all — survey §7(b)).
54 cases pass across the three plugin scripts (21 evidence-citation, 15
nygard-adr-spine, 18 madr-options) — evidence-citation/tests/
run-gate-tests.sh, nygard-adr-spine/tests/run-gate-tests.sh, madr-options/
tests/run-gate-tests.sh, this session's own run. `core/hooks/tests/
compliance-check.sh` exits 0 against all three plugins' `hooks/`
directories — this session's own run, confirmed against `core/hooks/
tests/compliance-check.sh` (core repo, gate-lib compliance detector).
Each plugin's test script now checks for `gate-lib.sh`'s resolvability
first and prints `SKIP-ALL`/exits 0 when core isn't checked out alongside
this repo, matching the existing external-dependency SKIP posture already
in `tests/run-gate-tests.sh` for `record-fields-gate.sh`/`trailer-gate.sh`
— tests/run-gate-tests.sh (pre-existing pattern, unchanged by this issue).

**(i) README reconciliation.** Removed the three ghost file entries
(`feasibility/hooks/record-fields-gate.sh`, `trailer-gate.sh`,
`handbook-trigger-gate.sh` — none exist on disk, confirmed by `find . -type
f` in this session, matching survey §8's finding) from `## What is here`;
documented all three sibling methodology plugins
(`madr-options/hooks/options-gate.sh`, `nygard-adr-spine/hooks/
spine-gate.sh`, `evidence-citation/hooks/citation-gate.sh`) and their kill
switches (`MADR_OPTIONS_GATE_OFF`, `NYGARD_ADR_SPINE_GATE_OFF`,
`EVIDENCE_CITATION_GATE_OFF`) alongside the existing
`FEASIBILITY_CYCLE_OFF` documentation — README.md.

## Why

Referencing `gate-lib.sh` rather than hand-fixing each defect locally
closes the exact duplication risk `docs/handbooks/gate-house-standard.md`
warns core's own prior gates already suffered, now reproduced locally in
miniature by this repo's three independently hand-rolled copies —
docs/issue-42/proposals/2026-08-01-gate-a-plus-remediation.md
("Rationale"). `spine-gate.sh`'s unconditional Edit deny was a defect,
not a conservative-by-design choice, because `gate_reconstruct_write`
exists specifically to turn a diff fragment into the full resulting
content — core/hooks/lib/gate-house-standard.md:30-33.

## Open findings

None open at delivery. The one item deferred rather than resolved is the
pre-existing `record-fields-gate.sh` test mismatch under "What did not
work" / "Risks" below — out of this issue's write set, flagged for a
follow-up rather than left silent.

## Next steps

None required to close this issue — every item in the approved proposal's
"What will be done" (a)-(i) is delivered and green. The one carried-
forward item is the core-side `record-fields-gate.sh` mismatch under
"Open finding resolution path" immediately below, which belongs to a
follow-up outside this repo's write set.

## Open finding resolution path

The `record-fields-gate.sh` test mismatch (`record-empty`/
`open-no-backlog` want=deny got=allow) resolves by either core fixing its
own gate or this repo's `tests/run-gate-tests.sh` fixtures being updated
to match core's current, intentional behavior — whichever a maintainer
confirms after inspecting `core/hooks/record-fields-gate.sh` directly;
out of this issue's write set (`core/hooks/**` referenced only), so no
resolution is attempted here.

## What did not work

The root `tests/run-gate-tests.sh`'s pre-existing `record-empty` and
`open-no-backlog` cases (targeting core's own `record-fields-gate.sh`,
run only when `CLAUDE_PLUGIN_ROOT_CORE` resolves) fail against the
current core checkout — want=deny, got=allow — this session's own run
with `CLAUDE_PLUGIN_ROOT_CORE` set. This is core's own gate, untouched by
this issue's write set (`core/hooks/**` is out of scope per the approved
proposal's own "Out of scope" section, referenced-only per
`docs/handbooks/canon-scripts.md`), and reproduces identically with none
of this session's edits applied (isolated by re-running the same root
harness with no repo changes and `CLAUDE_PLUGIN_ROOT_CORE` set against
the same core checkout) — not a regression this issue introduced. Left
unfixed and flagged here rather than silently worked around; belongs to
a core-side issue, not this repo's phase 2.

## Consequences

Two-way door: every change in this record is a local reference/behavior
change inside this repo's own three gate scripts and their tests, plus a
README edit — nothing touches `core/hooks/**` itself (out of scope,
referenced not copied), and any single gate could be reverted to its
pre-migration form without affecting the other two or core. The gates now
hard-depend on `core/hooks/lib/gate-lib.sh` being resolvable at hook-run
time (via `CLAUDE_PLUGIN_ROOT_CORE` or a sibling checkout); when core
isn't installed, the gates fail closed (deny) in production and the test
scripts print `SKIP-ALL` rather than fail, matching this repo's existing
external-dependency posture for `record-fields-gate.sh`/`trailer-gate.sh`.

## Risks

- accepted — citation-gate's line-adjacency heuristic may still
  false-positive on non-claim prose that happens to end in `.`/`:` with
  no citation nearby: this is the same documented trade-off the
  pre-migration gate already carried (evidence-citation/hooks/
  citation-gate.sh's own header comment), narrowed in scope
  (line-adjacent, not whole-document) rather than eliminated, per the
  approved proposal's own "Out of scope" item ruling out a full NLP
  claim detector.
- accepted — `options-gate.sh`'s Edit/MultiEdit posture (deny outright:
  it still needs the complete `Write` content to verify Candidates/
  Options sections) is unchanged by this issue, per the approved
  proposal's explicit "gate-lib migration only" scope for
  `options-gate.sh`: a known, intentional limitation, not an oversight,
  mitigated by the fact that `options-gate.sh` only fires on the same two
  owned paths citation-gate/spine-gate also protect, and a `Write`
  remains available for any full-record edit.
- deferred — the pre-existing `record-fields-gate.sh` test mismatch
  documented above under "What did not work": it is core's own gate and
  out of this issue's write set; a follow-up issue against
  `tokenmaxxxer-core` (or this repo's root test fixtures, if the mismatch
  turns out to be a fixture drift rather than a live core bug) is the
  right next step.

## Options considered

1. **Reference-adopt `core/hooks/lib/gate-lib.sh`/`gate-lib.py`, migrate
   all three gates onto it (chosen).** Delivered as scoped: all three
   gates now source gate-lib.sh/gate-lib.py for trap, kill-switch, path
   normalization, and (for citation-gate/spine-gate) Edit/MultiEdit
   reconstruction, confirmed by `core/hooks/tests/compliance-check.sh`
   exiting 0 against all three plugins' `hooks/` directories (this
   session's own run).
2. **Hand-patch each of the three gates' own defects in place, without
   sourcing `gate-lib.sh` (dropped).** Rejected in phase 1 (docs/issue-42/
   proposals/2026-08-01-gate-a-plus-remediation.md, "Candidates
   considered" item 2) for reproducing the three-independent-copies
   failure mode and contradicting issue #42's own "자체 재구현 금지"
   precondition; not revisited in phase 2 — no new information changed
   that judgment.
3. **Write a repo-local shared helper (e.g. `feasibility/hooks/lib/
   gate-common.sh`) consolidating the three gates' duplicated logic,
   without depending on core (dropped).** Rejected in phase 1 for being
   the "own reimplementation" issue #42 forbids under a different name;
   not revisited in phase 2.

## Evidence format

Citation format used throughout this record:
`<claim> — <source: path:line | URL | check-name score>`. Claims about
pre-migration gate behavior are cited to the same file:line ranges the
phase-1 survey/proposal already established (carried forward per
docs/issue-42/reports/technical-feasibility/survey.md and docs/issue-42/
proposals/2026-08-01-gate-a-plus-remediation.md); claims about this
session's own test/compliance-check runs are cited to the specific test
script or check invoked, this session's own run.
