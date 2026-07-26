#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|NotebookEdit|Bash): enforces the feasibility
# role's state machine against its two v2-contract-owned per-subject record
# paths (docs/reports/records/<subject>/feasibility.md and
# .../spikes/<spike-slug>.md), using `transition-rules.md` as the single
# source of legal transitions. This gate only ever fires on write-shaped
# tool calls (Write|Edit|NotebookEdit|Bash, per this hook's own
# registration) — reads are unconditionally allowed per contract section 4
# ("READ is unconditionally broad"), and this file contains no read-path
# logic to relax.
#
# The gate answers exactly two questions:
#   1. Does this write reach the state file, judged by RESOLVED TARGET PATH
#      — never by a literal filename in the command string, never by tool
#      name? A Bash write whose target cannot be determined statically
#      (variable, expansion, command substitution, glob, eval, heredoc into
#      a computed name) is treated as reaching the state file.
#   2. If it reaches the state file: is the resulting transition present as
#      a row in transition-rules.md? Present -> allow (subject to the
#      content precondition below). Absent -> deny.
# Everything that does not reach the state file is allowed through without
# comment.
#
# Two distinct denials, never conflated:
#   - "RULES COULD NOT BE LOADED" (transition-rules.md or the current/
#     proposed state could not be determined, or the hook input itself was
#     malformed)
#   - "this transition is not in the table" (rules loaded fine; the specific
#     from -> to pair just isn't a row)
# Malformed hook input (unparseable JSON, missing fields) denies with the
# RULES COULD NOT BE LOADED message — never a silent exit 0.
#
# Kill switch: export FEASIBILITY_GATE_OFF=1 (still fails closed in every
# other respect; only turns the whole gate off).
set -euo pipefail

case "${FEASIBILITY_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

deny() {
  echo "feasibility-cycle: DENIED — $1" >&2
  exit 2
}

command -v python3 >/dev/null 2>&1 || deny "RULES COULD NOT BE LOADED: python3 is required to evaluate this gate and was not found."

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "RULES COULD NOT BE LOADED: no tool-input payload was received."

# Root resolution (frozen contract:
# docs/proposals/2026-07-26-gate-root-from-project-dir.md): candidate root =
# CLAUDE_PROJECT_DIR when set, but only trusted once validated — (a) the
# tool call's actual target resolves inside it, and (b) it looks like a real
# project root (git work-tree top-level, or docs/specs/role-handoff-contract.md
# present). An unset or invalid candidate falls back to the git top-level of
# the tool call's target path, then the git top-level of cwd. A root that
# remains indeterminate is refused outright — never silently allowed,
# including for writes into the owned record tree.
_gate_target="$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    e = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
ti = e.get("tool_input") if isinstance(e, dict) else None
if isinstance(ti, dict):
    fp = ti.get("file_path")
    if isinstance(fp, str) and fp:
        print(fp)
' 2>/dev/null || true)"

_gate_is_plausible_root() {
  [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }
}

_gate_target_under_root() {
  [ -z "$2" ] && return 0
  python3 -c '
import os, posixpath, sys
root, target = sys.argv[1], sys.argv[2]
try:
    root_real = posixpath.normpath(os.path.realpath(root).replace("\\", "/"))
except Exception:
    sys.exit(1)
norm = target.replace("\\", "/")
absu = norm if posixpath.isabs(norm) else posixpath.join(root_real, norm)
absu = posixpath.normpath(absu)
real = posixpath.normpath(os.path.realpath(absu).replace("\\", "/"))
sys.exit(0 if (real == root_real or real.startswith(root_real + "/")) else 1)
' "$1" "$2"
}

root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _gate_is_plausible_root "$CLAUDE_PROJECT_DIR" && _gate_target_under_root "$CLAUDE_PROJECT_DIR" "$_gate_target"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$root" ]; then
  _gate_fallback_dir="$_gate_target"
  [ -n "$_gate_fallback_dir" ] || _gate_fallback_dir="$(pwd -P)"
  [ -d "$_gate_fallback_dir" ] || _gate_fallback_dir="$(dirname "$_gate_fallback_dir")"
  root="$(git -C "$_gate_fallback_dir" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$root" ]; then
  root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -n "$root" ] || deny "RULES COULD NOT BE LOADED: no project root could be determined (CLAUDE_PROJECT_DIR unset or failed validation, and no git top-level found for the tool call's target or for cwd). Refusing rather than silently allowing an indeterminate-root write."

