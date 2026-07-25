---
name: build-vs-buy
description: Use this skill when running the prior-art probe inside the feasibility role's `probing` state — produces a build-vs-buy comparison and per-dependency health scores before that probe can resolve.
---

# Build vs buy

**Belongs to state:** `probing`, prior-art probe.

## What it asks the user for

Ask the user: does this specification already exist as prior art (an
existing product, library, or patented approach), and if a build-or-buy
choice is live, what alternatives should be compared? Ask one question at a
time: first whether prior art exists at all, then — only if a genuine
build-vs-buy choice is on the table — for the candidate alternatives to
compare.

## Artifact

Writes to `feasibility-record.md`'s prior-art probe field (a pointer to, or
inline table within, a project-local file, e.g.
`feasibility/build-vs-buy.md`). This artifact write is not gated — only the
state file's `status` transition is gated.

## Field list

- **Build-vs-buy comparison table**, one row per candidate: option (build /
  buy — named vendor or package), cost/TCO estimate, vendor-lock-in or
  maintenance-burden risk, and whether the capability is a competitive
  differentiator.
- **Per-dependency health score** — for each open-source dependency the
  specification would pull in, an attached health score (OpenSSF Scorecard
  or equivalent aggregated 0-10 score). Note plainly that this score
  measures process hygiene (branch protection, dependency pinning, CI
  checks), not code quality or absence of vulnerabilities.

## Reversibility note

Buying is usually the two-way door (a contract can be cancelled); building
in-house on a core architectural dependency is usually the one-way door
(migrating off it later is expensive). Record this classification per
option in the comparison table using `reversibility-tag`, and scale the
evidence required for the prior-art probe to resolve `pass` accordingly —
a one-way-door build decision needs more than a two-way-door buy decision.

## Resolution rule

The prior-art probe does not resolve until the comparison table (or an
explicit "no prior art of note" finding) and, where dependencies are named,
their health scores are recorded.
