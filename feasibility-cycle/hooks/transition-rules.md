# Feasibility role transition table

Single source of truth for legal transitions of `feasibility-record.md`'s
`status` field. Read by both `inject-transition-rules.sh` (UserPromptSubmit)
and `state-gate.sh` (PreToolUse). `from` is the on-disk status before the
write; `none` means no record file exists yet (first-ever write). `actor`
is `user` when the transition requires the user to have said something in
this conversation, `agent` when the agent may make it unilaterally.

from | to | actor | precondition
--- | --- | --- | ---
none | idle | agent | first write to feasibility-record.md
none | scoped | agent | market_argument_supplied: false recorded in frontmatter
scoped | probing | agent | agent begins the four probes
probing | scoped | agent | a probe revealed the specification itself must change
probing | verdict | user | all four probe fields (technical, prior_art, legal_regulatory, threat_model) resolved as pass/fail/blocked, AND the user has approved rendering the verdict in this conversation
