#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|NotebookEdit|Bash): enforces the feasibility
# role's state machine against `feasibility-record.md` at the project root,
# using `transition-rules.md` as the single source of legal transitions.
#
# The gate answers exactly two questions:
#   1. Does this write reach the state file, judged by RESOLVED TARGET PATH
#      — never by a literal filename in the command string, never by tool
#      name? A Bash write whose target cannot be determined statically
#      (variable, expansion, command substitution, glob, eval, heredoc into
#      a computed name) is treated as reaching the state file.
#   2. If it reaches the state file: is the resulting transition present as
#      a row in transition-rules.md? Present -> allow (subject to the
#      content precondition below). Absent -> deny.
# Everything that does not reach the state file is allowed through without
# comment.
#
# Two distinct denials, never conflated:
#   - "RULES COULD NOT BE LOADED" (transition-rules.md or the current/
#     proposed state could not be determined, or the hook input itself was
#     malformed)
#   - "this transition is not in the table" (rules loaded fine; the specific
#     from -> to pair just isn't a row)
# Malformed hook input (unparseable JSON, missing fields) denies with the
# RULES COULD NOT BE LOADED message — never a silent exit 0.
#
# Kill switch: export FEASIBILITY_GATE_OFF=1 (still fails closed in every
# other respect; only turns the whole gate off).
set -euo pipefail

case "${FEASIBILITY_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

deny() {
  echo "feasibility-cycle: DENIED — $1" >&2
  exit 2
}

command -v python3 >/dev/null 2>&1 || deny "RULES COULD NOT BE LOADED: python3 is required to evaluate this gate and was not found."

root="${CLAUDE_PROJECT_DIR:-}"
[ -n "$root" ] || root="$(pwd)"
root="$(cd "$root" 2>/dev/null && pwd -P)" || deny "RULES COULD NOT BE LOADED: could not resolve the project root."

plugin_root="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$plugin_root" ]; then
  plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P)"
fi
rules_file="$plugin_root/hooks/transition-rules.md"

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "RULES COULD NOT BE LOADED: no tool-input payload was received."

FEASIBILITY_PAYLOAD="$payload" FEASIBILITY_ROOT="$root" FEASIBILITY_RULES_FILE="$rules_file" python3 <<'PY'
import json, os, posixpath, re, shlex, sys

def deny(msg):
    print("feasibility-cycle: DENIED - %s" % msg, file=sys.stderr)
    sys.exit(2)

def allow():
    sys.exit(0)

try:
    event = json.loads(os.environ.get("FEASIBILITY_PAYLOAD", ""))
except ValueError:
    deny("RULES COULD NOT BE LOADED: tool-input payload is not valid JSON.")
if not isinstance(event, dict):
    deny("RULES COULD NOT BE LOADED: tool-input payload is not a JSON object.")

tool = event.get("tool_name")
tool_input = event.get("tool_input")
if not isinstance(tool, str) or not tool:
    deny("RULES COULD NOT BE LOADED: tool_name missing from payload.")
if not isinstance(tool_input, dict):
    deny("RULES COULD NOT BE LOADED: tool_input missing or malformed in payload.")

root = os.environ["FEASIBILITY_ROOT"]
record_name = "feasibility-record.md"
record_abs = posixpath.normpath(posixpath.join(root, record_name))

# --- question 1: does this write reach the state file? -------------------
target_path = None
new_content = None

