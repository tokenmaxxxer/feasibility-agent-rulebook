---
status: draft
---

# Agent roles and their state machines

This document defines the `feasibility` agent role this repository carries,
alongside the two that already exist (`coding`, `qa`), specifies how the
human user drives the role in a star topology (user at the centre, agents
never talking to each other), and gives the role's internal state machine at
the concreteness of `coding-agent-rulebook`'s warrant plugin: named states, a
named artifact carrying the state, explicit gate conditions evaluated on a
file, not on which tool wrote it.

Sources for every research claim are the eight files under
`docs/reports/research/2026-07-25-swpd-roles/`, cited by filename.

## Part 1 — Roles

### `feasibility`

**Decides**: whether the specification can be built, and whether it may be
built — the lead-engineer feasibility-risk seat in Cagan's trio
(product-discovery.md), plus the constraint classes the trio's engineer alone
cannot clear: legal, regulatory, and threat-model risk
(security-legal-compliance.md).

**Given to start**: the specification only, deliberately without the market
argument that motivated it. The split mirrors Stage-Gate's separation of
execution from gating authority (lifecycle-frameworks-handoffs.md): a
feasibility verdict argued from "but this will make money" is not a
feasibility verdict.

**Produces**: a constraint list, a go/no-go verdict, and the measurement
design — what events get collected, and where. The measurement-design output
exists because instrumentation decided after the fact cannot measure the
thing it needed to measure; DORA's architecture-capability findings tie
architectural decisions made early to delivery performance measured much
later (engineering-architecture.md, lifecycle-frameworks-handoffs.md), and
GDPR's DPIA is the sharpest form of this pattern turned into law: the
privacy impact assessment must be completed "prior to the processing," not
after — a legally forced instance of shift-left
(security-legal-compliance.md).

**Prevents**: late discovery of a technical, legal, or regulatory blocker,
and instrumentation added too late to measure the thing it was supposed to
measure.

### `coding` (existing, as-is)

Described from `coding-agent-rulebook`'s `warrant` plugin, read directly, not
proposed to change. A request becomes a proposal file under
`docs/proposals/`, whose frontmatter carries `status: proposed -> approved ->
landed` and a `files:` write set. Approval freezes the write set; a
`PreToolUse` hook (`warrant/hooks/scope-gate.sh`) then refuses edits outside
that set and refuses commits without a `Proposal: <path>` trailer, judged
against the resolved path or command string regardless of which tool
produced it. A `SessionStart` hook (`warrant/hooks/state.sh`) reads the
repository — proposal frontmatter plus `git log --grep` — and reports open
units back to a fresh session with no other memory. Nothing here is changed
by this document.

### `qa` (existing, as-is)

Described from `qa-agent-rulebook`'s `qa-cycle` plugin (see
`docs/specs/qa-cycle-state-machine.md` in that repository), read directly,
not proposed to change. Its unit is one feedback item, not the project: an
item moves `observed -> reproducing -> reproduced`, then to one of four
human-gated destinations (`handed-off`, `not-a-defect`, `wont-fix`, or back
to `reproducing`/`observed`/`parked-unreproducible`), with `handed-off ->
re-verifying -> verified-fixed` completing the loop once the human asserts a
fix landed. Human-locked transitions require a single-use verdict token
bound to both a specific item id and a specific (from, to) pair, minted only
from the user's own turn — never inferred from a file, issue, PR, comment, or
tool output. Nothing here is changed by this document.

## Part 2 — Working with the role

The user is the only channel between roles. Agents never talk to each other,
and the `feasibility` role runs in its own sandbox with only its own plugin
installed — it never reads another role's repository, exactly as
`coding-agent-rulebook` and `qa-agent-rulebook` today never read each
other's.

**Starting the role.** The user hands `feasibility` whatever its "given to
start" line in Part 1 names — the specification, deliberately without the
market argument that motivated it. A role opened without its entry
requirement met can still be opened — nothing locks the door — but it has
nothing to work from and says so; the requirement is on the work, not a gate
on entry.

**Answering a gate.** The role stops at named points (Part 3) and needs a
decision only the user can give — a go/no-go on a probe result. The role
never infers approval from the content of a file — a file saying the right
things is not consent. Whether the user approved, rejected, or
course-corrected is a semantic judgement the model makes from the
conversation, checked against the role's `transition-rules.md` table
(Part 3) for whether the resulting move is one the table allows for that
actor. This is unlike `qa-cycle`'s own mechanism, which mints a single-use
verdict token from the user's own turn (qa-agent-rulebook's
`docs/specs/qa-cycle-state-machine.md`); `feasibility` uses no such token.

