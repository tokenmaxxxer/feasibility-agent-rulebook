---
status: draft
---

# Feasibility-cycle state machine

Authoritative source for this role's shape: `docs/specs/agent-roles.md` in
the `tokenmaxxxer` spec repository (`feasibility` section, Part 3). This
file transcribes that role's table into this repository's own words so the
repository is self-contained at runtime and never reads outside itself.

## Carrying artifact

`feasibility-record.md` at the project root of the sandbox this plugin is
installed into. State lives in its YAML frontmatter, field `status`.

Frontmatter fields:

- `status`: one of `idle`, `scoped`, `probing`, `verdict`.
- `market_argument_supplied`: fixed to `false` from the moment `scoped` is
  entered — records, deliberately, that the market argument that motivated
  the specification was never given to this role.
- `technical`, `prior_art`, `legal_regulatory`, `threat_model`: each one of
  `unresolved`, or `pass: <evidence>` / `fail: <evidence>` /
  `blocked: <evidence>`.

## States

`idle`, `scoped`, `probing`, `verdict`.

`probing` covers four probes: technical feasibility, prior art,
legal/regulatory, threat model.

## Transition table

| From | To | Fires on | Gated? |
|---|---|---|---|
| `idle` | `scoped` | user hands the role a specification | no |
| `scoped` | `probing` | agent begins the four probes | no |
| `probing` | `verdict` | all four probes resolved | **yes** |
| `probing` | `scoped` | a probe reveals the specification itself must change | no |

## Rejection rule for the gated transition

`probing -> verdict` fails unless BOTH:

1. The record file's four probe fields (`technical`, `prior_art`,
   `legal_regulatory`, `threat_model`) are each resolved — not empty, not
   `unresolved` — to `pass: ...`, `fail: ...`, or `blocked: ...`.
2. An approval token exists at `.feasibility/tokens/verdict.token`, minted
   by `hooks/capture-approval.sh` from an unambiguous statement in the
   user's own conversational turn, naming the `probing -> verdict`
   transition. The token is single-use: `hooks/state-gate.sh` deletes it
   the moment it authorizes a transition, so a stale token cannot authorize
   a second one.

Resolved probe fields with no token do not pass — content is not consent.
A token with unresolved probe fields does not pass either — an approval
about a transition whose preconditions are not yet met authorizes nothing.

## Entry to `scoped`

Entry to `scoped` requires the specification only. The gate additionally
requires the frontmatter to state `market_argument_supplied: false`
explicitly, verified at the moment of the first write that sets
`status: scoped` — the file must say plainly that this argument was
deliberately withheld, not merely omit it.

## Refusals per state

- **`idle`**: refuses to probe anything without a specification handed to
  the role. No state file, or a state file with no specification behind it,
  means there is nothing yet for `scoped` to record.
- **`scoped`**: refuses to render a verdict before probing starts —
  `scoped -> verdict` is not in the transition table and is refused by
  `state-gate.sh`'s exhaustive match (any transition not explicitly listed
  is denied).
- **`probing`**: refuses to argue from the market case — the specification
  is read without whatever motivated it, and the record file has no field
  for a market argument to be entered into in the first place.
- **`verdict`**: refuses to revise the verdict without reopening `probing`
  on a new probe finding. `verdict -> verdict` (a same-state rewrite) is
  permitted for correcting typos in the recorded verdict text, but there is
  no path back into `probing` other than the user handing the role a
  materially changed specification, which restarts the cycle.

## The gate mechanism

`hooks/state-gate.sh` runs on `PreToolUse` for `Write`, `Edit`,
`NotebookEdit`, and `Bash`. It resolves the TARGET PATH a call would write —
never trusting which tool performs the write — and judges any call whose
resolved path is `feasibility-record.md`:

- A `Bash` command whose text matches a write-shaped construct aimed at
  `feasibility-record.md` (redirect, `tee`, in-place `sed`/`perl`/`ruby`,
  `cp`, `mv`) is **denied outright**: the gate cannot read the resulting
  content before the command runs, and it does not guess.
- An `Edit` or `NotebookEdit` call aimed at the same file is **denied
  outright** for the same reason — this gate only trusts fully-materialized,
  readable content, which only a `Write` call provides.
- A `Write` call's proposed content is parsed; the transition it implies
  (old `status` on disk vs. new `status` in the proposed content) is checked
  against the table above.

On any malformed input — unparseable JSON payload, missing `tool_name`,
missing `tool_input`, a `status` value outside the four known states, an
unparseable existing record file, an unreadable token file — the gate
**denies** (exit code 2). It never falls through to allow on a surprise.

## Open question: four probes as sub-states, or sequential

Two shapes both satisfy the rejection rule above, since the rule only
requires all four probe fields resolved before `verdict`, and says nothing
about how the four probes are scheduled relative to each other:

- **Four independent open sub-states** — `probing/technical`,
  `probing/prior-art`, `probing/legal-regulatory`, `probing/threat-model`,
  each independently resolvable, with a richer per-probe status field in
  the record file and (if concurrent workers are wanted) a
  `parallel-decomposition`-style write-set split across them.
- **A single sequential pipeline** through the four, one at a time.

**This build implements the sequential form.** Reasons: the feasibility
role in this org runs as a single agent in a single sandbox (Part 2 of
`docs/specs/agent-roles.md`: roles never talk to each other and each runs in
its own sandbox), so there is no second worker to hand a probe to without
inventing cross-agent machinery this build is explicitly out of scope for;
and a sequential probe order lets an earlier probe's finding (e.g. prior art
revealing a patent that forecloses the whole approach) short-circuit the
remaining probes before they're run, which the transition table's
`probing -> scoped` escape hatch is shaped for. The question is left open in
this document rather than closed, because a future build that does want
concurrent probes (e.g. one worker per probe, `parallel-decomposition`'s
write-set contract keeping them from colliding on the same record file)
would only need to widen the record file's schema and `state-gate.sh`'s
per-field checks — the gated transition's rejection rule does not change
either way.
