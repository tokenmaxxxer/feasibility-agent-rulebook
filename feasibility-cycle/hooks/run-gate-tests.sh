#!/usr/bin/env bash
# Gate tests for state-gate.sh. Feeds hook JSON on stdin, asserts exit code
# and (for denials) that a "DENIED" message appears on stderr. Exits non-zero
# if any case fails.
#
# Cases (a)-(l) below run against THIS repo's own on-disk checkout (root
# resolution walks up from the gate script's own location), so they depend
# on this repo carrying its own docs/specs/role-handoff-contract.md. That
# file now exists (see docs/proposals/2026-07-27-repo-local-contract-file.md),
# so these cases exercise real transition-table logic instead of failing
# uniformly on the contract-presence check. The fresh-repo cases (m)-(p)
# below seed their own throwaway contract file inside a mocked repo and are
# unaffected either way.
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
  # Rule 0 needs the contract in the repo under test. Before the gate
  # anchored on the project being worked in, this passed because root
  # resolved to the RULEBOOK repo, which carries one — the fixtures were
  # never exercising Rule 0 against themselves.
  mkdir -p "$work/docs/specs"
  printf '# role-handoff-contract\n' > "$work/docs/specs/role-handoff-contract.md"
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

# (l) the gate follows the project, not its own location ------------------
# Where this hook sits on disk must not decide what it guards. Copy the whole
# hooks directory somewhere outside any project, run that copy with the
# project as cwd, and it must reach the same decision as the in-repo copy.
#
# Until 2026-07-26 root was the nearest `.git` ABOVE the hook itself. A
# rulebook loaded as a plugin from its own checkout — which is how an
# orchestrator swaps rulebooks per role — therefore guarded the rulebook's
# repo, and every write in the real project fell outside its owned paths and
# was allowed, silently, exit 0.
repo_root="$(cd "$script_dir/../.." && pwd -P)"
elsewhere="$(mktemp -d)"
cp -R "$script_dir" "$elsewhere/hooks"
payload_l='{"tool_name":"Write","tool_input":{"file_path":"docs/reports/records/s/feasibility.md","content":"---\nstatus: idle\n---\n"}}'
out_in="$(cd "$repo_root" && env -u CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT="$plugin_root" bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload_l" "$gate" 2>&1)"
code_in=$?
out_out="$(cd "$repo_root" && env -u CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT="$plugin_root" bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload_l" "$elsewhere/hooks/state-gate.sh" 2>&1)"
code_out=$?
rm -rf "$elsewhere"
if [ "$code_in" -eq "$code_out" ]; then
  pass=$((pass+1)); echo "PASS: (l) a copy of the gate outside the rulebook reaches the same decision as the in-repo gate (exit $code_out)"
else
  fail=$((fail+1)); echo "FAIL: (l) the gate's own location changed its decision (in-repo exit $code_in, out-of-tree exit $code_out) — out: $out_out | in: $out_in"
fi

# --- fresh-repo subject-scoped ownership + repo-local resolution cases ----
# state-gate.sh anchors its root by walking UP from ITS OWN on-disk location
# to the nearest enclosing .git — so to exercise it against a genuinely
# fresh/foreign repo (not this rulebook checkout), the gate script and
# transition-rules.md must themselves be copied into that fresh repo's own
# feasibility-cycle/hooks/ layout and invoked from there. This is also what
# proves the CLAUDE_PLUGIN_ROOT-independent fix: these cases run WITHOUT
# CLAUDE_PLUGIN_ROOT set at all (unset, not just empty), and without it
# pointing anywhere near the fresh repo.
new_fresh_repo() {
  cleanup
  work="$(mktemp -d)"
  git -C "$work" init -q
  mkdir -p "$work/docs/specs" "$work/feasibility-cycle/hooks"
  printf 'placeholder collaboration contract for gate tests\n' \
    > "$work/docs/specs/role-handoff-contract.md"
  cp "$gate" "$work/feasibility-cycle/hooks/state-gate.sh"
  cp "$script_dir/transition-rules.md" "$work/feasibility-cycle/hooks/transition-rules.md"
}

