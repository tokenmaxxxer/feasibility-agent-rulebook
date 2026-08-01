# Scout brief — issue #42 (2026-08-01)

Mode: batched-sequential (single session, no parallel subagent/tool fan-out
available for filesystem reads in this pass — Read/Bash calls were run in
sequence, not concurrently; stated per the fallback-disclosure rule).
Stages used: 2 (sweep + one deepening round), well under the 5-stage/3min
budget; stopped at judge point 1 — the exemplars found were already
decision-relevant and a second deepening round would not have changed the
proposal's shape.

Angle 1 (canon reference standard — the field's actual top-tier exemplar
for this exact task, not an external product): `core/hooks/lib/gate-lib.sh`
+ `core/hooks/lib/gate-lib.py` +
`docs/handbooks/gate-house-standard.md`, all at
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/`. This is the mandated
reference (issue #42's own precondition), not a competitor to weigh — it
supplies the must-bes below directly, not by inference.

Angle 2 (sibling rulebooks already doing this exact remediation): searched
`/home/jwjung/.tokenmaxxxer/work/*/docs/issue-*/proposals/*.md` for
`gate-house-standard` mentions — 40+ sibling rulebook repos have an open or
landed A+-remediation-shaped proposal referencing the same standard
(`implementation-rulebook-issue-64`, `capacity-planning-rulebook-issue-10`,
`data-engineering-rulebook-issue-13`, others). Read
`implementation-rulebook-issue-64`'s proposal in full as the deepest,
most-comparable exemplar (same "existing gates, migrate onto gate-lib,
semantic upgrade, mandatory tests, README reconciliation" shape as this
issue). — /home/jwjung/.tokenmaxxxer/work/implementation-rulebook-issue-64-implementation/docs/issue-64/proposals/2026-08-01-gate-a-plus-remediation.md

Angle 3 (this repo's own prior phase-1 proposal, same methodology-plugin
design already in force): `docs/issue-39/proposals/
2026-07-31-technical-feasibility-methodology-enforcement.md` — establishes
the plugin-composition architecture (`madr-options`/`nygard-adr-spine`/
`evidence-citation` as independent sibling plugins, gates wired via
`feasibility/hooks/hooks.json`) this proposal's fixes must fit inside,
without re-litigating that architecture.

## Must-bes (from the canon standard, angle 1)

- `gate_trap_fail_closed` as the one canonical EXIT trap — every gate calls
  it, none hand-rolls its own. —
  core/hooks/lib/gate-lib.sh:36-41
- `gate_kill_switch_active` — unrecognized value stays active; only a
  recognized on-spelling disables. —
  core/hooks/lib/gate-lib.sh:61-68
- `gate_reconstruct_write` (Python) — full Write/Edit/MultiEdit/
  NotebookEdit reconstruction, honoring `replace_all` per-edit. —
  core/hooks/lib/gate-lib.sh:30-33
- `gate_normalize_path` — absolute/relative/`./`-prefixed → root-relative
  tail, or `None` outside root. —
  core/hooks/lib/gate-lib.sh:27-29
- `gate_bash_write_targets` — token-scan a Bash command for path-shaped
  candidates, so a gate isn't blind to a Bash-tool file write. —
  core/hooks/lib/gate-lib.sh:88-90
- Six mandatory test-case groups, a compliance detector script
  (`compliance-check.sh`), listed in `canon-manifest.txt` so vendoring is
  itself caught by `stub-check.sh`. —
  docs/handbooks/gate-house-standard.md:58-94 (core repo)

## Performance axes the sibling remediations compete on

1. **Reference discipline** — does the proposal actually source
   `gate-lib.sh`/`gate-lib.py`, or hand-patch each defect locally?
   issue-64's proposal explicitly rejects the hand-patch alternative
   (its own Rationale section) on the grounds that hand-patching recreates
   the exact divergence bug the audit found. This repo's proposal adopts
   the same position (see survey §3: three independent copies of the same
   trap/kill-switch logic already exists here today, pre-empting the same
   failure).
2. **Named per-defect fix, not a generic "harden everything"** — issue-64's
   proposal maps each of its issue's five named defects to one lettered
   "what will be done" item; this repo's proposal follows the same
   1:1 defect→fix mapping discipline rather than a vague blanket rewrite.
3. **Scope discipline: existing gates fixed in place, no new plugin, no
   architecture re-litigation** — issue-64 explicitly keeps issue-61's
   already-settled plugin granularity; this repo's proposal keeps issue-39's
   already-settled three-plugin composition (angle 3), for the same reason.

## Adopt / skip

- **Adopt**: issue-64's per-lettered-item "what will be done" +
  "Alternative considered and rejected" pairing structure (make every
  design choice's rejected alternative explicit and reasoned, not just the
  chosen path) — the format `## Candidates considered` gate expects
  anyway, and reads more auditable than a flat fix-list.
- **Adopt**: `compliance-check.sh` as the ship-time evidence step (issue-64
  §f) rather than inventing a repo-local equivalent.
- **Skip**: issue-64 defers point (d) — full Edit/MultiEdit/path-normalize
  migration for every gate — to "whatever `compliance-check.sh` flags at
  phase 2," rather than exhaustively line-auditing every gate at phase 1.
  This repo's survey (§9, scope note) already found the same gap for
  `madr-options/hooks/options-gate.sh` (partially read only); this proposal
  follows issue-64's precedent and names `compliance-check.sh`'s
  phase-2 output as authoritative for exactly what needs migrating, rather
  than guessing at phase 1.

## Gap line

What this repo already meets vs. the field's must-bes: kill-switch
*semantics* are already correct by content in all three gates (survey §3)
— unlike core's own pre-#72 bug, no unrecognized-value-disables-gate
defect exists here today. What's missing: zero `gate-lib.sh`/`gate-lib.py`
references anywhere (survey §3), no Edit/MultiEdit reconstruction in any
of the three gates (survey §1), no absolute-path normalization outside
`spine-gate.sh` (survey §4), whole-document-presence semantic checks in
`citation-gate.sh` (survey §5), zero of the six mandatory test groups
confirmed passing (survey §7), and the README ghost-file/undocumented-
plugin gap (survey §8-9).

## Sources

- /home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/lib/gate-lib.sh
- /home/jwjung/tokenmaxxxer/tokenmaxxxer-core/docs/handbooks/gate-house-standard.md
- /home/jwjung/.tokenmaxxxer/work/implementation-rulebook-issue-64-implementation/docs/issue-64/proposals/2026-08-01-gate-a-plus-remediation.md
- docs/issue-39/proposals/2026-07-31-technical-feasibility-methodology-enforcement.md (this repo)
