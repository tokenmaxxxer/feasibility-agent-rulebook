#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|NotebookEdit|Bash): enforces the feasibility
# role's state machine against its two v2-contract-owned per-subject record
# paths (docs/reports/records/<subject>/feasibility.md and
# .../spikes/<spike-slug>.md), using `transition-rules.md` as the single
# source of legal transitions. This gate only ever fires on write-shaped
# tool calls (Write|Edit|NotebookEdit|Bash, per this hook's own
# registration) — reads are unconditionally allowed per contract section 4
# ("READ is unconditionally broad"), and this file contains no read-path
# logic to relax.
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# The state file's path is anchored to the repository root, found by walking
# UP from this hook script's own on-disk location to the nearest enclosing
# `.git`. The process working directory (CLAUDE_PROJECT_DIR/$PWD) is never
# consulted for this: a cwd outside the repo must not cause the state file
# to be resolved anywhere but inside this repo.
root=""
dir="$script_dir"
while [ -n "$dir" ]; do
  if [ -e "$dir/.git" ]; then
    root="$dir"
    break
  fi
  parent="$(dirname "$dir")"
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done
[ -n "$root" ] || deny "RULES COULD NOT BE LOADED: could not find an enclosing .git directory to anchor the project root (walked up from $script_dir)."

# --- collaboration contract presence check ---------------------------------
# The gate resolves exactly one root: this repo's own git root ($root,
# already resolved above). It reads docs/specs/role-handoff-contract.md
# inside that root only — no parent/sibling-repo walk, no SHA comparison
# against another repo's history. If the contract file is absent, handoff-
# protocol actions are refused with an honest message rather than silently
# passing.
contract_rel="docs/specs/role-handoff-contract.md"
if [ ! -f "$root/$contract_rel" ]; then
  deny "this repo has no collaboration contract yet ($contract_rel not found under $root)."
fi

# transition-rules.md is resolved REPO-LOCALLY, anchored to this hook
# script's own on-disk directory (which lives inside $root, already
# resolved above by walking up to the nearest .git) — never via
# CLAUDE_PLUGIN_ROOT or any plugin-install-layout assumption. A guarded
# repo that vendors/checks out this rulebook at its own repo root must
# find transition-rules.md sitting next to state-gate.sh regardless of
# whether CLAUDE_PLUGIN_ROOT is set, unset, or points somewhere unrelated.
rules_file="$script_dir/transition-rules.md"

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

# v2 blackboard contract (docs/specs/role-handoff-contract.md, section 11):
# feasibility no longer owns one project-root file. It owns two per-subject
# path shapes under docs/reports/records/<subject>/. record_name/record_abs
# (a single hardcoded root-level filename) is replaced by a path-shape
# match; everything downstream that used to compare against record_abs now
# calls is_owned_path(resolved) instead.
OWNED_PATH_RE = re.compile(
    r"^docs/reports/records/[^/]+/(feasibility\.md|spikes/[^/]+\.md)$"
)


def is_owned_path(resolved_abs):
    try:
        rel = posixpath.relpath(resolved_abs, root)
    except ValueError:
        return False
    rel = rel.replace("\\", "/")
    return bool(OWNED_PATH_RE.match(rel))

# Single source of truth for which tools this gate recognizes as capable of
# writing feasibility-record.md — used by both the "does this reach the
# state file" dispatch and the final dispatch fallback, so the two cannot
# drift apart the way Edit/MultiEdit did. A tool name outside this set that
# nonetheless reaches this script is a DENY, not a pass-through allow.
RECOGNIZED_WRITE_TOOLS = ("Write", "Edit", "MultiEdit", "NotebookEdit")

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
            if "/" in t or t.endswith(".md"):
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
            if is_owned_path(resolved):
                deny(
                    "a Bash command targets a feasibility-owned record path "
                    "(docs/reports/records/<subject>/feasibility.md or "
                    ".../spikes/<spike-slug>.md) with a write-shaped construct "
                    "(redirect/tee/cp/mv/in-place edit/dd/install). This gate "
                    "cannot read the resulting content before the command "
                    "runs, so it refuses the write outright. Use the Write "
                    "tool on this file instead."
                )
    allow()  # does not reach the state file: allowed without comment

