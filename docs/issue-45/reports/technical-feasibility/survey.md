# Current-state survey — issue-45 (재감사 잔여 결함, phase 1)

market_argument_supplied: false — this survey reads issue #45's defect
list on its own terms (a re-audit finding), not through any argument
that fixing it unlocks value; the issue text itself carries no market
argument to withhold.

## Scout skip record

Scouting (scout-directive) is skipped under the pure-bugfix condition:
every one of the four residual defects below is a confirmed, reproducible
bug (verified live against this session's own checkout, not inferred from
the issue text alone), and the fix shape for each is already established
by a landed precedent this repo must reference, not invent — core issue
#75's finalized guard/test-group shape, core's own `hooks/hooks.json`
matcher convention, and this repo's own issue-42 remediation pattern for
the other three gates. No external design space to survey; this closes
gaps against standards this repo (and core) already chose.

## §1 — legacy `tests/run-gate-tests.sh` red on main

Reproduced live: `bash tests/run-gate-tests.sh` (this session, with
`CLAUDE_PLUGIN_ROOT_CORE` resolved to the installed core plugin) —
`record-empty` and `open-no-backlog` both `want=deny got=allow`; 8
passed, 2 failed overall — this session's own run.

Root cause traced into `core/hooks/record-fields-gate.sh`
(installed core, `${CLAUDE_PLUGIN_ROOT_CORE}/hooks/record-fields-gate.sh`):
the gate only judges a write whose resolved path matches
`^docs/issue-[0-9]+/reports/${CLAUDE_ROLE}\.md$`
(record-fields-gate.sh:109, `RECORDS_RE`). This session's own
`CLAUDE_ROLE` is `technical-feasibility` — confirmed via `printenv
CLAUDE_ROLE`, this session — but `tests/run-gate-tests.sh`'s `REC`
fixture (tests/run-gate-tests.sh:20) is hardcoded to
`docs/issue-7/reports/feasibility.md`, the pre-rename role name. Because
`rel` (`docs/issue-7/reports/feasibility.md`) never matches
`RECORDS_RE` when `CLAUDE_ROLE=technical-feasibility`, the gate exits 0
("not this role's own record") on every case regardless of content —
`record-empty` and `open-no-backlog` both fall through to `allow`
because the gate never actually inspects them, not because the
content-checking logic is broken. `record-complete`/`foreign-path`
happen to already want `allow`, so they mask the same underlying
short-circuit. This is the exact "옛 역할명 잔재" class the issue names,
just surfacing as a silently-neutered test rather than stale prose.

## §2 — hooks.json matcher vs. gate code coverage

All three plugin gates' Python payload handlers accept and inspect
`Bash` tool_input — `tool not in ("Write", "Edit", "MultiEdit", "Bash")`
(madr-options/hooks/options-gate.sh:75, nygard-adr-spine/hooks/
spine-gate.sh:69, evidence-citation/hooks/citation-gate.sh:74) — and
each calls `gate_bash_write_targets`-style scanning to deny a `Bash`
command that writes to an owned path (survey confirmed this pass via
`bash-write-owned-target`/`bash-write-foreign-target` test cases, all
green in `tests/run-gate-tests.sh`'s own run). But every one of the three
plugins' `hooks.json` `PreToolUse` entries carries
`"matcher": "Write|Edit|MultiEdit"` (evidence-citation/hooks/hooks.json,
nygard-adr-spine/hooks/hooks.json, madr-options/hooks/hooks.json) — no
`Bash` alternative. In the real Claude Code runtime (not the test
harness, which invokes the gate script directly and bypasses matcher
routing entirely), a `Bash` tool call never reaches these three gates at
all — the Bash-write-detection code added under issue-42 item (h) is
live in tests only, dead in production. Core's own `hooks/hooks.json`
uses `"matcher": ".*"` for its `PreToolUse` gates
(`core/hooks/hooks.json:15`, installed core), covering every tool
including `Bash` — the precedent this repo's three plugins should match
but currently do not.

## §3 — missing-core test case

Core issue #75 (landed, `f61d52f` in the core checkout at
`/home/jwjung/.tokenmaxxxer/work/tokenmaxxxer-core-issue-75-implementation`)
mandates a seventh test group, `missing-core`, in `gate-lib.sh`'s own
test harness: exercising a gate with `CLAUDE_PLUGIN_ROOT_CORE` pointed at
a nonexistent path and no valid relative fallback, asserting deny (exit
2) — docs/issue-75/proposals/2026-08-01-gate-lib-source-guard-and-py-
parity.md "What will be done" item 4 (core repo). Grepping this repo's
four test scripts (`tests/run-gate-tests.sh`,
`evidence-citation/tests/run-gate-tests.sh`, `nygard-adr-spine/tests/
run-gate-tests.sh`, `madr-options/tests/run-gate-tests.sh`) for
`missing-core`/`missing_core` returns zero hits — this session's own
`grep`. All three plugin gates already carry the source guard core #75
also mandates (`. ".../gate-lib.sh" || { echo ...; exit 2; }` —
madr-options/hooks/options-gate.sh:31-32, nygard-adr-spine/hooks/
spine-gate.sh:29-30, evidence-citation/hooks/citation-gate.sh:32-33,
matching core #75's adopted call-site-guard shape) — confirming the
issue text's own claim that "source 가드는 이미 모범." The gap is test
coverage only: nothing in this repo exercises that guard path and
asserts deny when core is unresolvable.

## §4 — README / manifest legacy role name

`README.md` documents this repo's contract-level naming as
`branch issue-<n>/feasibility` and `record at
docs/issue-<n>/reports/feasibility.md` (README.md:8-9). Both are stale:
this very session's board-gate denials (live, this session) name the
required branch as `issue-45/technical-feasibility`, and the
role-directive system reminder + `CLAUDE_ROLE=technical-feasibility`
(printenv, this session) both confirm the enforced record path is
`docs/issue-45/reports/technical-feasibility.md`, not `feasibility.md`.
`README.md`'s `## What `feasibility` decides` heading and body (README.md
:12-15) likewise refer to "the feasibility role" where the contract now
enforces "technical-feasibility." The plugin/marketplace identifiers
themselves (`.claude-plugin/marketplace.json` `name: "feasibility"`,
`plugins[0].name: "feasibility"`, `source: "./feasibility"`) are internal
short IDs, not the user-facing contract vocabulary the issue's "옛
역할명" complaint targets, and are not renamed by this proposal (see
"Out of scope" in the sibling proposal document) — the defect is
specifically the branch/record-path prose in `README.md` describing a
role name the live contract no longer uses. No ghost *files* (nonexistent
paths) were found beyond the prose already fixed under issue-42 — `find
. -type f` cross-checked against README's `## What is here` file list
this session found no new mismatch — so §4's remaining scope is the
role-name prose, not additional ghost-file removal.

## Constraints carried into the proposal

- No change to `core/hooks/**` itself in this repo's phase 2 — referenced
  only, per `docs/handbooks/canon-scripts.md`'s reference-not-copy rule
  (same constraint issue-42's proposal already applied).
- The plugin/marketplace short identifier `feasibility` (directory name,
  `plugin.json`/`marketplace.json` `name` fields) is out of scope — only
  the branch/record-path prose in `README.md` is a confirmed defect
  against the live contract; renaming the plugin identifier itself is a
  separate, larger decision this issue does not ask for and this survey
  found no live-contract evidence requiring.
