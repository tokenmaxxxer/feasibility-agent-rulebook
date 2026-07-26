#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
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
# Tool-agnostic default-deny (docs/proposals/2026-07-26-scope-record-gate-tool-agnostic.md):
# the Write-only path used to deny every Edit/MultiEdit/NotebookEdit
# unconditionally, which is safe but over-broad (it also blocked legitimate
# non-transition writes via those tools). Edit/MultiEdit are now evaluated by
# applying the edit to on-disk content, same shape as Write; any other tool
# (NotebookEdit included) is judged by whether its payload exposes a
# content-bearing field (new_source/cells/etc) — if none can be found, the
# call is refused rather than allowed. There is no tool name for which this
# gate silently allows an indeterminate write to the front record.
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

set +e
FEAS_PAYLOAD="$payload" FEAS_CPD="${CLAUDE_PROJECT_DIR:-}" FEAS_CWD="$(pwd -P)" python3 <<'PY'
import json, os, posixpath, re, sys, subprocess

def deny(m): print("feasibility-cycle: DENIED (scope-record-gate) - %s" % m, file=sys.stderr); sys.exit(2)
def allow(): sys.exit(0)

# PYTHON LAYER (fail-closed on internal error): any uncaught exception —
# including os.path.* raising ValueError on a null-byte/undecodable path —
# becomes exit 2 (DENY), never the default exit 1 (fail-open). SystemExit from
# allow()/deny() bypasses excepthook, so the verdict paths are unchanged.
def _feas_fc_hook(_t, _v, _tb):
    try:
        sys.stderr.write("feasibility-cycle: DENIED (scope-record-gate) - fail-closed: internal error: %s\n" % _v)
    except Exception:
        pass
    os._exit(2)
sys.excepthook = _feas_fc_hook

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

# Read-only-tool passthrough (docs/proposals/2026-07-26-scope-record-gate-deny-on-ambiguity.md
# regression fix): this gate only governs transitions that MUTATE the front
# record's status to scope-approved. A tool that cannot write at all — Read,
# Grep, Glob, LS, or any other tool whose payload carries no content/write
# intent — is never a scope-approved transition, so it is never this gate's
# concern regardless of which path (e.g. the catch-all `.*` PreToolUse
# matcher) routed it here. This is a tool-identity passthrough, not a
# content-shape default-allow: the tool-agnostic default-deny below still
# applies to every tool NOT in this fixed known-read-only set, including any
# future/unknown tool name.
#
# `Skill` belongs in that set, and leaving it out made this plugin's own
# skills unreachable: the Skill tool's payload carries a skill name and no
# file path, so it fell through to the default-deny and was refused every
# time. Measured 2026-07-27 on a real run of the sibling product rulebook,
# which carries the same gate. A gate that blocks the rulebook from reading
# its own rulebook is guarding nothing: invoking a skill loads instructions
# into context and writes nothing, and every tool the skill then reaches for
# arrives here on its own and is judged on its own.
if tool in ("Read", "Grep", "Glob", "LS", "Skill"):
    allow()

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
    # Deny-on-ambiguity (docs/proposals/2026-07-26-scope-record-gate-deny-on-ambiguity.md):
    # an UNQUOTED heredoc marker (`<<EOF`, not `<<'EOF'`/`<<"EOF"`) means the
    # real shell performs parameter/command expansion on the body before it
    # is written to disk. If that body contains ANY expansion marker ($,
    # backtick, $(...), ${...}), this gate cannot prove the unexpanded text
    # it sees is what actually lands on disk — a `$VAR` could resolve to
    # `scope-approved` at runtime. Such a body is never treated as a literal;
    # a heredoc write whose literal target reaches (or, if unresolvable,
    # might reach) the front record with a non-provable body is refused.
    # A QUOTED heredoc marker disables shell expansion entirely, so its body
    # is still provably literal even if it happens to contain a `$`.
    SHELL_EXPANSION_RE = re.compile(r'\$|`')
    ambiguous_tree_hit = False
    for hm in HEREDOC_HEADER_RE.finditer(command):
        header, quote, content = hm.group(1), hm.group(2), hm.group(4)
        tm = HEREDOC_TARGET_RE.search(header)
        cand = literal_target_or_none(tm.group(1)) if tm else None
        rel = repo_rel(cand) if cand else None
        m = FRONT_RECORD_RE.match(rel) if rel else None
        if not m:
            continue
        if quote == "" and SHELL_EXPANSION_RE.search(content):
            ambiguous_tree_hit = True
            continue
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

