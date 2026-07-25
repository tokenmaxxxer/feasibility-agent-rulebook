#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|NotebookEdit|Bash): enforces the feasibility
# role's one gated transition, `probing -> verdict`, against
# `feasibility-record.md` at the project root.
#
# Unlike coding-agent-rulebook/warrant's scope-gate.sh, this gate FAILS
# CLOSED: unreadable payload, missing python3, unparseable state file,
# missing/mismatched token, or any other malformed condition all DENY the
# write. It never falls through to allow just because its own input looked
# strange — a gate that can be blinded into allowing is not a gate.
#
# The rule is evaluated against the TARGET PATH being written, never against
# which tool performs the write: a Bash redirect, `tee`, or in-place
# `sed`/`perl`/`ruby` edit aimed at feasibility-record.md is judged exactly
# like a Write/Edit tool call at the same path. Because a Bash write's
# resulting content cannot be inspected before the command runs, any Bash
# command that would write to the record file is denied outright — only
# Write/Edit/NotebookEdit calls (whose new content this gate can read) may
# ever pass the content check below.
#
# Kill switch: export FEASIBILITY_GATE_OFF=1 (still a DENY-by-default gate
# in every other respect; this switch only turns the whole gate off).
set -euo pipefail

case "${FEASIBILITY_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

deny() {
  echo "feasibility-cycle: DENIED — $1" >&2
  exit 2
}

command -v python3 >/dev/null 2>&1 || deny "python3 is required to evaluate this gate and was not found; failing closed."

root="${CLAUDE_PROJECT_DIR:-}"
[ -n "$root" ] || root="$(pwd)"
root="$(cd "$root" 2>/dev/null && pwd -P)" || deny "could not resolve the project root."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "no tool-input payload was received."

FEASIBILITY_PAYLOAD="$payload" FEASIBILITY_ROOT="$root" python3 <<'PY'
import json, os, posixpath, re, sys

def deny(msg):
    print("feasibility-cycle: DENIED - %s" % msg, file=sys.stderr)
    sys.exit(2)

def allow():
    sys.exit(0)

try:
    event = json.loads(os.environ.get("FEASIBILITY_PAYLOAD", ""))
except ValueError:
    deny("tool-input payload is not valid JSON.")
if not isinstance(event, dict):
    deny("tool-input payload is not a JSON object.")

tool = event.get("tool_name")
tool_input = event.get("tool_input")
if not isinstance(tool, str) or not tool:
    deny("tool_name missing from payload.")
if not isinstance(tool_input, dict):
    deny("tool_input missing or malformed in payload.")

root = os.environ["FEASIBILITY_ROOT"]
record_name = "feasibility-record.md"
record_abs = posixpath.normpath(posixpath.join(root, record_name))

# --- resolve the TARGET PATH this call would write, regardless of tool ---
target_path = None
new_content = None  # only known for Write; Edit/NotebookEdit content is not
                     # fully reconstructable here, so they are treated like
                     # Bash below: path-matched but content-blind -> denied
                     # unless the record is untouched by this call.

if tool == "Bash":
    command = tool_input.get("command")
    if not isinstance(command, str) or not command.strip():
        deny("Bash tool_input.command missing or empty.")
    # Does this command's text reference the record file at all, via a
    # write-shaped construct (redirect, tee, in-place sed/perl/ruby, cp, mv)?
    write_shapes = re.compile(
        r'>>?\s*[^|&;]*\bfeasibility-record\.md\b'
        r'|\btee\b[^|;]*\bfeasibility-record\.md\b'
        r'|\b(sed|perl|ruby)\b[^|;]*-i[a-zA-Z0-9]*\b[^|;]*\bfeasibility-record\.md\b'
        r'|\b(cp|mv)\b[^|;]*\bfeasibility-record\.md\b',
        re.I,
    )
    if write_shapes.search(command):
        deny(
            "a Bash command targets feasibility-record.md with a write-shaped "
            "construct (redirect/tee/in-place edit/cp/mv). This gate cannot read "
            "the resulting content before the command runs, so it refuses the "
            "write outright. Use the Write or Edit tool on this file instead."
        )
    allow()

if tool in ("Write", "Edit", "NotebookEdit"):
    path = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not isinstance(path, str) or not path:
        deny("%s tool_input carries no file_path." % tool)
    normalized = path.replace("\\", "/")
    absolute = posixpath.normpath(
        normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized)
    )
    resolved = posixpath.normpath(os.path.realpath(absolute).replace("\\", "/"))
    if resolved != record_abs:
        allow()  # not our file; nothing to gate
    target_path = resolved

    if tool == "Write":
        content = tool_input.get("content")
        if not isinstance(content, str):
            deny("Write tool_input carries no readable content for feasibility-record.md.")
        new_content = content
    else:
        # Edit / NotebookEdit: the fully-materialized new content is not
        # available to this hook. Since the record file's transitions can
        # only be trusted from readable, complete content, any Edit aimed at
        # this specific file is denied — same posture as the Bash case above.
        deny(
            "an Edit/NotebookEdit call targets feasibility-record.md. This gate "
            "only evaluates complete, readable content (a Write call); partial "
            "edits to the state file are refused so a transition can never be "
            "assembled from an unreadable diff. Rewrite the whole file with Write."
        )
