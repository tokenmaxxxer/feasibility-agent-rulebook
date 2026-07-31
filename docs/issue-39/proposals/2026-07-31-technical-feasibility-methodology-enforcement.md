# Proposal — enforce the technical-feasibility methodology as a plugin set (issue-39)

Phase 1 only. No execution in this PR — no new directory, no gate script,
no hook registration, no `directive.sh` edit, no `marketplace.json` edit
actually lands here. Survey: `docs/issue-39/reports/technical-feasibility/
survey.md`. Scout: skipped; reasoning recorded in the survey's section 7
(no external field to benchmark — the named exemplars are sibling
rulebooks in the same repo family, already inspected directly).

Norm source (per issue-39's own constraint): the methodology adopted in
`docs/issue-30/proposals/2026-07-31-technical-feasibility-rulebook-maturation.md`
sections (a) and (b) — this proposal does not re-derive the methodology,
only proposes how to make it self-enforcing.

**Revision note.** A previous version of this proposal (superseded by
this rewrite) designed a single deepened directive plus one monolithic
`feasibility/hooks/technical-feasibility-gate.sh` for the whole
methodology. The human approver rejected that shape on PR review for
issue #39, with this correction (verbatim):

> 단일 게이트/디렉티브 심화가 아니라 플러그인 세트로 체계화한다:
> - 채택 방법론 각각을 독립 플러그인으로 (core의 freelunch/scout처럼 —
>   룰북당 여러 개, freelunch 수준의 완성도).
> - 기획서(phase 1) 규범과 산출물(phase 2) 규범도 각각을 플러그인
>   조합으로 풀어낸다 — 어떤 플러그인들이 조합되어 그 규범이 성립하는지가
>   설계의 본체.
> - 각 플러그인 = 자기 완결(디렉티브/게이트/에이전트/테스트 포함 가능),
>   marketplace.json 등록, 명확한 단일 방법론 담당.
> - proposal에는 플러그인 목록(이름·담당 방법론·구성요소·조합 관계)이
>   필수.

This rewrite honors that correction structurally: no monolithic gate, no
single deepened directive. Instead, each adopted methodology in issue-30
becomes its own self-contained plugin (sibling to `feasibility`, the way
`core`'s repo registers `freelunch` and `scout` as independent siblings
rather than folding them into one giant plugin), and the phase-1/phase-2
norms are each defined as an explicit COMPOSITION of several plugins —
not as their own plugin, and not as a single deepened directive.

## Plugin list

Three new sibling plugins are proposed, each owning exactly one
methodology from issue-30, each self-contained (directive fragment +
gate + tests; no agent proposed — see per-plugin sections), each
registered as its own `marketplace.json` entry next to `feasibility`.

| Plugin | Methodology owned | Components | Registration |
|---|---|---|---|
| `madr-options` | MADR's "Candidates/Options considered" discipline: plural candidates, one-line rejection reasons each, carried forward from phase-1 to phase-2 | directive fragment, gate (`madr-options/hooks/options-gate.sh`), tests | new `marketplace.json` entry, `source: ./madr-options` |
| `nygard-adr-spine` | Nygard's minimal ADR spine (Title/Status/Context/Decision/Consequences) as the phase-2 record's base shape | directive fragment, gate (`nygard-adr-spine/hooks/spine-gate.sh`), tests | new `marketplace.json` entry, `source: ./nygard-adr-spine` |
| `evidence-citation` | OpenSSF-Scorecard-style mandatory evidence citation format (`<claim> — <source: URL \| path:line \| check-name score>`), no bare assertions | directive fragment, gate (`evidence-citation/hooks/citation-gate.sh`), tests | new `marketplace.json` entry, `source: ./evidence-citation` |

Explicitly NOT proposed as new plugins — issue-30 states these are
"carried, not re-derived," so they stay reused existing skills inside
the `feasibility` plugin rather than becoming new plugins:
- `spike-report` (timebox-before-investigation order discipline) — used
  by reference from `feasibility/skills/spike-report/`, unchanged.
- `reversibility-tag` (one-way/two-way door tag) — used by reference
  from `feasibility/skills/reversibility-tag/`, unchanged.
- `stride-table` (risk-disposition vocabulary
  mitigated/accepted/deferred) — used by reference from
  `feasibility/skills/stride-table/`, unchanged.

`feasibility` itself remains the sole *role* plugin — the only one that
actually invokes `core_role_directive` and owns `write_scope`. The three
new plugins are *methodology* plugins: they do not run
`core_role_directive`, they do not own a role, and (per the composition
mechanism in the next section) their directive text and gates are pulled
into `feasibility`'s own directive and `hooks.json`, not run standalone
against a role of their own.

## The composition mechanism (methodology plugin → role plugin)

Only `feasibility` calls `core_role_directive` (sourced, never copied,
from `${CLAUDE_PLUGIN_ROOT_CORE}/hooks/lib/role-directive.sh`) — that is
unchanged. A methodology plugin that is not itself a role therefore
cannot run its own `SessionStart` directive independently and have it
mean anything; its directive text has to become part of
`feasibility/hooks/directive.sh`'s existing heredoc arguments.

Proposed mechanism, since no existing precedent for a non-role plugin
composing INTO a role plugin's directive was found and verified in this
repo (core's `freelunch`/`scout` are themselves standalone role-shaped
plugins, not directive-fragment sources — this repo does not currently
show them being sourced into another plugin's directive text; this is
flagged as open question 1 below, not asserted as verified precedent):

- Each methodology plugin ships a plain-text fragment file, e.g.
  `madr-options/directive-fragment.md`, containing the exact prose to be
  spliced into `feasibility/hooks/directive.sh`'s `RESEARCH` or
  `EXECUTION JUDGMENT` heredoc argument at a marked insertion point
  (e.g. an HTML-comment-style marker `<!-- madr-options:begin -->` /
  `<!-- madr-options:end -->` inside the heredoc).
  `feasibility/hooks/directive.sh` is a text-edit-only change (matching
  issue-30's own precedent for this same file) that concatenates the
  three fragments' current content into the relevant argument strings at
  the point the three plugin proposals below specify — this stays a
  static edit to `feasibility`'s own file, not a runtime `source` of the
  methodology plugins' files, because `directive.sh` runs once per
  session and a build-time/authoring-time splice is simpler and matches
  the "sourced unmodified from `core_role_directive`, text-edit only"
  precedent already established.
- Each methodology plugin's gate is invoked directly, as its own
  `PreToolUse` entry, from `feasibility/hooks/hooks.json` — this part
  has direct precedent (`pricing-rulebook`'s gate sits "on top of, never
  instead of" `core`'s canon gate, invoked from the role plugin's own
  `hooks.json`), so gate composition is NOT the open question; only the
  directive-text splice mechanism is.
- Each methodology plugin's path is resolved the same way `core`'s
  canon scripts are resolved today (`CLAUDE_PLUGIN_ROOT`-sibling
  resolution, e.g. `${CLAUDE_PLUGIN_ROOT}/../madr-options/hooks/
  options-gate.sh`), never vendored into `feasibility/hooks/`.

This mechanism is flagged plainly in the open questions section: it is a
genuinely new design element with no verified existing precedent in this
repo, and the approver may prefer a different mechanism.

## Phase-1 PROPOSAL norm = composition

The phase-1 technical-feasibility proposal norm (issue-30 (a)) is not
its own plugin. It is assembled from:

| Plugin / skill | What it contributes | How it plugs in |
|---|---|---|
| `evidence-citation` | `## Evidence format` section requirement + citation format `<claim> — <source: URL \| path:line \| check-name score>`, no bare assertions | directive fragment spliced into the `RESEARCH` argument's `technical:` bullet; gate check on the `## Evidence format` section |
| `madr-options` | `## Candidates considered` section requirement, 2+ candidates, one-line rejection reason each | directive fragment spliced into the `RESEARCH` argument; gate check on the `## Candidates considered` section |
| `feasibility:spike-report` (existing skill, referenced not duplicated) | `## Timebox and acceptance criteria` section, timebox-before-investigation order discipline | already referenced by `directive.sh`'s existing `technical:` bullet, unchanged |
| `feasibility:reversibility-tag` (existing skill, referenced not duplicated) | `## Reversibility` section, one-way/two-way door tag | already referenced by `directive.sh`'s existing `technical:` bullet, unchanged |

`## Question` (the single answerable claim) is not owned by any single
plugin — it is base document-shape prose already implicit in
`directive.sh`'s existing "state the question as a single answerable
claim" line and is kept there, not assigned to a new plugin.

`feasibility/hooks/hooks.json` wires the `madr-options` and
`evidence-citation` gates in sequence (order stated below) for the
phase-1 write-surface regex:
`^docs/issue-[0-9]+/proposals/.*technical-feasibility.*\.md$`.

## Phase-2 RECORD norm = composition

The phase-2 ADR-style record norm (issue-30 (b)) is likewise not its own
plugin. It is assembled from:

| Plugin / skill | What it contributes | How it plugs in |
|---|---|---|
| `nygard-adr-spine` | Title / Status / Context / Decision / Consequences skeleton | directive fragment spliced into the `EXECUTION JUDGMENT` argument; gate checks the five spine fields |
| `madr-options` | `Options considered` = every phase-1 candidate carried forward or explicitly dropped-with-reason | same plugin as phase-1's candidates check, reused; gate checks candidate carry-forward against the phase-1 proposal file |
| `evidence-citation` | citations carried forward from phase-1, no unsourced re-assertion in phase 2 | same plugin as phase-1's citation check, reused; gate checks citation format on any new claim in the record |
| `feasibility:stride-table` (existing skill, referenced not duplicated) | `Risks` disposition vocabulary (`mitigated \| accepted \| deferred`) | already referenced by `directive.sh`; gate check on the `Risks` section lives inside `nygard-adr-spine`'s gate since `Risks` is one of the spine's own fields |
| `feasibility:reversibility-tag` (existing skill, referenced not duplicated) | `Consequences`' reversibility tag, carried or updated from phase-1 | already referenced by `directive.sh`; consistency check lives inside `nygard-adr-spine`'s gate since `Consequences` is a spine field |

`feasibility/hooks/hooks.json` wires the `nygard-adr-spine`,
`madr-options`, and `evidence-citation` gates in sequence (order stated
below) for the phase-2 write-surface regex:
`^docs/issue-[0-9]+/reports/feasibility\.md$` — each gate fires only
when the record's content indicates the technical-probe section is
present/being written, so writes that are legitimately about
`prior_art`/`legal_regulatory`/`threat_model` only are not denied.

**Stated gate order** (both phases): `evidence-citation` runs first
(citations are a prerequisite fact-format check, cheapest and most
foundational), then `madr-options` (candidates/options, which reference
citations), then — phase 2 only — `nygard-adr-spine` (the outer
skeleton, which subsumes the Risks/Consequences checks). Each gate
fails closed independently; any denial blocks the write. This order is
a proposal, not fixed by any existing precedent; flagged as open
question 4.

**Role-plugin wiring carried from the previous version of this
proposal, unchanged and still additive**: `feasibility/hooks/hooks.json`
also gains a `PreToolUse` entry invoking `core`'s canon-referenced
`record-fields-gate.sh` (closing the gap the survey found — `hooks.json`
already sets `RECORD_FIELDS_TERMINAL_STATES` but never wires the gate
in). This is role-plugin wiring, not a new methodology plugin, and stays
in `feasibility/hooks/hooks.json`, invoked before the three methodology
gates (generic §20 fields checked first, then the technical-domain
document-shape checks).

## Per-plugin detail

### `madr-options`

Owns: MADR's "Candidates/Options considered" discipline only.

- **Directive fragment** (`madr-options/directive-fragment.md`),
  spliced into `feasibility/hooks/directive.sh`'s `RESEARCH` and
  `EXECUTION JUDGMENT` arguments: name `## Candidates considered` /
  `Options considered` verbatim; state the plural-candidates
  prohibition (no candidate list of length 1); state the one-line
  reason requirement per candidate; state the carry-forward judgment
  rule — every phase-1 candidate must appear in phase-2 `Options
  considered` or the record must state why it was dropped, no silent
  drops.
- **Gate** (`madr-options/hooks/options-gate.sh`): fail-closed,
  `PreToolUse` on `Write|Edit|MultiEdit`, matched against the same two
  write-surface regexes as `feasibility`'s own gates (phase-1 proposal /
  phase-2 record), pass-through (`exit 0`) on anything else.
  - Phase-1 check: `## Candidates considered` present, names 2+ items
    (naive heuristic: 2+ list-item markers or 2+ named-option
    sub-headers under that section — exact parsing logic is an
    implementation-time decision, not fixed here), each with adjacent
    prose (a one-line reason is not independently machine-verifiable
    beyond "non-empty text follows the item," flagged as a known
    heuristic limit, not a hard content check).
  - Phase-2 check: every phase-1 candidate name found in `Options
    considered`, OR an explicit "dropped: <reason>" note per missing
    one — a best-effort string match against the phase-1 proposal file
    this record's technical section should reference (cross-file check;
    flagged as open question 3, carried from the previous version).
  - This gate also owns the **order-constraint document-shape check**
    (see "Order constraint" subsection below): the same phase-1 check
    that requires `## Candidates considered` also requires `## Timebox
    and acceptance criteria` to be present in the same write, which is
    where the order enforcement actually lives — stated explicitly here
    since it could plausibly live in `nygard-adr-spine` instead and the
    approver should know which plugin the previous version's reasoning
    landed in.
  - Kill switch: `MADR_OPTIONS_GATE_OFF=1`.