# --- collaboration contract presence check ---------------------------------
# The gate resolves exactly one root: the validated project root ($root,
# already resolved above). It reads docs/specs/role-handoff-contract.md
# inside that root only — no parent/sibling-repo walk, no SHA comparison
# against another repo's history. If the contract file is absent, handoff-
# protocol actions are refused with an honest message rather than silently
# passing.
contract_rel="docs/specs/role-handoff-contract.md"
if [ ! -f "$root/$contract_rel" ]; then
  deny "this repo has no collaboration contract yet ($contract_rel not found under $root)."
fi

# transition-rules.md is resolved REPO-LOCALLY, anchored to this hook
# script's own on-disk directory — never via CLAUDE_PLUGIN_ROOT or any
# plugin-install-layout assumption. A guarded repo that vendors/checks out
# this rulebook at its own repo root must find transition-rules.md sitting
# next to state-gate.sh regardless of whether CLAUDE_PLUGIN_ROOT is set,
# unset, or points somewhere unrelated.
rules_file="$script_dir/transition-rules.md"

set +e
FEASIBILITY_PAYLOAD="$payload" FEASIBILITY_ROOT="$root" FEASIBILITY_RULES_FILE="$rules_file" python3 <<'PY'
import json, os, posixpath, re, shlex, sys

def deny(msg):
    print("feasibility-cycle: DENIED - %s" % msg, file=sys.stderr)
    sys.exit(2)

def allow():
    sys.exit(0)

# PYTHON LAYER (fail-closed on internal error): any uncaught exception —
# e.g. os.path.realpath raising ValueError on a null-byte/undecodable
# file_path — becomes exit 2 (DENY) rather than the default exit 1, which
# Claude Code treats as non-blocking (fail-open). SystemExit raised by
# deny()/allow() bypasses excepthook, so the exact deny(2)/allow(0) verdict
# paths are preserved unchanged.
def _feas_fc_hook(_t, _v, _tb):
    try:
        sys.stderr.write("feasibility-cycle: DENIED - fail-closed: internal error: %s\n" % _v)
    except Exception:
        pass
    os._exit(2)
sys.excepthook = _feas_fc_hook

try:
    event = json.loads(os.environ.get("FEASIBILITY_PAYLOAD", ""))
except ValueError:
    deny("RULES COULD NOT BE LOADED: tool-input payload is not valid JSON.")
if not isinstance(event, dict):
    deny("RULES COULD NOT BE LOADED: tool-input payload is not a JSON object.")

tool = event.get("tool_name")
tool_input = event.get("tool_input")
if not isinstance(tool, str) or not tool:
    deny("RULES COULD NOT BE LOADED: tool_name missing from payload.")
if not isinstance(tool_input, dict):
    deny("RULES COULD NOT BE LOADED: tool_input missing or malformed in payload.")

root = os.environ["FEASIBILITY_ROOT"]

# v2 blackboard contract (docs/specs/role-handoff-contract.md, section 11):
# feasibility no longer owns one project-root file. It owns two per-subject
# path shapes under docs/reports/records/<subject>/. record_name/record_abs
# (a single hardcoded root-level filename) is replaced by a path-shape
# match; everything downstream that used to compare against record_abs now
# calls is_owned_path(resolved) instead.
OWNED_PATH_RE = re.compile(
    r"^docs/reports/records/[^/]+/(feasibility\.md|spikes/[^/]+\.md)$"
)


def is_owned_path(resolved_abs):
    try:
        rel = posixpath.relpath(resolved_abs, root)
    except ValueError:
        return False
    rel = rel.replace("\\", "/")
    return bool(OWNED_PATH_RE.match(rel))

# Single source of truth for which tools this gate recognizes as capable of
# writing feasibility-record.md — used by both the "does this reach the
# state file" dispatch and the final dispatch fallback, so the two cannot
# drift apart the way Edit/MultiEdit did. A tool name outside this set that
# nonetheless reaches this script is a DENY, not a pass-through allow.
RECOGNIZED_WRITE_TOOLS = ("Write", "Edit", "MultiEdit", "NotebookEdit")

