---
name: license-scan
description: Use this skill when running the legal-regulatory probe inside the feasibility role's `probing` state — produces a per-dependency license verdict and a regulatory-applicability note before that probe can resolve.
---

# License scan

**Belongs to state:** `probing`, legal-regulatory probe.

## What it asks the user for

Ask the user what dependencies (packages, SaaS, third-party services) the
specification would pull in, if not already listed. Then ask what
regulatory regime, if any, the user believes applies (data category,
customer/region), so the note below is grounded rather than guessed. This
is research, not a legal opinion — say so plainly if a real legal
determination is needed and none is available.

## Artifact

Writes to `feasibility-record.md`'s legal-regulatory probe field (a pointer
to, or inline table within, a project-local file, e.g.
`feasibility/license-scan.md`). This artifact write is not gated — only the
state file's `status` transition is gated.

## Field list

- **Per-dependency license verdict** — one verdict per dependency (FOSSA /
  ScanCode-or-equivalent shape): package name, declared license,
  compatibility verdict, and any custom or dual-licensing edge case flagged.
- **Regulatory-applicability note** — which regulatory regimes (if any)
  apply to this specification, mirroring the DPIA-before-processing pattern
  for data-handling designs. State plainly where this is research rather
  than legal advice.

## Resolution rule

The legal-regulatory probe does not resolve until every named dependency
has a license verdict and the regulatory-applicability note is written
(even if that note is "none identified" — it must be an explicit finding,
not a silent omission).
