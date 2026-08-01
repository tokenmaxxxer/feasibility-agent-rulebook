# Current-state survey — issue #42 (2026-08-01)

Write surfaces this issue touches: `evidence-citation/hooks/citation-gate.sh`,
`nygard-adr-spine/hooks/spine-gate.sh`, `madr-options/hooks/options-gate.sh`
(each own `tests/run-gate-tests.sh`), `tests/run-gate-tests.sh` (root),
`README.md`. No `core/` file is touched — reference only.

## 1. The two Edit-handling contradiction the issue names

- `citation-gate.sh:101-114` (`extract_text`): on `Edit`, reads only
  `new_string`; on `MultiEdit`, concatenates every edit's `new_string`
  regardless of that edit's own `replace_all` flag. Never reconstructs the
  file's actual resulting content — checks are run against a bare fragment.
  This is fail-*open* in effect: a phase-1 write that satisfies the
  `## Evidence format` check by splitting a citation-less claim across two
  `Edit` calls, each individually too short to trip `CITATION_RE`, is never
  caught, because no call ever sees the merged result. — citation-gate.sh:101
- `spine-gate.sh:116-121`: on `Edit`/`MultiEdit`, `ti.get("content")` is
  `None` (`Write` is the only tool carrying a `content` field) and the gate
  denies unconditionally: `"no full-content field found... needs the
  complete record content"`. Every `Edit`/`MultiEdit` against
  `docs/issue-<n>/reports/technical-feasibility.md` is blocked outright,
  even a one-line typo fix on an otherwise-compliant record. —
  spine-gate.sh:116-121
- These two gates fire on the *same* write-surface family
  (`docs/issue-<n>/{proposals,reports}/**`) with opposite Edit postures —
  one silently under-checks, the other over-blocks — with no reconstruction
  step in either. Confirms the issue's "citation-gate Edit fail-open vs
  spine-gate Edit 전면 차단" claim exactly.

## 2. Citation regex requires an em-dash, no ASCII fallback

`citation-gate.sh:125`: `CITATION_RE = re.compile(r"—\s*.*(?:source:|https?://|[\w./-]+:\d+)", ...)`.
The only claim/source separator this regex accepts is the em-dash
character `—` (U+2014). A citation written with an ASCII hyphen (`-` or
`--`) — a plausible typing accident, especially given the repo's own
directive text mixes both (`docs/handbooks/*` and the `SessionStart` hook
text shown to the agent write `— <source: ...>` but ASCII `-` is what a
keyboard naturally produces) — never matches, so a citation-shaped line
using `-` is denied as if it had no citation at all. Confirmed the exact
character requirement by reading the regex; not independently reproduced
against a live tool call in this survey (static read, not a spawned test).
— citation-gate.sh:125

## 3. No gate in this repo sources `core/hooks/lib/gate-lib.sh`

