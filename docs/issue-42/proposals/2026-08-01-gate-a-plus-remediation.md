---
subject: issue-42
role: technical-feasibility
---

# Proposal — gate A+ remediation (phase 1 design)

Phase 1 only. No execution in this PR — no gate script edit, no
`gate-lib.sh` sourcing, no test file lands here. Survey: `docs/issue-42/
reports/technical-feasibility/survey.md`. Scout brief: `docs/issue-42/
reports/technical-feasibility/scout-brief.md`.

files touched in phase 2: `evidence-citation/hooks/citation-gate.sh`
(gate-lib migration, Edit/MultiEdit reconstruction, path normalization,
em-dash regex fix, section/adjacency semantic upgrade), `nygard-adr-spine/
hooks/spine-gate.sh` (gate-lib migration, Edit/MultiEdit reconstruction —
replaces the current unconditional deny), `madr-options/hooks/
options-gate.sh` (gate-lib migration only — its path normalization and
section-scoped parsing are already close to standard, per survey §9 scope
note and this proposal's own re-read), each plugin's own `hooks/tests/`
or `tests/run-gate-tests.sh` (six mandatory case groups), root `tests/
run-gate-tests.sh` (fold-in unchanged), `README.md` (ghost-file removal,
real-plugin/kill-switch documentation).

## Question

Can this repo's three methodology gates (`citation-gate.sh`,
`spine-gate.sh`, `options-gate.sh`) be brought to A+ — fail-closed
uniformly, contradiction-free Edit/MultiEdit handling, section/adjacency
semantic checks, full mandatory test coverage, an accurate README — by
referencing core's already-landed `gate-lib.sh`/`gate-lib.py` rather than
re-deriving equivalent logic a fourth time in this repo?

## Timebox and acceptance criteria

Phase 2 timebox: one focused session, no multi-day investigation —
every defect this proposal names is already located to a specific file
and line range (survey.md), and the fix for each is "call the canon
function instead of the hand-rolled equivalent," not open-ended design
work. Acceptance: `core/hooks/tests/compliance-check.sh` exits 0 against
all three plugins' `hooks/` directories; the six mandatory test-case
groups pass in each plugin's own test script; the full suite (root +
three plugins) is green; `README.md`'s file/kill-switch inventory matches
`ls` output exactly. If `compliance-check.sh` surfaces a defect class not
named in this proposal (e.g. inside `options-gate.sh`'s currently
under-read Edit path), phase 2 fixes it too — the checklist below is the
floor this proposal commits to, not a ceiling that blocks fixing what the
detector finds (matching issue-64's own precedent, scout-brief.md "adopt"
item 2).

## Candidates considered

1. **Reference-adopt `core/hooks/lib/gate-lib.sh`/`gate-lib.py`, migrate
   all three gates onto it (chosen).** Every fail-closed trap, kill-switch
   check, Edit/MultiEdit reconstruction, and path normalization this repo
   needs is already implemented, tested, and canonized in core
   (`docs/handbooks/gate-house-standard.md`, core repo). Migrating sources
   one already-correct implementation instead of adding a fourth
   independent copy of the same logic.
2. **Hand-patch each of the three gates' own defects in place, without
   sourcing `gate-lib.sh` (rejected).** Fixes today's known bugs
   (em-dash-only regex, spine-gate's unconditional Edit deny) but leaves
   three gates each maintaining their own trap/kill-switch/reconstruction
   logic — precisely how this repo arrived at three independently
   hand-rolled, subtly different copies of the same boilerplate in the
   first place (survey §3). Also directly contradicts issue #42's own
   stated precondition ("자체 재구현 금지"). Rejected.
3. **Write a repo-local shared helper (e.g. `feasibility/hooks/lib/
   gate-common.sh`) consolidating the three gates' duplicated logic,
   without depending on core (rejected).** Solves the three-copies
   duplication within this repo but re-derives — under a different name —
   exactly the logic `gate-lib.sh` already provides and core's own
   `stub-check.sh`/`canon-manifest.txt` machinery is built to catch as a
   vendored copy. Rejected: this is the "own reimplementation" issue #42
   forbids, just refactored to look local rather than copy-pasted three
   times.

## Rationale

**Why reference `gate-lib.sh` rather than hand-fix each defect locally**:
survey §3 confirms zero references to `gate-lib.sh`/`gate-lib.py` anywhere
in the three plugins today, despite core issue #72 (the stated
precondition) having already landed the exact functions needed — the trap,
the kill-switch check, `Edit`/`MultiEdit`/`NotebookEdit` reconstruction
honoring `replace_all`, and root-relative path normalization
(core/hooks/lib/gate-lib.sh:36-90). Each of this repo's three gates
independently re-derives the trap and kill-switch check by hand
(evidence-citation/hooks/citation-gate.sh:2-3,33-35; nygard-adr-spine/
hooks/spine-gate.sh:26-32; madr-options/hooks/options-gate.sh:2-3,32-35) —
the exact divergence-over-time failure mode `gate-house-standard.md:39-57`
documents core's own prior canon having suffered, now reproduced locally
in miniature by this repo's three copies (currently harmless by content —
survey §3 found the kill-switch semantics already correct in all three —
but structurally the same risk).