# --- question 1: does this write reach the state file? -------------------
target_path = None
new_content = None

if tool == "Bash":
    command = tool_input.get("command")
    if not isinstance(command, str) or not command.strip():
        deny("RULES COULD NOT BE LOADED: Bash tool_input.command missing or empty.")

    # --- path-reference default-deny (frozen contract) ---------------------
    # docs/proposals/2026-07-26-gate-nested-shell-default-deny.md: default-
    # deny whenever the command TEXT references a feasibility-owned record
    # path (docs/reports/records/<subject>/feasibility.md or
    # .../spikes/<slug>.md) unless the reference is PROVABLY READ-ONLY: only
    # read-type commands touch it, no nested-shell invocation (sh -c/
    # bash -c/eval/env ... sh/xargs), no command substitution ($( )/
    # backticks), and no write idiom anywhere in the command. This does not
    # depend on enumerating write idioms — failing the read-only proof is
    # itself the denial trigger, so write_text/write_bytes/os.write and any
    # future un-enumerated idiom are caught the same way. Unlike the other
    # role gates, this gate has NO own-record exemption here: per this
    # gate's pre-existing policy (see the (q1)/could_write section below),
    # EVERY Bash-mediated write reaching an owned record path — own or
    # foreign — is refused outright, since Bash content can never be
    # verified against transition-rules.md before the shell runs it.
    _PRDD_TREE_RE = re.compile(r'docs/reports/records/[^\s"\'`)]*(?:feasibility\.md|spikes/[^\s"\'`)]*\.md)')
    _PRDD_NESTED_SHELL_RE = re.compile(
        r'\b(?:sh|bash|zsh|ksh|dash)\s+-c\b|\beval\b|\bxargs\b|'
        r'\benv\b[^\n;&|]*\b(?:sh|bash|zsh|ksh|dash)\b'
    )
    _PRDD_CMD_SUBST_RE = re.compile(r'\$\(|`')
    _PRDD_WRITE_IDIOM_RE = re.compile(
        r'(?:^|[\s;&|])\d?>{1,2}(?!\&)|\btee\b|\bdd\b[^\n;&|]*\bof=|'
        r'\bopen\s*\([^)]*,\s*[\'"][wxa]|'
        r'\.write_text\s*\(|\.write_bytes\s*\(|\.write\s*\(|\bos\.write\s*\('
    )
    _PRDD_OPEN_ANY_RE = re.compile(r"\bopen\s*\([^)]*,\s*['\"][wxa]")
    _PRDD_OPEN_LITERAL_RE = re.compile(r"\bopen\s*\(\s*(['\"])(.*?)\1\s*,\s*(['\"])[wxa]")
    _PRDD_WT_ANY_RE = re.compile(r"\.\s*write_(?:text|bytes)\s*\(")
    _PRDD_WT_LITERAL_RE = re.compile(r"\(\s*(['\"])(.*?)\1\s*\)\s*\.\s*write_(?:text|bytes)\s*\(")
    _PRDD_REDIRECT_RE = re.compile(r"(?:^|[\s;&|])\d?(>>|>\|?)(?!\&)\s*(\S+)")
    _PRDD_READ_WHITELIST = {
        "cat", "grep", "egrep", "fgrep", "head", "tail", "test", "[", "ls",
        "wc", "find", "stat", "diff", "file", "less", "more", "readlink",
        "realpath", "md5sum", "sha1sum", "sha256sum", "basename", "dirname",
        "true", "echo", "pwd",
    }

    def _prdd_leading_tokens(cmd):
        leads = []
        for seg in re.split(r'[;&|\n]+', cmd):
            toks = seg.split()
            i = 0
            while i < len(toks) and (
                re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', toks[i]) or toks[i] in ("sudo", "env")
            ):
                i += 1
            if i < len(toks):
                leads.append(posixpath.basename(toks[i].strip("'\"")))
        return leads

    if _PRDD_TREE_RE.search(command):
        _prdd_proven_read_only = (
            not _PRDD_NESTED_SHELL_RE.search(command)
            and not _PRDD_CMD_SUBST_RE.search(command)
            and not _PRDD_WRITE_IDIOM_RE.search(command)
            and all(t in _PRDD_READ_WHITELIST for t in _prdd_leading_tokens(command))
        )
        if not _prdd_proven_read_only:
            deny(
                "path-reference default-deny: this Bash command references a "
                "feasibility-owned record path and this gate could not prove the "
                    "reference is read-only (no nested shell, no command substitution, no "
                    "write idiom, only read-type commands touching the path). Per the frozen "
                    "path-reference default-deny contract "
                    "(docs/proposals/2026-07-26-gate-nested-shell-default-deny.md), an "
                    "unproven reference into the owned record tree is refused rather than "
                    "allowed through."
                )

    dynamic_construct = re.compile(
        r'\$\{?\w|\$\(|`|\*|\?|~|\beval\b|\bsource\b|\.\s+/|<\(|>\(|<<'
    )
    write_shape = re.compile(
        r'>>?(?!\()'
        r'|\btee\b'
        r'|\b(cp|mv|dd|install)\b'
        r'|\b(sed|perl|ruby)\b[^|;\n]*-i[a-zA-Z0-9]*\b'
        # write-through-another-tool: e.g. `python3 -c "open(path,
        # 'w').write(...)"`. Judged by RESOLVED TARGET PATH like every
        # other idiom above, not by which tool performs the write.
        r'|\bopen\s*\([^)]*,\s*[\'"][wxa]',
        re.I,
    )
    # Matches ONLY when open()'s first argument is a single, complete
    # quoted literal immediately followed by the comma — never a partial
    # match into the middle of a concatenation expression (e.g.
    # `'docs/reports/records/' + subject + '/feasibility.md'` must NOT
    # yield a truncated literal capture; it must be treated as dynamic).
    OPEN_LITERAL_RE = re.compile(
        r"\bopen\s*\(\s*['\"]([^'\"]*)['\"]\s*,\s*['\"][wxa]"
    )
    # Loose detector: is this an open(...) write call AT ALL, literal or
    # not? Used only to decide whether the call is write-shaped.
    OPEN_WRITE_RE = re.compile(r"\bopen\s*\([^)]*,\s*['\"][wxa][^'\"]*['\"]")

    could_write = write_shape.search(command) is not None
    is_dynamic = dynamic_construct.search(command) is not None

    # A python-style open(...) write call whose first argument is not a
    # simple, complete literal string (e.g. built from concatenation or a
    # variable) is a write with an indeterminate target — treated the same
    # as any other unresolvable-target write below.
    if not is_dynamic and OPEN_WRITE_RE.search(command) and not OPEN_LITERAL_RE.search(command):
        is_dynamic = True

    if could_write and is_dynamic:
        # Target not statically determinable AND write-shaped: treat as
        # reaching the state file per contract. Content can't be inspected,
        # so no transition can ever be proven legal -> deny. A dynamic
        # construct with NO write-shape is NOT denied here (handled by the
        # could_write check below) — that would be the global-deny
        # regression this gate must avoid.
        deny(
            "a Bash command could write a file and its write target is not "
            "statically determinable (shell variable, command/process "
            "substitution, indirection, glob, eval, source, or heredoc into a "
            "computed name). Treating this as reaching feasibility-record.md "
            "per policy: this gate cannot prove the resulting transition is in "
            "transition-rules.md, so it refuses. Use the Write tool on a "
            "literal path instead."
        )

    if could_write:
        try:
            tokens = shlex.split(command, comments=False)
        except ValueError:
            deny(
                "a Bash command could write a file but its argument text "
                "could not be parsed (unbalanced quoting); treating this as "
                "reaching feasibility-record.md and refusing."
            )
        candidates = []
        for tok in tokens:
            t = tok
            for op in (">>", ">"):
                if t.startswith(op):
                    t = t[len(op):]
            if t.startswith("-"):
                continue
            if "/" in t or t.endswith(".md"):
                candidates.append(t)
        for _om in OPEN_LITERAL_RE.finditer(command):
            if _om.group(1):
                candidates.append(_om.group(1))
        for cand in candidates:
            normalized = cand.replace("\\", "/")
            absolute = posixpath.normpath(
                normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized)
            )
            try:
                resolved = posixpath.normpath(os.path.realpath(absolute).replace("\\", "/"))
            except OSError:
                resolved = absolute
            if is_owned_path(resolved):
                deny(
                    "a Bash command targets a feasibility-owned record path "
                    "(docs/reports/records/<subject>/feasibility.md or "
                    ".../spikes/<spike-slug>.md) with a write-shaped construct "
                    "(redirect/tee/cp/mv/in-place edit/dd/install). This gate "
                    "cannot read the resulting content before the command "
                    "runs, so it refuses the write outright. Use the Write "
                    "tool on this file instead."
                )
    allow()  # does not reach the state file: allowed without comment