if tool == "Bash":
    command = tool_input.get("command")
    if not isinstance(command, str) or not command.strip():
        deny("RULES COULD NOT BE LOADED: Bash tool_input.command missing or empty.")

    dynamic_construct = re.compile(
        r'\$\{?\w|\$\(|`|\*|\?|~|\beval\b|\bsource\b|\.\s+/|<\(|>\(|<<'
    )
    write_shape = re.compile(
        r'>>?(?!\()'
        r'|\btee\b'
        r'|\b(cp|mv|dd|install)\b'
        r'|\b(sed|perl|ruby)\b[^|;\n]*-i[a-zA-Z0-9]*\b',
        re.I,
    )

    could_write = write_shape.search(command) is not None
    is_dynamic = dynamic_construct.search(command) is not None

    if could_write and is_dynamic:
        # Target not statically determinable AND write-shaped: treat as
        # reaching the state file per contract. Content can't be inspected,
        # so no transition can ever be proven legal -> deny. A dynamic
        # construct with NO write-shape is NOT denied here (handled by the
        # could_write check below) — that would be the global-deny
        # regression this gate must avoid.
        deny(
            "a Bash command could write a file and its write target is not "
            "statically determinable (shell variable, command/process "
            "substitution, indirection, glob, eval, source, or heredoc into a "
            "computed name). Treating this as reaching feasibility-record.md "
            "per policy: this gate cannot prove the resulting transition is in "
            "transition-rules.md, so it refuses. Use the Write tool on a "
            "literal path instead."
        )

    if could_write:
        try:
            tokens = shlex.split(command, comments=False)
        except ValueError:
            deny(
                "a Bash command could write a file but its argument text "
                "could not be parsed (unbalanced quoting); treating this as "
                "reaching feasibility-record.md and refusing."
            )
        candidates = []
        for tok in tokens:
            t = tok
            for op in (">>", ">"):
                if t.startswith(op):
                    t = t[len(op):]
            if t.startswith("-"):
                continue
            if "/" in t or t.endswith(".md") or t == record_name:
                candidates.append(t)
        for cand in candidates:
            normalized = cand.replace("\\", "/")
            absolute = posixpath.normpath(
                normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized)
            )
            try:
                resolved = posixpath.normpath(os.path.realpath(absolute).replace("\\", "/"))
            except OSError:
                resolved = absolute
            if resolved == record_abs:
                deny(
                    "a Bash command targets feasibility-record.md (resolved "
                    "path match) with a write-shaped construct (redirect/tee/"
                    "cp/mv/in-place edit/dd/install). This gate cannot read the "
                    "resulting content before the command runs, so it refuses "
                    "the write outright. Use the Write tool on this file instead."
                )
    allow()  # does not reach the state file: allowed without comment

if tool in ("Write", "Edit", "NotebookEdit"):
    path = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not isinstance(path, str) or not path:
        deny("RULES COULD NOT BE LOADED: %s tool_input carries no file_path." % tool)
    normalized = path.replace("\\", "/")
    absolute = posixpath.normpath(
        normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized)
    )
    resolved = posixpath.normpath(os.path.realpath(absolute).replace("\\", "/"))
    if resolved != record_abs:
        allow()  # not the state file; nothing to gate
    target_path = resolved

    if tool == "Write":
        content = tool_input.get("content")
        if not isinstance(content, str):
            deny("RULES COULD NOT BE LOADED: Write tool_input carries no readable content for feasibility-record.md.")
        new_content = content
    else:
        deny(
            "an Edit/NotebookEdit call targets feasibility-record.md. This gate "
            "only evaluates complete, readable content (a Write call); partial "
            "edits to the state file are refused so a transition can never be "
            "assembled from an unreadable diff. Rewrite the whole file with Write."
        )
else:
    allow()  # tool this gate does not recognize touches nothing it governs

if target_path is None or new_content is None:
    deny("RULES COULD NOT BE LOADED: internal — no content resolved for a call this gate should have judged.")

# --- load transition-rules.md --------------------------------------------
rules_file = os.environ.get("FEASIBILITY_RULES_FILE", "")
try:
    with open(rules_file, encoding="utf-8-sig") as fh:
        rules_text = fh.read(1 << 20)
except OSError as e:
    deny("RULES COULD NOT BE LOADED: transition-rules.md at %s could not be read (%s)." % (rules_file, e))

