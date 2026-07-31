Every phase-2 record must carry Nygard's minimal ADR spine as its base
shape, plus one additional field this plugin's gate also checks:

1. Title — the record names the decision being made.
2. Status — one of proposed, accepted, or superseded, stated verbatim
   as a `Status:` field.
3. Context — a prose section describing the forces and constraints
   that make the decision necessary.
4. Decision — a `Decision:` field stating what was decided, mapped to
   an explicit verdict class (e.g. go, no-go, conditional).
5. Consequences — a section stating what follows from the decision,
   including a reversibility tag (one-way or two-way, or an
   equivalent phrasing) carried or updated from phase 1.
6. Risks — every Risks entry must carry a disposition of mitigated,
   accepted, or deferred; a Risks section with an undisposed entry, or
   with zero disposed entries, is incomplete.

A record that transitions to a terminal loop_state (for example
verdict or scope-approved) must have all six fields present and
complete; missing or incomplete spine fields at a terminal transition
are denied.
