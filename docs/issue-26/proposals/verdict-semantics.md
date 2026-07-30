## Request

Pin verdict-field semantics in this rulebook: selection criteria mapping
condition classes to the `go|no-go|conditional` enum values; the field
carries the bare standard value only, with all condition narrative in
the record body; name the `verdict_provisional` convention explicitly.
(Issue #26 — divergent past usage: controller #89 wrote `go` for a real
resolvable prerequisite, controller #91 wrote `conditional` for the same
class, console #1 wrote `conditional` for a mere scope constraint.)

## Constraints

- Prose-only change to this rulebook's role directive and README — no
  new gate logic (enum validation is tracked upstream at
  on-the-record#100, out of scope here).
- Must not collide with the existing `verdict-provisional` loop_state
  value already documented — the new `verdict_provisional` convention is
  a distinct, body-level marker on a `go` verdict and must be named as
  such.
- Selection criteria must be stated as a mapping other roles/sessions
  can apply mechanically: condition class -> enum value.

## What will be done

Edit `feasibility/hooks/directive.sh` (PROPOSAL and EXECUTION JUDGMENT
sections) and `README.md` ("What `feasibility` decides" and "Record
vocabulary" sections) to add:

1. Selection criteria, stated as a mapping:
   - a blocking condition that cannot proceed until resolved
     **externally** (outside this repo's own work) -> `verdict:
     conditional`, with the blocking condition in the `conditions:`
     list.
   - a prerequisite that is two-way (reversible) and resolvable
     **within the repo's own work** -> `verdict: go`, recording the
     prerequisite via the `verdict_provisional` convention (named
     explicitly, credited to controller #89 precedent) in the record
     body — never in the `conditions:` list, since the verdict itself
     is `go`.
   - a scope constraint only (no blocking or resolvable prerequisite,
     just a boundary on what was evaluated) -> `verdict: go`, with the
     constraint stated in the record body.
2. The bare-value rule: the `verdict` field itself carries only the
   standard enum value (`go`, `no-go`, or `conditional`) — every
   condition, prerequisite, or constraint narrative lives in the record
   body, never appended to or encoded in the field value.
3. An explicit note distinguishing the new `verdict_provisional`
   body-level convention (marks a `go` verdict's resolvable prerequisite)
   from the existing `verdict-provisional` loop_state value (marks a
   draft disposition before the human's PR-Approve act) — same words,
   different concepts, both kept.

## Out of scope

- Write-time enum validation / a new gate enforcing the bare-value rule
  (on-the-record#100, upstream).
- Renaming or otherwise changing the existing `verdict-provisional`
  loop_state value.
- Any change to `feasibility/hooks/record-fields-gate.sh` or other gate
  scripts.
- Retroactively correcting controller #89/#91 or console #1's existing
  records (external repos, not this rulebook).

## How it'll be verified

- `feasibility/hooks/directive.sh` PROPOSAL section states the
  three-way selection criteria (blocking-external ->
  `conditional`; two-way in-repo-resolvable -> `go` +
  `verdict_provisional`; scope-constraint-only -> `go` + body note) and
  the bare-value-only field rule.
- `README.md` "Record vocabulary" section names the `verdict_provisional`
  convention explicitly and distinguishes it from `verdict-provisional`.
- `grep -n "verdict_provisional" feasibility/hooks/directive.sh README.md`
  finds the convention named in both files.
