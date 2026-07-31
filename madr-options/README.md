# madr-options

Enforces MADR's "Candidates/Options considered" discipline for
technical-feasibility work: one methodology, owned by this plugin alone.

## What it enforces

- **Phase 1** (`docs/issue-<n>/proposals/*technical-feasibility*.md`): a
  `## Candidates considered` section naming **two or more** candidates, each
  with a one-line rejection reason, plus a `## Timebox and acceptance
  criteria` section in the same write (the order constraint:
  timebox-before-candidates — a proposal must commit to how long it will run
  and how success is judged before it can lean on "still comparing options"
  to justify drift).
- **Phase 2** (`docs/issue-<n>/reports/technical-feasibility.md`): every
  candidate named in the matching phase-1 proposal's `## Candidates
  considered` must reappear in this record's `Options considered` section,
  or be explicitly marked `dropped: <reason>`. No silent disappearance of a
  phase-1 candidate.

## Why

A single-candidate list is a foregone conclusion dressed up as analysis, and
candidates that quietly vanish between the proposal and the final record
erase exactly the tradeoff information a reviewer needs. This is the MADR
discipline adopted in issue-30 for the technical-feasibility methodology, now
carried into an independently enforceable gate for issue-39.

## Kill switch

Set `MADR_OPTIONS_GATE_OFF=1` (also accepts `true`/`yes`/`on`, any casing) to
disable the `PreToolUse` gate entirely.

## How it's wired

This plugin composes purely through its own, independent `hooks/hooks.json`:

- `SessionStart` runs `cat "${CLAUDE_PLUGIN_ROOT}/directive-fragment.md"` to
  announce the discipline into the session.
- `PreToolUse` (matched on `Write|Edit|MultiEdit`) runs
  `hooks/options-gate.sh`, which checks only the two write-surface paths
  above and passes through (`exit 0`) everything else.

No edits to `feasibility/` or any other plugin's files are needed — Claude
Code fires every enabled plugin's `hooks.json` independently, so this plugin
stands entirely on its own.

## Heuristic limits

The checks here are best-effort text heuristics, not a real parser:

- "One-line reason" is approximated as "non-empty prose follows the
  candidate marker" — it cannot verify the reason is substantive.
- Candidate-name matching between phase-1 and phase-2 is a case-insensitive
  substring match against a best-effort guess at the phase-1 proposal file
  (`docs/issue-<n>/proposals/*technical-feasibility*.md`), not semantic
  identity.
- Only a complete `Write` can be judged; `Edit`/`MultiEdit` against an
  owned path are denied (fail-closed) because this gate needs the full
  document content to verify section shape.

## Tests

```
bash madr-options/tests/run-gate-tests.sh
```

Covers: phase-1 allow (2+ candidates, reasons, timebox present); phase-1 deny
(single candidate); phase-1 deny (candidates present, timebox missing);
phase-2 allow (all phase-1 candidates carried forward); phase-2 allow
(missing candidate marked `dropped: <reason>`); phase-2 deny (missing
candidate, no dropped-reason); foreign-path passthrough; kill switch.