if not rules_text.strip():
    deny("RULES COULD NOT BE LOADED: transition-rules.md at %s is empty." % rules_file)

rows = []
for line in rules_text.splitlines():
    line = line.strip()
    if "|" not in line or not re.search(r"[A-Za-z]", line):
        continue
    parts = [p.strip() for p in line.strip("|").split("|")]
    if len(parts) != 4:
        continue
    if parts[0].lower() == "from":
        continue
    if set(parts[0]) <= set("- "):
        continue
    rows.append(tuple(parts))

if not rows:
    deny(
        "RULES COULD NOT BE LOADED: transition-rules.md at %s has no parseable "
        "'from | to | actor | precondition' rows." % rules_file
    )

legal = {(r[0].lower(), r[1].lower()) for r in rows}

# --- parse the proposed new content's frontmatter -------------------------
if not new_content.startswith("---"):
    deny("RULES COULD NOT BE LOADED: feasibility-record.md must open with YAML frontmatter (---).")
end = new_content.find("\n---", 3)
if end == -1:
    deny("RULES COULD NOT BE LOADED: feasibility-record.md frontmatter has no closing '---'.")
block = new_content[3:end]

def field(text_block, name):
    matches = re.findall(r"^" + re.escape(name) + r":\s*(.*?)\s*(?:#.*)?$", text_block, re.M)
    if len(matches) != 1:
        return None
    return matches[0].strip()

new_status = field(block, "status")
if not new_status:
    deny("RULES COULD NOT BE LOADED: proposed frontmatter has no (single, non-empty) 'status' field.")
new_status = new_status.lower()

known_states = {r[0].lower() for r in rows} | {r[1].lower() for r in rows}
known_states.discard("none")
if new_status not in known_states:
    deny("RULES COULD NOT BE LOADED: status '%s' is not one of the states in transition-rules.md (%s)." % (new_status, ", ".join(sorted(known_states))))

# Determine current on-disk status.
old_status = "none"
if os.path.exists(record_abs):
    try:
        with open(record_abs, encoding="utf-8-sig") as fh:
            old_text = fh.read(1 << 20)
    except OSError:
        deny("RULES COULD NOT BE LOADED: existing feasibility-record.md could not be read to determine the current state.")
    if not old_text.startswith("---"):
        deny("RULES COULD NOT BE LOADED: existing feasibility-record.md has no opening frontmatter '---'.")
    oend = old_text.find("\n---", 3)
    if oend == -1:
        deny("RULES COULD NOT BE LOADED: existing feasibility-record.md frontmatter has no closing '---'.")
    old_status = field(old_text[3:oend], "status")
    if not old_status:
        deny("RULES COULD NOT BE LOADED: existing feasibility-record.md status field is missing, duplicated, or empty; refusing to layer a new state on top of an unknown state.")
    old_status = old_status.lower()

if old_status == new_status:
    allow()  # rewriting fields within the same state is not a transition

if (old_status, new_status) not in legal:
    deny(
        "transition '%s -> %s' is not present as a row in transition-rules.md."
        % (old_status, new_status)
    )

# --- content precondition preserved for the one content-checked row ------
if old_status == "probing" and new_status == "verdict":
    probe_names = ("technical", "prior_art", "legal_regulatory", "threat_model")
    unresolved = []
    for n in probe_names:
        v = field(block, n)
        if not v:
            unresolved.append(n)
            continue
        low = v.lower()
        if not (low.startswith("pass") or low.startswith("fail") or low.startswith("blocked")):
            unresolved.append(n)
    if unresolved:
        deny(
            "probing -> verdict refused: probe field(s) not resolved: %s. "
            "Each of technical/prior_art/legal_regulatory/threat_model must be "
            "'pass: ...', 'fail: ...', or 'blocked: ...' (precondition from "
            "transition-rules.md)." % ", ".join(unresolved)
        )

allow()
PY
exit $?
