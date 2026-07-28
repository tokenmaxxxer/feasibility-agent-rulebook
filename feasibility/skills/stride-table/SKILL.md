---
name: stride-table
description: Use this skill when running the threat-model probe inside the feasibility role's `probing` state — produces a STRIDE per-finding table before that probe can resolve.
---

# STRIDE table

**Belongs to state:** `probing`, threat-model probe.

## What it asks the user for

Walk the specification's design (or, if a diagram exists, its trust
boundaries) and ask the user, element by element: "what could go wrong here
from an adversarial-input or security-design standpoint, and what
trust boundary or entry point does it cross?" Do not ask for the whole
table in one turn — build it row by row as elements are identified,
confirming each row's disposition with the user when it is not obvious
from the specification alone.

For each row, classify the threat against one or more of the six STRIDE
categories: Spoofing, Tampering, Repudiation, Information Disclosure,
Denial of Service, Elevation of Privilege.

## Artifact

Writes to `feasibility-record.md`'s threat-model probe field (a pointer to,
or inline table within, a project-local STRIDE table file, e.g.
`feasibility/stride-table.md`). This artifact write is not gated — only the
state file's `status` transition is gated.

## Field list, one row per (element, threat category)

- **Element** — the specific component, data flow, or trust boundary being
  analyzed.
- **Threat category** — one or more of Spoofing / Tampering / Repudiation /
  Information Disclosure / Denial of Service / Elevation of Privilege.
- **Entry point or trust boundary crossed**.
- **Mitigation-or-accepted-risk disposition** — mitigated, accepted, or
  deferred. Never leave this blank or "in progress."

## Resolution rule

Every row requires a non-empty disposition field before the threat-model
probe can resolve to `pass`/`fail`/`blocked` in `feasibility-record.md`.
Before writing the probe's resolution, tag every finding as a one-way or
two-way door per `reversibility-tag` — a one-way-door threat finding should
carry more rigorous mitigation evidence than a two-way-door one before this
probe is allowed to resolve `pass`.