run_fresh_gate() {
  # $1 = json payload; runs the COPY of the gate that now lives inside the
  # fresh repo, with CLAUDE_PLUGIN_ROOT deliberately unset and
  # CLAUDE_PROJECT_DIR unset, so nothing but the script's own on-disk
  # location (inside the fresh repo) can supply the root/rules resolution.
  env -u CLAUDE_PLUGIN_ROOT -u CLAUDE_PROJECT_DIR \
    bash "$work/feasibility-cycle/hooks/state-gate.sh" \
    <<<"$1" >"$work/stdout" 2>"$work/stderr"
  echo $?
}

# (m) fresh repo, subject-scoped feasibility record, (none) -> idle bootstrap
# write to docs/reports/records/<subject>/feasibility.md -> ALLOW, and the
# gate must NOT fail with "rules could not be loaded" (proves repo-local
# transition-rules.md resolution works with CLAUDE_PLUGIN_ROOT unset).
new_fresh_repo
subject_path="docs/reports/records/widget-x/feasibility.md"
payload="$(json_write "$work/$subject_path" $'---\nstatus: idle\n---\nbody\n')"
code="$(run_fresh_gate "$payload")"
check "(m) fresh repo, subject-scoped feasibility.md, (none) -> idle -> allow" allow "$code"
grep -qi "rules could not be loaded" "$work/stderr" && {
  echo "FAIL: (m) gate reported rules could not be loaded despite repo-local transition-rules.md being present"
  fail=$((fail+1))
}

# (n) fresh repo, same subject, a legal in-subject transition
# scoped -> probing -> ALLOW, still no CLAUDE_PLUGIN_ROOT.
new_fresh_repo
subject_path="docs/reports/records/widget-x/feasibility.md"
mkdir -p "$(dirname "$work/$subject_path")"
printf -- '---\nstatus: scoped\n---\nbody\n' > "$work/$subject_path"
payload="$(json_write "$work/$subject_path" $'---\nstatus: probing\n---\nbody\n')"
code="$(run_fresh_gate "$payload")"
check "(n) fresh repo, subject-scoped feasibility.md, scoped -> probing -> allow" allow "$code"

# (o) fresh repo, foreign-role write under the SAME subject
# (docs/reports/records/<subject>/coding.md) does not match feasibility's
# owned-path shape at all -> the gate has nothing to enforce and lets it
# through unjudged (§11: a role's gate only ever governs its OWN
# <role>.md under a subject, never a sibling role's file) -- this is the
# REFUSE-shaped case in spirit (the write is not feasibility's to police)
# and must not be confused with an ALLOW verdict on a feasibility
# transition: no transition-table judgement occurs at all here.
new_fresh_repo
foreign_path="docs/reports/records/widget-x/coding.md"
mkdir -p "$(dirname "$work/$foreign_path")"
payload="$(json_write "$work/$foreign_path" $'---\nstatus: idle\n---\nbody\n')"
code="$(run_fresh_gate "$payload")"
check "(o) fresh repo, foreign-role coding.md under same subject -> allow (not feasibility-owned, ungated)" allow "$code"

# (p) fresh repo, feasibility spike record under a subject -> ALLOW
# (docs/reports/records/<subject>/spikes/<slug>.md), proving the owned-path
# regex's second shape still resolves against the repo-local root.
new_fresh_repo
spike_path="docs/reports/records/widget-x/spikes/probe-one.md"
mkdir -p "$(dirname "$work/$spike_path")"
payload="$(json_write "$work/$spike_path" $'---\nstatus: idle\n---\nbody\n')"
code="$(run_fresh_gate "$payload")"
check "(p) fresh repo, subject-scoped spikes/<slug>.md, (none) -> idle -> allow" allow "$code"

echo
echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
