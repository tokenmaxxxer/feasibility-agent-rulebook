#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit): §21 bucket half.
# Refuses any write under docs/ that lands outside the six sanctioned
# buckets (decisions, handbooks, proposals, reports, specs, _assets). A
# top-level docs/README.md is allowed (bucket index). Writes outside docs/
# pass through untouched.
#
# Fail-closed: malformed/missing input, unresolvable root => DENY. Kill
# switch: FEASIBILITY_BUCKET_GATE_OFF=1.
set -euo pipefail

case "${FEASIBILITY_BUCKET_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

deny() { echo "feasibility-cycle: DENIED (doc-bucket-gate) — $1" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || deny "python3 is required and was not found."
payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "no tool-input payload was received."

FEAS_PAYLOAD="$payload" FEAS_CPD="${CLAUDE_PROJECT_DIR:-}" FEAS_CWD="$(pwd -P)" python3 <<'PY'
import json, os, posixpath, re, sys, subprocess

def deny(m): print("feasibility-cycle: DENIED (doc-bucket-gate) - %s" % m, file=sys.stderr); sys.exit(2)
def allow(): sys.exit(0)

try:
    event = json.loads(os.environ.get("FEAS_PAYLOAD",""))
except ValueError:
    deny("tool-input payload is not valid JSON.")
if not isinstance(event, dict): deny("tool-input payload is not a JSON object.")
tool = event.get("tool_name"); ti = event.get("tool_input")
if not isinstance(tool, str) or not tool: deny("tool_name missing from payload.")
if not isinstance(ti, dict): deny("tool_input missing or malformed in payload.")
path = ti.get("file_path") or ti.get("notebook_path")
if not isinstance(path, str) or not path: deny("write call carries no file_path.")

def plausible_root(d):
    return bool(d) and os.path.isdir(d) and (os.path.exists(os.path.join(d,".git"))
        or os.path.isfile(os.path.join(d,"docs/specs/role-handoff-contract.md")))
def git_top(d):
    try:
        r = subprocess.run(["git","-C",d,"rev-parse","--show-toplevel"],capture_output=True,text=True)
        return (r.stdout.strip() or None) if r.returncode==0 else None
    except Exception: return None

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
    allow()  # outside the repo; not a docs-bucket concern

if rel != "docs" and not rel.startswith("docs/"):
    allow()  # not under docs/
if rel == "docs/README.md":
    allow()  # bucket index

BUCKETS = ("decisions","handbooks","proposals","reports","specs","_assets")
parts = rel.split("/")
# rel == "docs/<bucket>/..." — parts[0]=="docs"
if len(parts) < 3 or parts[1] not in BUCKETS:
    deny("'%s' lands under docs/ but outside the six sanctioned buckets "
         "(%s). Per contract §21 every doc must live in one of these buckets; "
         "place it in the correct bucket instead." % (rel, ", ".join(BUCKETS)))
allow()
PY