**Carrying output forward.** The user moves artifacts between sandboxes by
hand — copies a specification file into the role, pastes its verdict
onward into whatever role picks up next. Nothing is automatic, nothing is
shared between repositories, and the role does not read another role's
files directly. This is the same constraint `coding-agent-rulebook` and
`qa-agent-rulebook` already satisfy toward each other today.

**Returning to a finished role.** The user may reopen the role at any time
with new input — a `verdict`-state feasibility check can be reopened against
a changed specification. Order relative to other roles is advisory: nothing
enforces what comes before or after `feasibility`; the user routes.

**The failure this arrangement has, stated plainly.** With the user as the
only router and no cross-agent communication, the thing that goes wrong is
the user losing track of which output is current — which specification is
the live one, which verdict is stale. The mitigation costs nothing and
requires no shared machinery: the role, on being opened, reports its own
current state and what its last output was based on, read from its own
repository — the same thing `warrant/hooks/state.sh` already does at
`SessionStart` for `coding` ("reads the proposal files and git, and says
where things stand. It writes nothing"). This is per-role visibility only.
There is no global view across roles, and a role that is never opened stays
silently stale — nobody is told the specification changed unless
`feasibility` is reopened. That cost is accepted deliberately: any global
view would need a shared write target, and a shared write target is exactly
what per-repository write gates (`scope-gate.sh`'s write-set freeze,
`qa-cycle`'s workspace-only persistence) exist to refuse.

## Part 3 — State machine

Mechanism applying to the `feasibility` role below. There is no
approval-token minting hook and no regex deciding intent: whether the user
approved, rejected, or course-corrected is a semantic judgement the model
makes from conversation context, not a token minted by a hook.

The role's legal transitions live in a per-repo data file
`feasibility-cycle/hooks/transition-rules.md`, pipe-delimited with columns
`from | to | actor | precondition`, where `actor` is `user` for transitions
that require the user to have said something and `agent` otherwise. A
`UserPromptSubmit` hook renders the rows matching the current state into
every prompt as a condition→allowed-transition table. If the table or the
state file cannot be read, that hook still emits a block saying so and
forbidding transitions until it is fixed — it never exits silently.

The `PreToolUse` gate decides only two things: whether a write reaches the
role's state file, judged by resolved target path rather than tool name or
literal filename (the same discipline `scope-gate.sh` applies for `coding`:
a guard that inspects only file-editing tool payloads is bypassed by the
same edit made through a shell redirect or in-place `sed`, so the gate
resolves the path regardless of which tool produced the write), and whether
the resulting transition is a row in the table. It reports "rules could not
be loaded" and "transition not in table" as distinct denials. Anything not
reaching the state file passes.

On each transition the model appends one line to the state file naming the
user utterance it read as the basis. Nothing enforces this; it exists so a
reader outside the session can see what the transition rested on.

This rulebook implements all of this itself — no shared file, no cross-repo
dependency.

A self-loop (a row whose `from` and `to` are the same state) is a legal
transition-table row like any other, gated the same way when marked
`actor: user`. It is how a repeatable, no-clean-single-precondition decision
(a timebox extension, a continuous sign-off, a disputed-finding
resolution) is recorded without minting a state the shape does not need.

**Skills.** The `feasibility` role also carries a `skills/` directory,
`feasibility-cycle/skills/<name>/SKILL.md`, one skill per artifact-producing
conversation named in Part 3 below. A skill runs a conversation with the
user and writes a named artifact to its own file path (e.g.
`feasibility-cycle/skills/spike-report/...`) — a different file from the
role's state file. **This matters because it is easy to get backwards: the
`PreToolUse` gate above binds only to the state file's resolved path. A
skill's artifact write is never gated** — the model can write, revise, or
fail to write a spike report freely; only the write that changes the
`status` field in the state file is checked against the transition table.

**Bootstrap convention.** When the role's state file does not exist, the
current state is the synthetic literal `(none)`. The role's
`transition-rules.md` carries at least one row whose `from` is `(none)`,
naming the role's legal initial state; the write that creates the state
file is allowed exactly when such a row exists for the target, and denied
otherwise as an ordinary "transition not in table" case — no separate
mechanism from the one above. The `UserPromptSubmit` injector renders
`(none)` as a normal current state and lists its rows like any other; it
emits the "rules could not be loaded" failure block only for a missing or
unparseable `transition-rules.md`, or a state file that exists but whose
state field is absent, duplicated, or unparseable — a missing state file is
not a failure. A state file that exists is checked, both by the
`UserPromptSubmit` injector and by the `PreToolUse` gate, against the role's
declared state list regardless of what value it holds — `(none)` included —
and any value outside that list, `(none)` or otherwise, is treated
identically to "unparseable," never merged with the true-absent case.
`(none)` never appears as a `to` value: nothing transitions
into it, and deleting the state file is not a transition. This rulebook uses
this same literal, implemented independently per the no-shared-file rule
above. `coding-agent-rulebook` and `qa-agent-rulebook` are untouched by this
convention.

### `feasibility`

**Carrying artifact**: the feasibility record file; state in its frontmatter
field `status`.

**States**: `idle`, `scoped`, `probing`, `verdict-provisional`, `verdict`.
`probing` covers four probes: technical, prior art, legal/regulatory,
threat model. `verdict-provisional` is a draft disposition — findings and,
where applicable, a `conditions` list — recorded but not yet accepted;
`verdict` is reserved for the state after an explicit accept.

**Transition table**:

| From | To | Fires on |
|---|---|---|
| `idle` | `scoped` | user hands the role a specification |
| `scoped` | `probing` | agent begins the four probes |
| `probing` | `probing` | **gated, self-loop** — a probe's timebox expires with no conclusive answer; user decides extend (with a new, separately-scoped timebox) vs. stop |
| `probing` | `verdict-provisional` | **gated** — all four probes resolved (pass/fail/blocked, with evidence and a reversibility tag), draft disposition written |
| `verdict-provisional` | `verdict` | **gated** — user (or a named ADR/ARB-equivalent approver) explicitly changes status from provisional to accepted in their own turn; silence does not count |
| `verdict-provisional` | `scoped` | user rejects the draft verdict and returns it with a named reason |
| `probing` | `scoped` | a probe reveals the specification itself must change before probing can continue |

**Rejection rule**: `probing -> verdict-provisional` fails unless the file
records a resolution (pass/fail/blocked, with evidence) for each of the four
probe fields — technical, prior art, legal/regulatory, threat model. Any
field still empty or marked in-progress fails the transition.
`verdict-provisional -> verdict` fails unless the model judges, from the
user's own turn, that an explicit accept was given — a draft with all
fields filled in but no such semantic acceptance does not advance.

**Refuses while in each state**: in `idle`, refuses to probe anything without
a specification. In `scoped`, refuses to render a verdict before probing
starts. In `probing`, refuses to argue from the market case — the
specification is read without whatever motivated it (Part 1) — and refuses
to silently continue a probe past its declared timebox without the user
deciding extend vs. stop. In `verdict-provisional`, refuses to advance to
`verdict` without the user's explicit accept. In `verdict`, refuses to
revise the verdict without reopening `probing` on a new probe finding.

**Open question**: whether the four probes are four independent open
sub-states (`probing/technical`, `probing/prior-art`,
`probing/legal-regulatory`, `probing/threat-model`, each independently
resolvable — a more complex state file with per-probe status fields) or a
single sequential pipeline through them. This document does not decide it;
either shape satisfies the rejection rule above, which only requires all
four resolved before `verdict`.

## Reference

Full sourcing for every claim above is in
`docs/reports/research/2026-07-25-swpd-roles/`: `product-discovery.md`,
`design-ux.md`, `engineering-architecture.md`, `qa-testing.md`,
`release-ops-sre.md`, `security-legal-compliance.md`,
`data-experimentation.md`, `lifecycle-frameworks-handoffs.md`.

Gate mechanics with published, checkable criteria — not just a named
gate but a stated rule for what makes it fail — were found in exactly four
places across this research: Cooper's Stage-Gate must-meet/should-meet split,
Google's error-budget release-freeze policy, GDPR's Article 35 DPIA
requirement, and Shape Up's betting table. The strongest-enforced gate in
industry practice found anywhere in this research is ordinary code review,
because unlike the other four it has a mechanical blocking device attached
directly to the merge action rather than a process convention around it.
