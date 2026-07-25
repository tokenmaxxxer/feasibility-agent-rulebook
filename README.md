# tokenmaxxxer / feasibility-agent-rulebook

A Claude Code plugin marketplace for the `feasibility` role: decides whether
a specification can be built, and whether it may be built — the lead-engineer
feasibility-risk seat, plus legal, regulatory, and threat-model risk. See
`docs/specs/agent-roles.md` in the `tokenmaxxxer` spec repository for the
full role definition this repository implements; this repository is
self-contained and does not read that spec at runtime — its own
`docs/specs/state-machine.md` carries the whole transition table.

## What this role does

**Given to start**: the specification only, deliberately without the market
argument that motivated it. A feasibility verdict argued from "but this will
make money" is not a feasibility verdict.

**Produces**: a constraint list, a go/no-go verdict, and a measurement
design — what events get collected, and where.

**Prevents**: late discovery of a technical, legal, or regulatory blocker,
and instrumentation added too late to measure the thing it needed to
measure.

## State machine

States: `idle -> scoped -> probing -> verdict`. `probing` covers four
probes: technical feasibility, prior art, legal/regulatory, threat model,
run **sequentially** in this build (see the open question recorded in
`docs/specs/state-machine.md`). The gated transition `probing -> verdict` is
refused while any probe is unresolved, and separately refused without an
approval token minted from the user's own conversational turn — resolved
probe fields alone are not consent. Full detail:
`docs/specs/state-machine.md`.

## Handoff protocol

The authoritative contract is the work repo's own
`docs/specs/role-handoff-contract.md` — this rulebook is a plugin installed
into and pointed at a real work repo, and carries no copy of that file
itself. The rows below describe only how the feasibility role behaves
against whatever contract the work repo carries.

**ACCEPTS**: `hypothesis` — the spec to assess. The market argument that
motivated it is withheld regardless of what the input artifact actually
contains; this role's own "given to start" rule (above) overrides whatever
the upstream artifact carries. Refuses `build-proposal`, `qa-state`,
`review-record`, `ops-state` — none of these are within this role's accept
set.

**WHERE UPSTREAM LIVES**: `docs/proposals/<date>-<slug>.md`, `kind:
hypothesis`. Given only a pointer ("it's here"), this is the path shape to
resolve it against.

**PRODUCES**:

- `feasibility-record` at `docs/reports/records/<subject>/feasibility.md`.
  Required fields beyond the common header (`kind`, `subject`,
  `produced_by`, `upstream`, `handoff_status: provisional | final`): role
  status (`idle,scoped,probing,verdict`), `market_argument_supplied: false`,
  `technical`/`prior_art`/`legal_regulatory`/`threat_model` (each
  `unresolved | pass:<evidence> | fail:<evidence> | blocked:<evidence>`),
  `verdict: go | no-go | conditional` (required once role status reaches
  `verdict`), `measurement_design: <description or pointer>` (required
  alongside `verdict`).
- `spike-report` at
  `docs/reports/records/<subject>/spikes/<spike-slug>.md`. Required fields
  beyond the common header: Spike Title, Description/Goal, Type, Timebox,
  Acceptance Criteria, Tasks, Outcomes, Recommendation, Open questions,
  Reversibility tag.

**STOPS**:

- Upstream stale at role entry: the `hypothesis` path's recorded `sha` in
  this record's `upstream` entry no longer matches that path's current
  commit SHA. Stop before doing further work and ask the user whether to
  proceed on the recorded version or re-confirm against the current one.
- A `feasibility-record` or `spike-report` already exists at a path this
  role owns but this role did not write it, or a record already exists at a
  path this role does not own under `docs/reports/records/<subject>/`.
  Refuse to write, report the conflict (the path, and whose territory it
  falls in) — never overwrite or merge into it silently.
- Input carries `handoff_status: provisional`. This role may read it to
  plan or draft against but must not treat it as final input to an
  accept/refuse decision, nor record it as the baseline for the staleness
  check, until `handoff_status` reads `final`.

## Install

```
curl -fsSL https://raw.githubusercontent.com/tokenmaxxxer/feasibility-agent-rulebook/main/install.sh | bash
```

This registers the `tokenmaxxxer-feasibility` marketplace and installs the
`feasibility-agent-env` bundle plus `feasibility-cycle` at **user scope**.
It prefers a real `claude` CLI (standalone, or the binary bundled inside the
VSCode extension) and falls back to merging `extraKnownMarketplaces` and
`enabledPlugins` into `~/.claude/settings.json` — backing up the existing
file first, following symlinks rather than replacing them, and aborting
without writing anything if the existing file fails to parse as JSON.

Or, from any Claude Code session, the equivalent by hand:

```
/plugin marketplace add tokenmaxxxer/feasibility-agent-rulebook
/plugin install feasibility-agent-env@tokenmaxxxer-feasibility
```

Verify with `/plugins`. `install.sh --help` prints usage; the only other
input it reads is `TOKENMAXXXER_SETTINGS_ONLY=1`, which forces the
settings-file fallback path.

## Plugins

| Plugin | What it does |
|---|---|
| [feasibility-cycle](feasibility-cycle/) | The state machine, its two hooks, and the skill that runs the four-probe feasibility cycle. |
| [feasibility-agent-env](feasibility-agent-env/) | One-install bundle: pulls in `feasibility-cycle`. Contains no code of its own. |

## Isolation

This repository is fully self-contained. No shared code, no cross-repo
dependency, and no shared file with `coding-agent-rulebook`,
`qa-agent-rulebook`, or any sibling `*-agent-rulebook` repository. Every
plugin `source` in `.claude-plugin/marketplace.json` is `./`-relative to
this repository, and `install.sh` names only this repository and its own
marketplace.
