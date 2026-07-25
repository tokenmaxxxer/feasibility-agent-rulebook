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
