---
name: reversibility-tag
description: Cross-cutting standing directive across all four feasibility probes — classify every finding as a one-way or two-way door before it is written to a probe-resolution field. Not a user-facing question; a discipline the agent applies to itself.
---

# Reversibility tag

**Belongs to state:** `probing` — cross-cutting across all four probes
(technical, prior-art, legal-regulatory, threat-model), not a probe of its
own.

This is a standing directive to the agent, not a question put to the user.
Bezos's one-way-door / two-way-door framing: some decisions are
consequential and hard to reverse (a one-way door) and must be made
methodically and carefully; others are cheap to reverse (a two-way door)
and can be made quickly. Reversibility is not a fifth probe — it is a field
on every finding the other four probes produce, and it scales how much
evidence a probe needs before it can resolve `pass`.

## What it does, before any probe-resolution field is written

For every finding produced by `spike-report`, `stride-table`,
`build-vs-buy`, or `license-scan`, classify it:

- **One-way door** — hard or costly to reverse (e.g. a core architectural
  dependency, a data-model choice migrating data later would be expensive
  to undo). Require more rigorous, more corroborated evidence before that
  finding is allowed to support a probe resolving `pass`.
- **Two-way door** — cheap and quick to reverse (e.g. a config flag, a
  vendor contract that can be cancelled). A lighter evidence bar is
  acceptable.

## Artifact

Not a separate file. This tag is written inline as a field on each finding
within the probe artifact that produced it (the spike report, the STRIDE
table row, the build-vs-buy comparison row, the license-scan entry) —
never a standalone `feasibility/reversibility.md`. Like those artifacts,
this write is not the state file and is not gated by `state-gate.sh`.

## Field added to every finding

- **Reversibility** — `one-way` or `two-way`, plus a one-line reason (what
  would it cost, in time or money, to undo this if it turns out wrong).

## Rule

A probe's resolution field in `feasibility-record.md` (`technical`,
`prior_art`, `legal_regulatory`, `threat_model`) should not be written as
`pass` if any of its one-way-door findings lack the heavier evidence this
tag calls for — say so to the user rather than resolving optimistically.