if tool in RECOGNIZED_WRITE_TOOLS:
    path = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not isinstance(path, str) or not path:
        deny("RULES COULD NOT BE LOADED: %s tool_input carries no file_path." % tool)
    normalized = path.replace("\\", "/")
    absolute = posixpath.normpath(
        normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized)
    )
    resolved = posixpath.normpath(os.path.realpath(absolute).replace("\\", "/"))
    if not is_owned_path(resolved):
        allow()  # not a feasibility-owned record path; nothing to gate
    target_path = resolved

    if tool == "Write":
        content = tool_input.get("content")
        if not isinstance(content, str):
            deny("RULES COULD NOT BE LOADED: Write tool_input carries no readable content for the feasibility record.")
        new_content = content
    else:
        deny(
            "an Edit/MultiEdit/NotebookEdit call targets a feasibility-owned record "
            "path. This gate only evaluates complete, readable content (a Write "
            "call); partial edits to the record are refused so a transition can "
            "never be assembled from an unreadable diff. Rewrite the whole file "
            "with Write."
        )
else:
    # Bash already returned above (via allow() or deny()); anything else
    # reaching here is a tool name outside RECOGNIZED_WRITE_TOOLS.
    deny(
        "an unrecognized tool (%r) reached this gate. This gate's recognized-write-tool "
        "list is %r (plus Bash, handled separately); a tool name outside that set is "
        "treated as a denial, not a pass — unknown input fails closed rather than being "
        "assumed to be a read." % (tool, RECOGNIZED_WRITE_TOOLS)
    )

