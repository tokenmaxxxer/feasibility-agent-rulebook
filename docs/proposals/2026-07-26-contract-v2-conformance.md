---
status: approved
files:
  - README.md
  - feasibility-cycle/hooks/state-gate.sh
  - feasibility-cycle/hooks/run-gate-tests.sh
---

# Conform feasibility to the v2 blackboard/event contract

## Intent

`docs/specs/role-handoff-contract.md` landed at commit `b240ec4` as the
authority spec (v2, `status: final`). It replaces v1's one-shot
ACCEPTS/refuse parcel model with a shared per-subject blackboard: each role
reads freely, writes only its own record under
`docs/reports/records/<subject>/`, and wakes on board changes rather than on
a handoff being "accepted." This repository — `feasibility-agent-rulebook`
— currently implements neither the v1 handoff protocol described in its own
`README.md` (`docs/proposals/2026-07-26-role-protocol-section.md`) in v2
shape, nor a blackboard-shaped gate: `feasibility-cycle/hooks/state-gate.sh`
still gates a single project-root file, `feasibility-record.md`, driven by a
`status` field and `transition-rules.md`, with no notion of `subject`,
`kind`, or per-subject paths at all (confirmed by reading
`docs/specs/state-machine.md` and the gate script in full — neither
mentions `kind` or `subject` anywhere; `grep -rn "kind" feasibility-cycle/`
returns nothing).

This proposal commissions two things: (1) rewriting the "Handoff protocol"
section of `README.md` into v2's WAKES-ON/READ/DEPENDS-ON/NEVER-OVERWRITE
shape, and (2) rewriting `state-gate.sh` so its refusals match what v2
actually asks a gate to enforce, dropping the parts of the current design
that model a world v2 no longer describes (a single global `status` field
gating one file).

## What is being commissioned

### 1. `README.md` — "Handoff protocol" section rewrite

Current section (lines 35–86) is built entirely around v1's ACCEPTS/refuse
verb:

> **ACCEPTS**: `hypothesis` — the spec to assess. ... Refuses
> `build-proposal`, `qa-state`, `review-record`, `ops-state` — none of these
> are within this role's accept set.

Replace this with four subsections matching the contract's own section
numbers, so a reader can trace each claim back to its source row:

- **WAKES-ON (contract §3, row: `feasibility`)** — replace ACCEPTS
  entirely. State plainly: feasibility wakes when a new or changed
  `hypothesis` record appears on the board (`docs/proposals/<date>-<slug>.md`,
  `kind: hypothesis`), not when a hypothesis is "handed to" it. Drop the
  refuse-list (`build-proposal`, `qa-state`, `review-record`, `ops-state`)
  — §4 makes reading any of these unconditionally fine; there is no refuse
  set left to state, only a narrower DEPENDS-ON (below). Keep the existing
  "given to start" carve-out (market argument withheld) as this role's own
  rule layered on top of the wake, exactly as the current text already
  frames it — that rule survives the rewrite unchanged.