- **Tests**: allow (2+ candidates, one-line reasons, phase-1); deny
  (single candidate, phase-1); deny (phase-1 proposal with candidates
  but missing timebox section — the order-constraint case); allow (all
  phase-1 candidates carried into phase-2 `Options considered`); deny
  (a phase-1 candidate missing from phase-2 with no dropped-reason);
  allow (foreign path passthrough); allow (kill switch, any content).
- No agent proposed: this is a single document-shape discipline, not a
  repeated multi-step procedure.

### `nygard-adr-spine`

Owns: Nygard's minimal ADR spine only (Title/Status/Context/Decision/
Consequences) as the phase-2 record's base shape.

- **Directive fragment** (`nygard-adr-spine/directive-fragment.md`),
  spliced into `feasibility/hooks/directive.sh`'s `EXECUTION JUDGMENT`
  argument: name the five spine components verbatim (Title, Status
  `proposed|accepted|superseded`, Context, Decision with the mechanical
  verdict-class mapping already required, Consequences including the
  reversibility tag) plus `Risks` (each disposed
  `mitigated|accepted|deferred`, borrowing `stride-table`'s vocabulary)
  as the sixth field this plugin's gate also checks, since `Risks` sits
  in the same phase-2 record and has no other owning plugin.
- **Gate** (`nygard-adr-spine/hooks/spine-gate.sh`): fail-closed,
  `PreToolUse`, phase-2 write-surface regex only
  (`^docs/issue-[0-9]+/reports/feasibility\.md$`), technical-probe
  section only, pass-through on anything else.
  - Checks: `Status:` field exists; `Decision:` field exists with a
    stated verdict class; `Context` prose exists; `Consequences`
    section exists and states a reversibility tag; every `Risks` entry
    carries a disposition (`mitigated|accepted|deferred`); no record
    transitions to a terminal `loop_state` while the technical probe's
    spine is incomplete. Matched by header/keyword rather than a
    literal `## Title` header, since issue-30 (b) describes fields more
    than fixed headers for this part — implementation should decide
    exact matching against the accepted issue-30 text, not against this
    proposal's paraphrase.
  - Kill switch: `NYGARD_ADR_SPINE_GATE_OFF=1`.
- **Tests**: allow (all spine fields present, all risks disposed); deny
  (missing `Status:`); deny (a `Risks` entry with no disposition); deny
  (record transitions to a terminal `loop_state` with an incomplete
  spine); allow (foreign path passthrough); allow (kill switch).
- No agent proposed: single document-shape discipline per issue, not a
  repeated procedure comparable to `implementation-rulebook`'s hunt
  cadence.

### `evidence-citation`

Owns: OpenSSF-Scorecard-style mandatory evidence citation format only.

- **Directive fragment** (`evidence-citation/directive-fragment.md`),
  spliced into both `feasibility/hooks/directive.sh` arguments (`
  RESEARCH` for phase 1, `EXECUTION JUDGMENT` for phase 2): state the
  citation format verbatim — `<claim> — <source: URL | path:line |
  check-name score>` — and the prohibition: a claim with no citation is
  not evidence; phase 2 may not re-derive a phase-1-cited claim from
  memory, citations must be carried forward.
- **Gate** (`evidence-citation/hooks/citation-gate.sh`): fail-closed,
  `PreToolUse`, both write-surface regexes, technical-probe-relevant
  content only, pass-through on anything else.
  - Phase-1 check: `## Evidence format` section, if it contains prose,
    contains at least one citation shaped like the required format (a
    bare section with zero `—`/`source:`-shaped citations denies).
  - Phase-2 check: any new factual claim in the record's technical
    section carries a citation in the same format (best-effort —
    detecting "a factual claim" generically is the hardest part of this
    check and is flagged as the highest false-positive-risk item,
    carried from the previous version's phase-1 check 4 concern but
    relocated here since verdict-language detection is dropped — see
    open question 2).
  - Kill switch: `EVIDENCE_CITATION_GATE_OFF=1`.
- **Tests**: allow (phase-1, cited claims); deny (phase-1, `## Evidence
  format` present but zero citations); allow (phase-2, all claims cited
  or carried forward); deny (phase-2, a new claim with no citation);
  allow (foreign path passthrough); allow (kill switch).
- No agent proposed: single format-shape discipline, checked per-write.

## Order constraint discussion (carried, relocated)

Issue-30's only genuine ORDER constraint is: timebox + acceptance
criteria agreed BEFORE investigation work starts (phase 1 only). As
stated under `madr-options` above, this now lives inside
`madr-options`'s phase-1 gate check, because the same write that
contains `## Candidates considered` content already implies
investigation happened, and requiring `## Timebox and acceptance
criteria` to co-exist in that same committed write is the actual
enforcement point — not a property of the ADR spine (`nygard-adr-spine`)
or the citation format (`evidence-citation`), neither of which has any
positional stake in this ordering. This is a same-write, document-shape
check, not a session-level tool-call transcript check: it cannot catch
investigation happening in the agent's own tool-call history before any
document write at all (e.g., web searches run before the timebox is
agreed, with the timebox document written only afterward). Closing that
fully would require a session-state tracker comparable to
`implementation-rulebook`'s `hunt-state.sh` — out of scope for this
proposal unless the approver wants that heavier mechanism; carried as
open question 3 below (renumbered from the previous version's question
3).

## `tests/run-gate-tests.sh` harness fix (carried, now affects three gates)

Confirmed broken today by the survey: `tests/run-gate-tests.sh`
references `record-fields-gate.sh` and `trailer-gate.sh` as
same-directory local files under `feasibility/hooks/`, neither of which
exists there (0/7 passing, all `exit-127`). This proposal's plugin set
adds three MORE gates, each with their own test cases (listed per-plugin
above), which will suffer the same problem unless the harness is fixed
first: it must resolve canon-referenced and sibling-plugin-referenced
gates via `CLAUDE_PLUGIN_ROOT`-style sibling path resolution instead of
a hardcoded `$HOOKS/$3`, matching issue-34's reference-not-copy fix for
`stub-check.sh`. Any implementation of this proposal must fix this
harness (or split it into per-plugin test files, one per new plugin
directory, each resolving its own gate by relative path — an
implementation-time choice) before the new gates' tests can run at all.
Leaving the harness silently broken while adding three new gates next to
it would contradict the issue's own request for working gates + test
pairs.

## Agents / checklists

None of the three methodology plugins propose an `agents/` directory.
Each owns a single document-shape discipline applied once per phase, not
a genuinely repeated multi-step procedure comparable to
`implementation-rulebook`'s hunt cadence (dispatch-a-hunter-at-two-
fixed-points, re-cleared each time). The directive fragments plus the
three gates already cover the full methodology; a checklist agent would
duplicate the gates' own checks in prose form with no additional
enforcement value, and the existing `spike-report`/`reversibility-tag`/
`stride-table`/`license-scan`/`build-vs-buy` skills already serve as the
checklist-equivalent reference material for each probe. This is a
recommendation, not a foregone conclusion — carried as open question 5
below.

