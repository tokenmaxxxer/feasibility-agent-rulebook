#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|MultiEdit): MADR "Candidates/Options considered"
# discipline (see ../directive-fragment.md).
#
# Owned write-surface paths:
#   phase-1: docs/issue-<n>/proposals/*technical-feasibility*.md
#   phase-2: docs/issue-<n>/reports/technical-feasibility.md
#
# Phase-1 check: a `## Candidates considered` section naming 2+ candidates,
# each followed by non-empty prose (the one-line reason) — AND a
# `## Timebox and acceptance criteria` section present in the same content
# (the order-constraint check this gate also owns).
#
# Phase-2 check: every candidate name found in the phase-1 proposal's
# `## Candidates considered` section (same issue number, best-effort file
# lookup) must appear in this write's `Options considered` section, or the
# record must carry `dropped: <reason>` for that name.
#
# Heuristic limits (documented, not fixed): "one-line reason" is approximated
# as "non-empty text follows the candidate marker" — it cannot verify the
# reason is substantive. Candidate-name matching across phase-1/phase-2 is a
# best-effort case-insensitive substring match, not semantic identity.
#
# Fail-closed: malformed/missing input, unresolvable root => DENY.
# Kill switch: MADR_OPTIONS_GATE_OFF=1 (1/true/yes/on disables).
#
# Referenced (never copied) from core's gate-house standard (issue-72):
# core/hooks/lib/gate-lib.sh / gate-lib.py, per docs/handbooks/
# canon-scripts.md's reference-not-copy rule.

. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" 2>/dev/null && pwd -P)}/hooks/lib/gate-lib.sh" \
  || { echo "madr-options: DENIED (options-gate) — gate-lib.sh not found; set CLAUDE_PLUGIN_ROOT_CORE to core's plugin root" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail

# Drain stdin unconditionally first, so an upstream pipe never sees SIGPIPE
# from an early exit (e.g. the kill switch below) under `set -o pipefail`.
payload="$(cat 2>/dev/null || true)"

gate_kill_switch_active "${MADR_OPTIONS_GATE_OFF:-}" || { trap - EXIT; exit 0; }

deny() { gate_deny "madr-options (options-gate)" "$1"; }
command -v python3 >/dev/null 2>&1 || deny "python3 is required and was not found."

[ -n "$payload" ] || deny "no tool-input payload was received."

set +e
MADR_PAYLOAD="$payload" MADR_CPD="${CLAUDE_PROJECT_DIR:-}" MADR_CWD="$(pwd -P)" GATE_LIB_PY="$GATE_LIB_PY" python3 <<'PY'
import importlib.util, json, os, posixpath, re, sys, subprocess, glob

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate_lib)

def deny(m): print("madr-options: DENIED (options-gate) - %s" % m, file=sys.stderr); sys.exit(2)
def allow(): sys.exit(0)

def _fc_hook(_t, _v, _tb):
    try:
        sys.stderr.write("madr-options: DENIED (options-gate) - fail-closed: internal error: %s\n" % _v)
    except Exception:
        pass
    os._exit(2)
sys.excepthook = _fc_hook

event = gate_lib.gate_parse_json_or_deny(os.environ.get("MADR_PAYLOAD", ""), deny)

tool = event.get("tool_name")
ti = event.get("tool_input")
if not isinstance(tool, str) or not tool:
    deny("tool_name missing from payload.")
if not isinstance(ti, dict):
    deny("tool_input missing or malformed in payload.")

if tool not in ("Write", "Edit", "MultiEdit", "Bash"):
    allow()

def plausible_root(d):
    return bool(d) and os.path.isdir(d) and os.path.exists(os.path.join(d, ".git"))
def git_top(d):
    try:
        r = subprocess.run(["git","-C",d,"rev-parse","--show-toplevel"],capture_output=True,text=True)
        return (r.stdout.strip() or None) if r.returncode == 0 else None
    except Exception:
        return None

