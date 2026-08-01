---
subject: issue-45
role: technical-feasibility
---

# Proposal — 게이트 A+ 최종 마감: 재감사 잔여 결함 보수 (phase 1 design)

Phase 1 only. No execution in this PR — no gate script edit, no test
file lands here. Survey: `docs/issue-45/reports/technical-feasibility/
survey.md`.

files touched in phase 2: `tests/run-gate-tests.sh` (REC fixture role
name), `evidence-citation/hooks/hooks.json`, `nygard-adr-spine/hooks/
hooks.json`, `madr-options/hooks/hooks.json` (matcher), each plugin's own
`tests/run-gate-tests.sh` (`missing-core` case), `README.md`
(branch/record-path prose).

## Question

Can this repo's remaining post-issue-42 gaps — a legacy test fixture
still keyed to the pre-rename role name, a matcher/code coverage gap
that leaves the Bash-write defense dead in production, missing
`missing-core` test coverage for a guard that already exists, and stale
role-name prose in `README.md` — be closed by referencing already-landed
precedent (core issue #75's finalized guard/test-group shape, core's own
`hooks.json` matcher convention, this repo's own live contract
enforcement) rather than by any new design?

## Timebox and acceptance criteria

Phase 2 timebox: one focused session, no multi-day investigation — all
four defects are already located to a specific file/line by
`survey.md`, and every fix references a precedent this repo or core
already adopted (no open design question). Acceptance:
`bash tests/run-gate-tests.sh` (root) is green (0 failed); each of the
three plugins' own `tests/run-gate-tests.sh` includes and passes a
`missing-core` case; `core/hooks/tests/compliance-check.sh` still exits
0 against all three plugins' `hooks/` directories after the matcher
change (matcher is not a compliance-check-scanned surface, but must not
regress); `README.md`'s branch/record-path prose names
`technical-feasibility`, not `feasibility`, everywhere the live contract
enforces that name; a live `Bash` tool call targeting an owned record
path is denied end-to-end through the real `hooks.json` matcher (not
just the direct-invocation test harness). If any of these checks
surfaces a defect class not named in this proposal, phase 2 fixes it too
— matching issue-42's own precedent (its proposal's "Timebox and
acceptance criteria" section, same clause).

## Candidates considered

1. **Reference-adopt core #75's finalized guard/test-group shape and
   core's own `hooks.json` `".*"` matcher convention; fix the test
   fixture's role name to match the live contract (chosen).** Every fix
   below cites a precedent already landed either in core (issue #75's
   `missing-core` seventh test group, core's own `hooks/hooks.json:15`
   `".*"` matcher) or in this repo's own live, observed contract
   enforcement (`CLAUDE_ROLE=technical-feasibility`, board-gate's own
   branch-name denial text, this session). No new logic is designed —
   only referenced and applied, matching issue-42's own governing
   rationale (docs/issue-42/proposals/2026-08-01-gate-a-plus-remediation.
   md, "Rationale") and this issue's own precondition text ("공통 항목은
   core #75의 확정 가드/규칙을 참조 적용").
2. **Widen `tests/run-gate-tests.sh`'s `REC` fixture to a
   role-parameterized value (e.g. read `$CLAUDE_ROLE` at test time and
   build the path dynamically) instead of a literal
   `technical-feasibility` path (rejected).** Would make the fixture
   resilient to a future role rename, but the test's own stated purpose
   (tests/run-gate-tests.sh:4-11 header comment) is to exercise *this
   repo's* record-fields-gate integration under *this repo's actual,
   current* role — a role-agnostic fixture hides exactly the kind of
   drift §1 found (a hardcoded name silently going stale) behind an
   abstraction, rather than keeping the fixture as a literal, readable
   assertion of what the live contract currently requires. Rejected:
   trades a self-documenting literal for indirection that would have
   hidden this exact defect, not caught it earlier.
3. **Leave the matcher as `Write|Edit|MultiEdit` and instead have the
   three gates' own Python payload handlers early-exit cleanly on `Bash`
   with a documented "not reachable via hooks.json today" comment,
   removing the now-dead Bash-handling code (rejected).** Deletes the
   §2 gap by removing the capability rather than wiring it up, directly
   contradicting issue-42's own delivered scope (record-fields-gate item
   (h): "a net-new capability, since no gate previously inspected `Bash`
   tool_input at all") and this issue's own requirement 2 ("hooks.json
   matcher와 코드의 도구 커버리지 완전 정합" — full parity, not parity by
   deletion). Rejected: the code already exists, tested, and correct;
   the gap is wiring, not design.
4. **Rename the plugin/marketplace short identifier `feasibility` to
   `technical-feasibility` repo-wide (directory, `plugin.json`,
   `marketplace.json`, install command) alongside the README prose fix
   (rejected for this issue).** Would fully unify the naming, but
   survey.md §4 found no live-contract evidence requiring the plugin
   *identifier* itself to change — only the branch/record-path *prose*
   is demonstrably wrong against the live contract. A full identifier
   rename touches the marketplace install command every existing
   installer has already run (`claude plugin marketplace add
   tokenmaxxxer/feasibility-agent-rulebook`), which is a breaking,
   externally-visible change this issue's re-audit scope does not ask
   for and this proposal's timebox does not budget design/migration work
   for. Rejected for this issue; left as a candidate a future issue could
   pick up if the identifier mismatch itself becomes a confirmed defect
   (not just a prose one).

## Rationale

