#!/usr/bin/env bash
# PreToolUse hook (Bash matching 'git commit'): §13 trailer.
# When a feasibility unit is in progress (any owned feasibility record exists
# in a non-terminal status) the commit message must carry this repo's
# declared trailer key ('Proposal:'). A commit for an in-progress unit whose
# message lacks the trailer => DENY.
#
# Fail-closed: malformed/missing input, indeterminate git root, or a commit
# whose message cannot be read (no -m/-F, i.e. an editor commit) while a unit
# is in progress => DENY. Kill switch: FEASIBILITY_TRAILER_GATE_OFF=1.
set -euo pipefail

case "${FEASIBILITY_TRAILER_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

deny() { echo "feasibility-cycle: DENIED (trailer-gate) — $1" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || deny "python3 is required and was not found."
command -v git >/dev/null 2>&1 || deny "git is required and was not found."
payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "no tool-input payload was received."

set +e
FEAS_PAYLOAD="$payload" FEAS_CPD="${CLAUDE_PROJECT_DIR:-}" FEAS_CWD="$(pwd -P)" python3 <<'PY'
import json, os, re, sys, shlex, subprocess

TRAILER_RE = re.compile(r"^\s*Proposal:\s*\S", re.M)
TERMINAL = {"verdict", "scope-approved"}

def deny(m): print("feasibility-cycle: DENIED (trailer-gate) - %s" % m, file=sys.stderr); sys.exit(2)
def allow(): sys.exit(0)

# PYTHON LAYER (fail-closed on internal error): any uncaught exception becomes
# exit 2 (DENY), never the default exit 1 (fail-open). SystemExit from
# allow()/deny() bypasses excepthook, leaving the verdict paths untouched.
def _feas_fc_hook(_t, _v, _tb):
    try:
        sys.stderr.write("feasibility-cycle: DENIED (trailer-gate) - fail-closed: internal error: %s\n" % _v)
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
if tool != "Bash":
    allow()
if not isinstance(ti, dict): deny("tool_input missing or malformed in payload.")
command = ti.get("command")
if not isinstance(command, str) or not command.strip():
    deny("Bash tool_input.command missing or empty.")

try:
    toks = shlex.split(command, comments=False)
except ValueError:
    if re.search(r"\bgit\b.*\bcommit\b", command):
        deny("a git commit command could not be parsed (unbalanced quoting); refusing.")
    allow()

# Find the git-commit sub-invocation and its argv tail.
commit_idx = None
for i,t in enumerate(toks):
    if os.path.basename(t) == "git":
        for j in range(i+1, len(toks)):
            if toks[j].startswith("-"): continue
            if toks[j] == "commit":
                commit_idx = j
            break
        if commit_idx is not None:
            break
if commit_idx is None:
    allow()
argv = toks[commit_idx+1:]

# Extract the commit message from -m/--message or -F/--file.
def read_message(argv):
    msgs = []; i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("-m","--message"):
            if i+1 < len(argv): msgs.append(argv[i+1]); i += 2; continue
            return None, "flag-without-value"
        if a.startswith("--message="):
            msgs.append(a.split("=",1)[1]); i += 1; continue
        if a.startswith("-m") and len(a) > 2:
            msgs.append(a[2:]); i += 1; continue
        if a in ("-F","--file"):
            if i+1 < len(argv): return ("__FILE__", argv[i+1])
            return None, "flag-without-value"
        if a.startswith("--file="):
            return ("__FILE__", a.split("=",1)[1])
        i += 1
    if msgs:
        return "\n\n".join(msgs), None
    return None, "no-message-flag"

msg, aux = read_message(argv)

cwd = os.environ.get("FEAS_CWD",""); cpd = os.environ.get("FEAS_CPD","")
def git_top(d):
    try:
        r = subprocess.run(["git","-C",d,"rev-parse","--show-toplevel"],capture_output=True,text=True)
        return (r.stdout.strip() or None) if r.returncode==0 else None
    except Exception: return None
root = None
if cpd and os.path.isdir(cpd) and (os.path.exists(os.path.join(cpd,".git")) or
        os.path.isfile(os.path.join(cpd,"docs/specs/role-handoff-contract.md"))):
    root = git_top(cpd)
if not root:
    root = git_top(cwd)
if not root:
    deny("could not determine the git repository root for this commit; refusing (fail closed).")

# Is a feasibility unit in progress? Scan owned records for a non-terminal status.
def frontmatter_status(text):
    if not text.startswith("---"): return None
    end = text.find("\n---", 3)
    if end == -1: return None
    ms = re.findall(r"^status:\s*(.*?)\s*(?:#.*)?$", text[3:end], re.M)
    if len(ms) != 1: return None
    return ms[0].strip().rstrip("\r").strip().lower()

records_root = os.path.join(root, "docs", "reports", "records")
in_progress = False
if os.path.isdir(records_root):
    for subj in os.listdir(records_root):
        rec = os.path.join(records_root, subj, "feasibility.md")
        if os.path.isfile(rec):
            try:
                with open(rec, encoding="utf-8-sig") as fh:
                    st = frontmatter_status(fh.read(1 << 20))
            except OSError:
                deny("an existing feasibility record (%s) could not be read to determine "
                     "whether a unit is in progress; refusing (fail closed)." % rec)
            if st is None:
                deny("an existing feasibility record (%s) has no parseable status; refusing "
                     "(fail closed)." % rec)
            if st not in TERMINAL:
                in_progress = True
                break

if not in_progress:
    allow()  # no in-progress unit; §13 trailer not required by this gate

# A unit is in progress: the trailer is required and must be readable.
if msg == "__FILE__":
    fpath = aux if os.path.isabs(aux) else os.path.join(root, aux)
    try:
        with open(fpath, encoding="utf-8-sig") as fh:
            text = fh.read(1 << 20)
    except OSError:
        deny("commit message file could not be read to verify the required trailer; refusing.")
elif msg is None:
    deny("a feasibility unit is in progress but this commit provides no readable message "
         "(no -m/--message/-F). The §13 'Proposal:' trailer cannot be verified on an editor "
         "commit; pass the message with -m including the trailer.")
else:
    text = msg

if not TRAILER_RE.search(text):
    deny("a feasibility unit is in progress but this commit message lacks the required §13 "
         "trailer ('Proposal: <path>'). Add the trailer identifying the governing proposal.")
allow()
PY
rc=$?
# SHELL LAYER (fail-closed on internal error): map any terminal code other
# than 0 (allow) or 2 (deny) to exit 2.
if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then
  echo "feasibility-cycle: DENIED (trailer-gate) — fail-closed: internal error (judge exited $rc)" >&2
  exit 2
fi
exit "$rc"