## `marketplace.json` change (named, not executed here)

Add two new sibling entries (naming pattern matches the existing
`feasibility` entry's shape — `name`/`source`/`description`, description
naming the single methodology owned):

```json
{
  "name": "madr-options",
  "source": "./madr-options",
  "description": "MADR's candidates/options-considered discipline: plural candidates, one-line rejection reasons, carried forward from phase-1 proposals into phase-2 records. Composes into feasibility's directive and hooks.json; not a standalone role."
},
{
  "name": "nygard-adr-spine",
  "source": "./nygard-adr-spine",
  "description": "Nygard's minimal ADR spine (Title/Status/Context/Decision/Consequences) plus Risks disposition, as the phase-2 record base shape. Composes into feasibility's directive and hooks.json; not a standalone role."
},
{
  "name": "evidence-citation",
  "source": "./evidence-citation",
  "description": "OpenSSF-Scorecard-style mandatory evidence citation format (<claim> — <source>), no bare assertions, carried forward across phases. Composes into feasibility's directive and hooks.json; not a standalone role."
}
```

Three, not one — matching the approver's requirement that adopted
methodologies register as independent plugins, "룰북당 여러 개" (several
per rulebook), the way `core`'s repo registers `freelunch` and `scout`
as siblings.

## Open questions for the approver

