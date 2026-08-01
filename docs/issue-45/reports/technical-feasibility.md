---
subject: issue-45
role: technical-feasibility
loop_state: verdict
---

# Record — 게이트 A+ 최종 마감: 재감사 잔여 결함 보수 (phase 2)

## Status

accepted

## Context

The 2026-08-01 re-audit (issue #45) named four residual defects left after issue-42's gate-lib migration, all four already located and cited in phase 1 — source: docs/issue-45/reports/technical-feasibility/survey.md.

Defect 1: `tests/run-gate-tests.sh`'s `REC` fixture was hardcoded to the pre-rename role name `docs/issue-7/reports/feasibility.md`, silently neutering `record-fields-gate.sh`'s content checks under this session's actual `CLAUDE_ROLE=technical-feasibility` — source: docs/issue-45/reports/technical-feasibility/survey.md, section 1.

Defect 2: the three plugin gates' `hooks.json` `PreToolUse` matcher (`Write|Edit|MultiEdit`) left the already-implemented `Bash`-write detection dead in the real runtime, reachable only through the direct-invocation test harness — source: docs/issue-45/reports/technical-feasibility/survey.md, section 2.

Defect 3: no `missing-core` test case exercised the already-present source guard in any of the four test scripts, against core issue #75's landed seventh-mandatory-group precedent — source: docs/issue-45/reports/technical-feasibility/survey.md, section 3.

Defect 4: `README.md`'s branch/record-path prose still named `feasibility` where the live contract enforces `technical-feasibility` — source: docs/issue-45/reports/technical-feasibility/survey.md, section 4.

The approved phase-1 proposal committed to closing all four by referencing already-landed precedent rather than any new design — source: docs/issue-45/proposals/2026-08-01-gate-a-plus-final-remediation.md.

## Decision

go

## Why

Every fix cites a precedent already landed either in core or in this repo's own live, observed contract enforcement — source: docs/issue-45/proposals/2026-08-01-gate-a-plus-final-remediation.md, "Candidates considered" item 1.

No new gate logic or design was needed; this closes wiring/coverage/prose gaps against already-landed capability, matching issue-42's own precedent scope — source: docs/issue-42/reports/technical-feasibility.md, "Decision".

## What was done

**(a) `tests/run-gate-tests.sh`'s stale role name.** `REC` changed from `docs/issue-7/reports/feasibility.md` to `docs/issue-7/reports/technical-feasibility.md` — source: tests/run-gate-tests.sh:20. This restores `RECORDS_RE` matching under `CLAUDE_ROLE=technical-feasibility`; `record-empty`/`open-no-backlog` now correctly report `want=deny got=deny` — source: this session's own `bash tests/run-gate-tests.sh` run.

**(a-followup) `GOOD` fixture field-contract drift, found by fixing (a).** With `REC` corrected, `record-fields-gate.sh` began actually inspecting the fixture content and denied `record-complete` (`want=allow got=deny` on first re-run) — source: this session's own `bash tests/run-gate-tests.sh` run. Core's live gate requires a `loop_state:` field and an "open findings" section, not the `status:` field the old `GOOD` fixture carried — source: installed core `hooks/record-fields-gate.sh`, lines 174-198. This is a stale fixture shape predating core issue #66's field-contract evolution, never exercised while the path mismatch masked all content checks. Fixed by updating `GOOD` to `loop_state: landed` plus an `## Open findings` section; `record-complete` now reports `want=allow got=allow` — source: this session's own `bash tests/run-gate-tests.sh` run.

**(b) `hooks.json` matcher widened to `".*"`.** `evidence-citation/hooks/hooks.json`, `nygard-adr-spine/hooks/hooks.json`, and `madr-options/hooks/hooks.json` all changed `"matcher": "Write|Edit|MultiEdit"` to `"matcher": ".*"`, matching core's own convention — source: installed core `hooks/hooks.json:15`. No gate script change was needed; the Python handlers already accepted `Bash` — source: docs/issue-45/reports/technical-feasibility/survey.md, section 2. A live `Bash` tool call targeting an owned record/proposal path now reaches all three gates through the real matcher wiring, not only the direct-invocation test harness.

**(c) `missing-core` test case added per plugin.** Each of the three plugins' `tests/run-gate-tests.sh` gained a case pointing `CLAUDE_PLUGIN_ROOT_CORE` at a nonexistent path and asserting deny (exit 2), mirroring core #75's own group-7 shape — source: installed core `hooks/tests/run-gate-lib-tests.sh:230-238`. All three already carried the source guard that case exercises — source: docs/issue-45/reports/technical-feasibility/survey.md, section 3. All three now pass `missing-core` — source: this session's own runs of `evidence-citation/tests/run-gate-tests.sh`, `nygard-adr-spine/tests/run-gate-tests.sh`, `madr-options/tests/run-gate-tests.sh`.

**(d) `README.md`'s branch/record-path prose.** `README.md`'s opening paragraph and "What decides" heading now name `technical-feasibility` as the enforced role identifier and `issue-<n>/technical-feasibility` / `docs/issue-<n>/reports/technical-feasibility.md` as the branch/record path — source: README.md. This matches this session's own board-gate denial text naming branch `issue-45/technical-feasibility` and this session's own `CLAUDE_ROLE=technical-feasibility` — source: this session's own board-gate denial and `printenv CLAUDE_ROLE`. The plugin/marketplace short identifier `feasibility` (repo title, directory name, `plugin.json`/`marketplace.json` name fields, install command) is unchanged, per the approved proposal's own scope — source: docs/issue-45/proposals/2026-08-01-gate-a-plus-final-remediation.md, "Out of scope".

## What did not work

Nothing was reverted or abandoned — source: this record's own "What was done" section above. All four named defects plus the one follow-on defect (a-followup) were fixed as scoped — source: docs/issue-45/proposals/2026-08-01-gate-a-plus-final-remediation.md, "What will be done".

## Consequences

Reversibility: two-way — every change here is a matcher string, a test fixture literal, a new test case, or README prose, none changing gate logic or semantics — source: docs/issue-45/proposals/2026-08-01-gate-a-plus-final-remediation.md, "Timebox and acceptance criteria".

The root suite now reports `0 failed` end to end, including the previously-masked `record-complete` case and all three plugins' new `missing-core` cases — source: this session's own `bash tests/run-gate-tests.sh` run.

`Bash`-tool writes to owned paths are now denied in the real runtime, closing the production gap survey §2 found — source: docs/issue-45/reports/technical-feasibility/survey.md, section 2.

`core/hooks/tests/compliance-check.sh` still exits 0 against all three plugins' `hooks/` directories after the matcher change — source: this session's own run of installed core `hooks/tests/compliance-check.sh` against `evidence-citation/hooks`, `nygard-adr-spine/hooks`, `madr-options/hooks`.

## Risks

- mitigated — widening the matcher to `".*"` means non-write tool calls also route through these `PreToolUse` hooks now; each gate's own early tool-name check already passes through any other tool name as `allow` — source: madr-options/hooks/options-gate.sh:75, nygard-adr-spine/hooks/spine-gate.sh:69, evidence-citation/hooks/citation-gate.sh:74 — so the wider matcher only adds reachability for tools the gates already recognize; no new denial surface was introduced.
- accepted — the plugin/marketplace short identifier `feasibility` still differs from the enforced role name `technical-feasibility`; carried forward as dropped in phase 1 with no live-contract evidence requiring the identifier itself to change — source: docs/issue-45/proposals/2026-08-01-gate-a-plus-final-remediation.md, "Candidates considered" item 4 — left for a future issue if the identifier mismatch itself becomes a confirmed defect.

## Options considered

1. **Reference-adopt core #75's finalized guard/test-group shape and core's own `hooks.json` `".*"` matcher convention; fix the test fixture's role name to match the live contract (chosen).** Delivered as scoped — every fix cites a precedent already landed either in core or in this repo's own live contract enforcement, no new gate logic was designed — source: docs/issue-45/proposals/2026-08-01-gate-a-plus-final-remediation.md, "What will be done".
2. **Widen `tests/run-gate-tests.sh`'s `REC` fixture to a role-parameterized value instead of a literal path (dropped).** Rejected in phase 1 for trading a self-documenting literal for indirection that would have hidden this exact defect rather than caught it — source: docs/issue-45/proposals/2026-08-01-gate-a-plus-final-remediation.md, "Candidates considered" item 2. Not revisited in phase 2; no new information changed that judgment.
3. **Leave the matcher as `Write|Edit|MultiEdit` and delete the now-dead `Bash`-handling code from the three gates instead of wiring it up (dropped).** Rejected in phase 1 for contradicting issue-42's own delivered scope and this issue's own full-parity requirement — source: docs/issue-45/proposals/2026-08-01-gate-a-plus-final-remediation.md, "Candidates considered" item 3. Not revisited in phase 2.
4. **Rename the plugin/marketplace short identifier `feasibility` to `technical-feasibility` repo-wide, alongside the README prose fix (dropped for this issue).** Rejected in phase 1: no live-contract evidence requires the identifier itself to change, and a full rename would break every existing installer's marketplace-add command, a breaking externally-visible change outside this issue's timebox — source: docs/issue-45/proposals/2026-08-01-gate-a-plus-final-remediation.md, "Candidates considered" item 4. Left as a candidate a future issue could pick up, per this record's own "Risks" (accepted).

## Next steps

None — verdict is terminal; all four named defects plus the one follow-on defect are fixed and confirmed green — source: this session's own `bash tests/run-gate-tests.sh` run.

## Open-finding resolution path

None open — both risks in this record's own "Risks" section above already carry a terminal disposition, mitigated or accepted — source: this record, "Risks" section.

## Evidence format

Citation format used throughout this record: `<claim> — <source: URL | path:line | check-name score>`. Claims about pre-fix gate/test/README state are carried forward from docs/issue-45/reports/technical-feasibility/survey.md and docs/issue-45/proposals/2026-08-01-gate-a-plus-final-remediation.md rather than re-derived; claims about this session's own test/compliance-check runs are cited to the specific test script or check invoked, this session's own run.
