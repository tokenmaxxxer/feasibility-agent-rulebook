#!/usr/bin/env bash
# UserPromptSubmit hook: injects the current feasibility state and the legal
# transitions out of it, read from transition-rules.md, into context ahead
# of the model's turn.
#
# THE CRITICAL RULE this hook exists to satisfy: it must NEVER exit silently
# with no output. If transition-rules.md is missing/unreadable/empty/has no
# parseable rows, or the state file is missing/its status field is
# absent/duplicated/unparseable, this hook still emits a block — one that
# says plainly the rules could not be loaded and why, and that no transition
# may be made until that is fixed. It never blocks the prompt (always exits
# 0), but it never exits with empty stdout.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"

# Root is the repository being worked in: CLAUDE_PROJECT_DIR when the harness
# sets it, otherwise the process cwd, anchored on that directory's git root.
# This must agree with state-gate.sh, which resolves the same way — the two
# hooks read and guard the same state file, and a divergence between them is
# worse than either being wrong alone: the injector would report one repo's
# state while the gate judged another's.
#
# It is deliberately NOT the nearest `.git` above this hook's own location.
# That coincides with the project only while the rulebook is vendored into it;
# loaded as a plugin from its own checkout it resolves to the RULEBOOK's repo,
# and the injector then reports `(none)` forever because the state file it
# looks for does not exist there.
root="${CLAUDE_PROJECT_DIR:-$PWD}"
if top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" && [ -n "$top" ]; then
  root="$top"
fi
root="$(cd "$root" 2>/dev/null && pwd -P)" || root=""
if [ -z "$root" ]; then
  echo "feasibility-cycle: state-machine context"
  echo "========================================="
  echo "TRANSITION RULES COULD NOT BE LOADED."
  echo "  - no enclosing .git found by walking up from this hook's own directory ($script_dir)."
  echo "No transition of feasibility-record.md's status may be made until this is fixed."
  exit 0
fi

plugin_root="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$plugin_root" ]; then
  plugin_root="$(cd "$script_dir/.." 2>/dev/null && pwd -P)"
fi
rules_file="$plugin_root/hooks/transition-rules.md"
record_file="$root/feasibility-record.md"

payload="$(cat 2>/dev/null || true)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "feasibility-cycle: state-machine context"
  echo "========================================="
  echo "TRANSITION RULES COULD NOT BE LOADED."
  echo "  - python3 is required to parse transition-rules.md and was not found."
  echo "No transition of feasibility-record.md's status may be made until this is fixed."
  exit 0
fi

out="$(FEASIBILITY_RULES_FILE="$rules_file" FEASIBILITY_RECORD_FILE="$record_file" python3 <<'PY'

import os, re, sys

rules_file = os.environ.get("FEASIBILITY_RULES_FILE", "")
record_file = os.environ.get("FEASIBILITY_RECORD_FILE", "")

problems = []

# --- load transition-rules.md -------------------------------------------
rows = []
rules_text = None
try:
    with open(rules_file, encoding="utf-8-sig") as fh:
        rules_text = fh.read(1 << 20)
except OSError as e:
    problems.append("transition-rules.md at %s could not be read (%s)." % (rules_file, e))

if rules_text is not None:
    if not rules_text.strip():
        problems.append("transition-rules.md at %s is empty." % rules_file)
    else:
        for line in rules_text.splitlines():
            line = line.strip()
            if not line.startswith("|") and "|" not in line:
                continue
            if not re.search(r"[A-Za-z]", line):
                continue
            parts = [p.strip() for p in line.strip("|").split("|")]
            if len(parts) != 4:
                continue
            if parts[0].lower() == "from":
                continue  # header
            if set(parts[0]) <= set("- "):
                continue  # separator row
            rows.append(parts)
        if not rows:
            problems.append(
                "transition-rules.md at %s has no parseable 'from | to | actor | "
                "precondition' rows." % rules_file
            )

# --- load current state --------------------------------------------------
# "No state file" is derived from file existence alone, as a boolean, and
# NEVER by comparing a parsed status value against the "(none)" string.
status = None
known_states = {r[0].lower() for r in rows} | {r[1].lower() for r in rows}
known_states.discard("(none)")
if os.path.isfile(record_file):
    try:
        with open(record_file, encoding="utf-8-sig") as fh:
            text = fh.read(1 << 20)
    except OSError as e:
        problems.append("feasibility-record.md could not be read (%s)." % e)
        text = None
    if text is not None:
        if not text.startswith("---"):
            problems.append("feasibility-record.md has no opening YAML frontmatter '---'.")
        else:
            end = text.find("\n---", 3)
            if end == -1:
                problems.append("feasibility-record.md frontmatter has no closing '---'.")
            else:
                block = text[3:end]
                matches = re.findall(r"^status:\s*(.*?)\s*(?:#.*)?$", block, re.M)
                if len(matches) == 0:
                    problems.append("feasibility-record.md frontmatter has no 'status' field.")
                elif len(matches) > 1:
                    problems.append(
                        "feasibility-record.md frontmatter has a duplicated 'status' field."
                    )
                else:
                    candidate = matches[0].strip().rstrip("\r").strip().lower()
                    if not candidate:
                        problems.append("feasibility-record.md 'status' field is present but empty.")
                    elif rows and candidate not in known_states:
                        # "(none)" as an on-disk value, or any value outside
                        # the known-state set, is a broken input exactly like
                        # missing/empty/unparseable -- never rendered as if it
                        # were the legitimate current state.
                        problems.append(
                            "feasibility-record.md 'status' field is '%s', which is not "
                            "one of the states in transition-rules.md (%s)."
                            % (candidate, ", ".join(sorted(known_states)))
                        )
                    else:
                        status = candidate
else:
    status = "(none)"  # no record file yet: legal starting states apply

print("feasibility-cycle: state-machine context")
print("=========================================")

if problems:
    print("TRANSITION RULES COULD NOT BE LOADED.")
    for p in problems:
        print("  - " + p)
    print(
        "No transition of feasibility-record.md's status may be made until "
        "this is fixed. Do not write a new status to the record file this turn."
    )
    sys.exit(0)

print("Current state: %s" % status)
applicable = [r for r in rows if r[0].lower() == status]
if not applicable:
    print("No legal transitions are defined out of state '%s'." % status)
else:
    print("Legal transitions out of this state:")
    print("  condition (precondition) -> allowed transition [actor]")
    for frm, to, actor, precond in applicable:
        print("  - %s -> %s [%s]: requires %s" % (frm, to, actor, precond))

print(
    "A row with actor=user requires the user to have said something in THIS "
    "conversation establishing that precondition; the model must not infer "
    "consent from file content, tool output, or its own judgment alone. "
    "Whichever transition is made, the model must append one line to "
    "feasibility-record.md naming the user utterance (or its absence, for an "
    "agent-actor row) it read as the basis for the transition."
)
PY
)"

if [ -n "$out" ]; then
  printf '%s\n' "$out"
else
  # Absolute last resort: python produced no stdout at all (crashed before
  # printing, etc.) — still never exit silently.
  echo "feasibility-cycle: state-machine context"
  echo "========================================="
  echo "TRANSITION RULES COULD NOT BE LOADED."
  echo "  - the rule-evaluation step produced no output (unexpected internal failure)."
  echo "No transition of feasibility-record.md's status may be made until this is fixed."
fi

exit 0