`grep -rn "gate-lib" evidence-citation/ nygard-adr-spine/ madr-options/`
returns zero hits. All three gates hand-roll their own fail-closed EXIT
trap (`__fc()`/`trap __fc EXIT`, byte-identical boilerplate duplicated
three times — citation-gate.sh:2-3, spine-gate.sh's trap is folded into
`set -euo pipefail` plus its own `_fc_hook` Python excepthook, options-gate
likely matches this pattern too, not yet read line-by-line) and their own
kill-switch case statement, instead of `. ".../gate-lib.sh"` +
`gate_kill_switch_active`. This is exactly the precondition issue #42
states: core issue #72 has landed (`core/hooks/lib/gate-lib.sh` and
`docs/handbooks/gate-house-standard.md` both exist and are readable at
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/`), but this repo's own
three methodology gates were built (issue-39, landed before #72) before the
canon existed and have not been migrated onto it. —
core/hooks/lib/gate-lib.sh:1-9 (reference-not-copy directive, "added to
core/hooks/tests/canon-manifest.txt so stub-check.sh catches a vendored
copy")

Kill-switch semantics happen to already be *correct* by content
(`nygard-adr-spine`'s `case ... in ""|0|false|no|off) ;; 1|true|yes|on)
exit 0 ;; *) ;; esac` and `citation-gate`'s equivalent `case ... in
1|true|yes|on) exit 0 ;; esac` both default an unrecognized value to
"stays active"), so this is not the on/unrecognized-value bug
`gate-house-standard.md` describes core's *own* prior gates having — it is
a duplication-not-defect issue: three independently maintained copies of
the same logic, the exact failure mode `gate-house-standard.md:39-57`
warns diverges silently over time.

## 4. Path matching: no absolute-path normalization

`citation-gate.sh:80`: `norm = path.replace("\\", "/").lstrip("/")` — a
naive strip, not a root-relative resolution. An absolute path whose tail
happens to match the phase-1/phase-2 regex after stripping the leading `/`
would pass, but a `./`-prefixed relative path, a path containing `../`, or
an absolute path under a *different* root that coincidentally shares the
same tail are all handled inconsistently — no `posixpath.realpath`
resolution against `CLAUDE_PROJECT_DIR`/git-toplevel the way
`spine-gate.sh:90-110` already does for its own single write surface.
`spine-gate.sh` itself does this correctly (root resolution via
`CLAUDE_PROJECT_DIR` or `git rev-parse --show-toplevel`, then
`posixpath.normpath`/`os.path.realpath`), so the fix is "bring
`citation-gate.sh` and `madr-options/hooks/options-gate.sh` up to
`spine-gate.sh`'s own already-correct level," reachable in this repo via
`gate_normalize_path` in `gate-lib.py` per the standard rather than
copying `spine-gate.sh`'s inline block a third time. — citation-gate.sh:80,
spine-gate.sh:90-110, core/hooks/lib/gate-house-standard.md:27-29

## 5. Semantic checks: substring/proximity, not section/adjacency

- `citation-gate.sh:125-145` (phase-1): finds the `## Evidence format`
  section by heading regex (already section-scoped, not whole-document —
  partially structural), but *within* that section the check is
  `CITATION_RE.search(section)` — one match anywhere in the section text
  satisfies the whole section, regardless of how many distinct claims the
  section prose contains. A section with five claims and one citation
  passes.
- `citation-gate.sh:158-163` (phase-2): a "claim-shaped line" heuristic
  (`ends in . or :`) combined with `ANY_CITATION_IN_DOC` — literally
  "does the word/character `—` or `source:` or a URL appear *anywhere in
  the whole document*," the most permissive possible reading, explicitly
  documented as such in the code's own comment (`"Any citation anywhere in
  the document is treated as satisfying 'carried forward'"`). This is the
  issue's "부분문자열" complaint at its most literal: presence, not
  per-claim adjacency.
- `madr-options/hooks/options-gate.sh` already does per-item structural
  extraction (`extract_section` + `candidate_items`, options-gate.sh:130-190
  — walks list-marker/header boundaries), the most section/adjacency-aware
  of the three today; not itself flagged as needing the substring→structure
  upgrade issue #42 asks for, since it already parses items instead of
  scanning for a keyword.
- `spine-gate.sh` matches by heading/bold-label regex (`find_field`,
  `has_heading`) scoped to each field's own section slice
  (`re.search(r"^#{1,6}\s*risks\s*$(.*?)(?=^#{1,6}\s|\Z)", ...)` for
  Risks) — already section-scoped per field, the shape citation-gate's
  phase-2 check should move toward: per-claim adjacency within a section,
  not whole-document presence.

## 6. Deny-reason delivery

