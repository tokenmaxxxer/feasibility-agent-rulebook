---
name: feasibility-cycle
description: Use this skill when running the feasibility role — deciding whether a specification can be built and whether it may be built (technical, prior-art, legal/regulatory, and threat-model risk). Trigger when handed a specification (deliberately without the market argument that motivated it) and asked for a feasibility verdict, or when resuming an in-progress feasibility check.
---

# Feasibility cycle

You are running the `feasibility` role: decide whether a specification can be
built, and whether it may be built. You are handed the specification only —
deliberately without the market argument. A verdict argued from "but this
will make money" is not a feasibility verdict; do not ask for or accept that
argument.

## State

All state lives in `feasibility-record.md` at the project root, in YAML
frontmatter, field `status`. States: `idle`, `scoped`, `probing`, `verdict`.
See `docs/specs/state-machine.md` in this plugin's repository for the full
transition table and rejection rules — that file is authoritative; this
skill only orients you at the start of a session.

## Starting

1. Read `feasibility-record.md` if it exists to learn the current `status`
   and probe fields. Report it back to the user before doing anything else —
   which state you're in, and what the record's probe fields currently say.
2. If no record file exists and you have been handed a specification, create
   `feasibility-record.md` with `status: scoped`, `market_argument_supplied:
   false`, and the four probe fields set to `unresolved`. Use the Write tool
   — the state-gate hook denies Edit/NotebookEdit calls against this file and
   denies any Bash write to it, so always rewrite the whole file with Write.

## Running the probes

This build runs the four probes **sequentially**, not as four concurrent
open sub-states (see the open question recorded in
`docs/specs/state-machine.md`). Move `status: probing` once you begin, then
work the four probe fields in order: `technical`, `prior_art`,
`legal_regulatory`, `threat_model`. Each resolves to `pass: <evidence>`,
`fail: <evidence>`, or `blocked: <evidence>`.

- **technical** — can this be built with a technology chosen at this point in
  time? Route deep technology-choice questions through the `tech-feasibility`
  skill if installed elsewhere; here, record the resolution and its evidence.
- **prior_art** — does this already exist, or does building it collide with
  existing patents? Route through `prior-art-scan` if installed; record the
  resolution.
- **legal_regulatory** — what law, license, or platform policy applies?
  Route through `compliance-scan` if installed; record the resolution. This
  is research, not a legal opinion — say so if a real determination is
  needed.
- **threat_model** — what could go wrong from an adversarial-input or
  security-design standpoint? Route through `stride` if installed; record
  the resolution.

If a probe reveals the specification itself must change before probing can
continue, move `status: scoped` (this transition is ungated) and report why.

## Entering verdict

`probing -> verdict` is refused by the state-gate hook until all four probe
fields are resolved (not empty, not `unresolved`) AND the user has given an
unambiguous approval for this transition in their own turn (a bare "ok" does
not count — say plainly that you are asking to move to verdict, and wait for
the user to say so unambiguously). The approval token is minted by
`capture-approval.sh` from the user's literal words; you cannot manufacture
it by writing to the record file yourself.

## Producing the verdict

Once in `verdict`, write the go/no-go call and the measurement design (what
events get collected, and where) into the record file. Do not revise a
rendered verdict without reopening `probing` on a new probe finding.
