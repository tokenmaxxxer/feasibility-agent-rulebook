#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook (Write|Edit|MultiEdit): Nygard's minimal ADR spine
# (Title/Status/Context/Decision/Consequences) plus a Risks-disposition
# field, checked on the phase-2 record's own write surface only.
#
# This plugin composes purely via its OWN independent hooks.json
# (SessionStart announces directive-fragment.md, PreToolUse runs this
# gate) — nothing is spliced into feasibility/hooks/directive.sh; Claude
# Code fires every enabled plugin's hooks.json independently, so no edit
# to any sibling plugin is required for this gate to run.
#
# Fail-closed: malformed/missing input, unresolvable root => DENY.
# Kill switch: NYGARD_ADR_SPINE_GATE_OFF=1 (1/true/yes/on disables).
#
# Heuristic limits (documented, not hidden): section detection is by
# markdown ATX heading / bold-label text match and simple regex on
# "Field:" lines — it does not parse a formal grammar. A record that
# buries a required field in unrelated prose, or spells a heading in an
# unrecognized way, may be denied even though a human would read it as
# complete; conversely, a field name appearing in an unrelated context
# (e.g. inside a code block) may be picked up as if it were the real
# field. These are accepted trade-offs for a fast, dependency-free gate.

set -euo pipefail

case "${NYGARD_ADR_SPINE_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  1|true|yes|on) exit 0 ;;
  *) ;;
esac

