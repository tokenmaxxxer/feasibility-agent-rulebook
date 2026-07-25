# Feasibility role transition table

Single source of truth for legal transitions of `feasibility-record.md`'s
`status` field. Read by both `inject-transition-rules.sh` (UserPromptSubmit)
and `state-gate.sh` (PreToolUse). `from` is the on-disk status before the
write; `(none)` means no record file exists yet (first-ever write). `actor`
is `user` when the transition requires the user to have said something in
this conversation, `agent` when the agent may make it unilaterally.

States: `idle`, `scoped`, `probing`, `verdict-provisional`, `verdict`.
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
