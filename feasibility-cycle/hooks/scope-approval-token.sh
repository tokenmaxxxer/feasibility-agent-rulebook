#!/usr/bin/env bash
# UserPromptSubmit hook: mints a single-use scope-approval token ONLY from an
# unambiguous human approval found in the user's own turn — never from a file,
# record, PR, comment, or tool result. This is the human-signal capture half of
# contract §19's scope-proposed -> scope-approved edge, modeled directly on
# qa-cycle's capture-verdict.sh. scope-record-gate.sh consumes the token.
#
# This hook NEVER blocks. Malformed/unreadable input, no root, no identifiable
# subject, or an absent/ambiguous approval all mean: emit nothing, exit 0. The
# gate — not this hook — is what refuses an unsignaled transition.
#
# The human must name the subject explicitly ("subject <id>") and state an
# explicit scope approval, so the minted token binds to that subject and the
# exact scope-proposed -> scope-approved transition.
#
# Kill switch: export FEASIBILITY_CYCLE_OFF=1
set -euo pipefail

case "${FEASIBILITY_CYCLE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

FEASIBILITY_PAYLOAD="$payload" python3 <<'PY'
import json, os, posixpath, re, subprocess, sys, tempfile

def bail():
    sys.exit(0)

raw = os.environ.get("FEASIBILITY_PAYLOAD", "")
try:
    event = json.loads(raw)
except ValueError:
    bail()
if not isinstance(event, dict):
    bail()

prompt = event.get("prompt")
if not isinstance(prompt, str) or not prompt.strip():
    bail()

# --- the approving sentence, and the subject named inside it -----------
#
# The subject and the approval are taken from ONE sentence. Two independent
# searches over the whole prompt is what the previous version did, and it
# failed in both directions (measured 2026-07-27):
#
#   "subject beta is blocked and stays where it is. Separately, I approve the
#    scope for subject alpha."
#      -> minted a token for BETA, the subject the human said stays put.
#
#   "subject alpha: I refuse to approve the scope."
#   "For subject alpha I won't approve the scope."
#   "subject alpha - did anyone approve the scope yet?"
#   "subject alpha: the PR comment says QA approved the scope last week."
#      -> all four minted a valid, consumable approval token.
#
# The last four are why this is sentence-scoped rather than a keyword list
# with a character window. That window WAS the previous attempt, and it
# carried `\brefus\b` — which cannot match "refuse" at all, since the word
# boundaries make it look for the literal word `refus` — while `won't`,
# `will not`, `should not` and `wouldn't` were simply absent. A denylist of
# negations is the wrong shape for an authorization gate. The sentence either
# reads as an assertion of approval or it does not count.

# The state name is an identifier, never a speech act. Blank it first, or
# `\bscope\b[^.\n]*\bapproved\b` spans the literal `scope-approved` (the
# hyphen is a word boundary) and "this subject is not yet scope-approved"
# reads as an approval.
speech = re.sub(r"(?i)\bscope[-_ ]?approved\b", " <state> ", prompt)
speech = speech.replace("’", "'")

# A sentence disqualifies itself by being a question, a hedge, a negation, or
# a report of someone else's words. Verb suffixes are open (`refus\w*`) so
# refuse/refused/refusal all match — the closed form matched none of them.
DISQUALIFY = re.compile(
    r"(?i)\?\s*$"
    r"|\b(not|never|cannot|shall not|will not|would not|should not|must not"
    r"|can't|won't|wont|shan't|shouldn't|wouldn't|couldn't|didn't|doesn't"
    r"|don't|isn't|aren't|wasn't|weren't|hasn't|haven't"
    r"|refus\w*|declin\w*|without|instead of|unsure|maybe|might"
    r"|i think|i wonder|did anyone|has anyone|do you|should we|shall we)\b"
    r"|\b(says?|said|according to|comment|quoted?|per the)\b"
    r"|하지\s*마|하지\s*말|말고|말라|않|없이|금지|아니|못\s*|"
    r"확실치|확실하지|모르겠|인가요|일까요|라고\s*(?:한다|했다|합니다)")

