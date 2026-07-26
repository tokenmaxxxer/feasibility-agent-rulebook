#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit|Bash): §19 front-record
# side. Peer to state-gate.sh on the identical target path
# (docs/reports/records/<subject>/feasibility.md). state-gate.sh checks the
# scope-proposed -> scope-approved transition is a legal table row; THIS gate
# adds the human-signal check the bare table row cannot express: a
# scope-proposed -> scope-approved write requires a human-placed, unconsumed
# approval token for the subject (mirroring qa-cycle's capture-verdict.sh
# token mechanism). The hook NEVER performs the approval — it only refuses an
# unsignaled one. Everything that is not this specific transition is allowed
# through untouched.
#
# Bash coverage (docs/proposals/2026-07-26-scope-record-gate-bash-bypass.md):
# this gate used to fire only on Write/Edit/MultiEdit/NotebookEdit, so a
# Bash-authored write to the front record (redirect, heredoc, tee, sed -i,
# `Path(...).write_text(...)`, `open(...).write(...)`) could land
# scope-approved with zero human token. hooks.json now also routes Bash here.
# The Bash branch judges a write by its RESOLVED TARGET PATH and, where
# extractable, its LITERAL resulting frontmatter `status:` — never by tool
# name. Any Bash write that reaches (or may reach, given an unresolvable
# target/content) the front record is refused unless both target and content
# are literally determined and shown not to set scope-approved (or a valid
# token covers the transition). This never mints or infers a token.
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

FRONT_RECORD_RE = re.compile(r"^docs/reports/records/([^/]+)/feasibility\.md$")

def frontmatter_status(text):
    if not (text or "").startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    block = text[3:end]
    ms = re.findall(r"^status:\s*(.*?)\s*(?:#.*)?$", block, re.M)
    if len(ms) != 1:
        return None
    return ms[0].strip().rstrip("\r").strip().lower()

def require_token_and_check(root, subject):
    """Shared §19 enforcement for scope-proposed -> scope-approved, used
    identically by the Write path and the Bash path below. Read-only check
    (unlike product-cycle's single-use token, this repo's existing Write
    path never consumed the token either — preserved as-is, not widened)."""
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
             "unilaterally, per contract §19 — regardless of which tool authors the write." % (subject, subject))
    try:
        if os.path.getsize(token_real) == 0:
            deny("approval token for subject '%s' is empty; a valid human-placed token is "
                 "required. Refusing per §19." % subject)
    except OSError:
        deny("approval token for subject '%s' could not be read; refusing per §19." % subject)

cwd = os.environ.get("FEAS_CWD", "")
cpd = os.environ.get("FEAS_CPD", "")

