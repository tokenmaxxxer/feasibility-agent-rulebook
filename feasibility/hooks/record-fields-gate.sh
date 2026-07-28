#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit): §20 minimum-content.
# Peer to state-gate.sh on feasibility's owned record paths
# (docs/issue-<n>/reports/feasibility.md and
# .../spikes/<slug>.md). state-gate.sh validates the status transition; THIS
# gate validates §20's minimum content on the SAME proposed Write content:
# every role record must state what was done, why, and the concrete upstream
# basis, and — when the record leaves work open (a non-terminal status) —
# must additionally carry a next-steps section and an open-finding
# resolution-path section. Missing a required-for-this-state section => DENY.
#
# Fail-closed: malformed/missing input, unresolvable root => DENY. Kill
# switch: FEASIBILITY_FIELDS_GATE_OFF=1.
set -euo pipefail

case "${FEASIBILITY_FIELDS_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

deny() { echo "feasibility-cycle: DENIED (record-fields-gate) — $1" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || deny "python3 is required and was not found."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "no tool-input payload was received."

set +e
FEAS_PAYLOAD="$payload" FEAS_CPD="${CLAUDE_PROJECT_DIR:-}" FEAS_CWD="$(pwd -P)" python3 <<'PY'
import json, os, posixpath, re, sys, subprocess

def deny(m): print("feasibility-cycle: DENIED (record-fields-gate) - %s" % m, file=sys.stderr); sys.exit(2)
def allow(): sys.exit(0)

# PYTHON LAYER (fail-closed on internal error): any uncaught exception —
# including os.path.* raising ValueError on a null-byte/undecodable path —
# becomes exit 2 (DENY), never the default exit 1 (fail-open). SystemExit from
# allow()/deny() bypasses excepthook, so the verdict paths are unchanged.
def _feas_fc_hook(_t, _v, _tb):
    try:
        sys.stderr.write("feasibility-cycle: DENIED (record-fields-gate) - fail-closed: internal error: %s\n" % _v)
    except Exception:
        pass
    os._exit(2)
sys.excepthook = _feas_fc_hook

try:
    event = json.loads(os.environ.get("FEAS_PAYLOAD", ""))
except ValueError:
    deny("tool-input payload is not valid JSON.")
if not isinstance(event, dict):
    deny("tool-input payload is not a JSON object.")
tool = event.get("tool_name"); ti = event.get("tool_input")
if not isinstance(tool, str) or not tool:
    deny("tool_name missing from payload.")
if not isinstance(ti, dict):
    deny("tool_input missing or malformed in payload.")

path = ti.get("file_path") or ti.get("notebook_path")
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

norm = path.replace("\\","/"); cpd = os.environ.get("FEAS_CPD",""); cwd = os.environ.get("FEAS_CWD","")
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
if not re.match(r"^docs/issue-[0-9]+/reports/(feasibility\.md|spikes/[^/]+\.md)$", rel):
    allow()  # not a feasibility-owned record path; nothing to gate

# Only a complete Write can be judged; an Edit is a partial diff -> fail closed.
if tool != "Write":
    deny("an Edit/MultiEdit/NotebookEdit targets a feasibility record; this gate needs the "
         "complete content. Rewrite the whole file with Write so §20's required sections "
         "can be verified.")
content = ti.get("content")
if not isinstance(content, str):
    deny("Write carries no readable content for the feasibility record.")

if not content.startswith("---"):
    deny("record must open with YAML frontmatter (---).")
fend = content.find("\n---", 3)
if fend == -1:
    deny("record frontmatter has no closing '---'.")
block = content[3:fend]; body = content[fend+4:]
ms = re.findall(r"^status:\s*(.*?)\s*(?:#.*)?$", block, re.M)
if len(ms) != 1 or not ms[0].strip():
    deny("record frontmatter has no single non-empty 'status' field (§20: current loop_state must be recorded).")
status = ms[0].strip().rstrip("\r").strip().lower()

# Heading text (markdown ATX headings) lowered, plus bold-label lines.
headings = [h.strip().lower() for h in re.findall(r"^#{1,6}\s+(.*?)\s*#*\s*$", body, re.M)]
labels = [l.strip().lower() for l in re.findall(r"^\*\*(.*?)\*\*", body, re.M)]
sections = headings + labels
hay = " \n ".join(sections)

def has(*keysets):
    # each keyset is a tuple of alternative phrases; a section satisfies it
    # if any section text contains any alternative.
    for phrases in keysets:
        if not any(p in hay for p in phrases):
            return False
    return True

missing = []
if not has(("what was done","what i did","what was built","work done","what")):
    missing.append("what-was-done")
if not has(("why","rationale","reasoning")):
    missing.append("why")
if not has(("upstream","basis","commit sha","source record","based on")):
    missing.append("upstream-basis")

TERMINAL = {"verdict", "scope-approved"}
if status not in TERMINAL:
    if not has(("next step","next-steps","next steps","what remains","remaining")):
        missing.append("next-steps")
    if not has(("open finding","open-finding","finding resolution","resolution path","how findings")):
        missing.append("open-finding-resolution-path")

if missing:
    deny("record is missing required section(s): %s. Per contract §20 every role record "
         "must state what was done, why, and the concrete upstream basis; a record left in a "
         "non-terminal state (%s) additionally requires next-steps and an open-finding "
         "resolution path." % (", ".join(missing), status))
allow()
PY
rc=$?
# SHELL LAYER (fail-closed on internal error): map any terminal code other
# than 0 (allow) or 2 (deny) to exit 2.
if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then
  echo "feasibility-cycle: DENIED (record-fields-gate) — fail-closed: internal error (judge exited $rc)" >&2
  exit 2
fi
exit "$rc"
