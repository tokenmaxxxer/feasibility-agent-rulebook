---
name: spike-report
description: Use this skill when running the technical probe inside the feasibility role's `probing` state — a timeboxed spike to answer one uncertain technical question before a feasibility verdict can be drafted.
---

# Spike report

**Belongs to state:** `probing`, technical probe.

A spike is a timeboxed investigation whose output is knowledge, not
shippable code. This skill runs the human-in-the-loop negotiation the
research found at both ends of a spike (agreeing the question and timebox
before starting; reporting back at the timebox's end) and writes the
resulting spike report as one artifact — never asks for everything in one
turn.

## What it asks the user for, one thing at a time

1. **The question** — what specifically do we need to know to resolve the
   technical probe? State it as a single, answerable question, not a broad
   area.
2. **A proposed timebox** — 1 to 3 days is the convergent practitioner
   range; ask the user to confirm or adjust it. Do not start work until the
   user has agreed the timebox, not merely heard it proposed.
3. **Acceptance criteria** — write what "answered" looks like *before* work
   starts, not after. This is the load-bearing discipline: acceptance
   criteria written after the investigation is indistinguishable from
   post-hoc rationalization, and this skill refuses to accept it that way
   (see "Timestamp discipline" below).

Only after all three are agreed does the skill begin the investigation.

## While investigating

Record Tasks/Activities as they happen. The spike's internal method (which
tool, which throwaway script) is not something to ask the user about — no
sourced practice reviews or approves a spike's means, only its question and
timebox.

## If the timebox expires with no conclusive answer

Stop. Do not silently keep going. Report to the user: what gaps remain,
and what more time would likely buy. The user decides: extend with a
**new**, separately-scoped timebox (its own acceptance criteria, not a
silent continuation of the old one), or stop and record the gap as an open
finding. This is the `probing -> probing` self-loop in
`feasibility-cycle/hooks/transition-rules.md` — write the extension (or the
stop-and-record decision) into the spike report, but this write is to the
spike report artifact, not the state file, and is not itself gated.

## On completion

Record: Tasks/Activities, Outcomes/Learnings (findings), a Recommendation,
and any open questions for future work. Then classify every finding this
probe produced as a one-way or two-way door (Bezos framing) using the
`reversibility-tag` skill's standing directive before writing the
technical-probe field's resolution (`pass`/`fail`/`blocked` plus evidence)
in `feasibility-record.md`.

## Artifact

Writes to `feasibility-record.md`'s own project (a project-local spike
report file, one per spike, e.g. `feasibility/spike-report-<slug>.md`),
using the field skeleton at
`feasibility-cycle/skills/spike-report/templates/spike-report-template.md`.
This artifact write is not gated — only the `feasibility-record.md` state
file's `status` field transition is gated by `state-gate.sh`. The
technical-probe resolution field in `feasibility-record.md` should point at
(or summarize) the spike report file, and its evidence should not be
written until the acceptance criteria are actually met or the timebox
stop-and-record decision is made.

## Field list (spike-report-template.md)

- Spike Title
- Description/Goal (the question being investigated)
- Type of spike (technical / functional / architectural)
- Estimated Timebox
- Acceptance Criteria — written and timestamped before work starts
- Tasks/Activities
- Outcomes/Learnings
- Recommendation
- Open questions for future work

## Timestamp discipline

Refuse to mark Acceptance Criteria complete if its recorded timestamp
postdates the timebox's recorded start — that ordering violation is exactly
the "acceptance criteria written after the fact" failure mode the practice
research names. If you notice this has already happened, say so plainly to
the user rather than silently backdating the field.
