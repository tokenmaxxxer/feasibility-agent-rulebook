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
design. Which role a `verdict: go` wakes is canon at
[on-the-record `docs/specs/wake-routing.md`](https://github.com/tokenmaxxxer/on-the-record/blob/main/docs/specs/wake-routing.md),
not this rulebook.

## What is here

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
    feasibility/hooks/record-fields-gate.sh  s20 minimum content on the
                                        record and on spike reports
    feasibility/hooks/trailer-gate.sh   commits staging docs/issue-<n>/** carry
                                        `Subject: issue-<n>`
    feasibility/hooks/handbook-trigger-gate.sh  s21 same-turn handbook sync
    feasibility/skills/                 spike-report, stride-table,
                                        license-scan, build-vs-buy,
                                        reversibility-tag
    tests/                              repo-level checks (never installed)

## Record vocabulary

`status`/`loop_state`: `idle, scoped, probing, verdict` (+ the
`verdict-provisional` draft disposition, and `scope-proposed,
scope-approved` when this is the front record). Probe fields `technical`
/ `prior_art` / `legal_regulatory` / `threat_model`, each `unresolved |
pass:<evidence> | fail:<evidence> | blocked:<evidence>`. Spike reports
live at `docs/issue-<n>/reports/spikes/<slug>.md` (a core R5 grant).

## Install

    claude plugin marketplace add tokenmaxxxer/feasibility-agent-rulebook
    claude plugin install feasibility@tokenmaxxxer-feasibility

Kill switch: `FEASIBILITY_CYCLE_OFF=1`.

## Run the checks

    /bin/bash tests/parse-check.sh
    /bin/bash tests/run-gate-tests.sh
    /bin/bash tests/deny-only-check.sh
