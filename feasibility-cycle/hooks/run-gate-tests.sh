#!/usr/bin/env bash
# Gate tests for state-gate.sh. Feeds hook JSON on stdin, asserts exit code
# and (for denials) that a "DENIED" message appears on stderr. Exits non-zero
# if any case fails.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
gate="$script_dir/state-gate.sh"
plugin_root="$(cd "$script_dir/.." && pwd -P)"

pass=0
fail=0

work=""
cleanup() { [ -n "$work" ] && rm -rf "$work"; }
trap cleanup EXIT

new_work() {
  cleanup
  work="$(mktemp -d)"
}

run_gate() {
  # $1 = json payload
  CLAUDE_PROJECT_DIR="$work" CLAUDE_PLUGIN_ROOT="$plugin_root" \
    bash "$gate" <<<"$1" >"$work/stdout" 2>"$work/stderr"
  echo $?
}

seed_record() {
  # $1 = content
  printf '%s' "$1" > "$work/feasibility-record.md"
}

json_write() {
  # $1 = file path (absolute), $2 = content
  python3 -c '
import json, sys
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": sys.argv[1], "content": sys.argv[2]}}))
' "$1" "$2"
}

json_bash() {
  # $1 = command string
  python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))
'  "$1"
}

check() {
  # $1 = label, $2 = expected ("allow" or "deny"), $3 = actual exit code
  local label="$1" expected="$2" code="$3"
  local ok=0
  if [ "$expected" = "allow" ] && [ "$code" = "0" ]; then
    ok=1
  elif [ "$expected" = "deny" ] && [ "$code" != "0" ]; then
    if grep -qi "denied" "$work/stderr"; then
      ok=1
    else
      echo "FAIL: $label -- exited non-zero but stderr had no visible DENIED message"
    fi
  fi
  if [ "$ok" = 1 ]; then
    pass=$((pass+1))
    echo "PASS: $label (exit=$code)"
  else
    fail=$((fail+1))
    echo "FAIL: $label (expected=$expected exit=$code)"
    echo "  --- stderr ---"
    sed 's/^/  /' "$work/stderr"
  fi
}

# (a) same-state write on a state with NO self-loop row -> DENIED
# 'idle' has no idle|idle row.
new_work
seed_record $'---\nstatus: idle\n---\nbody\n'
payload="$(json_write "$work/feasibility-record.md" $'---\nstatus: idle\nnote: changed\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(a) same-state write, no self-loop row (idle) -> deny" deny "$code"

# (b) same-state write on a state WITH a self-loop row -> ALLOWED
# 'probing' has probing|probing|user row.
new_work
seed_record $'---\nstatus: probing\ntechnical: pass foo\nprior_art: pass bar\nlegal_regulatory: pass baz\nthreat_model: pass qux\n---\nbody\n'
payload="$(json_write "$work/feasibility-record.md" $'---\nstatus: probing\ntechnical: pass foo\nprior_art: pass bar\nlegal_regulatory: pass baz\nthreat_model: pass qux\nnote: timebox extended\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(b) same-state write, has self-loop row (probing) -> allow" allow "$code"

# (c) a normal table-legal transition -> ALLOWED
# scoped -> probing | agent
new_work
seed_record $'---\nstatus: scoped\n---\nbody\n'
payload="$(json_write "$work/feasibility-record.md" $'---\nstatus: probing\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(c) legal transition scoped -> probing -> allow" allow "$code"

# (d) a transition absent from the table -> DENIED
# idle -> verdict is not a row.
new_work
seed_record $'---\nstatus: idle\n---\nbody\n'
payload="$(json_write "$work/feasibility-record.md" $'---\nstatus: verdict\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(d) illegal transition idle -> verdict -> deny" deny "$code"

# (e) Bash-shaped write resolving to the state file is judged the same way,
# including the historical bypass shape f=feasibility-record.md; ... > "$f"
new_work
seed_record $'---\nstatus: idle\n---\nbody\n'
payload="$(json_bash 'f=feasibility-record.md; printf "hi" > "$f"')"
code="$(run_gate "$payload")"
check "(e) Bash bypass shape f=feasibility-record.md > \"\$f\" -> deny" deny "$code"

new_work
seed_record $'---\nstatus: idle\n---\nbody\n'
payload="$(json_bash 'echo hi > feasibility-record.md')"
code="$(run_gate "$payload")"
check "(e2) Bash literal-path redirect into feasibility-record.md -> deny" deny "$code"

# (f) malformed hook JSON -> DENIED with visible output, never silent exit 0
new_work
code="$(run_gate '{not valid json')"
check "(f) malformed hook JSON -> deny with visible message" deny "$code"

# (g) existing state file with value "(none)" -> DENIED with "rules could
# not be loaded" (the hunter's exact reproduction)
new_work
seed_record $'---\nstatus: (none)\n---\nbody\n'
payload="$(json_write "$work/feasibility-record.md" $'---\nstatus: idle\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(g) existing status '(none)' -> deny (rules could not be loaded)" deny "$code"
grep -qi "rules could not be loaded" "$work/stderr" || { echo "FAIL: (g) message did not mention rules could not be loaded"; fail=$((fail+1)); }

# (h) existing state file with an empty status value -> DENIED likewise
new_work
seed_record $'---\nstatus:\n---\nbody\n'
payload="$(json_write "$work/feasibility-record.md" $'---\nstatus: idle\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(h) existing status empty -> deny (rules could not be loaded)" deny "$code"
grep -qi "rules could not be loaded" "$work/stderr" || { echo "FAIL: (h) message did not mention rules could not be loaded"; fail=$((fail+1)); }

# (i) existing state file with a value not in the known-state set -> DENIED
new_work
seed_record $'---\nstatus: not-a-real-state\n---\nbody\n'
payload="$(json_write "$work/feasibility-record.md" $'---\nstatus: idle\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(i) existing status out-of-set -> deny (rules could not be loaded)" deny "$code"
grep -qi "rules could not be loaded" "$work/stderr" || { echo "FAIL: (i) message did not mention rules could not be loaded"; fail=$((fail+1)); }

# (j) existing state file with a valid value followed by trailing
# whitespace/CRLF -> treated as that valid state, not as broken
new_work
seed_record $'---\r\nstatus: scoped   \r\n---\r\nbody\r\n'
payload="$(json_write "$work/feasibility-record.md" $'---\nstatus: probing\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(j) existing status 'scoped' with trailing ws/CRLF -> allow (scoped -> probing)" allow "$code"

# (k) state file genuinely absent -> the (none) -> X bootstrap row is still
# ALLOWED (regression guard)
new_work
payload="$(json_write "$work/feasibility-record.md" $'---\nstatus: idle\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(k) genuinely absent state file -> (none) -> idle bootstrap -> allow" allow "$code"

echo
echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
