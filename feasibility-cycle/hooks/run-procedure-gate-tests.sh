#!/usr/bin/env bash
# Tests for the six procedure-enforcing gates added per proposal
# docs/proposals/2026-07-26-implement-procedure-hooks-all-rulebooks.md.
# Each gate gets at least one crafted violation (must DENY) and one
# compliant case (must ALLOW). Builds throwaway git repos per case.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
plugin_root="$(cd "$script_dir/.." && pwd -P)"
pass=0; fail=0
work=""
cleanup() { [ -n "$work" ] && rm -rf "$work"; }
trap cleanup EXIT

new_work() {
  cleanup
  work="$(mktemp -d)"
  git init -q "$work"
  mkdir -p "$work/docs/specs"
  printf 'placeholder contract\n' > "$work/docs/specs/role-handoff-contract.md"
}

run() { # $1 gate  $2 json
  CLAUDE_PROJECT_DIR="$work" CLAUDE_PLUGIN_ROOT="$plugin_root" \
    bash "$script_dir/$1" <<<"$2" >"$work/out" 2>"$work/err"
  echo $?
}
json_write() { python3 -c 'import json,sys;print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]}}))' "$1" "$2"; }
json_edit()  { python3 -c 'import json,sys;print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":"a","new_string":"b"}}))' "$1"; }
json_bash()  { python3 -c 'import json,sys;print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1"; }

check() { # $1 label $2 expected $3 code
  local ok=0
  if [ "$2" = allow ] && [ "$3" = 0 ]; then ok=1
  elif [ "$2" = deny ] && [ "$3" != 0 ]; then grep -qi denied "$work/err" && ok=1; fi
  if [ "$ok" = 1 ]; then pass=$((pass+1)); echo "PASS: $1 (exit=$3)"
  else fail=$((fail+1)); echo "FAIL: $1 (expected=$2 exit=$3)"; sed 's/^/    /' "$work/err"; fi
}

rec="docs/reports/records/widget/feasibility.md"
mk_rec() { mkdir -p "$work/$(dirname "$rec")"; printf '%s' "$1" > "$work/$rec"; }

full_body='---
status: probing
---
# What was done
probed the thing
# Why
because the choice mattered
# Upstream basis
based on commit abc123
# Next steps
finish probe two
# Open finding resolution path
findings tracked in verify.md
'

# ===== scope-record-gate =====
# Violation: scope-proposed -> scope-approved with NO approval token.
new_work; mk_rec $'---\nstatus: scope-proposed\n---\nbody\n'
code=$(run scope-record-gate.sh "$(json_write "$work/$rec" $'---\nstatus: scope-approved\n---\nbody\n')")
check "scope-record: approve without token -> deny" deny "$code"
# Compliant: same transition WITH a human-placed token present.
new_work; mk_rec $'---\nstatus: scope-proposed\n---\nbody\n'
mkdir -p "$work/docs/reports/records/widget/tokens"; printf 'approved by human\n' > "$work/docs/reports/records/widget/tokens/scope-approved.token"
code=$(run scope-record-gate.sh "$(json_write "$work/$rec" $'---\nstatus: scope-approved\n---\nbody\n')")
check "scope-record: approve with token -> allow" allow "$code"
# Non-governed transition passes (probing self-write).
new_work; mk_rec $'---\nstatus: probing\n---\nbody\n'
code=$(run scope-record-gate.sh "$(json_write "$work/$rec" $'---\nstatus: probing\n---\nbody\n')")
check "scope-record: unrelated transition -> allow" allow "$code"

# ===== record-fields-gate =====
# Violation: non-terminal record missing required sections.
new_work
code=$(run record-fields-gate.sh "$(json_write "$work/$rec" $'---\nstatus: probing\n---\njust a body\n')")
check "record-fields: missing sections -> deny" deny "$code"
# Compliant: full body with all required sections.
new_work
code=$(run record-fields-gate.sh "$(json_write "$work/$rec" "$full_body")")
check "record-fields: all sections present -> allow" allow "$code"

# ===== path-ownership-gate =====
# Violation: writing another role's record under a subject.
new_work
code=$(run path-ownership-gate.sh "$(json_write "$work/docs/reports/records/widget/coding.md" $'---\nstatus: x\n---\n')")
check "path-ownership: foreign role record -> deny" deny "$code"
# Compliant: writing feasibility's own record.
new_work
code=$(run path-ownership-gate.sh "$(json_write "$work/$rec" $'---\nstatus: idle\n---\n')")
check "path-ownership: own feasibility record -> allow" allow "$code"

# ===== doc-bucket-gate =====
# Violation: a doc outside the six buckets.
new_work
code=$(run doc-bucket-gate.sh "$(json_write "$work/docs/random/note.md" $'hi\n')")
check "doc-bucket: outside buckets -> deny" deny "$code"
# Compliant: a doc in a sanctioned bucket.
new_work
code=$(run doc-bucket-gate.sh "$(json_write "$work/docs/reports/note.md" $'hi\n')")
check "doc-bucket: inside reports bucket -> allow" allow "$code"

# ===== handbook-trigger-gate =====
# Violation: commit changes operational surface, no handbook touched.
new_work
printf '{}\n' > "$work/package.json"; git -C "$work" add package.json
code=$(run handbook-trigger-gate.sh "$(json_bash "git commit -m 'add deps'")")
check "handbook-trigger: op surface without handbook -> deny" deny "$code"
# Compliant: same op surface change WITH a handbook update in the commit.
new_work
printf '{}\n' > "$work/package.json"; mkdir -p "$work/docs/handbooks"; printf '# c\n' > "$work/docs/handbooks/deps.md"
git -C "$work" add package.json docs/handbooks/deps.md
code=$(run handbook-trigger-gate.sh "$(json_bash "git commit -m 'add deps + handbook'")")
check "handbook-trigger: op surface with handbook -> allow" allow "$code"
# Compliant: a commit with no operational surface at all.
new_work
printf 'x\n' > "$work/README.md"; git -C "$work" add README.md
code=$(run handbook-trigger-gate.sh "$(json_bash "git commit -m 'docs only'")")
check "handbook-trigger: no op surface -> allow" allow "$code"

# ===== trailer-gate =====
# Violation: unit in progress (non-terminal record), commit lacks trailer.
new_work; mk_rec $'---\nstatus: probing\n---\nbody\n'
code=$(run trailer-gate.sh "$(json_bash "git commit -m 'wip'")")
check "trailer: in-progress unit, no trailer -> deny" deny "$code"
# Compliant: same, message carries the Proposal: trailer.
new_work; mk_rec $'---\nstatus: probing\n---\nbody\n'
code=$(run trailer-gate.sh "$(json_bash "git commit -m 'wip

Proposal: docs/proposals/2026-07-26-implement-procedure-hooks-all-rulebooks.md'")")
check "trailer: in-progress unit, with trailer -> allow" allow "$code"
# Compliant: no in-progress unit (terminal record) -> trailer not required.
new_work; mk_rec $'---\nstatus: verdict\n---\nbody\n'
code=$(run trailer-gate.sh "$(json_bash "git commit -m 'done'")")
check "trailer: terminal record, no trailer required -> allow" allow "$code"

# ===== fail-closed spot checks =====
new_work
code=$(run scope-record-gate.sh '{not json')
check "scope-record: malformed JSON -> deny (fail closed)" deny "$code"
new_work
code=$(run record-fields-gate.sh '{not json')
check "record-fields: malformed JSON -> deny (fail closed)" deny "$code"
new_work
code=$(run doc-bucket-gate.sh '{not json')
check "doc-bucket: malformed JSON -> deny (fail closed)" deny "$code"

# ===== fail-closed-on-internal-error crash tests =====
# Frozen contract docs/proposals/2026-07-26-gates-fail-closed-on-internal-error.md:
# a crash-inducing payload (null byte in file_path, or malformed JSON) must
# resolve to EXACTLY exit 2 (DENY) — Claude Code blocks only on exit 2; any
# other non-zero code is treated as non-blocking (fail-open). Previously a
# null byte in file_path made os.path.realpath raise an uncaught ValueError
# (exit 1 = fail-open). These cases assert exit == 2 specifically.
check2() { # $1 label $2 code : assert DENY with exit code EXACTLY 2
  if [ "$2" = 2 ] && grep -qi denied "$work/err"; then
    pass=$((pass+1)); echo "PASS: $1 (exit=2)"
  else
    fail=$((fail+1)); echo "FAIL: $1 (expected exit=2 got=$2)"; sed 's/^/    /' "$work/err"
  fi
}
json_nul_write() { # $1 = absolute path; JSON carries a trailing \u0000 escape
  # Emit the null as the literal 6-char ASCII escape \u0000 (never a raw
  # null byte, which bash command substitution silently strips). The gate's
  # json.loads decodes it to a real null in file_path, so os.path.realpath
  # raises ValueError -> the fail-closed path -> exit 2.
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s%s","content":"x"}}' "$1" '\u0000'
}

# Path-processing gates: null byte in file_path -> realpath ValueError -> exit 2.
for g in scope-record-gate.sh record-fields-gate.sh path-ownership-gate.sh doc-bucket-gate.sh; do
  new_work
  code=$(run "$g" "$(json_nul_write "$work/$rec")")
  check2 "$g: null-byte file_path -> exit 2 (fail closed)" "$code"
done

# All gates: malformed JSON -> exit 2 (DENY), not some other non-blocking code.
for g in scope-record-gate.sh record-fields-gate.sh path-ownership-gate.sh doc-bucket-gate.sh handbook-trigger-gate.sh trailer-gate.sh; do
  new_work
  code=$(run "$g" '{not json')
  check2 "$g: malformed JSON -> exit 2 (fail closed)" "$code"
done

echo
echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
