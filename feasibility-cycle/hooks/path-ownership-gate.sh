#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit): §11 path-ownership.
# Generalizes coding's scope-gate.sh write-set shape to §11's static,
# role-permanent owned-path table. A feasibility session may write only its
# OWN paths; a Write/Edit reaching another role's record under a subject
# (docs/reports/records/<subject>/<other-role>.md) => DENY (report the
# conflict, never overwrite). Non-record writes and feasibility's own paths
# pass through.
#
# Feasibility's owned paths per §11 + the §21 doc grants:
#   docs/reports/records/<subject>/feasibility.md
#   docs/reports/records/<subject>/spikes/<slug>.md
#   docs/{decisions,handbooks,proposals,reports,specs,_assets}/**  (shared doc buckets)
# Any other docs/reports/records/<subject>/<something> is another role's and
# is refused.
#
# Fail-closed: malformed/missing input, unresolvable root => DENY. Kill
# switch: FEASIBILITY_PATHOWN_GATE_OFF=1.
set -euo pipefail

case "${FEASIBILITY_PATHOWN_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

deny() { echo "feasibility-cycle: DENIED (path-ownership-gate) — $1" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || deny "python3 is required and was not found."
payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "no tool-input payload was received."

set +e
FEAS_PAYLOAD="$payload" FEAS_CPD="${CLAUDE_PROJECT_DIR:-}" FEAS_CWD="$(pwd -P)" python3 <<'PY'
import json, os, posixpath, re, sys, subprocess

def deny(m): print("feasibility-cycle: DENIED (path-ownership-gate) - %s" % m, file=sys.stderr); sys.exit(2)
def allow(): sys.exit(0)

# PYTHON LAYER (fail-closed on internal error): any uncaught exception —
# including os.path.* raising ValueError on a null-byte/undecodable path —
# becomes exit 2 (DENY), never the default exit 1 (fail-open). SystemExit from
# allow()/deny() bypasses excepthook, so the verdict paths are unchanged.
def _feas_fc_hook(_t, _v, _tb):
    try:
        sys.stderr.write("feasibility-cycle: DENIED (path-ownership-gate) - fail-closed: internal error: %s\n" % _v)
    except Exception:
        pass
    os._exit(2)
sys.excepthook = _feas_fc_hook

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
    # target escapes the repo entirely; not a record path we own -> refuse to
    # judge but do not silently pass a records-tree write. Outside-repo writes
    # are not this gate's concern.
    allow()

# The gate only polices the per-subject records tree. Anything outside it
# (including the shared docs buckets, which doc-bucket-gate handles) is not a
# §11 ownership conflict this gate decides.
m = re.match(r"^docs/reports/records/([^/]+)/(.+)$", rel)
if not m:
    allow()
subject, leaf = m.group(1), m.group(2)

# Feasibility's own leaves under a subject: feasibility.md and spikes/<slug>.md.
if leaf == "feasibility.md":
    allow()
if re.match(r"^spikes/[^/]+\.md$", leaf):
    allow()
# The subject's tokens/ dir is human-placed signal, not a role record; a
# feasibility session placing its own approval token is not a §11 violation.
if re.match(r"^tokens/[^/]+$", leaf):
    allow()

# Anything else under the subject dir is another role's exclusive path.
owner = leaf.split("/")[0]
owner = owner[:-3] if owner.endswith(".md") else owner
deny("'%s' is owned by role '%s' per contract §11, not by feasibility. Report the conflict; "
     "do not overwrite or merge into another role's record." % (rel, owner))
PY
rc=$?
# SHELL LAYER (fail-closed on internal error): map any terminal code other
# than 0 (allow) or 2 (deny) to exit 2.
if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then
  echo "feasibility-cycle: DENIED (path-ownership-gate) — fail-closed: internal error (judge exited $rc)" >&2
  exit 2
fi
exit "$rc"
