# tokenmaxxxer / feasibility-agent-rulebook

The `feasibility` role on contract v3. A feasibility session is spawned
with two plugin sets installed: this marketplace's `feasibility` plugin,
and the [tokenmaxxxer-core](https://github.com/tokenmaxxxer/tokenmaxxxer-core)
plugins (`core`, `terse`, `freelunch`, `scout`). Core owns the interaction
protocol — issue in, two-phase PR out (research/survey/proposal → human
review Approve → execution), branch `issue-<n>/feasibility`, record at
`docs/issue-<n>/reports/feasibility.md`. This rulebook owns only what is
feasibility-specific.

## What `feasibility` decides

Whether the specification CAN be built and MAY be built — the
lead-engineer feasibility seat plus legal, regulatory, and threat-model
risk. Given the spec deliberately WITHOUT the market argument
(`market_argument_supplied: false`, recorded explicitly). Produces a
constraint list, a `verdict: go|no-go|conditional`, and the measurement
design. Selection criteria: a blocking condition resolvable only
**externally** -> `conditional` (blocking condition in `conditions:`);
a two-way prerequisite resolvable **within this repo's own work** ->
`go` + the `verdict_provisional` convention in the record body (see
"Record vocabulary"); a scope constraint only -> `go` + the constraint
in the record body. The `verdict` field carries the bare enum value
only — narrative lives in the record body.

## What is here

This marketplace ships four plugins (`.claude-plugin/marketplace.json`).
`record-fields-gate.sh`, `trailer-gate.sh`, and `handbook-trigger-gate.sh`
are **core canon**, not vendored here — core fires them globally against
every rulebook once installed (issue-31: core canon reference transition).

    feasibility/hooks/directive.sh      SessionStart — the four facets:
                                        research (the four probes, each with
                                        its evidence bar), survey (spec sans
                                        market argument + deploy-config
                                        surface), proposal (verdict +
                                        measurement design + spike timeboxes),
                                        judgment (all-four-probes-or-no-
                                        verdict, provisional vs accepted,
                                        reversibility scales evidence,
                                        timebox expiry goes to the human)
    feasibility/skills/                 spike-report, stride-table,
                                        license-scan, build-vs-buy,
                                        reversibility-tag

    madr-options/hooks/options-gate.sh       MADR "Candidates/Options
                                        considered" discipline: plural
                                        candidates, one-line rejection
                                        reasons, phase-1 -> phase-2
                                        carry-forward. Kill switch:
                                        `MADR_OPTIONS_GATE_OFF=1`.
    nygard-adr-spine/hooks/spine-gate.sh     Nygard's minimal ADR spine
                                        (Title/Status/Context/Decision/
                                        Consequences) plus Risks
                                        disposition, on the phase-2 record.
                                        Kill switch:
                                        `NYGARD_ADR_SPINE_GATE_OFF=1`.
    evidence-citation/hooks/citation-gate.sh OpenSSF-Scorecard-style
                                        mandatory evidence citation format
                                        (`<claim> — <source>`), no bare
                                        assertions, carried forward across
                                        phases. Kill switch:
                                        `EVIDENCE_CITATION_GATE_OFF=1`.

    tests/                              repo-level checks (never installed)

All three methodology gates (`citation-gate.sh`, `spine-gate.sh`,
`options-gate.sh`) source core's `core/hooks/lib/gate-lib.sh`/
`gate-lib.py` (issue-72 gate-house standard) for their fail-closed trap,
kill-switch check, path normalization, and Edit/MultiEdit reconstruction
— referenced, never reimplemented, resolved via
`CLAUDE_PLUGIN_ROOT_CORE`. When core isn't installed/checked out
alongside this repo, these gates fail closed (deny) rather than silently
no-op.

## Record vocabulary

`status`/`loop_state`: `idle, scoped, probing, verdict` (+ the
`verdict-provisional` draft disposition, and `scope-proposed,
scope-approved` when this is the front record). Probe fields `technical`
/ `prior_art` / `legal_regulatory` / `threat_model`, each `unresolved |
pass:<evidence> | fail:<evidence> | blocked:<evidence>`. Spike reports
live at `docs/issue-<n>/reports/spikes/<slug>.md` (a core R5 grant).

`verdict_provisional` (underscore) is a **body-level convention**, not a
`loop_state` value: on a `verdict: go` record, it names an in-repo,
two-way-resolvable prerequisite in the record body (controller #89
precedent). It is distinct from `verdict-provisional` (hyphenated)
above, which is the phase-1-vs-human-accepted `loop_state` disposition.
Same words, different concepts; both are kept.

## Install

    claude plugin marketplace add tokenmaxxxer/feasibility-agent-rulebook
    claude plugin install feasibility@tokenmaxxxer-feasibility

Kill switch: `FEASIBILITY_CYCLE_OFF=1`.

## Run the checks

    /bin/bash tests/parse-check.sh
    /bin/bash tests/run-gate-tests.sh   # folds in each plugin's own tests/run-gate-tests.sh
    /bin/bash tests/deny-only-check.sh

The methodology-gate test scripts (and the root harness that folds them
in) require `core/hooks/lib/gate-lib.sh` to be resolvable — set
`CLAUDE_PLUGIN_ROOT_CORE` to core's plugin root, or check core out as a
sibling of this repo. Without it they print `SKIP-ALL` and exit 0 rather
than fail, matching how the root harness already treats
`record-fields-gate.sh`/`trailer-gate.sh` as an external dependency.
Core's own `core/hooks/tests/compliance-check.sh <plugin>/hooks` is the
ship-time detector for gate-lib compliance across all three gates.