if target_path is None or new_content is None:
    deny("RULES COULD NOT BE LOADED: internal — no content resolved for a call this gate should have judged.")

# --- load transition-rules.md --------------------------------------------
rules_file = os.environ.get("FEASIBILITY_RULES_FILE", "")
try:
    with open(rules_file, encoding="utf-8-sig") as fh:
        rules_text = fh.read(1 << 20)
except OSError as e:
    deny("RULES COULD NOT BE LOADED: transition-rules.md at %s could not be read (%s)." % (rules_file, e))

if not rules_text.strip():
    deny("RULES COULD NOT BE LOADED: transition-rules.md at %s is empty." % rules_file)

rows = []
for line in rules_text.splitlines():
    line = line.strip()
    if "|" not in line or not re.search(r"[A-Za-z]", line):
        continue
    parts = [p.strip() for p in line.strip("|").split("|")]
    if len(parts) != 4:
        continue
    if parts[0].lower() == "from":
        continue
    if set(parts[0]) <= set("- "):
        continue
    rows.append(tuple(parts))

if not rows:
    deny(
        "RULES COULD NOT BE LOADED: transition-rules.md at %s has no parseable "
        "'from | to | actor | precondition' rows." % rules_file
    )

legal = {(r[0].lower(), r[1].lower()) for r in rows}

# --- parse the proposed new content's frontmatter -------------------------
if not new_content.startswith("---"):
    deny("RULES COULD NOT BE LOADED: feasibility-record.md must open with YAML frontmatter (---).")
end = new_content.find("\n---", 3)
if end == -1:
    deny("RULES COULD NOT BE LOADED: feasibility-record.md frontmatter has no closing '---'.")
block = new_content[3:end]

def field(text_block, name):
    matches = re.findall(r"^" + re.escape(name) + r":\s*(.*?)\s*(?:#.*)?$", text_block, re.M)
    if len(matches) != 1:
        return None
    return matches[0].strip()

new_status = field(block, "status")
if not new_status:
    deny("RULES COULD NOT BE LOADED: proposed frontmatter has no (single, non-empty) 'status' field.")