**Why `spine-gate.sh`'s current behavior (unconditional Edit/MultiEdit
deny) is a defect and not a conservative-by-design choice**: the gate's
own comment (survey §1) frames this as "Edit/MultiEdit carry diff
fragments, not the full record; this gate needs the complete content" —
correct as a constraint, wrong as a response. `gate_reconstruct_write`
exists specifically to turn a diff fragment into the full resulting
content by replaying it against the current on-disk file
(core/hooks/lib/gate-house-standard.md:30-33), which is exactly the
capability missing here. Continuing to deny every Edit outright once that
capability is referenced would be strictly worse than before migration —
it would keep the over-blocking half of the issue's named contradiction
while fixing only citation-gate's under-checking half.

**Alternative considered and rejected — leave `citation-gate.sh`'s
regex accepting only em-dash, and instead have `directive.sh` instruct the
agent to always type an em-dash**: this pushes a formatting requirement
onto every future write instead of fixing the check, and does nothing for
a human reviewer or an external contributor who is not reading
`directive.sh`'s SessionStart text at the moment of typing. Rejected in
favor of widening `CITATION_RE` to accept an ASCII `--`/`-` separator
alongside `—`, since the format the directive already documents
(`<claim> — <source: ...>`) is a *display* convention, not something a
gate should refuse to recognize in its ASCII-typed form.

## What will be done

**(a) `citation-gate.sh` — Edit/MultiEdit reconstruction.**
`extract_text` (citation-gate.sh:95-114) is replaced by a call into
`gate_lib.gate_reconstruct_write(tool, tool_input, current_content)`
(loaded via `GATE_LIB_PY`, per `gate-lib.sh`'s own usage comment),
reading the file's current on-disk content first so `Edit`/`MultiEdit`
are checked against the actual resulting document, not a bare
`new_string` fragment. Closes the fail-open half of the issue's named
contradiction.

**(b) `spine-gate.sh` — Edit/MultiEdit reconstruction, remove the
unconditional deny.** `content = ti.get("content")` /
`if not isinstance(content, str): deny(...)` (spine-gate.sh:116-121) is
replaced by the same `gate_reconstruct_write` call used in (a), so an
`Edit`/`MultiEdit` against the phase-2 record is checked against its real
resulting content instead of being blocked outright. Closes the
fail-closed-too-hard half of the same contradiction.

**(c) Kill-switch migration (all three gates).** Each gate's hand-rolled
kill-switch case statement (citation-gate.sh:33-35, spine-gate.sh:28-32,
options-gate.sh:32-35) is replaced by `. "$GATE_LIB_SH"` +
`gate_kill_switch_active "${X_OFF:-}"`, matching `gate-lib.sh`'s own usage
comment exactly. Semantics are unchanged (already correct per survey §3)
— this closes the duplication risk, not a live bug.

**(d) Fail-closed trap unification.** Each gate's hand-rolled
`__fc()`/`trap __fc EXIT` (or, for `spine-gate.sh`, its `set -euo
pipefail` + Python `_fc_hook` combination) is replaced by
`gate_trap_fail_closed`, called as the first statement per `gate-lib.sh`'s
own documented ordering (before `set -uo pipefail`).

**(e) Path normalization (`citation-gate.sh` only).**
`norm = path.replace("\\", "/").lstrip("/")` (citation-gate.sh:80) is
replaced by `gate_lib.gate_normalize_path(root, path)`, resolved the same
way `spine-gate.sh` and `options-gate.sh` already resolve root
(`CLAUDE_PROJECT_DIR` or git-toplevel fallback — both already implement
this correctly per survey §4/§9 scope note; `citation-gate.sh` is the one
gate of the three that skips root resolution entirely today).
`options-gate.sh`'s own normalization (options-gate.sh:79-108) is
migrated to the same `gate_normalize_path` call for consistency and
duplication removal, not because it is currently wrong.

**(f) Citation regex ASCII fallback.** `CITATION_RE`
(citation-gate.sh:125) is widened from em-dash-only
(`r"—\s*.*(?:...)"`) to accept `—`, `--`, or a single ` - ` (space-hyphen-
space, to avoid matching a mid-word hyphen) as the claim/source separator,
keeping the same source-shape alternation (`source:`/URL/`path:line`)
unchanged.

**(g) Semantic upgrade — section/adjacency, not substring.**
`citation-gate.sh`'s phase-1 check (currently "one citation match anywhere
in the `## Evidence format` section satisfies the whole section",
citation-gate.sh:140) is changed to split the section into individual
claim-lines (a claim-shaped line = ends in `.`/`:`, per the phase-2
heuristic already in the same file) and require each such line to carry
its own citation on the same line or the immediately following line —
the same same-line/adjacent-line adjacency test `spine-gate.sh`'s Risks
check already applies to disposition tags (survey §5 names this as the
already-correct comparator shape). `citation-gate.sh`'s phase-2 check
(currently "any citation anywhere in the whole document" satisfies every
claim, citation-gate.sh:156) is narrowed the same way: a claim-shaped line
with no citation on itself or the immediately adjacent line denies, unless
it is a verbatim match (case-insensitive substring) of a sentence already
present, verbatim, in the phase-1 proposal's own content (the
"carried-forward, not re-derived" case) — read via the same cross-file
lookup `options-gate.sh`'s phase-2 carry-forward check already performs
(survey confirms this pattern exists and works today for candidates).

