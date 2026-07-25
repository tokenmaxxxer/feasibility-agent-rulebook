#!/usr/bin/env bash
# UserPromptSubmit hook: mints a single-use approval token for the one gated
# transition this role has — `probing -> verdict` — from an unambiguous
# statement in the user's OWN turn. Never from a file, a probe result, or any
# tool output: content is not consent.
#
# This hook never blocks. Malformed input, no project, no record file, wrong
# state, or an ambiguous/absent verdict all mean: mint nothing, exit 0. The
# state-gate.sh PreToolUse hook is what refuses; this hook only mints.
#
# Kill switch: export FEASIBILITY_SIGNOFF_DISABLE=1
set -euo pipefail

case "${FEASIBILITY_SIGNOFF_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0

root="${CLAUDE_PROJECT_DIR:-}"
[ -n "$root" ] || root="$(pwd)"
root="$(cd "$root" 2>/dev/null && pwd -P)" || exit 0

record_file="$root/feasibility-record.md"
[ -f "$record_file" ] || exit 0

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

FEASIBILITY_PAYLOAD="$payload" FEASIBILITY_ROOT="$root" FEASIBILITY_RECORD="$record_file" python3 <<'PY'
import json, os, re, sys, tempfile

try:
    event = json.loads(os.environ.get("FEASIBILITY_PAYLOAD", ""))
except ValueError:
    sys.exit(0)
if not isinstance(event, dict):
    sys.exit(0)

prompt = event.get("prompt")
if not isinstance(prompt, str) or not prompt.strip():
    sys.exit(0)

root = os.environ["FEASIBILITY_ROOT"]
record_path = os.environ["FEASIBILITY_RECORD"]

try:
    with open(record_path, encoding="utf-8-sig") as fh:
        text = fh.read(1 << 20)
except OSError:
    sys.exit(0)

if not text.startswith("---"):
    sys.exit(0)
end = text.find("\n---", 3)
if end == -1:
    sys.exit(0)
block = text[3:end]

m = re.search(r"^status:\s*([A-Za-z]+)\s*(?:#.*)?$", block, re.M)
status = m.group(1).lower() if m else None
if status != "probing":
    sys.exit(0)  # the only gated transition starts from `probing`

probe_names = ("technical", "prior_art", "legal_regulatory", "threat_model")
probes = {}
for name in probe_names:
    pm = re.search(r"^" + re.escape(name) + r":\s*(.*?)\s*(?:#.*)?$", block, re.M)
    probes[name] = pm.group(1).strip() if pm else ""

def resolved(v):
    if not v:
        return False
    low = v.lower()
    if low in ("unresolved", "in-progress", "in progress", "pending", ""):
        return False
    return low.startswith(("pass", "fail", "blocked"))

if not all(resolved(probes[n]) for n in probe_names):
    sys.exit(0)  # fields not all resolved yet; content alone can't earn a token anyway

# Require an explicit, unambiguous statement naming the verdict transition.
# Reject bare assent ("ok", "sounds good", ...) even if it appears alongside
# other text — the whole prompt must not be JUST that.
stripped = prompt.strip()
if re.fullmatch(r'(ok|okay|sure|sounds good|yep|yes|k|fine|👍)[.!]?', stripped, re.I):
    sys.exit(0)

verdict_re = re.compile(
    r"\b(approve|confirm(ed|ing)?|render|move|proceed)\b.{0,40}\b(verdict)\b"
    r"|\b(verdict)\b.{0,40}\b(approve|confirm(ed|ing)?|ready|go ahead)\b"
    r"|\bprobing\s*->\s*verdict\b",
    re.I,
)
if not verdict_re.search(prompt):
    sys.exit(0)

tokens_dir = os.path.join(root, ".feasibility", "tokens")
os.makedirs(tokens_dir, exist_ok=True)
token_file = os.path.join(tokens_dir, "verdict.token")

phrase = prompt.strip().replace("\r", "")[:300]
if re.search(r"(api[_-]?key|secret|password|passwd|token=|bearer |authorization:|-----BEGIN )", phrase, re.I):
    sys.exit(0)  # never mint a token carrying credential-shaped text

fd, tmp = tempfile.mkstemp(dir=tokens_dir)
with os.fdopen(fd, "w") as f:
    f.write("transition: probing -> verdict\n")
    f.write("record_file: feasibility-record.md\n")
    esc = phrase.replace("'", "''")
    f.write("phrase: '%s'\n" % esc)
os.replace(tmp, token_file)
sys.exit(0)
PY
exit 0