- **READ / DEPENDS-ON / NEVER-OVERWRITE (contract §4, §11)** — three short
  paragraphs:
  - READ is unconditionally broad: feasibility may read any board record
    for context (§4's opening bullet), never a violation by itself.
  - DEPENDS-ON is narrow: what feasibility's own verdict may be built on is
    the `hypothesis` record it is scoping/probing — the specification, read
    without the market argument. This is the natural counterpart to §4's
    explicit statement that "product depends on `feasibility-record`" and
    "coding depends on `hypothesis`, `feasibility-record`, and `finding`" —
    feasibility itself is what those two downstream DEPENDS-ON rows are
    reacting to, and its own basis is the `hypothesis` record, nothing
    else. Say this explicitly since §4's bullet list only lists product,
    coding, qa, review, and ops by name — feasibility's own row must be
    stated in this rulebook rather than left to inference.
  - NEVER-OVERWRITE, unchanged in substance from the current text but
    re-sourced to contract §11's table row: feasibility writes only
    `docs/reports/records/<subject>/feasibility.md` and
    `docs/reports/records/<subject>/spikes/<spike-slug>.md`.
- **Record spec (contract §2 rows for `feasibility-record` and
  `spike-report`, plus §7's `loop_state` framing)** — replace "PRODUCES"
  with this, keeping the field list the current README.md lines 54–69
  already carry (it is already correct against v2's table — no field-list
  change needed) but re-labeling role status as `loop_state` per §1/§7's
  vocabulary rather than the current README's bare "role status", and
  citing §7 for why `loop_state` (not a role's private sub-state notes) is
  what other roles may depend on:
  - `feasibility-record` at `docs/reports/records/<subject>/feasibility.md`:
    `loop_state` vocabulary `idle,scoped,probing,verdict`;
    `market_argument_supplied: false`; `technical`/`prior_art`/
    `legal_regulatory`/`threat_model`, each
    `unresolved|pass:<evidence>|fail:<evidence>|blocked:<evidence>`;
    `verdict: go|no-go|conditional` (required once `loop_state` reaches
    `verdict`); `measurement_design: <description or pointer>`.
  - `spike-report` at `docs/reports/records/<subject>/spikes/<spike-slug>.md`:
    `loop_state` n/a (closed report); required fields Spike Title,
    Description/Goal, Type, Timebox, Acceptance Criteria, Tasks, Outcomes,
    Recommendation, Open questions, Reversibility tag, plus fixture-N
    notation whenever fixtures are involved (per §2's row, "records the
    fixture count it was authored against, so a downstream re-run can
    detect additions/removals").
- **Finding back-edge (contract §5)** — new subsection, not present in the
  current README.md at all: feasibility may both produce a `finding`
  addressed to another role and receive one addressed to it. When
  feasibility closes a `finding` addressed to it, its `feasibility-record`
  must carry a `finding-response` entry per §5's response schema: a stable
  reference to the finding (record path plus finding identifier), the
  action taken or, if declined, the reason, and — when code or the spec
  changed as a result — proof of the fix (commit sha or equivalent
  evidence). Cite §5 verbatim on what makes an entry incomplete: "An entry
  missing any of these three parts does not close the finding."
- **Loop-termination note (contract §6)** — one line: a wake is consumed
  only by writing the resulting record entry (a `loop_state` change, a new
  `finding`, or a `finding-response`); an unchanged board wakes no one
  further from that write.

Retain the existing **STOPS** subsection (README.md lines 71–85) with
updates only to terminology: "Upstream stale at role entry" now cites
contract §12 (staleness/`acknowledged_sha`) instead of an unnamed rule, and
the never-overwrite conflict bullet cites §11's explicit sentence: "A role
finding an existing record already present at a path section 11 assigns to
a different role must refuse to write there and report the conflict to the
user, rather than overwriting or merging into it silently."

### 2. `feasibility-cycle/hooks/state-gate.sh` rewrite

Read in full: the current gate (`feasibility-cycle/hooks/state-gate.sh`,
365 lines) is a v1-shaped single-file state machine gate. It resolves one
hardcoded path, `feasibility-record.md` at the repo root
(`record_name = "feasibility-record.md"`, line 109), parses a `status`
field out of YAML frontmatter (`field(block, "status")`, line 282), and
checks the `(old_status, new_status)` pair against rows loaded from
`transition-rules.md`. It has no notion of `kind`, `subject`, or a
per-subject directory tree — there is no code path in it today that reads
or refuses based on record `kind` at all, and no read-refusal logic exists
to delete (confirmed: `grep -rn "kind" feasibility-cycle/` returns nothing;
the only `field()` calls in the file are for `"status"`). This means item 3
of the task brief ("delete any kind-based read-refusal logic found") has no
target in this repo as it stands — flag this explicitly in the write-up
below rather than silently skip it, since the absence is itself a finding:
the gate needs the machinery added, not merely relaxed.

Commission the following changes:

- **Path model.** Replace the single `record_abs =
  posixpath.normpath(posixpath.join(root, "feasibility-record.md"))` target
  with recognition of the two owned path shapes from contract §11:
  `docs/reports/records/<subject>/feasibility.md` and
  `docs/reports/records/<subject>/spikes/<spike-slug>.md`. A write whose
  resolved path matches neither shape and is not obviously outside
  `docs/reports/records/**` is out of this gate's concern (allowed through,
  same as today's "does not reach the state file" branch, lines 195/207).
  A write whose resolved path falls under `docs/reports/records/<subject>/`
  but is neither of the two owned shapes (e.g. it would write into
  `.../<subject>/coding.md` or `.../<subject>/product.md`) must be denied —
  this is the mechanical form of §11's ownership table and its explicit
  sentence about refusing to overwrite another role's record path.
- **Reads are always allowed.** State explicitly in the gate's own header
  comment (currently lines 1–28, which describe the gate as answering "does
  this write reach the state file") that this gate is a `PreToolUse` hook
  for write-shaped tool calls only and never fires on reads — this is
  already true mechanically (the hook only runs on
  `Write|Edit|NotebookEdit|Bash`, per the header comment's own first line)
  but the comment should say so affirmatively, citing contract §4's
  READ-broad rule, so a future reader does not mistake the absence of a
  read check for an oversight.
- **Narrow the job to three refusals**, replacing the current
  status/transition-table model:
  (a) writes outside feasibility's two owned path shapes under
  `docs/reports/records/<subject>/` (see above) — new logic;
  (b) DEPENDS-ON violations where mechanically detectable — concretely,
  this repo's own state-machine content check
  (`state-gate.sh` lines 343–360, the `probing -> verdict-provisional`
  probe-field precondition) is the kind of check that survives: it is a
  content precondition on feasibility's *own* record, not a check on
  another role's kind, so keep it, but re-key it against `loop_state`
  instead of the current `status` field name to match contract §1/§7's
  field name; the transition table itself (`transition-rules.md`,
  `idle,scoped,probing,verdict`) already matches contract §2's
  `feasibility-record` `loop_state` vocabulary verbatim, so no vocabulary
  change is needed, only the field rename and the per-subject path
  targeting;
  (c) refuse handoff actions when the work repo has no contract — this is
  already implemented and should be kept as-is: `state-gate.sh` lines
  63–73, the "collaboration contract presence check" that denies with
  `"this repo has no collaboration contract yet (%s not found under %s)."`
  when `docs/specs/role-handoff-contract.md` is absent from the resolved
  repo root. This block needs no change beyond continuing to run before the
  per-subject path logic above.
- **`kind:` comment-tolerance fix.** The task brief asks specifically for
  `^kind:\s*(\S+)\s*$`-style regex to be hunted down and fixed to tolerate
  `kind: feasibility-record  # re-scoped`. No literal regex of that
  anchored, non-comment-tolerant shape exists in this repository today —
  the only field-parsing regex present is `field()` at
  `feasibility-cycle/hooks/state-gate.sh` lines 276–280:
  `r"^" + re.escape(name) + r":\s*(.*?)\s*(?:#.*)?$"`, applied today only
  to `name="status"`. This regex already has a `(?:#.*)?` comment-tolerance
  clause. Once the gate is extended to parse a `kind:` field (needed for
  the per-subject path/kind recognition above, since distinguishing a
  `feasibility.md` write from a `spikes/<slug>.md` write may need `kind` in
  addition to path shape per contract §1's common header), reuse this same
  `field()` helper for `kind` rather than introducing a second, stricter
  regex — this preserves the comment tolerance the contract requires at
  §2's closing paragraph ("`kind` parsing by any gate must tolerate a
  trailing comment on the line ... a regex anchored to end-of-line with no
  comment tolerance is a gate defect") by construction, rather than by a
  fix applied after the fact. Flag this as a "build it correctly the first
  time" note rather than a "fix an existing bug" note, since the literal
  bug the brief describes is not present in this codebase yet — it would
  only be introduced if a naive `kind:` parser were added without reusing
  `field()`.
- **Drop what no longer fits.** The current status/transition-table
  machinery (`transition-rules.md` loading, `(old_status, new_status) not
  in legal` check, lines 246–335) models a single global state file, not a
  per-subject blackboard. Commission a decision, not a silent deletion: the
  rewrite must either (i) keep this machinery scoped per-subject — i.e.
  load and compare `loop_state` off the specific
  `docs/reports/records/<subject>/feasibility.md` being written, rather
  than a single root-level file — or (ii) drop the transition-legality
  check from the gate entirely and rely on this rulebook's skill-level
  prompting for state-machine discipline, leaving the gate to enforce only
  path ownership and the contract-presence check. This proposal does not
  choose between (i) and (ii) — that choice belongs to whoever implements
  this, informed by `docs/specs/state-machine.md`'s existing gated-transition
  rule (`probing -> verdict-provisional` requires all four probes resolved)
  and by the `.feasibility/tokens/verdict.token` approval-token mechanism
  described there, both of which currently assume a single project-root
  record and will need the same per-subject treatment if kept.

### 3. `feasibility-cycle/hooks/run-gate-tests.sh` — flag only

Read in full. All fourteen current cases (a–l) construct payloads against a
single `$work/feasibility-record.md` at a temp directory root (e.g.
`seed_record`, line 30, writes directly to `"$work/feasibility-record.md"`;
`json_write` targets that same literal path throughout). Every one of these
cases will need rewriting once `state-gate.sh` targets
`docs/reports/records/<subject>/feasibility.md` and
`.../spikes/<spike-slug>.md` instead of a project-root file — this proposal
does not write those test updates, only flags that the entire test file is
coupled to the path this proposal changes and must be revisited case by
case: (a)/(b)/(c)/(d)/(j)/(k) exercise the status/transition logic that
item 2(iv) above defers a design decision on; (e)/(e2) exercise the Bash
bypass-shape detection against the literal filename
`feasibility-record.md`, which will need updating to the new path shape
regardless of which side of the (i)/(ii) decision above is taken; (g)/(h)/(i)
exercise the `(none)`/empty/out-of-set existing-status edge cases, which
only make sense if decision (i) (per-subject state comparison kept) is
taken; (l) exercises repo-root resolution via `.git` walk-up, which is
independent of the path-shape change and should need no rewrite.

## Write set

- `README.md` — "Handoff protocol" section (current lines 35–86), rewritten
  per item 1 above.
- `feasibility-cycle/hooks/state-gate.sh` — path-targeting, `kind:` parsing
  via the existing `field()` helper, and the (i)/(ii) transition-legality
  decision, per item 2 above.
- `feasibility-cycle/hooks/run-gate-tests.sh` — flagged, not written by this
  proposal; commissioned as a necessary follow-on once `state-gate.sh`
  changes land, per item 3 above.

No other file in this repository is in scope. In particular, out of scope:

- `docs/specs/state-machine.md` and `docs/specs/agent-roles.md` — these may
  also need per-subject rewording once the gate's design decision (i)/(ii)
  is made, but that is a separate proposal once the gate's shape is
  settled, not this one.
- `transition-rules.md` (the vocabulary it carries,
  `idle,scoped,probing,verdict`, already matches contract §2's
  `feasibility-record` `loop_state` list and needs no wording change under
  this proposal).
- `docs/specs/role-handoff-contract.md` itself — authored and landed
  upstream at `b240ec4`; this repository never carries a copy of it and
  none is proposed here.
- The other five sibling `*-agent-rulebook` repositories (coding, qa,
  product, ops, review) — each needs its own equivalent proposal, per this
  repository's own stated isolation guarantee (`README.md`, "Isolation"
  section: "No shared code, no cross-repo dependency").
- `warrant`'s `scope-gate.sh` — not present in this repository; contract
  §11's "carried over, unenforced" note about it applies unchanged.

## Out of scope

No build. No commit. This document is a proposal (`status: proposed`)
commissioning the two rewrites and flagging the test-file follow-on; it
does not itself edit `README.md`, `state-gate.sh`, or
`run-gate-tests.sh`.

## What did not work

Execution of this proposal deliberately narrowed `state-gate.sh`'s scope
below what item 2 above commissions in full, on explicit instruction from
the task that authorized implementation: only the hardcoded record-name
(`record_name = "feasibility-record.md"` / `record_abs`, formerly line
109) was replaced, with a new `OWNED_PATH_RE` / `is_owned_path()` matching
both owned per-subject shapes (`.../feasibility.md` and
`.../spikes/<spike-slug>.md`). Two things item 2 asks for were **not**
attempted and remain open:

- The `status` field is still read and compared as `status`, not renamed to
  `loop_state` (item 2(b) in the proposal). The `field()` helper and its
  comment-tolerant regex are untouched, so a `kind:` parser can reuse it
  cleanly later, but no `kind:` parsing was added — the gate still cannot
  distinguish a `feasibility.md` write from a `spikes/<slug>.md` write by
  `kind`, only by path shape, which happens to be sufficient today since
  the two owned shapes are already structurally distinct paths.
- The transition-legality decision (i) vs (ii) in item 2's "Drop what no
  longer fits" bullet was not made: the existing `(old_status, new_status)`
  check against `transition-rules.md` still runs unmodified, now gated on
  whichever per-subject `feasibility.md` the write targets rather than a
  single root file. This happens to satisfy option (i) as a side effect of
  the path-shape change, but that was not a deliberate design choice made
  here — it should be treated as provisional, not as this proposal's
  resolution of that open question.
- `feasibility-cycle/hooks/run-gate-tests.sh` was left untouched, per the
  proposal's own write set (item 3 is "flagged, not written"). All
  fourteen existing cases still construct payloads against
  `$work/feasibility-record.md` and will fail against the rewritten gate;
  this is the expected, proposal-acknowledged follow-on debt, not a defect
  introduced silently.
