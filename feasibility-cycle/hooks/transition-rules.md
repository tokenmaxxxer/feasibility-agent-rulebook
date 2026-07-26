# Feasibility role transition table

Single source of truth for legal transitions of `feasibility-record.md`'s
`status` field. Read by both `inject-transition-rules.sh` (UserPromptSubmit)
and `state-gate.sh` (PreToolUse). `from` is the on-disk status before the
write; `(none)` means no record file exists yet (first-ever write). `actor`
is `user` when the transition requires the user to have said something in
this conversation, `agent` when the agent may make it unilaterally.

States: `idle`, `scoped`, `probing`, `verdict-provisional`, `verdict`, `scope-proposed`, `scope-approved`.
`scope-proposed`/`scope-approved` are the §19 front-record scope-approval
states: feasibility proposes a scope statement (`scope-proposed`); the human
approves it (`scope-proposed -> scope-approved`, `actor: user`). The
`scope-proposed -> scope-approved` transition additionally requires a
human-placed approval token (enforced by the sibling `scope-record-gate.sh`,
mirroring qa-cycle's `capture-verdict.sh` human-token mechanism); the bare
table row records only that the transition is legal in principle.
`verdict-provisional` sits between `probing` and `verdict` — a draft
disposition (feasible / infeasible / feasible-with-conditions) with
recorded findings, distinct from an explicitly accepted verdict. There is
no dedicated sub-state for a timebox extension mid-probe: it is a
`probing -> probing` self-loop, `actor: user`, below.

from | to | actor | precondition
--- | --- | --- | ---
(none) | idle | agent | first write to feasibility-record.md
(none) | scoped | agent | market_argument_supplied: false recorded in frontmatter
scoped | probing | agent | agent begins the four probes
probing | scoped | agent | a probe revealed the specification itself must change
probing | probing | user | practitioner reports a probe's timebox expired with no conclusive answer; user decides extend (with a new, separately-scoped timebox) vs. stop
probing | verdict-provisional | agent | all four probe fields (technical, prior_art, legal_regulatory, threat_model) resolved pass/fail/blocked with evidence and a draft disposition, including a reversibility classification per finding
verdict-provisional | verdict | user | user (or a named ADR/ARB-equivalent approver) explicitly changes status from provisional to accepted in their own turn — silence does not count
verdict-provisional | scoped | user | user rejects the draft verdict and returns it with a named reason (rework), mirroring an ADR/ARB "reject or require changes" outcome
(none) | scope-proposed | agent | first write proposes a scope statement for human approval (§19 front record)
scoped | scope-proposed | agent | feasibility proposes a scope statement for the subject, awaiting human approval (§19)
scope-proposed | scope-proposed | agent | feasibility revises the still-unapproved scope statement in place
scope-proposed | scope-approved | user | human explicitly approves the proposed scope statement in their own turn; requires a human-placed approval token (§19) — silence never counts