1. **Directive-fragment composition mechanism**: is the proposed
   static-splice mechanism (a marked-insertion-point text file per
   methodology plugin, concatenated by hand/tooling into
   `feasibility/hooks/directive.sh`'s heredoc arguments at
   authoring/implementation time) sound, or does the approver want a
   different mechanism — e.g. a runtime `source` of fragment files from
   `directive.sh` itself? This is flagged plainly because no existing
   precedent for a non-role plugin composing into a role plugin's
   directive was found and verified in this repo; `core`'s
   `freelunch`/`scout` are themselves standalone plugins, not verified
   examples of fragment-sourcing into a consuming role's directive.
2. **Evidence-claim detection in phase-2 (`evidence-citation` gate)**:
   detecting "a new factual claim exists with no citation" generically
   in prose is the highest false-positive-risk check in this design —
   acceptable as a best-effort heuristic, or should this check be
   dropped from the gate and left as directive-text + PR-review only,
   the way issue-30 itself deferred looser judgment calls to human
   review?
3. **Cross-file candidate-carry-forward check (`madr-options`'s phase-2
   check)**: worth the complexity of a gate that reads a second file
   (the phase-1 proposal) to verify carry-forward, or should this stay a
   PR-review convention (as issue-30's own gate-condition 1 already
   assumed it would)? Relatedly: is the document-shape-implies-order
   enforcement for the timebox-before-candidates constraint (living in
   `madr-options`'s phase-1 gate, see "Order constraint discussion"
   above) sufficient, or does the approver want a genuine session-level
   state tracker (à la `hunt-state.sh`)?
4. **Gate execution order**: is `evidence-citation` →
   `madr-options` → (`nygard-adr-spine`, phase-2 only) the right
   sequence, or does the approver want a different order or independent
   (unordered) execution with all denials collected before responding?
5. **Agents/checklist recommendation**: confirm "none needed" across all
   three plugins, or request a lightweight onboarding checklist skill
   for one or more despite the no-additional-enforcement-value argument
   above.
6. **`tests/run-gate-tests.sh` harness fix scope**: fix it as part of
   this issue's execution (it now blocks three new gates' tests, not
   just one), or split it into this issue plus a narrower separate issue
   given it affects gates beyond just the ones this proposal adds?

## Order constraint (for this issue itself)

No sequencing dependency on any other currently-open issue. Depends only
on issue-30's already-merged, already-accepted proposal as its norm
source (a closed dependency, not an open one).