deny() { echo "nygard-adr-spine: DENIED (spine-gate) — $1" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || deny "python3 is required and was not found."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "no tool-input payload was received."

set +e
NYGARD_PAYLOAD="$payload" NYGARD_CPD="${CLAUDE_PROJECT_DIR:-}" NYGARD_CWD="$(pwd -P)" \
  NYGARD_TERMINAL_STATES="${NYGARD_ADR_SPINE_TERMINAL_STATES:-verdict scope-approved}" \
  python3 <<'PY'
import json, os, posixpath, re, sys, subprocess

def deny(m): print("nygard-adr-spine: DENIED (spine-gate) - %s" % m, file=sys.stderr); sys.exit(2)
def allow(): sys.exit(0)

def _fc_hook(_t, _v, _tb):
    try:
        sys.stderr.write("nygard-adr-spine: DENIED (spine-gate) - fail-closed: internal error: %s\n" % _v)
    except Exception:
        pass
    os._exit(2)
sys.excepthook = _fc_hook

try:
    event = json.loads(os.environ.get("NYGARD_PAYLOAD", ""))
except ValueError:
    deny("tool-input payload is not valid JSON.")
if not isinstance(event, dict):
    deny("tool-input payload is not a JSON object.")

tool = event.get("tool_name")
ti = event.get("tool_input")
if not isinstance(tool, str) or not tool:
    deny("tool_name missing from payload.")
if tool not in ("Write", "Edit", "MultiEdit"):
    allow()  # foreign tool: nothing to gate
if not isinstance(ti, dict):
    deny("tool_input missing or malformed in payload.")

path = ti.get("file_path")
if not isinstance(path, str) or not path:
    deny("write call carries no file_path.")

def plausible_root(d):
    return bool(d) and os.path.isdir(d) and (os.path.exists(os.path.join(d, ".git"))
        or os.path.isfile(os.path.join(d, "docs/specs/role-handoff-contract.md")))
def git_top(d):
    try:
        r = subprocess.run(["git","-C",d,"rev-parse","--show-toplevel"],capture_output=True,text=True)
        return (r.stdout.strip() or None) if r.returncode == 0 else None
    except Exception:
        return None

norm = path.replace("\\","/")
cpd = os.environ.get("NYGARD_CPD","")
cwd = os.environ.get("NYGARD_CWD","")
root = None
if plausible_root(cpd):
    try:
        cand = os.path.realpath(cpd)
        absu = norm if posixpath.isabs(norm) else posixpath.join(cand,norm)
        real = os.path.realpath(absu)
        if real == cand or real.startswith(cand+"/"): root = cand
    except Exception: root = None
if root is None:
    base = norm if posixpath.isabs(norm) else posixpath.join(cwd,norm)
    d = base if os.path.isdir(base) else posixpath.dirname(base)
    root = git_top(d) or git_top(cwd)
if not root:
    deny("no project root could be determined; refusing rather than silently allowing.")

absu = posixpath.normpath(norm if posixpath.isabs(norm) else posixpath.join(root,norm))
resolved = posixpath.normpath(os.path.realpath(absu).replace("\\","/"))
try:
    rel = posixpath.relpath(resolved, root).replace("\\","/")
except ValueError:
    allow()

# Phase-2 only write surface.
if not re.match(r"^docs/issue-[0-9]+/reports/technical-feasibility\.md$", rel):
    allow()  # foreign path: nothing to gate

content = ti.get("content")
if not isinstance(content, str):
    # Edit/MultiEdit carry diff fragments, not the full record; this
    # gate needs the complete content to judge the whole spine.
    deny("no full-content field found on this write; the spine gate needs the complete "
         "record content (as Write's 'content') to verify all six fields.")

lower = content.lower()

def find_field(label):
    # Inline form: "Status: proposed" or "**Status:** proposed".
    m = re.search(r"^\s*\**" + label + r"\**\s*:\s*(.+)$", content, re.M | re.I)
    if m:
        return m.group(1).strip()
    # Heading form: a "## Status" (or similar) heading with the value on
    # the next non-empty line.
    m = re.search(r"^#{1,6}\s*" + label + r"\s*#*\s*$\n+([^\n#].*)$", content, re.M | re.I)
    if m:
        return m.group(1).strip()
    return None

def has_heading(*phrases):
    headings = [h.strip().lower() for h in re.findall(r"^#{1,6}\s+(.*?)\s*#*\s*$", content, re.M)]
    labels = [l.strip().lower() for l in re.findall(r"^\*\*(.*?)\*\*", content, re.M)]
    hay = " \n ".join(headings + labels)
    return any(p in hay for p in phrases)

missing = []

# 1. Status field: proposed | accepted | superseded
status_val = find_field("status")
if not status_val or not re.search(r"\b(proposed|accepted|superseded)\b", status_val, re.I):
    missing.append("Status (must be one of proposed|accepted|superseded)")

# 2. Decision field with a stated verdict class
decision_val = find_field("decision")
if not decision_val or not re.search(r"\b(go|no-go|conditional|proposed|accepted|superseded|"
                                      r"mitigated|accepted|deferred)\b", decision_val, re.I):
    # Fall back: a Decision section/heading with any non-empty verdict-like content nearby.
    if not (has_heading("decision") and decision_val):
        missing.append("Decision (must state a verdict class)")

# 3. Context prose section
if not has_heading("context"):
    missing.append("Context")

# 4. Consequences section with a reversibility tag
if not has_heading("consequences"):
    missing.append("Consequences")
else:
    m = re.search(r"consequences.*?(?=^#{1,6}\s|\Z)", content, re.I | re.S | re.M)
    scope = m.group(0) if m else content
    if not re.search(r"\b(one-way|two-way|one way|two way|reversible|irreversible)\b", scope, re.I):
        missing.append("Consequences reversibility tag (one-way|two-way)")

# 5. Risks: every entry disposed mitigated|accepted|deferred
if has_heading("risks"):
    m = re.search(r"^#{1,6}\s*risks\s*$(.*?)(?=^#{1,6}\s|\Z)", content, re.I | re.S | re.M)
    risks_block = m.group(1) if m else ""
    # Risk entries: list items or table rows under the Risks section.
    entries = [ln for ln in risks_block.splitlines()
               if re.match(r"^\s*[-*]\s+\S", ln) or re.match(r"^\s*\|.+\|\s*$", ln)]
    entries = [e for e in entries if not re.match(r"^\s*\|[-:\s|]+\|\s*$", e)]  # drop table separator rows
    if not entries:
        missing.append("Risks (section present but no entries found)")
    else:
        for e in entries:
            if not re.search(r"\b(mitigated|accepted|deferred)\b", e, re.I):
                missing.append("Risks entry without a disposition: %r" % e.strip())

if missing:
    # Determine whether this is a terminal transition (stricter framing only).
    terminal_states = set(os.environ.get("NYGARD_TERMINAL_STATES", "verdict scope-approved").split())
    loop_state = find_field("loop_state") or status_val or ""
    is_terminal = loop_state.strip().lower() in terminal_states
    prefix = ("record transitions to a terminal loop_state (%s) " % loop_state.strip()
              if is_terminal else "record ")
    deny("%swith incomplete Nygard ADR spine — missing/incomplete: %s" % (prefix, "; ".join(missing)))

allow()
PY
rc=$?
if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then
  echo "nygard-adr-spine: DENIED (spine-gate) — fail-closed: internal error (judge exited $rc)" >&2
  exit 2
fi
exit "$rc"