cpd = os.environ.get("MADR_CPD",""); cwd = os.environ.get("MADR_CWD","")

def resolve_root(anchor_path):
    r = None
    if plausible_root(cpd):
        r = os.path.realpath(cpd)
    if r is None:
        base = anchor_path.replace("\\","/")
        base = base if posixpath.isabs(base) else posixpath.join(cwd, base)
        d = base if os.path.isdir(base) else posixpath.dirname(base)
        r = git_top(d) or git_top(cwd)
    return r

PHASE1_RE = re.compile(r"^docs/issue-([0-9]+)/proposals/.*technical-feasibility.*\.md$")
PHASE2_RE = re.compile(r"^docs/issue-([0-9]+)/reports/technical-feasibility\.md$")

if tool == "Bash":
    cmdline = ti.get("command")
    if not isinstance(cmdline, str):
        deny("Bash payload carries no command string.")
    root = resolve_root(cwd)
    if not root:
        deny("no project root could be determined; refusing rather than silently allowing.")
    for tok in re.findall(r"[\w./~$-]+", cmdline):
        rel_tok = gate_lib.gate_normalize_path(root, tok)
        if rel_tok and (PHASE1_RE.match(rel_tok) or PHASE2_RE.match(rel_tok)):
            deny("a Bash command appears to write to a madr-options-owned "
                 "path (%s); this gate cannot verify content written "
                 "outside Write/Edit/MultiEdit, so it refuses rather than "
                 "silently allowing an unchecked write." % rel_tok)
    allow()

path = ti.get("file_path")
if not isinstance(path, str) or not path:
    allow()  # nothing to key off of; not this gate's concern

root = resolve_root(path)
if not root:
    deny("no project root could be determined; refusing rather than silently allowing.")

rel = gate_lib.gate_normalize_path(root, path)
if rel is None:
    allow()  # resolves outside root; nothing to gate

m1 = PHASE1_RE.match(rel)
m2 = PHASE2_RE.match(rel)
if not m1 and not m2:
    allow()  # foreign path; not this gate's concern

# Only a complete Write can be judged; Edit/MultiEdit are partial diffs.
if tool != "Write":
    deny("an Edit/MultiEdit targets a madr-options-owned path; this gate needs "
         "the complete content. Rewrite the whole file with Write so the "
         "Candidates/Options considered sections can be verified.")

content = ti.get("content")
if not isinstance(content, str):
    deny("Write carries no readable content.")

def extract_section(body, heading_regex):
    """Return the text of the first section whose heading matches
    heading_regex, up to (not including) the next heading of the same or
    shallower level, or end of document."""
    lines = body.splitlines()
    heads = []
    for i, line in enumerate(lines):
        hm = re.match(r"^(#{1,6})\s+(.*?)\s*#*\s*$", line)
        if hm:
            heads.append((i, len(hm.group(1)), hm.group(2).strip()))
    for idx, (i, level, text) in enumerate(heads):
        if heading_regex.match(text):
            end = len(lines)
            for j2, lvl2, _ in heads[idx+1:]:
                if lvl2 <= level:
                    end = j2
                    break
            return "\n".join(lines[i+1:end])
    return None

def candidate_items(section_text):
    """Best-effort candidate extraction: list-item markers ('- ', '* ', '1. ')
    or sub-headers (### Name) at the top of the section. Each candidate's
    'reason' is the non-empty text on/after its marker line, up to the next
    marker or blank-then-marker. This is a heuristic — it approximates
    'one-line reason' as 'non-empty prose follows the item', it does not
    verify substantive content."""
    items = []
    lines = section_text.splitlines()
    marker_re = re.compile(r"^\s*(?:[-*]|\d+\.)\s+(.*\S)\s*$")
    header_re = re.compile(r"^#{1,6}\s+(.*\S)\s*$")
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        mm = marker_re.match(line)
        hm = header_re.match(line)
        if mm:
            name_and_reason = mm.group(1)
            reason = name_and_reason
            j = i + 1
            while j < n and not marker_re.match(lines[j]) and not header_re.match(lines[j]):
                if lines[j].strip():
                    reason = reason + " " + lines[j].strip()
                j += 1
            items.append((name_and_reason, reason.strip()))
            i = j
            continue
        if hm:
            name = hm.group(1)
            reason = ""
            j = i + 1
            while j < n and not marker_re.match(lines[j]) and not header_re.match(lines[j]):
                if lines[j].strip():
                    reason = (reason + " " + lines[j].strip()).strip()
                j += 1
            items.append((name, reason))
            i = j
            continue
        i += 1
    return items