if tool == "Bash":
    command = ti.get("command")
    if not isinstance(command, str) or not command.strip():
        deny("Bash call has no usable command string (fail-closed).")

    root = cpd if plausible_root(cpd) else (git_top(cwd) or None)
    if not root:
        deny("no project root could be determined for this Bash call (fail-closed).")
    root = os.path.realpath(root)

    def repo_rel(tgt):
        norm_ = tgt.replace("\\", "/")
        absu = posixpath.normpath(norm_ if posixpath.isabs(norm_) else posixpath.join(root, norm_))
        resolved_ = posixpath.normpath(os.path.realpath(absu).replace("\\", "/"))
        if resolved_ == root or not resolved_.startswith(root + "/"):
            return None
        return resolved_[len(root) + 1:]

    LITERAL_TOKEN_RE = re.compile(r'^[A-Za-z0-9_./\-]+$')

    def literal_target_or_none(raw_token):
        if not raw_token:
            return None
        tok = raw_token
        if len(tok) >= 2 and tok[0] == tok[-1] and tok[0] in "\"'":
            inner = tok[1:-1]
            return inner if LITERAL_TOKEN_RE.match(inner) else None
        if LITERAL_TOKEN_RE.match(tok):
            return tok
        return None

    TREE_HINT = "docs/reports/records/"
    determined = []  # (subject, abs_path, new_text)
    determined_rels = set()  # repo-relative targets already fully resolved above,
                              # so the coarser OTHER_WRITE_RES redirect pattern below
                              # (which also matches a heredoc's own `>`/`>>`) does not
                              # re-flag the SAME write as ambiguous.

    # A heredoc's redirect target and its `<<MARKER` introducer may appear in
    # either order on the header line (`cat > f <<'EOF'` or
    # `cat <<'EOF' > f`) — match the whole header line first, then pull the
    # redirect target out of it independently of ordering.
    HEREDOC_HEADER_RE = re.compile(
        r"(?m)^([^\n]*<<-?\s*(['\"]?)(\w+)\2[^\n]*)\n(.*?)\n[ \t]*\3\b", re.S)
    HEREDOC_TARGET_RE = re.compile(r'(?:^|[\s;&|])\d?>{1,2}(?!\&)\s*([^\s;&|<>]+)')
    for hm in HEREDOC_HEADER_RE.finditer(command):
        header, content = hm.group(1), hm.group(4)
        tm = HEREDOC_TARGET_RE.search(header)
        cand = literal_target_or_none(tm.group(1)) if tm else None
        rel = repo_rel(cand) if cand else None
        m = FRONT_RECORD_RE.match(rel) if rel else None
        if m:
            determined.append((m.group(1), posixpath.join(root, rel), content))
            determined_rels.add(rel)

    WT_CONTENT_RE = re.compile(
        r"(['\"])([^'\"]*)\1\s*\)\s*\.\s*write_(?:text|bytes)\s*\(\s*"
        r"(?:'''(.*?)'''|\"\"\"(.*?)\"\"\"|'([^']*)'|\"([^\"]*)\")", re.S)
    for wm in WT_CONTENT_RE.finditer(command):
        cand = literal_target_or_none(wm.group(2))
        rel = repo_rel(cand) if cand else None
        m = FRONT_RECORD_RE.match(rel) if rel else None
        if m:
            content = next((g for g in wm.groups()[2:] if g is not None), "")
            determined.append((m.group(1), posixpath.join(root, rel), content))

    OPEN_CONTENT_RE = re.compile(
        r"open\s*\(\s*(['\"])([^'\"]*)\1\s*,\s*['\"][wxa][^'\"]*['\"]\s*\)\s*\.\s*write\s*\(\s*"
        r"(?:'''(.*?)'''|\"\"\"(.*?)\"\"\"|'([^']*)'|\"([^\"]*)\")", re.S)
    for om in OPEN_CONTENT_RE.finditer(command):
        cand = literal_target_or_none(om.group(2))
        rel = repo_rel(cand) if cand else None
        m = FRONT_RECORD_RE.match(rel) if rel else None
        if m:
            content = next((g for g in om.groups()[2:] if g is not None), "")
            determined.append((m.group(1), posixpath.join(root, rel), content))

    OTHER_WRITE_RES = [
        re.compile(r'(?:^|[\s;&|])\d?>{1,2}(?!\&)\s*([^\s;&|<>]+)'),
        re.compile(r'\btee\b(?:\s+-a)?\s+([^\s;&|<>]+)'),
        re.compile(r'\b(?:sed|perl|ruby)\b[^|;&\n]*\s-i\b[A-Za-z0-9_.\-]*\s+([^\s;&|<>]+)'),
        re.compile(r'\bcp\b\s+.*?([^\s;&|<>]+)\s*(?:[;&|\n]|$)'),
        re.compile(r'\bmv\b\s+.*?([^\s;&|<>]+)\s*(?:[;&|\n]|$)'),
        re.compile(r'\bdd\b[^|;&\n]*\bof=([^\s;&|<>]+)'),
        re.compile(r'\binstall\b\s+.*?([^\s;&|<>]+)\s*(?:[;&|\n]|$)'),
    ]
    any_write_op = bool(HEREDOC_HEADER_RE.search(command)) or bool(WT_CONTENT_RE.search(command)) or bool(OPEN_CONTENT_RE.search(command))
    ambiguous_tree_hit = False
    for rgx in OTHER_WRITE_RES:
        for m in rgx.finditer(command):
            any_write_op = True
            cand = literal_target_or_none(m.group(1))
            hit = False
            if cand is not None:
                rel = repo_rel(cand)
                if rel is not None and FRONT_RECORD_RE.match(rel) and rel not in determined_rels:
                    hit = True
            elif TREE_HINT in command:
                hit = True
            if hit:
                ambiguous_tree_hit = True
    if re.search(r"\.\s*write_(?:text|bytes)\s*\(", command) and not WT_CONTENT_RE.search(command):
        any_write_op = True
        if TREE_HINT in command:
            ambiguous_tree_hit = True
    if re.search(r"\bopen\s*\([^)]*,\s*['\"][wxa][^'\"]*['\"]\s*\)", command) and not OPEN_CONTENT_RE.search(command):
        any_write_op = True
        if TREE_HINT in command:
            ambiguous_tree_hit = True

    if not any_write_op:
        allow()

    if ambiguous_tree_hit:
        deny(
            "a Bash write reaches (or may reach, given an unresolvable target or content) the "
            "owned front-record path docs/reports/records/<subject>/feasibility.md, and this "
            "gate could not literally determine both the target and the resulting content. Per "
            "the frozen fail-closed contract "
            "(docs/proposals/2026-07-26-scope-record-gate-bash-bypass.md), an indeterminate Bash "
            "write into the front record is refused rather than allowed through — use Write "
            "instead, or make the target and content fully literal."
        )

    for subject, abs_path, new_text in determined:
        new_status = frontmatter_status(new_text)
        if new_status != "scope-approved":
            continue
        if os.path.exists(abs_path):
            try:
                with open(abs_path, encoding="utf-8-sig") as fh:
                    old_status = frontmatter_status(fh.read(1 << 20))
            except OSError:
                old_status = None
        else:
            old_status = "(none)"
        if old_status == "scope-approved":
            continue
        if old_status != "scope-proposed":
            # Same rule the Write path applies: only scope-proposed ->
            # scope-approved is token-gated; anything else is this gate's
            # concern only insofar as it cannot silently mint scope-approved
            # from an unknown/unparseable prior state — fail closed here too.
            if old_status is None:
                deny("a Bash write would set subject '%s' front record to scope-approved but its "
                     "current on-disk status could not be determined (fail-closed)." % subject)
            continue
        require_token_and_check(root, subject)

    allow()

path = ti.get("file_path") or ti.get("notebook_path")
if not isinstance(path, str) or not path:
    # No target path on a write-shaped call is malformed input -> fail closed.
    deny("write call carries no file_path.")

norm = path.replace("\\", "/")

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

require_token_and_check(root, subject)
allow()
PY
