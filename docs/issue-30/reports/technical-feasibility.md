# technical-feasibility — issue-30 phase 2 record

loop_state: accepted

Upstream basis: docs/issue-30/proposals/2026-07-31-technical-feasibility-rulebook-maturation.md,
approved via the single-account exact-string comment `APPROVE
issue-30/technical-feasibility` (contract v3 s19), PR #37 (phase 1)
merged 2026-07-31.

## What was done

Reflected the approved proposal's plugin-reflection plan (section (d))
into the `feasibility` plugin:

- **`feasibility/hooks/directive.sh`**: the `technical:` bullet of the
  `RESEARCH` argument to `core_role_directive` now names two required
  fields for the technical probe: (1) candidates considered, plural,
  each with a cited reason for accept/reject — never a single foregone
  option; (2) the evidence citation format `<claim> — <source: URL |
  path:line | check-name score>`, no bare assertions. This is a text
  edit inside the existing heredoc string only; still one physical line
  (verified with `wc -l`); `core_role_directive`'s call signature is
  unchanged and still sourced from the core canon path
  (`${CLAUDE_PLUGIN_ROOT_CORE}/hooks/lib/role-directive.sh`) — nothing
  copied out of core.
- **`feasibility/hooks/hooks.json`**: left unchanged, per the proposal's
  own plan — `RECORD_FIELDS_TERMINAL_STATES=verdict scope-approved`
  already covers the terminal states the ADR-style record norms plug
  into; no new field or gate was needed there.
- **Gate**: the proposal's five gate conditions (candidates carried
  forward from phase 1, citation format enforced, ADR-style record
  present alongside the `pass|fail|blocked` probe field, every risk
  disposed `mitigated|accepted|deferred`, reversibility tag consistent)
  stay a PR-review-time human convention in this pass, not a new
  automated `PreToolUse` check — exactly as the proposal recommended; a
  future mechanical field-presence gate is out of scope here.

## Why

The proposal's own rationale (section (c)) is the governing why: MADR's
"candidates considered" over bare Nygard because this repo's review
culture already needs to see rejected options, not just the winner;
Nygard's minimal spine kept for the record itself because this repo's
records (issue-31, issue-34 precedent) stay short and push scoring
detail to the supporting evidence files, not the record; mandatory
citation because `directive.sh` already requires it for `prior_art` and
the two probes frequently touch the same underlying claim; reversibility
carried, not re-derived, because `reversibility-tag` is already a
cross-probe field; risk disposition vocabulary shared with
`stride-table` so one probe-reader learns one vocabulary, not four. No
automated gate this pass because the proposal explicitly deferred that
choice to a future, separately-approved, canon-referenced proposal
rather than bundling a new hand-written check into this reflection.

The proposal's two open questions were left unanswered by the approval
(a bare exact-string match carries no prose, per contract v3 s19 —
approval is never interpreted from prose). Both resolve to the
proposal's own stated default, since no override was given: (1) the
phase-2 ADR-style record is inline-by-default in `feasibility.md`'s
technical-probe field, not a separate file; (2) gate automation stays a
human-review convention, not automated, until a future issue proposes
otherwise.

## Reversibility

Two-way door: the directive text edit is a plain string change,
revertable with one more commit; no schema, no data, no external
contract changed.

## Verdict

verdict: go — reflection complete, no blocking condition outstanding.

## Risks

- Two added required-field callouts increase the density of an already
  long directive bullet, which could reduce at-a-glance readability —
  disposition: accepted (matches the density of the other three probe
  bullets in the same paragraph; probe-to-probe consistency was weighed
  above single-bullet terseness).

## Open findings

None outstanding — the phase-1 proposal's plugin-reflection plan (d) is
fully applied; the two open questions to the approver are resolved
above by the proposal's own stated defaults in the absence of an
override.

## Next steps

None required to close this issue. If a future issue wants a mechanical
field-presence gate for the ADR-style record components, that is its
own canon-referenced proposal per the issue-31/issue-34 precedent, not
a continuation of this one.

## Resolution path

No open finding remains open on this record; nothing routes forward.
