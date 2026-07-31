#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
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
set -euo pipefail

# Drain stdin unconditionally first, so an upstream pipe never sees SIGPIPE
# from an early exit (e.g. the kill switch below) under `set -o pipefail`.
payload="$(cat 2>/dev/null || true)"

case "$(printf '%s' "${MADR_OPTIONS_GATE_OFF:-}" | tr '[:upper:]' '[:lower:]')" in
  1|true|yes|on) exit 0 ;;
esac

deny() { echo "madr-options: DENIED (options-gate) — $1" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || deny "python3 is required and was not found."

[ -n "$payload" ] || deny "no tool-input payload was received."

set +e
MADR_PAYLOAD="$payload" MADR_CPD="${CLAUDE_PROJECT_DIR:-}" MADR_CWD="$(pwd -P)" python3 <<'PY'
import json, os, posixpath, re, sys, subprocess, glob

def deny(m): print("madr-options: DENIED (options-gate) - %s" % m, file=sys.stderr); sys.exit(2)
def allow(): sys.exit(0)

def _fc_hook(_t, _v, _tb):
    try:
        sys.stderr.write("madr-options: DENIED (options-gate) - fail-closed: internal error: %s\n" % _v)
    except Exception:
        pass
    os._exit(2)
sys.excepthook = _fc_hook

try:
    event = json.loads(os.environ.get("MADR_PAYLOAD", ""))
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

if tool not in ("Write", "Edit", "MultiEdit"):
    allow()

path = ti.get("file_path")
if not isinstance(path, str) or not path:
    allow()  # nothing to key off of; not this gate's concern

def plausible_root(d):
    return bool(d) and os.path.isdir(d) and os.path.exists(os.path.join(d, ".git"))
def git_top(d):
    try:
        r = subprocess.run(["git","-C",d,"rev-parse","--show-toplevel"],capture_output=True,text=True)
        return (r.stdout.strip() or None) if r.returncode == 0 else None
    except Exception:
        return None

norm = path.replace("\\","/")
cpd = os.environ.get("MADR_CPD",""); cwd = os.environ.get("MADR_CWD","")
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

PHASE1_RE = re.compile(r"^docs/issue-([0-9]+)/proposals/.*technical-feasibility.*\.md$")
PHASE2_RE = re.compile(r"^docs/issue-([0-9]+)/reports/technical-feasibility\.md$")

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