else:
    allow()  # tool this gate does not recognize touches nothing it governs

if target_path is None or new_content is None:
    deny("internal: no content resolved for a call this gate should have judged.")

# --- parse the proposed new content's frontmatter -----------------------
if not new_content.startswith("---"):
    deny("feasibility-record.md must open with YAML frontmatter (---).")
end = new_content.find("\n---", 3)
if end == -1:
    deny("feasibility-record.md frontmatter has no closing '---'.")
block = new_content[3:end]

def field(name):
    m = re.search(r"^" + re.escape(name) + r":\s*(.*?)\s*(?:#.*)?$", block, re.M)
    return m.group(1).strip() if m else None

new_status = field("status")
if new_status is None:
    deny("frontmatter has no 'status' field.")
new_status = new_status.lower()

VALID_STATES = ("idle", "scoped", "probing", "verdict")
if new_status not in VALID_STATES:
    deny("status '%s' is not one of %s." % (new_status, ", ".join(VALID_STATES)))

# Determine current on-disk status to know which transition is proposed.
old_status = None
if os.path.exists(record_abs):
    try:
        with open(record_abs, encoding="utf-8-sig") as fh:
            old_text = fh.read(1 << 20)
    except OSError:
        deny("existing feasibility-record.md could not be read to determine the current state.")
    if old_text.startswith("---"):
        oend = old_text.find("\n---", 3)
        if oend != -1:
            om = re.search(r"^status:\s*([A-Za-z]+)\s*(?:#.*)?$", old_text[3:oend], re.M)
            old_status = om.group(1).lower() if om else None
    if old_status is None:
        deny("existing feasibility-record.md frontmatter is unparseable; refusing to layer a new state on top of unknown state.")
else:
    old_status = None  # first-ever write; only idle/scoped are legitimate starting points

# idle -> scoped requires only the specification (no probe/market fields
# enforced by this gate beyond market_argument_supplied being explicitly
# recorded as false).
if old_status is None:
    if new_status not in ("idle", "scoped"):
        deny("first write to feasibility-record.md must set status to 'idle' or 'scoped', not '%s'." % new_status)
    if new_status == "scoped":
        mkt = field("market_argument_supplied")
        if mkt is None or mkt.strip().lower() != "false":
            deny(
                "entry to 'scoped' requires the frontmatter field "
                "'market_argument_supplied: false', recording that the market "
                "argument was deliberately withheld from this role."
            )
    allow()

if old_status == new_status:
    allow()  # rewriting probe fields etc. within the same state is fine

# --- the one gated transition: probing -> verdict ------------------------
if old_status == "probing" and new_status == "verdict":
    probe_names = ("technical", "prior_art", "legal_regulatory", "threat_model")
    unresolved = []
    for n in probe_names:
        v = field(n)
        if v is None or not v:
            unresolved.append(n)
            continue
        low = v.lower()
        if not (low.startswith("pass") or low.startswith("fail") or low.startswith("blocked")):
            unresolved.append(n)
    if unresolved:
        deny(
            "probing -> verdict refused: probe field(s) not resolved: %s. "
            "Each of technical/prior_art/legal_regulatory/threat_model must be "
            "'pass: ...', 'fail: ...', or 'blocked: ...'." % ", ".join(unresolved)
        )
    tokens_dir = os.path.join(root, ".feasibility", "tokens")
    token_file = os.path.join(tokens_dir, "verdict.token")
    if not os.path.isfile(token_file):
        deny(
            "probing -> verdict refused: no approval token at "
            ".feasibility/tokens/verdict.token. This transition requires an "
            "unambiguous approval from the user's own turn (minted by "
            "capture-approval.sh); resolved probe fields alone are not consent."
        )
    try:
        with open(token_file, encoding="utf-8") as fh:
            token_text = fh.read(4096)
    except OSError:
        deny("approval token file exists but could not be read.")
    if "transition: probing -> verdict" not in token_text:
        deny("approval token does not match the 'probing -> verdict' transition.")
    # Single-use: consume it now so a stale token can't authorize a later re-entry.
    try:
        os.remove(token_file)
    except OSError:
        deny("approval token could not be consumed (removed); refusing rather than risk reuse.")
    allow()

# probing -> scoped: ungated per the transition table (a probe reveals the
# specification itself must change).
if old_status == "probing" and new_status == "scoped":
    allow()

# scoped -> probing: ungated (agent begins the four probes).
if old_status == "scoped" and new_status == "probing":
    allow()

deny("transition '%s -> %s' is not permitted by the feasibility state machine." % (old_status, new_status))
PY
exit $?