new_status = new_status.strip().rstrip("\r").strip().lower()

known_states = {r[0].lower() for r in rows} | {r[1].lower() for r in rows}
known_states.discard("(none)")
if new_status not in known_states:
    deny("RULES COULD NOT BE LOADED: status '%s' is not one of the states in transition-rules.md (%s)." % (new_status, ", ".join(sorted(known_states))))

# Determine current on-disk status. "No state file" is derived from file
# existence alone, as a boolean, and NEVER by comparing a parsed status
# value against the "(none)" string. Only a genuinely absent file yields the
# synthetic "(none)" old status used for bootstrap-row matching.
file_exists = os.path.exists(target_path)
if not file_exists:
    old_status = "(none)"
else:
    try:
        with open(target_path, encoding="utf-8-sig") as fh:
            old_text = fh.read(1 << 20)
    except OSError:
        deny("RULES COULD NOT BE LOADED: existing feasibility-record.md could not be read to determine the current state.")
    if not old_text.startswith("---"):
        deny("RULES COULD NOT BE LOADED: existing feasibility-record.md has no opening frontmatter '---'.")
    oend = old_text.find("\n---", 3)
    if oend == -1:
        deny("RULES COULD NOT BE LOADED: existing feasibility-record.md frontmatter has no closing '---'.")
    old_status = field(old_text[3:oend], "status")
    if not old_status:
        deny("RULES COULD NOT BE LOADED: existing feasibility-record.md status field is missing, duplicated, or empty; refusing to layer a new state on top of an unknown state.")
    # Strip trailing whitespace/CRLF before the membership check; a value
    # that is only whitespace after stripping counts as empty.
    old_status = old_status.strip().rstrip("\r").strip().lower()
    if not old_status:
        deny("RULES COULD NOT BE LOADED: existing feasibility-record.md status field is empty (whitespace only); refusing to layer a new state on top of an unknown state.")
    # An EXISTING state file's value must be a member of the known-state
    # set. "(none)" as a value, or any value outside the set, is the same
    # broken-input case as missing/empty/unparseable -- never treated as if
    # the file were absent, and never routed to the "not in the table"
    # denial (the table is not what failed here).
    if old_status not in known_states:
        deny(
            "RULES COULD NOT BE LOADED: existing feasibility-record.md status "
            "'%s' is not one of the states in transition-rules.md (%s); "
            "refusing to layer a new state on top of an unrecognized state."
            % (old_status, ", ".join(sorted(known_states)))
        )

if (old_status, new_status) not in legal:
    deny(
        "transition '%s -> %s' is not present as a row in transition-rules.md."
        % (old_status, new_status)
    )

# --- content precondition preserved for the one content-checked row ------
# Gated at probing -> verdict-provisional (not probing -> verdict): the
# four-probe-content requirement moved to the new intermediate state per
# the revised state set (verdict-provisional is the draft disposition;
# verdict is reserved for after an explicit user accept, which carries no
# content precondition of its own beyond the actor:user judgment call).
if old_status == "probing" and new_status == "verdict-provisional":
    probe_names = ("technical", "prior_art", "legal_regulatory", "threat_model")
    unresolved = []
    for n in probe_names:
        v = field(block, n)
        if not v:
            unresolved.append(n)
            continue
        low = v.lower()
        if not (low.startswith("pass") or low.startswith("fail") or low.startswith("blocked")):
            unresolved.append(n)
    if unresolved:
        deny(
            "probing -> verdict-provisional refused: probe field(s) not resolved: %s. "
            "Each of technical/prior_art/legal_regulatory/threat_model must be "
            "'pass: ...', 'fail: ...', or 'blocked: ...' (precondition from "
            "transition-rules.md)." % ", ".join(unresolved)
        )

allow()
PY
rc=$?
# SHELL LAYER (fail-closed on internal error): the judge exits 0 (allow) or 2
# (deny). Any other terminal code (crash, signal, interpreter death) is mapped
# to exit 2 so a non-2 non-zero code cannot leak through as fail-open.
if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then
  echo "feasibility-cycle: DENIED — fail-closed: internal error (judge exited $rc)" >&2
  exit 2
fi
exit "$rc"
