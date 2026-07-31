# evidence-citation

A methodology plugin for the technical-feasibility cycle. It enforces
OpenSSF-Scorecard-style mandatory evidence citation discipline: every
factual claim in a technical-feasibility proposal (phase 1) or record
(phase 2) must carry a citation in the format

```
<claim> — <source: URL | path:line | check-name score>
```

A claim with no citation is not evidence. Phase 2 may not re-derive a
phase-1-cited claim from memory — citations must be carried forward,
not restated uncited.

## Why

This is the citation-discipline methodology issue-30 adopted for the
technical-feasibility rulebook: an OpenSSF-Scorecard-style requirement
that every claim resolve to a pointable source (a URL, a repository
`path:line`, or an automated check's `check-name score`) rather than an
unsupported assertion. See
`docs/issue-39/proposals/2026-07-31-technical-feasibility-methodology-enforcement.md`,
section "`evidence-citation`", for the accepted proposal this plugin
implements.

## How it composes

This plugin is self-contained and composes purely through its OWN
independent `hooks/hooks.json` — no other plugin's files are edited to
wire it in, because Claude Code fires every enabled plugin's
`hooks.json` independently:

- `SessionStart` runs `cat "${CLAUDE_PLUGIN_ROOT}/directive-fragment.md"`,
  announcing the citation format and its rules into the session at the
  start of every session in which this plugin is enabled.
- `PreToolUse` (matcher `Write|Edit|MultiEdit`) runs
  `hooks/citation-gate.sh`, which checks writes to the two
  technical-feasibility write surfaces:
  - Phase 1: `docs/issue-<n>/proposals/*technical-feasibility*.md`
  - Phase 2: `docs/issue-<n>/reports/technical-feasibility.md`

  Any other tool or path is a pass-through (allow).

## Gate behavior and known limitations

`hooks/citation-gate.sh` is fail-closed (malformed/missing input denies)
but its *citation* checks are deliberately heuristic, and this is the
highest false-positive-risk gate in the technical-feasibility
methodology set by design:

- Phase 1: if a `## Evidence format` section exists and has prose
  content, it must contain at least one citation shaped like the
  required format (an em-dash `—` followed by `source:`-shaped text, a
  URL, or a `path:line` reference). A bare/absent/empty section is fine
  — nothing to check.
- Phase 2: best-effort only. It denies solely when the whole document
  has zero citations anywhere AND at least one claim-shaped line is
  present. Any citation anywhere in the document is treated as
  satisfying "carried forward," since the heuristic cannot reliably
  distinguish a genuinely carried-forward claim from a newly re-derived
  one. On ambiguity this check leans ALLOW rather than block a write,
  per the proposal's stated risk tolerance for this gate.
- It cannot verify that a citation is *true*, only that something
  citation-shaped is present.
- `Edit`/`MultiEdit` payloads only carry the diff fragment being
  written (`new_string`), not a merged final-file view, so those checks
  are best-effort against the new text only.

## Kill switch

Set `EVIDENCE_CITATION_GATE_OFF=1` (also accepts `true`/`yes`/`on`,
case-insensitive) to disable the gate entirely (exits 0 unconditionally).

## Tests

```
bash evidence-citation/tests/run-gate-tests.sh
```

Runs the gate as a real subprocess against a throwaway git-init'd
tmpdir for each case, checks exit codes (0 = allow, 2 = deny), and
exits nonzero if any case fails. Covers: phase-1 allow (cited claims),
phase-1 deny (`## Evidence format` present with prose but zero
citations), phase-1 allow (bare/empty section), phase-2 allow (claims
cited/carried forward), phase-2 deny (new uncited claim, zero citations
anywhere), foreign-path passthrough, and the kill switch.