if tool in RECOGNIZED_WRITE_TOOLS:
    path = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not isinstance(path, str) or not path:
        deny("RULES COULD NOT BE LOADED: %s tool_input carries no file_path." % tool)
    normalized = path.replace("\\", "/")
    absolute = posixpath.normpath(
        normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized)
    )
    resolved = posixpath.normpath(os.path.realpath(absolute).replace("\\", "/"))
    if not is_owned_path(resolved):
        allow()  # not a feasibility-owned record path; nothing to gate
    target_path = resolved

    if tool == "Write":
        content = tool_input.get("content")
        if not isinstance(content, str):
            deny("RULES COULD NOT BE LOADED: Write tool_input carries no readable content for the feasibility record.")
        new_content = content
    else:
        deny(
            "an Edit/MultiEdit/NotebookEdit call targets a feasibility-owned record "
            "path. This gate only evaluates complete, readable content (a Write "
            "call); partial edits to the record are refused so a transition can "
            "never be assembled from an unreadable diff. Rewrite the whole file "
            "with Write."
        )
else:
    # Bash already returned above (via allow() or deny()); anything else
    # reaching here is a tool name outside RECOGNIZED_WRITE_TOOLS.
    deny(
        "an unrecognized tool (%r) reached this gate. This gate's recognized-write-tool "
        "list is %r (plus Bash, handled separately); a tool name outside that set is "
        "treated as a denial, not a pass — unknown input fails closed rather than being "
        "assumed to be a read." % (tool, RECOGNIZED_WRITE_TOOLS)
    )

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
new_status = new_status.strip().rstrip("\r").strip().lower()

known_states = {r[0].lower() for r in rows} | {r[1].lower() for r in rows}
known_states.discard("(none)")
if new_status not in known_states:
    deny("RULES COULD NOT BE LOADED: status '%s' is not one of the states in transition-rules.md (%s)." % (new_status, ", ".join(sorted(known_states))))

# Determine current on-disk status. "No state file" is derived from file
# existence alone, as a boolean, and NEVER by comparing a parsed status
# value against the "(none)" string. Only a genuinely absent file yields the
# synthetic "(none)" old status used for bootstrap-row matching.
file_exists = os.path.exists(target_path)
if not file_exists:
    old_status = "(none)"
else:
    try:
        with open(target_path, encoding="utf-8-sig") as fh:
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
    # Strip trailing whitespace/CRLF before the membership check; a value
    # that is only whitespace after stripping counts as empty.
    old_status = old_status.strip().rstrip("\r").strip().lower()
    if not old_status:
        deny("RULES COULD NOT BE LOADED: existing feasibility-record.md status field is empty (whitespace only); refusing to layer a new state on top of an unknown state.")
    # An EXISTING state file's value must be a member of the known-state
    # set. "(none)" as a value, or any value outside the set, is the same
    # broken-input case as missing/empty/unparseable -- never treated as if
    # the file were absent, and never routed to the "not in the table"
    # denial (the table is not what failed here).
    if old_status not in known_states:
        deny(
            "RULES COULD NOT BE LOADED: existing feasibility-record.md status "
            "'%s' is not one of the states in transition-rules.md (%s); "
            "refusing to layer a new state on top of an unrecognized state."
            % (old_status, ", ".join(sorted(known_states)))
        )

if (old_status, new_status) not in legal:
    deny(
        "transition '%s -> %s' is not present as a row in transition-rules.md."
        % (old_status, new_status)
    )

# --- content precondition preserved for the one content-checked row ------
# Gated at probing -> verdict-provisional (not probing -> verdict): the
# four-probe-content requirement moved to the new intermediate state per
# the revised state set (verdict-provisional is the draft disposition;
# verdict is reserved for after an explicit user accept, which carries no
# content precondition of its own beyond the actor:user judgment call).
if old_status == "probing" and new_status == "verdict-provisional":
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
            "probing -> verdict-provisional refused: probe field(s) not resolved: %s. "
            "Each of technical/prior_art/legal_regulatory/threat_model must be "
            "'pass: ...', 'fail: ...', or 'blocked: ...' (precondition from "
            "transition-rules.md)." % ", ".join(unresolved)
        )

allow()
PY
exit $?