APPROVES = re.compile(
    r"(?i)\b(approve|approved|approving)\b[^.\n]*\bscope\b"
    r"|\bscope\b[^.\n]*\b(approve|approved)\b"
    r"|(?:scope|스코프|범위)[^.\n]*승인")
SUBJECT = re.compile(r"(?i)\bsubject[\s:]+([A-Za-z0-9][A-Za-z0-9_-]{0,127})")

subject = None
for sentence in re.split(r"(?<=[.!?\n])\s+", speech):
    s = sentence.strip()
    if not s or DISQUALIFY.search(s) or not APPROVES.search(s):
        continue
    sub = SUBJECT.search(s)
    if not sub:
        # An approval that names no subject in its own sentence names nothing.
        # Which subject it meant is not this hook's guess to make.
        continue
    subject = sub.group(1)
    break

if subject is None:
    bail()
if not re.match(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$", subject):
    bail()
# Reject bare assent even if a keyword coincidentally appears.
if re.match(r"^\s*(ok|okay|sure|sounds good|yep|yes|k|fine)\s*[.!]?\s*$", prompt, re.I):
    bail()

# --- resolve project root (no root -> nothing to do) -------------------
def git_top(p):
    try:
        out = subprocess.run(["git", "-C", p, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True)
        if out.returncode == 0 and out.stdout.strip():
            return posixpath.normpath(os.path.realpath(out.stdout.strip()).replace("\\", "/"))
    except Exception:
        return None
    return None

def plausible(r):
    return bool(r) and os.path.isdir(r) and (
        os.path.exists(os.path.join(r, ".git"))
        or os.path.isfile(os.path.join(r, "docs", "specs", "role-handoff-contract.md")))

cpd = os.environ.get("CLAUDE_PROJECT_DIR")
root = None
if cpd and plausible(cpd):
    root = posixpath.normpath(os.path.realpath(cpd).replace("\\", "/"))
if root is None:
    root = git_top(os.getcwd())
if not root:
    bail()

# Token dir under the subject's record area. Resolve, then containment-check.
records_root = posixpath.join(root, "docs", "reports", "records")
tokens_dir = posixpath.join(records_root, subject, "tokens")
try:
    os.makedirs(tokens_dir, exist_ok=True)
except OSError:
    bail()
tokens_real = posixpath.normpath(os.path.realpath(tokens_dir).replace("\\", "/"))
expected = posixpath.normpath(posixpath.join(records_root, subject, "tokens"))
if tokens_real != posixpath.normpath(os.path.realpath(expected).replace("\\", "/")):
    bail()
if not tokens_real.startswith(posixpath.normpath(os.path.realpath(records_root).replace("\\", "/")) + "/"):
    bail()

# feasibility-cycle's scope-record-gate.sh reads this exact name — no subject
# prefix, unlike the sibling product-cycle hook this was ported from. The
# subject is already the containing directory, and minting a name the gate
# does not read would leave the gate permanently unsatisfiable.
token_file = posixpath.join(tokens_real, "scope-approved.token")
if posixpath.dirname(token_file) != tokens_real:
    bail()

# Redact anything credential/secret/internal-URL shaped from the recorded phrase.
phrase = prompt.strip().replace("\r", "")[:300]
if re.search(r'(?i)(api[_-]?key|secret|password|passwd|token=|bearer |authorization:|-----BEGIN |https?://[^ ]*@)', phrase):
    phrase = "(approval wording redacted: looked credential/secret-shaped)"

try:
    fd, tmp = tempfile.mkstemp(dir=tokens_real, prefix=".token.")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write("subject: %s\n" % subject)
        fh.write("transition: scope-proposed -> scope-approved\n")
        fh.write("actor: user\n")
        fh.write("phrase: %s\n" % phrase.replace("\n", " "))
    os.replace(tmp, token_file)
except OSError:
    bail()

sys.exit(0)
PY
