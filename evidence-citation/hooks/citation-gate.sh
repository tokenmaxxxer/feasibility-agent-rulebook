#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|MultiEdit|Bash): OpenSSF-Scorecard-style
# mandatory evidence citation format enforcement. Peer methodology gate for
# the technical-feasibility cycle's two write surfaces (phase-1 proposal,
# phase-2 record). Required format:
#   <claim> — <source: URL | path:line | check-name score>
# (an ASCII `--` or a space-hyphen-space `-` separator is also accepted;
# `—` is the canonical/display form, not a hard requirement on typed input.)
#
# This is a best-effort heuristic gate and the highest false-positive-risk
# gate in the technical-feasibility methodology set by design (see the
# accepted proposal, docs/issue-39/proposals/
# 2026-07-31-technical-feasibility-methodology-enforcement.md, section
# "evidence-citation"). Known limitations, documented rather than hidden:
#   - It cannot verify a citation is TRUE, only that something citation-shaped
#     is present near a claim.
#   - The phase-2 "new claim with no citation" heuristic is a line-adjacency
#     check (own line or the immediately adjacent line), not a full NLP
#     claim detector — false positives on non-claim prose remain possible.
#   - Edit/MultiEdit are checked against the full reconstructed resulting
#     document (current on-disk content + the edit applied), not a bare
#     diff fragment — see gate_reconstruct_write below.
#
# Fail-closed: malformed/missing input, unresolvable root, or an
# unreconstructable Edit/MultiEdit/Bash write => DENY.
# Kill switch: EVIDENCE_CITATION_GATE_OFF=1 (1/true/yes/on, any case).
#
# Referenced (never copied) from core's gate-house standard (issue-72):
# core/hooks/lib/gate-lib.sh / gate-lib.py, per docs/handbooks/
# canon-scripts.md's reference-not-copy rule.

. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" 2>/dev/null && pwd -P)}/hooks/lib/gate-lib.sh" \
  || { echo "evidence-citation: DENIED (citation-gate) — gate-lib.sh not found; set CLAUDE_PLUGIN_ROOT_CORE to core's plugin root" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail

# Drain stdin first regardless of the kill switch, so an upstream writer
# piping the payload in never sees a broken pipe (SIGPIPE) from an early exit.
payload="$(cat 2>/dev/null || true)"

gate_kill_switch_active "${EVIDENCE_CITATION_GATE_OFF:-}" || { trap - EXIT; exit 0; }

deny() { gate_deny "evidence-citation (citation-gate)" "$1"; }
command -v python3 >/dev/null 2>&1 || deny "python3 is required and was not found."

[ -n "$payload" ] || deny "no tool-input payload was received."

set +e
EC_PAYLOAD="$payload" EC_CPD="${CLAUDE_PROJECT_DIR:-}" EC_CWD="$(pwd -P)" GATE_LIB_PY="$GATE_LIB_PY" \
  python3 <<'PY'
import importlib.util, json, os, posixpath, re, subprocess, sys

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)

def deny(m): print("evidence-citation: DENIED (citation-gate) - %s" % m, file=sys.stderr); sys.exit(2)
def allow(): sys.exit(0)

def _fc_hook(_t, _v, _tb):
    try:
        sys.stderr.write("evidence-citation: DENIED (citation-gate) - fail-closed: internal error: %s\n" % _v)
    except Exception:
        pass
    os._exit(2)
sys.excepthook = _fc_hook

event = gate_lib.gate_parse_json_or_deny(os.environ.get("EC_PAYLOAD", ""), deny)

tool = event.get("tool_name")
ti = event.get("tool_input")
if not isinstance(tool, str) or not tool:
    deny("tool_name missing from payload.")
if tool not in ("Write", "Edit", "MultiEdit", "Bash"):
    allow()  # not a write-surface tool this gate cares about
if not isinstance(ti, dict):
    deny("tool_input missing or malformed in payload.")

def git_top(d):
    try:
        r = subprocess.run(["git", "-C", d, "rev-parse", "--show-toplevel"], capture_output=True, text=True)
        return (r.stdout.strip() or None) if r.returncode == 0 else None
    except Exception:
        return None

cpd = os.environ.get("EC_CPD", "")
cwd = os.environ.get("EC_CWD", "")
root = None
if cpd and os.path.isdir(cpd):
    root = os.path.realpath(cpd)
if root is None:
    root = git_top(cwd)
if not root:
    deny("no project root could be determined; refusing rather than silently allowing.")

PHASE1 = re.compile(r"^docs/issue-[0-9]+/proposals/.*technical-feasibility.*\.md$")
PHASE2 = re.compile(r"^docs/issue-[0-9]+/reports/technical-feasibility\.md$")

def owned_rel(path):
    """Root-relative tail if `path` matches an owned surface, else None."""
    if not isinstance(path, str) or not path:
        return None
    rel = gate_lib.gate_normalize_path(root, path)
    if rel is None:
        return None
    if PHASE1.match(rel) or PHASE2.match(rel):
        return rel
    return None