def _read_disk_resolved():
    if not os.path.exists(resolved):
        return None
    try:
        with open(resolved, encoding="utf-8-sig") as fh:
            return fh.read(1 << 20)
    except OSError:
        return None

# Proposed new content. Write carries full content directly. Edit/MultiEdit
# are evaluated by applying the edit(s) to the on-disk text (same shape as
# product-cycle's gate). Any other/future tool (NotebookEdit included) is
# handled by the tool-agnostic default-deny below
# (docs/proposals/2026-07-26-scope-record-gate-tool-agnostic.md): if a
# literal resulting text cannot be extracted from the payload, the call is
# refused rather than allowed — there is no tool name for which this gate
# silently permits an indeterminate write to the front record.
if tool == "Write":
    content = ti.get("content")
    if not isinstance(content, str):
        deny("Write carries no readable content for the feasibility record.")
    new_text = content
elif tool == "Edit":
    old_string = ti.get("old_string")
    new_string = ti.get("new_string")
    if not isinstance(old_string, str) or not isinstance(new_string, str):
        deny("Edit call on the front record is missing old_string/new_string (fail-closed).")
    disk = _read_disk_resolved()
    if old_string == "":
        new_text = new_string
    else:
        if disk is None:
            deny("Edit call on the front record but the on-disk file could not be read (fail-closed).")
        if old_string not in disk:
            deny("Edit call's old_string was not found verbatim in the front record (fail-closed).")
        new_text = disk.replace(old_string, new_string,
                                (10**9 if ti.get("replace_all") is True else 1))
elif tool == "MultiEdit":
    edits = ti.get("edits")
    if not isinstance(edits, list) or not edits:
        deny("MultiEdit call on the front record has no usable edits list (fail-closed).")
    disk = _read_disk_resolved()
    text = disk if disk is not None else ""
    for e in edits:
        if not isinstance(e, dict):
            deny("MultiEdit call has a non-object edit entry (fail-closed).")
        o_ = e.get("old_string"); n_ = e.get("new_string")
        if not isinstance(o_, str) or not isinstance(n_, str):
            deny("MultiEdit edit missing old_string/new_string (fail-closed).")
        if o_ == "":
            text = n_; continue
        if o_ not in text:
            deny("MultiEdit old_string not found verbatim at the point it is applied (fail-closed).")
        text = text.replace(o_, n_, (10**9 if e.get("replace_all") is True else 1))
    new_text = text
else:
    def _generic_content(tid):
        for key in ("content", "new_source", "text", "data"):
            v = tid.get(key)
            if isinstance(v, str):
                return v
        cells = tid.get("cells")
        if isinstance(cells, list):
            parts = []
            for c in cells:
                if not isinstance(c, dict):
                    continue
                src = c.get("source") if "source" in c else c.get("new_source")
                if isinstance(src, str):
                    parts.append(src)
                elif isinstance(src, list) and all(isinstance(x, str) for x in src):
                    parts.append("".join(src))
            if parts:
                return "\n".join(parts)
        return None

    generic_content = _generic_content(ti)
    if generic_content is None:
        deny(
            "tool '%s' targets the front record docs/reports/records/%s/feasibility.md but this "
            "gate cannot literally determine the resulting content from its payload shape "
            "(fail-closed): a tool call whose effect on the gated scope-approved transition "
            "cannot be determined is refused, never allowed by default." % (tool, subject)
        )
    new_text = generic_content

new_status = frontmatter_status(new_text)
if new_status is None:
    deny("proposed feasibility record has no single parseable 'status' field in its frontmatter.")

# Current on-disk status.
disk_now = _read_disk_resolved()
if disk_now is None:
    old_status = "(none)"
else:
    old_status = frontmatter_status(disk_now)
    if old_status is None:
        deny("existing feasibility record has no single parseable 'status' field.")

# Only the scope-proposed -> scope-approved transition is token-gated here.
if not (old_status == "scope-proposed" and new_status == "scope-approved"):
    allow()

require_token_and_check(root, subject)
allow()
PY
rc=$?
# SHELL LAYER (fail-closed on internal error): map any terminal code other
# than 0 (allow) or 2 (deny) to exit 2.
if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then
  echo "feasibility-cycle: DENIED (scope-record-gate) — fail-closed: internal error (judge exited $rc)" >&2
  exit 2
fi
exit "$rc"