if m1:
    cand_section = extract_section(content, re.compile(r"^Candidates considered$"))
    if cand_section is None:
        deny("phase-1 write is missing a '## Candidates considered' section.")
    items = candidate_items(cand_section)
    if len(items) < 2:
        deny("'## Candidates considered' must enumerate 2 or more candidates "
             "(found %d); a single-candidate list is a foregone conclusion, "
             "not a comparison." % len(items))
    for name, reason in items:
        if not reason.strip():
            deny("candidate '%s' has no one-line reason (non-empty prose) "
                 "attached." % name)
    timebox_section = extract_section(content, re.compile(r"^Timebox and acceptance criteria$"))
    if timebox_section is None:
        deny("phase-1 write is missing the '## Timebox and acceptance "
             "criteria' section required alongside '## Candidates "
             "considered' (order constraint: timebox-before-candidates).")
    allow()

if m2:
    issue_n = m2.group(1)
    opts_section = extract_section(content, re.compile(r"^Options considered$"))
    if opts_section is None:
        deny("phase-2 write is missing an 'Options considered' section.")
    opts_lower = opts_section.lower()

    # Best-effort: find the corresponding phase-1 proposal for this issue.
    proposal_glob = os.path.join(root, "docs", "issue-%s" % issue_n, "proposals",
                                  "*technical-feasibility*.md")
    matches = sorted(glob.glob(proposal_glob))
    if not matches:
        # No phase-1 proposal found for this issue: nothing to carry forward
        # from, so the carry-forward check cannot be applied. Best-effort —
        # allow rather than block on a check we have no basis for.
        allow()

    proposal_path = matches[0]
    try:
        with open(proposal_path, "r", encoding="utf-8", errors="replace") as f:
            proposal_content = f.read()
    except Exception:
        allow()  # unreadable proposal; nothing to check against

    p1_cand_section = extract_section(proposal_content, re.compile(r"^Candidates considered$"))
    if p1_cand_section is None:
        allow()  # phase-1 proposal itself has no candidates section; nothing to carry forward
    p1_items = candidate_items(p1_cand_section)

    def cand_name(name_and_reason):
        # Trim trailing " — reason"/" - reason"/": reason" so we key off the
        # name-ish leading token(s), best-effort.
        n = re.split(r"\s+[—-]\s+|\s*:\s+", name_and_reason, maxsplit=1)[0]
        return n.strip().strip("*").strip()

    missing = []
    for name_and_reason, _reason in p1_items:
        name = cand_name(name_and_reason)
        if not name:
            continue
        name_l = name.lower()
        if name_l in opts_lower:
            continue
        dropped_re = re.compile(re.escape(name_l) + r"[^\n]*dropped\s*:", re.I)
        if dropped_re.search(opts_lower) or ("dropped:" in opts_lower and name_l in opts_lower):
            continue
        missing.append(name)

    if missing:
        deny("phase-1 candidate(s) not carried into phase-2 'Options "
             "considered' and not marked 'dropped: <reason>': %s" %
             ", ".join(missing))
    allow()

allow()
PY
rc=$?
if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then
  echo "madr-options: DENIED (options-gate) — fail-closed: internal error (judge exited $rc)" >&2
  exit 2
fi
exit "$rc"
