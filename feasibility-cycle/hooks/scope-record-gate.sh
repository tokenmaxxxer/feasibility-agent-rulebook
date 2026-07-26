#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit): §19 front-record side.
# Peer to state-gate.sh on the identical target path
# (docs/reports/records/<subject>/feasibility.md). state-gate.sh checks the
# scope-proposed -> scope-approved transition is a legal table row; THIS gate
# adds the human-signal check the bare table row cannot express: a
# scope-proposed -> scope-approved write requires a human-placed, unconsumed
# approval token for the subject (mirroring qa-cycle's capture-verdict.sh
# token mechanism). The hook NEVER performs the approval — it only refuses an
# unsignaled one. Everything that is not this specific transition is allowed
# through untouched.
#
# Fail-closed: malformed/missing input, unresolvable root, unreadable record
# => DENY (never a silent exit 0). Kill switch: FEASIBILITY_SCOPE_GATE_OFF=1.
set -euo pipefail

case "${FEASIBILITY_SCOPE_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

deny() { echo "feasibility-cycle: DENIED (scope-record-gate) — $1" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || deny "python3 is required to evaluate this gate and was not found."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "no tool-input payload was received."

FEAS_PAYLOAD="$payload" FEAS_CPD="${CLAUDE_PROJECT_DIR:-}" FEAS_CWD="$(pwd -P)" python3 <<'PY'
import json, os, posixpath, re, sys, subprocess

def deny(m): print("feasibility-cycle: DENIED (scope-record-gate) - %s" % m, file=sys.stderr); sys.exit(2)
def allow(): sys.exit(0)

raw = os.environ.get("FEAS_PAYLOAD", "")
try:
    event = json.loads(raw)
except ValueError:
    deny("tool-input payload is not valid JSON.")
if not isinstance(event, dict):
    deny("tool-input payload is not a JSON object.")

tool = event.get("tool_name")
ti = event.get("tool_input")
if not isinstance(tool, str) or not tool:
    deny("tool_name missing from payload.")
if not isinstance(ti, dict):
    deny("tool_input missing or malformed in payload.")

# Only Write/Edit-family calls reach this matcher. A path must be present.
path = ti.get("file_path") or ti.get("notebook_path")
if not isinstance(path, str) or not path:
    # No target path on a write-shaped call is malformed input -> fail closed.
    deny("write call carries no file_path.")

def plausible_root(d):
    return bool(d) and os.path.isdir(d) and (os.path.exists(os.path.join(d, ".git"))
        or os.path.isfile(os.path.join(d, "docs/specs/role-handoff-contract.md")))

def git_top(d):
    try:
        out = subprocess.run(["git", "-C", d, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True)
        if out.returncode == 0:
            return out.stdout.strip() or None
    except Exception:
        return None
    return None

norm = path.replace("\\", "/")
cpd = os.environ.get("FEAS_CPD", "")
cwd = os.environ.get("FEAS_CWD", "")

root = None
if plausible_root(cpd):
    try:
        cand = os.path.realpath(cpd)
        absu = norm if posixpath.isabs(norm) else posixpath.join(cand, norm)
        real = os.path.realpath(absu)
        if real == cand or real.startswith(cand + "/"):
            root = cand
    except Exception:
        root = None
if root is None:
    base = norm if posixpath.isabs(norm) else posixpath.join(cwd, norm)
    d = base if os.path.isdir(base) else posixpath.dirname(base)
    root = git_top(d) or git_top(cwd)
if not root:
    deny("no project root could be determined; refusing rather than silently allowing.")

absu = posixpath.normpath(norm if posixpath.isabs(norm) else posixpath.join(root, norm))
resolved = posixpath.normpath(os.path.realpath(absu).replace("\\", "/"))
try:
    rel = posixpath.relpath(resolved, root).replace("\\", "/")
except ValueError:
    allow()

# This gate only governs the front record (feasibility.md), not spikes.
if not re.match(r"^docs/reports/records/([^/]+)/feasibility\.md$", rel):
    allow()
subject = rel.split("/")[3]

def frontmatter_status(text):
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    block = text[3:end]
    ms = re.findall(r"^status:\s*(.*?)\s*(?:#.*)?$", block, re.M)
    if len(ms) != 1:
        return None
    return ms[0].strip().rstrip("\r").strip().lower()

# Proposed new status. Only Write carries full content; an Edit to this path
# cannot be evaluated for the transition -> fail closed (mirrors state-gate).
if tool == "Write":
    content = ti.get("content")
    if not isinstance(content, str):
        deny("Write carries no readable content for the feasibility record.")
    new_status = frontmatter_status(content)
    if new_status is None:
        deny("proposed feasibility record has no single parseable 'status' field in its frontmatter.")
else:
    deny("an Edit/MultiEdit/NotebookEdit targets the feasibility front record; this gate "
         "only evaluates a complete Write. Rewrite the whole file with Write so the "
         "scope-approval transition can be judged.")

# Current on-disk status.
if not os.path.exists(resolved):
    old_status = "(none)"
else:
    try:
        with open(resolved, encoding="utf-8-sig") as fh:
            old_status = frontmatter_status(fh.read(1 << 20))
    except OSError:
        deny("existing feasibility record could not be read to determine the current state.")
    if old_status is None:
        deny("existing feasibility record has no single parseable 'status' field.")

# Only the scope-proposed -> scope-approved transition is token-gated here.
if not (old_status == "scope-proposed" and new_status == "scope-approved"):
    allow()

# Require a human-placed, unconsumed approval token for THIS subject.
# Token lives beside the record under a tokens/ dir; a human (via the
# conversational capture mechanism) places it. The gate never mints it.
if not re.match(r"^[A-Za-z0-9_.-]{1,128}$", subject) or subject.startswith("-") or subject in (".", ".."):
    deny("subject '%s' has an unsafe name; refusing." % subject)
token = posixpath.join(root, "docs/reports/records", subject, "tokens", "scope-approved.token")
token_real = posixpath.normpath(token)
expected_dir = posixpath.normpath(posixpath.join(root, "docs/reports/records", subject, "tokens"))
if posixpath.dirname(token_real) != expected_dir:
    deny("resolved token path escaped the subject's tokens/ directory; refusing.")
if not os.path.isfile(token_real):
    deny("scope-proposed -> scope-approved requires a human-placed approval token for subject "
         "'%s' (expected docs/reports/records/%s/tokens/scope-approved.token, mirroring "
         "qa-cycle's capture-verdict.sh mechanism); none found. This state may not be set "
         "unilaterally, per contract §19." % (subject, subject))
try:
    if os.path.getsize(token_real) == 0:
        deny("approval token for subject '%s' is empty; a valid human-placed token is "
             "required. Refusing per §19." % subject)
except OSError:
    deny("approval token for subject '%s' could not be read; refusing per §19." % subject)
allow()
PY