**(h) Mandatory test cases + full-suite green.** Add, to each of the
three plugins' own test script: `Edit` with `replace_all: true` against a
multiply-occurring `old_string`; `MultiEdit` with mixed `replace_all`
true/false edits; malformed JSON (truncated, empty, non-object); kill
switch set to an unrecognized value, asserting the gate stays **active**;
an absolute `file_path` plus a `./`-prefixed variant matching the same
scope an existing relative-path fixture already matches; a `Bash`-tool
file write reaching the same target a `Write`-tool call would hit (net-new
capability via `gate_bash_write_targets`, since none of the three gates
currently inspects `Bash` tool_input at all — survey §7(b)). Run
`core/hooks/tests/compliance-check.sh` against `evidence-citation/hooks/`,
`nygard-adr-spine/hooks/`, `madr-options/hooks/` as the ship-time evidence
step (scout-brief.md "adopt" item 2). Root `tests/run-gate-tests.sh`
already folds in each plugin's own test script (survey confirms this
wiring exists, tests/run-gate-tests.sh:57-66) — no change needed there
beyond whatever the plugin scripts themselves gain.

**(i) README reconciliation.** Remove the three ghost file entries
(`feasibility/hooks/record-fields-gate.sh`, `trailer-gate.sh`,
`handbook-trigger-gate.sh` — none exist on disk, survey §8) from `##
What is here`; add `madr-options/`, `nygard-adr-spine/`,
`evidence-citation/` as documented sibling plugins (currently entirely
absent from the README despite being merged since issue-39); add the
three kill switches (`MADR_OPTIONS_GATE_OFF`, `NYGARD_ADR_SPINE_GATE_OFF`,
`EVIDENCE_CITATION_GATE_OFF`) next to the existing
`FEASIBILITY_CYCLE_OFF` documentation (README.md:66, survey §9).

## Out of scope

- Any change to `core/hooks/**` itself — referenced only, per
  `docs/handbooks/canon-scripts.md`'s reference-not-copy rule.
- Re-litigating issue-39's three-plugin composition architecture (which
  plugin owns which methodology, how directive fragments splice into
  `feasibility/hooks/directive.sh`) — this issue fixes the three existing
  gates in place, it does not redesign the plugin set.
- A line-by-line pre-audit of every remaining defect inside
  `options-gate.sh`'s Edit/MultiEdit path beyond what this proposal
  already names — `compliance-check.sh`'s phase-2 output is the
  authoritative detector for anything this proposal's necessarily
  incomplete read (survey §9 scope note) missed, matching issue-64's own
  precedent (scout-brief.md "adopt" item 2).
- Widening the citation-adjacency check (item (g)) into a full NLP claim
  detector — it stays a line-adjacency heuristic, same false-positive
  trade-off already documented in `citation-gate.sh`'s own header comment,
  narrowed from whole-document to line-adjacent scope, not replaced with a
  different detection technology.

## Evidence format

Citation format used throughout this proposal and its survey/scout-brief:
`<claim> — <source: path:line | URL | check-name score>`. Every factual
claim above about current gate behavior is cited to the exact file:line
range read to establish it (e.g. citation-gate.sh:125 for the em-dash-only
regex, spine-gate.sh:116-121 for the unconditional Edit deny), and every
claim about the canon standard is cited to
`core/hooks/lib/gate-lib.sh`/`docs/handbooks/gate-house-standard.md`'s own
line ranges, per `docs/issue-42/reports/technical-feasibility/survey.md`
and `docs/issue-42/reports/technical-feasibility/scout-brief.md`.

## How you'll know it worked

- This proposal PR is open against `main`, referencing `#42` (plain, not
  Closes/Fixes), with survey + scout-brief + this proposal committed under
  `docs/issue-42/`.
- On Approve, phase 2 lands (a)-(i): `citation-gate.sh` and
  `spine-gate.sh` both call `gate_reconstruct_write` for `Edit`/
  `MultiEdit` (confirmed by a test that edits an already-compliant record
  via `Edit` and gets `allow`, where today `spine-gate.sh` would `deny`
  and `citation-gate.sh` would silently under-check); all three gates
  source `gate-lib.sh`/`gate-lib.py` for trap, kill-switch, and path
  normalization, confirmed by `core/hooks/tests/compliance-check.sh`
  exiting 0 against all three plugins' `hooks/` directories; a citation
  written with an ASCII `-` passes `citation-gate.sh`'s phase-1 check; a
  phase-1 `## Evidence format` section with one citation covering five
  distinct claims is denied (the section/adjacency upgrade, confirmed by a
  new test case); the six mandatory test-case groups pass in each
  plugin's own test script and the full suite (root + three plugins) is
  green; `README.md`'s `## What is here` lists only files that exist on
  disk and documents all three methodology plugins and their kill
  switches.