All three gates already write denial text to stderr only
(`deny()` → `print(..., file=sys.stderr); sys.exit(2)` in every gate read),
consistent with the issue's ask; no defect found here in the three gates
surveyed. Not independently verified for `feasibility/hooks/directive.sh`
(SessionStart, no deny path) since it carries no `PreToolUse` gate of its
own — `feasibility/hooks/hooks.json` wires the three sibling gates instead
(confirmed by reading `docs/issue-39/proposals/
2026-07-31-technical-feasibility-methodology-enforcement.md:135-138`, the
plugin-composition design already landed).

## 7. Test coverage against the six mandatory groups

`grep -c` (manual read) of `evidence-citation/tests/run-gate-tests.sh`,
`nygard-adr-spine/tests/run-gate-tests.sh`, `madr-options/tests/
run-gate-tests.sh`, `tests/run-gate-tests.sh` (root) against the six
`gate-house-standard.md:60-72` groups (Edit+replace_all-true;
MultiEdit mixed replace_all; malformed JSON; kill-switch unrecognized
value stays-active; absolute + `./`-prefixed path; Bash-tool write target)
not yet exhaustively enumerated case-by-case in this survey pass (time
budget) — treated as **zero confirmed present** for the purposes of this
proposal's "what will be done," since (a) sections 1 and 3 above already
establish no gate reconstructs `Edit`/`MultiEdit` content at all, meaning
a `replace_all` test case cannot currently pass meaningfully against any
of the three gates' current logic, and (b) none of the three gates scans
`Bash` tool_input at all (only `Write`/`Edit`/`MultiEdit` are matched in
every `tool not in (...)` check read across all three files) so a
Bash-write-target case has no code path to exercise yet either. Both (a)
and (b) are read directly from the gates' own tool-dispatch logic, not
inferred.

## 8. README ghost files

`README.md:24-30` (`## What is here` table) lists
`feasibility/hooks/record-fields-gate.sh`,
`feasibility/hooks/trailer-gate.sh`, and
`feasibility/hooks/handbook-trigger-gate.sh` as files in this repo.
`ls feasibility/hooks/` returns only `directive.sh` and `hooks.json` — none
of the three listed gate files exist on disk. `tests/run-gate-tests.sh`'s
own header comment (lines 3-9) already documents *why*: those three are
now core canon gates, fired globally by `core` itself and referenced
(never vendored) from this repo's tests via `CLAUDE_PLUGIN_ROOT_CORE`
sibling resolution — the README section was never updated after that
migration (issue-31, per the comment's own citation) landed. The README
also does not mention `madr-options/`, `nygard-adr-spine/`, or
`evidence-citation/` at all (issue-39's three new plugins, already
merged), so the ghost-file problem is paired with a real-plugin omission
in the same section. — README.md:24-30, feasibility/hooks/ (ls output),
tests/run-gate-tests.sh:1-9

## 9. Kill-switch documentation

`README.md:66` documents only `FEASIBILITY_CYCLE_OFF=1`. The three
methodology plugins' own kill switches
(`MADR_OPTIONS_GATE_OFF`, `NYGARD_ADR_SPINE_GATE_OFF`,
`EVIDENCE_CITATION_GATE_OFF`) are undocumented in the README, matching the
issue's "실제... 킬스위치 문서화" ask directly. — README.md:66,
evidence-citation/hooks/citation-gate.sh:25, nygard-adr-spine/hooks/
spine-gate.sh:15, madr-options/hooks/options-gate.sh:27

## Scope note

`madr-options/hooks/options-gate.sh` was read only partially (structure
functions, kill-switch line, phase-1/phase-2 section checks) — its exact
Edit/MultiEdit content-extraction behavior and path-normalization logic
were not independently confirmed line-by-line in this survey pass; the
proposal treats it as needing the same gate-lib migration as the other two
on the strength of section 3's "zero gate-lib references anywhere in the
three plugins" finding, not a confirmed per-line defect list matching
citation-gate's. Implementation-time `compliance-check.sh` run (named in
the proposal) is the authoritative check for exactly what `options-gate.sh`
needs.
