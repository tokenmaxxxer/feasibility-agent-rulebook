#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook (Write|Edit|MultiEdit): OpenSSF-Scorecard-style mandatory
# evidence citation format enforcement. Peer methodology gate for the
# technical-feasibility cycle's two write surfaces (phase-1 proposal,
# phase-2 record). Required format:
#   <claim> — <source: URL | path:line | check-name score>
#
# This is a best-effort heuristic gate and the highest false-positive-risk
# gate in the technical-feasibility methodology set by design (see the
# accepted proposal, docs/issue-39/proposals/
# 2026-07-31-technical-feasibility-methodology-enforcement.md, section
# "evidence-citation"). Known limitations, documented rather than hidden:
#   - It cannot verify a citation is TRUE, only that something citation-shaped
#     is present near a claim.
#   - The phase-2 "new claim with no citation" heuristic is intentionally
#     permissive: on any ambiguity it leans ALLOW rather than block writing,
#     per the proposal's stated risk tolerance for this check.
#   - Only Write payloads carry full content; Edit/MultiEdit are checked
#     against the tool_input's available content fields (old_string/
#     new_string/edits) on a best-effort basis, not a merged final-file view.
#
# Fail-closed: malformed/missing input, unresolvable root => DENY.
# Kill switch: EVIDENCE_CITATION_GATE_OFF=1 (1/true/yes/on, any case).

set -uo pipefail

# Drain stdin first regardless of the kill switch, so an upstream writer
# piping the payload in never sees a broken pipe (SIGPIPE) from an early exit.
payload="$(cat 2>/dev/null || true)"

case "$(printf '%s' "${EVIDENCE_CITATION_GATE_OFF:-}" | tr '[:upper:]' '[:lower:]')" in
  1|true|yes|on) exit 0 ;;
esac

set -e
deny() { echo "evidence-citation: DENIED (citation-gate) — $1" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || deny "python3 is required and was not found."

[ -n "$payload" ] || deny "no tool-input payload was received."

set +e
EC_PAYLOAD="$payload" python3 <<'PY'
import json, os, re, sys

def deny(m): print("evidence-citation: DENIED (citation-gate) - %s" % m, file=sys.stderr); sys.exit(2)
def allow(): sys.exit(0)

# Fail-closed on any internal error (uncaught exception) rather than the
# default fail-open exit 1.
def _fc_hook(_t, _v, _tb):
    try:
        sys.stderr.write("evidence-citation: DENIED (citation-gate) - fail-closed: internal error: %s\n" % _v)
    except Exception:
        pass
    os._exit(2)
sys.excepthook = _fc_hook

try:
    event = json.loads(os.environ.get("EC_PAYLOAD", ""))
except ValueError:
    deny("tool-input payload is not valid JSON.")
if not isinstance(event, dict):
    deny("tool-input payload is not a JSON object.")

tool = event.get("tool_name")
ti = event.get("tool_input")
if not isinstance(tool, str) or not tool:
    deny("tool_name missing from payload.")
if tool not in ("Write", "Edit", "MultiEdit"):
    allow()  # not a write-surface tool this gate cares about
if not isinstance(ti, dict):
    deny("tool_input missing or malformed in payload.")

path = ti.get("file_path")
if not isinstance(path, str) or not path:
    deny("write call carries no file_path.")

norm = path.replace("\\", "/").lstrip("/")

PHASE1 = re.compile(r"^docs/issue-[0-9]+/proposals/.*technical-feasibility.*\.md$")
PHASE2 = re.compile(r"^docs/issue-[0-9]+/reports/technical-feasibility\.md$")

is_phase1 = bool(PHASE1.match(norm))
is_phase2 = bool(PHASE2.match(norm))
if not (is_phase1 or is_phase2):
    allow()  # foreign path; nothing to gate

# Best-effort content extraction: Write carries the whole file; Edit/
# MultiEdit only carry a diff fragment, so we check whatever text is
# available (the new content being introduced) rather than refusing
# outright, since this gate (unlike record-fields-gate) does not require
# whole-document judgment for every case.
def extract_text(tool_name, tool_input):
    parts = []
    if tool_name == "Write":
        c = tool_input.get("content")
        if isinstance(c, str):
            parts.append(c)
    elif tool_name == "Edit":
        for k in ("new_string",):
            v = tool_input.get(k)
            if isinstance(v, str):
                parts.append(v)
    elif tool_name == "MultiEdit":
        edits = tool_input.get("edits")
        if isinstance(edits, list):
            for e in edits:
                if isinstance(e, dict):
                    v = e.get("new_string")
                    if isinstance(v, str):
                        parts.append(v)
    return "\n".join(parts)

content = extract_text(tool, ti)
if not content:
    # Nothing new to judge (e.g. an Edit with no readable new_string) ->
    # nothing to check against; allow rather than block on absence of data.
    allow()

# Citation shape: an em-dash followed, somewhere on the rest of the line or
# shortly after, by "source:"-shaped text, a URL, a path:line reference, or
# a check-name score. Kept permissive per the proposal's stated tolerance.
CITATION_RE = re.compile(r"—\s*.*(?:source:|https?://|[\w./-]+:\d+)", re.IGNORECASE)
ANY_CITATION_IN_DOC = bool(CITATION_RE.search(content))

if is_phase1:
    # Look for a "## Evidence format" section (case-insensitive) up to the
    # next level-2 heading or end of document.
    m = re.search(r"^##\s*Evidence format\s*$", content, re.M | re.I)
    if not m:
        allow()  # section absent entirely: nothing to check (per spec)
    sec_start = m.end()
    nxt = re.search(r"^##\s+\S", content[sec_start:], re.M)
    sec_end = sec_start + nxt.start() if nxt else len(content)
    section = content[sec_start:sec_end].strip()
    if not section:
        allow()  # bare/empty section: nothing to check (per spec)
    if not CITATION_RE.search(section):
        deny("the '## Evidence format' section has prose content but no "
             "citation shaped like '<claim> - <source: URL | path:line | "
             "check-name score>'. A bare/empty section is fine; a section "
             "with prose must carry at least one such citation.")
    allow()

if is_phase2:
    # Best-effort: a "new factual claim" heuristic is a line ending in a
    # period or colon that has no em-dash citation anywhere on it. Per the
    # proposal's stated risk tolerance, this check leans ALLOW: it only
    # denies when the WHOLE document has zero citations anywhere AND at
    # least one such claim-shaped line is present. Any citation anywhere in
    # the document is treated as satisfying "carried forward" and the check
    # allows, since this heuristic cannot reliably tell a carried-forward
    # claim from a newly re-derived one.
    if ANY_CITATION_IN_DOC:
        allow()
    claim_line = re.compile(r"^\s*(?!#)(?!\s*$).*[.:]\s*$")
    lines = content.splitlines()
    has_claim_like_line = any(
        claim_line.match(line) and "—" not in line and "-" * 3 not in line
        for line in lines
    )
    if has_claim_like_line:
        deny("this record appears to contain new factual-claim-shaped "
             "content but the document has zero citations anywhere. "
             "Citations from phase 1 must be carried forward, and any new "
             "claim needs its own citation in the format '<claim> - "
             "<source: URL | path:line | check-name score>'. (Best-effort "
             "heuristic: false positives are possible on non-claim prose; "
             "if this is a false positive, add the carried-forward citation "
             "or rephrase.)")
    allow()  # no claim-shaped line detected; nothing to flag

allow()
PY
rc=$?
if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then
  echo "evidence-citation: DENIED (citation-gate) — fail-closed: internal error (judge exited $rc)" >&2
  exit 2
fi
exit "$rc"