if tool == "Bash":
    cmdline = ti.get("command")
    if not isinstance(cmdline, str):
        deny("Bash payload carries no command string.")
    # Mirrors gate-lib.sh's gate_bash_write_targets token-scan technique
    # (bash-side helper; reimplemented here since this payload is judged
    # in the Python side of the gate).
    for tok in re.findall(r"[\w./~$-]+", cmdline):
        if owned_rel(tok):
            deny("a Bash command appears to write to a citation-gate-owned "
                 "path (%s); this gate cannot verify content written outside "
                 "Write/Edit/MultiEdit, so it refuses rather than silently "
                 "allowing an unchecked write." % tok)
    allow()

path = ti.get("file_path")
if not isinstance(path, str) or not path:
    deny("write call carries no file_path.")

rel = owned_rel(path)
if rel is None:
    allow()  # foreign path; nothing to gate

is_phase1 = bool(PHASE1.match(rel))
is_phase2 = bool(PHASE2.match(rel))

# Read the file's current on-disk content (may not exist yet, e.g. a
# fresh Write) so Edit/MultiEdit can be reconstructed against the real
# resulting document rather than a bare diff fragment.
abs_path = os.path.join(root, rel)
current_content = None
if os.path.isfile(abs_path):
    try:
        with open(abs_path, "r", encoding="utf-8", errors="replace") as f:
            current_content = f.read()
    except Exception:
        current_content = None

content, ok = gate_lib.gate_reconstruct_write(tool, ti, current_content)
if not ok:
    deny("could not reconstruct the resulting content of this %s call "
         "(missing content/old_string/new_string, or old_string not found "
         "in the current file) — refusing rather than checking a partial "
         "or guessed view of the document." % tool)
if not content:
    allow()  # empty resulting content: nothing to check

# Citation shape: a claim/source separator (em-dash `—`, ASCII `--`, or a
# space-hyphen-space ` - `) followed, somewhere on the rest of the line or
# shortly after, by "source:"-shaped text, a URL, a path:line reference, or
# a check-name score.
CITATION_RE = re.compile(r"(?:—|--| - )\s*.*(?:source:|https?://|[\w./-]+:\d+)", re.IGNORECASE)

def is_claim_line(line):
    return bool(re.match(r"^\s*(?!#)(?!\s*$).*[.:]\s*$", line))

def line_has_citation(line):
    return bool(CITATION_RE.search(line))

if is_phase1:
    m = re.search(r"^##\s*Evidence format\s*$", content, re.M | re.I)
    if not m:
        allow()  # section absent entirely: nothing to check (per spec)
    sec_start = m.end()
    nxt = re.search(r"^##\s+\S", content[sec_start:], re.M)
    sec_end = sec_start + nxt.start() if nxt else len(content)
    section = content[sec_start:sec_end].strip()
    if not section:
        allow()  # bare/empty section: nothing to check (per spec)
    lines = section.splitlines()
    uncited = []
    for i, line in enumerate(lines):
        if not is_claim_line(line):
            continue
        nearby = lines[max(0, i - 1):i + 2]
        if not any(line_has_citation(l) for l in nearby):
            uncited.append(line.strip())
    if uncited:
        deny("the '## Evidence format' section has claim-shaped line(s) with "
             "no citation on the same or an adjacent line: %s. Required "
             "format: '<claim> — <source: URL | path:line | check-name "
             "score>' (ASCII '--' or ' - ' also accepted)." % "; ".join(uncited[:3]))
    allow()

if is_phase2:
    lines = content.splitlines()
    uncited = []
    for i, line in enumerate(lines):
        if not is_claim_line(line):
            continue
        nearby = lines[max(0, i - 1):i + 2]
        if any(line_has_citation(l) for l in nearby):
            continue
        uncited.append(line.strip())
    if not uncited:
        allow()

    # Carry-forward exception: a claim-shaped line with no adjacent
    # citation is still allowed if it is a verbatim (case-insensitive
    # substring) match of a sentence already present in the phase-1
    # proposal's own content (carried forward, not re-derived) — the same
    # cross-file lookup madr-options/hooks/options-gate.sh already
    # performs for its own carry-forward check.
    m = re.match(r"^docs/issue-([0-9]+)/reports/technical-feasibility\.md$", rel)
    issue_n = m.group(1) if m else None
    proposal_content = ""
    if issue_n:
        import glob
        matches = sorted(glob.glob(os.path.join(
            root, "docs", "issue-%s" % issue_n, "proposals", "*technical-feasibility*.md")))
        if matches:
            try:
                with open(matches[0], "r", encoding="utf-8", errors="replace") as f:
                    proposal_content = f.read()
            except Exception:
                proposal_content = ""
    proposal_lower = proposal_content.lower()

    still_uncited = [
        line for line in uncited
        if not (proposal_lower and line.lower() in proposal_lower)
    ]
    if still_uncited:
        deny("this record has claim-shaped line(s) with no citation on the "
             "same or an adjacent line, and not verbatim-carried-forward from "
             "the phase-1 proposal: %s. Citations from phase 1 must be "
             "carried forward, and any new claim needs its own citation "
             "('<claim> — <source: URL | path:line | check-name score>')." %
             "; ".join(still_uncited[:3]))
    allow()

allow()
PY
rc=$?
if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then
  echo "evidence-citation: DENIED (citation-gate) — fail-closed: internal error (judge exited $rc)" >&2
  exit 2
fi
exit "$rc"
