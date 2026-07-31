# nygard-adr-spine

Enforces Nygard's minimal ADR spine — Title, Status (proposed | accepted
| superseded), Context, Decision (with a stated verdict class), and
Consequences (with a reversibility tag) — plus a sixth field this
plugin's gate also checks: Risks, where every entry must carry a
disposition of mitigated, accepted, or deferred.

## Why

Source: issue-30's adopted methodology. The spine is the base shape a
phase-2 record (`docs/issue-<n>/reports/technical-feasibility.md`) must
carry before it can be treated as complete, independent of whichever
role or process produced it. A record missing Context, an undisposed
verdict, or a Risks entry with no disposition is not a finished ADR —
it is a draft, and the gate treats it that way, especially once the
record transitions to a terminal loop_state (e.g. `verdict` or
`scope-approved`).

## How it composes

This plugin is self-contained. It does not edit, splice into, or
depend on any other plugin's files (in particular, it does not touch
`feasibility/hooks/directive.sh`). Composition is via this plugin's own
independent `hooks.json`:

- `SessionStart` runs `cat "${CLAUDE_PLUGIN_ROOT}/directive-fragment.md"`,
  which is how the spine's directive text reaches the session.
- `PreToolUse` (matched on `Write|Edit|MultiEdit`) runs
  `hooks/spine-gate.sh`, which checks the six spine fields on any write
  to the phase-2 write surface
  (`docs/issue-<n>/reports/technical-feasibility.md`) and is a
  pass-through (`exit 0`) for every other tool or path.

Claude Code fires every enabled plugin's `hooks.json` independently, so
no wiring changes are needed in `feasibility` or any sibling plugin for
this gate and directive fragment to take effect.

## Kill switch

Set `NYGARD_ADR_SPINE_GATE_OFF=1` (also accepts `true`, `yes`, `on`) to
disable the gate entirely; it then exits 0 unconditionally, regardless
of content.

## Gate limits (documented, not hidden)

`hooks/spine-gate.sh` uses best-effort heuristics — markdown heading /
bold-label text matching and simple `Field:` regexes — not a formal
grammar. It only judges a Write carrying the record's full `content`
(an Edit/MultiEdit diff fragment cannot be judged in isolation, so it
is denied and the caller is asked to rewrite the whole file with
Write). It is fail-closed: malformed/missing payload, an undetermined
project root, or any internal error denies rather than silently
allowing.

## Tests

```
bash nygard-adr-spine/tests/run-gate-tests.sh
```

Runs the gate as a real subprocess against constructed payloads in
disposable git-initialized tmpdirs; prints pass/fail counts and exits
nonzero on any failure.