**Why the `REC` fixture fix is a one-line literal update, not a
redesign**: survey.md §1 traced the failure to a single stale string
(`tests/run-gate-tests.sh:20`, `docs/issue-7/reports/feasibility.md`)
that no longer matches `RECORDS_RE`'s role-scoped pattern under this
session's own confirmed `CLAUDE_ROLE=technical-feasibility` — the fix is
updating the literal to `docs/issue-7/reports/technical-feasibility.md`,
the same path shape every other record in this repo already uses (e.g.
`docs/issue-42/reports/technical-feasibility.md`, landed).

**Why the matcher fix is `".*"`, matching core, not an enumerated
`Write|Edit|MultiEdit|Bash`**: core's own `hooks/hooks.json:15` already
uses `".*"` for its `PreToolUse` gates, which is also future-proof
against a fifth write-capable tool this repo's gates would otherwise
need a sixth matcher update to cover — the same generality argument
`gate_bash_write_targets`'s own design already accepts (core issue #75
proposal, "Python port strategy" rationale: match the existing precedent
rather than re-deriving a narrower one).

**Why the `missing-core` case is added per-plugin, not once at the root
harness**: each plugin's own `tests/run-gate-tests.sh` already owns its
own kill-switch/malformed-JSON/path-normalization mandatory groups
(issue-42 item (h)) — `missing-core` is the seventh such mandatory group
core #75 defines, and belongs alongside the other six in the same file
per the same "each plugin ships its own standalone test script" pattern
`tests/run-gate-tests.sh`'s own header comment already documents
(tests/run-gate-tests.sh:69-72).

**Why README's fix is prose-only, not a rename**: the branch name and
record path are facts about the *live, enforced* contract — this
session's own board-gate denial text is direct, reproducible evidence of
what branch name the gate requires (`issue-45/technical-feasibility`),
so the fix is making the README's stated fact match the gate's actual,
observed behavior, not a stylistic preference between two acceptable
names.

## What will be done

**(a) Fix `tests/run-gate-tests.sh`'s stale role name.** `REC` (line 20)
changes from `docs/issue-7/reports/feasibility.md` to `docs/issue-7/
reports/technical-feasibility.md`, restoring `RECORDS_RE` matching under
this repo's actual `CLAUDE_ROLE`. Re-run confirms `record-empty`/
`open-no-backlog` now correctly `want=deny got=deny`.

**(b) Widen the three plugin gates' `hooks.json` matcher.** `"matcher":
"Write|Edit|MultiEdit"` becomes `"matcher": ".*"` in
`evidence-citation/hooks/hooks.json`, `nygard-adr-spine/hooks/
hooks.json`, `madr-options/hooks/hooks.json`, matching core's own
`hooks/hooks.json:15`. No gate script change — the Python handlers
already accept `Bash` (survey §2).

**(c) Add a `missing-core` mandatory test case to each plugin's own
`tests/run-gate-tests.sh`.** Point `CLAUDE_PLUGIN_ROOT_CORE` at a
nonexistent path with no valid relative fallback and assert the gate
denies (exit 2), mirroring core #75's own `run-gate-lib-tests.sh`
`missing-core` group shape (core issue-75 proposal, "What will be done"
item 4) applied against each plugin's already-landed source guard
(survey §3 confirms the guard clause already exists in all three gates).

**(d) Fix README's branch/record-path prose.** `README.md:8-9`'s
`branch issue-<n>/feasibility` / `docs/issue-<n>/reports/
feasibility.md` becomes `branch issue-<n>/technical-feasibility` /
`docs/issue-<n>/reports/technical-feasibility.md`; `README.md:12`'s
`## What \`feasibility\` decides` heading and its immediately following
body prose are updated to name `technical-feasibility` wherever they
describe the enforced role identifier, leaving the plugin/marketplace
short identifiers (`feasibility` directory, `plugin.json`/
`marketplace.json` `name` fields, install command) unchanged per
"Candidates considered" item 4.

## Out of scope

- Any change to `core/hooks/**` itself — referenced only, per
  `docs/handbooks/canon-scripts.md`'s reference-not-copy rule (same
  constraint issue-42 applied).
- Renaming the plugin/marketplace short identifier `feasibility`
  (directory, `plugin.json`, `marketplace.json`, install command) — no
  live-contract evidence requires it (survey §4); left for a future
  issue if the identifier mismatch itself becomes a confirmed defect.
- Any new gate logic or semantic check beyond what issue-42 already
  delivered — this issue closes wiring/coverage/prose gaps against
  already-landed logic, it does not add new detection capability.
- A line-by-line pre-audit of every remaining defect class beyond the
  four this proposal names — `compliance-check.sh`'s and
  `tests/run-gate-tests.sh`'s own green/red output are the authoritative
  detectors for anything this proposal's necessarily incomplete read
  missed, matching issue-42's own precedent.

## Evidence format

Citation format used throughout this proposal and its survey:
`<claim> — <source: path:line | URL | check-name score>`. Every claim
about current gate/test/README behavior is cited to the exact file:line
range read to establish it, and every claim about landed precedent is
cited to the specific core commit/proposal or this repo's own prior
issue-42 record, per `docs/issue-45/reports/technical-feasibility/
survey.md`.

## How you'll know it worked

- This proposal PR is open against `main`, referencing `#45` (plain, not
  Closes/Fixes), with survey + this proposal committed under
  `docs/issue-45/`.
- On Approve, phase 2 lands (a)-(d): `bash tests/run-gate-tests.sh`
  (root) reports `0 failed` (currently `2 failed`); each plugin's own
  test script reports a passing `missing-core` case; a `Bash` tool call
  targeting a `citation-gate`/`spine-gate`/`options-gate`-owned path is
  denied when exercised through the real `hooks.json` matcher wiring
  (not only the direct-invocation harness); `README.md`'s branch/
  record-path prose matches this repo's actual, live-enforced branch
  naming and record path exactly.
