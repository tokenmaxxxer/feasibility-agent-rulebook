#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook (Bash matching 'git commit'): §21 handbook-trigger half.
# When a commit's changed-file set introduces or changes operational surface
# (env/config, dependency manifest, migration, or run/setup/deploy script)
# and the same commit does not also touch a docs/handbooks/<component>.md,
# the commit is refused. Needs the whole changed-file set, hence commit-time.
#
# Operational-surface heuristics for this repo (declared here):
#   package.json, package-lock.json, pnpm-lock.yaml, yarn.lock,
#   pyproject.toml, poetry.lock, requirements*.txt, Dockerfile, docker-compose*,
#   *.env, *.env.example, any path under migrations/ or db/migrate/,
#   any path under .github/workflows/, install.sh, setup.sh, and any
#   deploy*/run* shell script.
#
# Fail-closed: malformed/missing input, indeterminate git root, or a git
# command that cannot be read => DENY. Kill switch:
# FEASIBILITY_HANDBOOK_GATE_OFF=1.
set -euo pipefail

case "${FEASIBILITY_HANDBOOK_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

deny() { echo "feasibility-cycle: DENIED (handbook-trigger-gate) — $1" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || deny "python3 is required and was not found."
command -v git >/dev/null 2>&1 || deny "git is required and was not found."
payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "no tool-input payload was received."

set +e
FEAS_PAYLOAD="$payload" FEAS_CPD="${CLAUDE_PROJECT_DIR:-}" FEAS_CWD="$(pwd -P)" python3 <<'PY'
import json, os, re, sys, shlex, subprocess

def deny(m): print("feasibility-cycle: DENIED (handbook-trigger-gate) - %s" % m, file=sys.stderr); sys.exit(2)
def allow(): sys.exit(0)

# PYTHON LAYER (fail-closed on internal error): any uncaught exception becomes
# exit 2 (DENY), never the default exit 1 (fail-open). SystemExit from
# allow()/deny() bypasses excepthook, leaving the verdict paths untouched.
def _feas_fc_hook(_t, _v, _tb):
    try:
        sys.stderr.write("feasibility-cycle: DENIED (handbook-trigger-gate) - fail-closed: internal error: %s\n" % _v)
    except Exception:
        pass
    os._exit(2)
sys.excepthook = _feas_fc_hook

try:
    event = json.loads(os.environ.get("FEAS_PAYLOAD",""))
except ValueError:
    deny("tool-input payload is not valid JSON.")
if not isinstance(event, dict): deny("tool-input payload is not a JSON object.")
tool = event.get("tool_name"); ti = event.get("tool_input")
if tool != "Bash":
    allow()  # this gate only fires on Bash; anything else is not ours
if not isinstance(ti, dict): deny("tool_input missing or malformed in payload.")
command = ti.get("command")
if not isinstance(command, str) or not command.strip():
    deny("Bash tool_input.command missing or empty.")

# Is this a git commit invocation? Tokenize; look for a 'git' ... 'commit'.
try:
    toks = shlex.split(command, comments=False)
except ValueError:
    # Unparseable command that mentions git commit -> fail closed; otherwise
    # not our concern.
    if re.search(r"\bgit\b.*\bcommit\b", command):
        deny("a git commit command could not be parsed (unbalanced quoting); refusing.")
    allow()
def is_commit(tokens):
    for i,t in enumerate(tokens):
        if os.path.basename(t) == "git":
            for u in tokens[i+1:]:
                if u.startswith("-"): continue
                return u == "commit"
    return False
if not is_commit(toks):
    allow()

cwd = os.environ.get("FEAS_CWD",""); cpd = os.environ.get("FEAS_CPD","")
def git_top(d):
    try:
        r = subprocess.run(["git","-C",d,"rev-parse","--show-toplevel"],capture_output=True,text=True)
        return (r.stdout.strip() or None) if r.returncode==0 else None
    except Exception: return None
root = None
if cpd and os.path.isdir(cpd) and (os.path.exists(os.path.join(cpd,".git")) or
        os.path.isfile(os.path.join(cpd,"docs/specs/role-handoff-contract.md"))):
    root = git_top(cpd) or (os.path.realpath(cpd) if os.path.exists(os.path.join(cpd,".git")) else None)
if not root:
    root = git_top(cwd)
if not root:
    deny("could not determine the git repository root for this commit; refusing rather than "
         "silently allowing (fail closed).")

# Changed-file set = staged files (what this commit will land).
try:
    r = subprocess.run(["git","-C",root,"diff","--cached","--name-only"],capture_output=True,text=True)
except Exception as e:
    deny("could not read the staged file set (%s); refusing." % e)
if r.returncode != 0:
    deny("git diff --cached failed (%s); refusing." % r.stderr.strip())
changed = [ln.strip() for ln in r.stdout.splitlines() if ln.strip()]

# `git commit -a` also lands modified-tracked files not yet staged.
if any(a in ("-a","--all","-am") or (a.startswith("-") and not a.startswith("--") and "a" in a) for a in toks):
    try:
        r2 = subprocess.run(["git","-C",root,"diff","--name-only"],capture_output=True,text=True)
        if r2.returncode == 0:
            for ln in r2.stdout.splitlines():
                if ln.strip() and ln.strip() not in changed:
                    changed.append(ln.strip())
    except Exception:
        deny("commit uses -a but the modified-tracked file set could not be read; refusing.")

if not changed:
    allow()  # nothing to land; no operational surface changed

OP_PATTERNS = [
    r"(^|/)package\.json$", r"(^|/)package-lock\.json$", r"(^|/)pnpm-lock\.yaml$",
    r"(^|/)yarn\.lock$", r"(^|/)pyproject\.toml$", r"(^|/)poetry\.lock$",
    r"(^|/)requirements[^/]*\.txt$", r"(^|/)Dockerfile$", r"(^|/)docker-compose[^/]*\.ya?ml$",
    r"\.env$", r"\.env\.example$", r"(^|/)migrations/", r"(^|/)db/migrate/",
    r"^\.github/workflows/", r"(^|/)install\.sh$", r"(^|/)setup\.sh$",
    r"(^|/)(deploy|run)[^/]*\.sh$",
]
op_re = re.compile("|".join(OP_PATTERNS))
op_hits = [c for c in changed if op_re.search(c)]
if not op_hits:
    allow()  # no operational surface in this commit

touches_handbook = any(re.match(r"^docs/handbooks/[^/]+\.md$", c) for c in changed)
if not touches_handbook:
    deny("this commit changes operational surface (%s) but does not touch any "
         "docs/handbooks/<component>.md. Per contract §21, update the handbook in the same "
         "unit of work." % ", ".join(op_hits))
allow()
PY
rc=$?
# SHELL LAYER (fail-closed on internal error): map any terminal code other
# than 0 (allow) or 2 (deny) to exit 2.
if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then
  echo "feasibility-cycle: DENIED (handbook-trigger-gate) — fail-closed: internal error (judge exited $rc)" >&2
  exit 2
fi
exit "$rc"
