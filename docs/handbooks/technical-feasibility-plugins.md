# Technical-feasibility methodology plugins

Three sibling plugins enforce the methodology adopted in issue-30 as
machine-checked gates, each self-contained and independent of the
`feasibility` role plugin's own files:

- `madr-options/` — MADR candidates/options-considered discipline.
- `nygard-adr-spine/` — Nygard's minimal ADR spine + Risks disposition.
- `evidence-citation/` — mandatory evidence citation format.

## Running the tests

From the repo root:

```
bash tests/run-gate-tests.sh
```

This runs the root harness (core-canon gate cases — `SKIP`s cleanly
when `core` isn't checked out next to this repo, since it's referenced,
not vendored) and folds in each plugin's own standalone test script.
Each plugin's tests are also directly runnable on their own, e.g.:

```
bash madr-options/tests/run-gate-tests.sh
bash nygard-adr-spine/tests/run-gate-tests.sh
bash evidence-citation/tests/run-gate-tests.sh
```

## Kill switches

Each gate can be disabled independently via its own environment
variable (`1|true|yes|on`):

- `MADR_OPTIONS_GATE_OFF`
- `NYGARD_ADR_SPINE_GATE_OFF`
- `EVIDENCE_CITATION_GATE_OFF`

## Registration

All three are registered in `.claude-plugin/marketplace.json` next to
`feasibility`. Enabling/disabling any of them is independent — none of
the three edits `feasibility/hooks/directive.sh` or
`feasibility/hooks/hooks.json`, so removing one is deleting its
directory and marketplace entry, nothing else.

See `docs/issue-39/reports/technical-feasibility.md` for the design
record (why independent-hooks composition was chosen over splicing
into `feasibility`'s directive).
