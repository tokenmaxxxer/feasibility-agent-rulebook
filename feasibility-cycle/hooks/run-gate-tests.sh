#!/usr/bin/env bash
# Gate tests for state-gate.sh. Feeds hook JSON on stdin, asserts exit code
# and (for denials) that a "DENIED" message appears on stderr. Exits non-zero
# if any case fails.
#
# Cases (a)-(l) below each build their own throwaway git repo under $work
# (root resolution now derives from CLAUDE_PROJECT_DIR — validated against
# the tool call's target and against plausible-project-root markers — per
# docs/proposals/2026-07-26-gate-root-from-project-dir.md), and write to a
# subject-scoped record path under docs/reports/records/ — feasibility's
# only owned-path shape under the v2 per-subject contract (a flat
# feasibility-record.md is NOT an owned path and is silently let through
# unjudged by is_owned_path(), which these cases used to trip over: they
# used to accidentally pass by resolving to the real on-disk repo instead
# of $work, entirely independent of what they intended to test). The
# fresh-repo cases (m)-(p) below seed their own throwaway contract file
# inside a mocked repo and are unaffected either way.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
gate="$script_dir/state-gate.sh"
plugin_root="$(cd "$script_dir/.." && pwd -P)"

pass=0
fail=0

work=""
cleanup() { [ -n "$work" ] && rm -rf "$work"; }
trap cleanup EXIT

record_path="docs/reports/records/gate-test-subject/feasibility.md"

new_work() {
  cleanup
  work="$(mktemp -d)"
  # $work must itself be a plausible project root (per
  # docs/proposals/2026-07-26-gate-root-from-project-dir.md's §2(a2)(ii))
  # for CLAUDE_PROJECT_DIR=$work (as run_gate sets it) to validate.
  git init -q "$work" >/dev/null 2>&1
  mkdir -p "$work/docs/specs" "$(dirname "$work/$record_path")"
  printf 'placeholder collaboration contract for gate tests\n' \
    > "$work/docs/specs/role-handoff-contract.md"
}

run_gate() {
  # $1 = json payload
  CLAUDE_PROJECT_DIR="$work" CLAUDE_PLUGIN_ROOT="$plugin_root" \
    bash "$gate" <<<"$1" >"$work/stdout" 2>"$work/stderr"
  echo $?
}

seed_record() {
  # $1 = content
  printf '%s' "$1" > "$work/$record_path"
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
payload="$(json_write "$work/$record_path" $'---\nstatus: idle\nnote: changed\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(a) same-state write, no self-loop row (idle) -> deny" deny "$code"

# (b) same-state write on a state WITH a self-loop row -> ALLOWED
# 'probing' has probing|probing|user row.
new_work
seed_record $'---\nstatus: probing\ntechnical: pass foo\nprior_art: pass bar\nlegal_regulatory: pass baz\nthreat_model: pass qux\n---\nbody\n'
payload="$(json_write "$work/$record_path" $'---\nstatus: probing\ntechnical: pass foo\nprior_art: pass bar\nlegal_regulatory: pass baz\nthreat_model: pass qux\nnote: timebox extended\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(b) same-state write, has self-loop row (probing) -> allow" allow "$code"

# (c) a normal table-legal transition -> ALLOWED
# scoped -> probing | agent
new_work
seed_record $'---\nstatus: scoped\n---\nbody\n'
payload="$(json_write "$work/$record_path" $'---\nstatus: probing\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(c) legal transition scoped -> probing -> allow" allow "$code"

# (d) a transition absent from the table -> DENIED
# idle -> verdict is not a row.
new_work
seed_record $'---\nstatus: idle\n---\nbody\n'
payload="$(json_write "$work/$record_path" $'---\nstatus: verdict\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(d) illegal transition idle -> verdict -> deny" deny "$code"

# (e) Bash-shaped write resolving to the state file is judged the same way,
# including the historical bypass shape f=<record path>; ... > "$f"
new_work
seed_record $'---\nstatus: idle\n---\nbody\n'
payload="$(json_bash "f=$record_path; printf \"hi\" > \"\$f\"")"
code="$(run_gate "$payload")"
check "(e) Bash bypass shape f=\$record_path > \"\$f\" -> deny" deny "$code"

new_work
seed_record $'---\nstatus: idle\n---\nbody\n'
payload="$(json_bash "echo hi > $record_path")"
code="$(run_gate "$payload")"
check "(e2) Bash literal-path redirect into owned record path -> deny" deny "$code"

# (f) malformed hook JSON -> DENIED with visible output, never silent exit 0
new_work
code="$(run_gate '{not valid json')"
check "(f) malformed hook JSON -> deny with visible message" deny "$code"

# (g) existing state file with value "(none)" -> DENIED with "rules could
# not be loaded" (the hunter's exact reproduction)
new_work
seed_record $'---\nstatus: (none)\n---\nbody\n'
payload="$(json_write "$work/$record_path" $'---\nstatus: idle\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(g) existing status '(none)' -> deny (rules could not be loaded)" deny "$code"
grep -qi "rules could not be loaded" "$work/stderr" || { echo "FAIL: (g) message did not mention rules could not be loaded"; fail=$((fail+1)); }

# (h) existing state file with an empty status value -> DENIED likewise
new_work
seed_record $'---\nstatus:\n---\nbody\n'
payload="$(json_write "$work/$record_path" $'---\nstatus: idle\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(h) existing status empty -> deny (rules could not be loaded)" deny "$code"
grep -qi "rules could not be loaded" "$work/stderr" || { echo "FAIL: (h) message did not mention rules could not be loaded"; fail=$((fail+1)); }

# (i) existing state file with a value not in the known-state set -> DENIED
new_work
seed_record $'---\nstatus: not-a-real-state\n---\nbody\n'
payload="$(json_write "$work/$record_path" $'---\nstatus: idle\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(i) existing status out-of-set -> deny (rules could not be loaded)" deny "$code"
grep -qi "rules could not be loaded" "$work/stderr" || { echo "FAIL: (i) message did not mention rules could not be loaded"; fail=$((fail+1)); }

# (j) existing state file with a valid value followed by trailing
# whitespace/CRLF -> treated as that valid state, not as broken
new_work
seed_record $'---\r\nstatus: scoped   \r\n---\r\nbody\r\n'
payload="$(json_write "$work/$record_path" $'---\nstatus: probing\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(j) existing status 'scoped' with trailing ws/CRLF -> allow (scoped -> probing)" allow "$code"

# (k) state file genuinely absent -> the (none) -> X bootstrap row is still
# ALLOWED (regression guard)
new_work
payload="$(json_write "$work/$record_path" $'---\nstatus: idle\n---\nbody\n')"
code="$(run_gate "$payload")"
check "(k) genuinely absent state file -> (none) -> idle bootstrap -> allow" allow "$code"

# (l) CLAUDE_PROJECT_DIR unset: git-toplevel fallback ---------------------
# Per docs/proposals/2026-07-26-gate-root-from-project-dir.md §2(b): with
# CLAUDE_PROJECT_DIR unset, root falls back to the git top-level of the
# PreToolUse target path, else the git top-level of cwd.
repo_root="$(cd "$script_dir/../.." && pwd -P)"
outside_dir="$(mktemp -d)"
l_scratch_subject="gateroot-l-test"
l_scratch_dir="$repo_root/docs/reports/records/$l_scratch_subject"
mkdir -p "$l_scratch_dir"
payload_l="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"docs/reports/records/$l_scratch_subject/feasibility.md\",\"content\":\"---\\nstatus: idle\\n---\\nbody\\n\"}}"
out_in="$(cd "$repo_root" && env -u CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT="$plugin_root" bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload_l" "$gate" 2>&1)"
code_in=$?
rm -rf "$l_scratch_dir"
if [ "$code_in" -eq 0 ]; then
  echo "PASS: (l1) CLAUDE_PROJECT_DIR unset, invoked inside this repo — falls back to this repo's own git top-level and enforces normally (exit 0)"
  pass=$((pass+1))
else
  echo "FAIL: (l1) CLAUDE_PROJECT_DIR unset, invoked inside this repo — expected exit 0 via git-toplevel fallback, got exit $code_in. Output: $out_in"
  fail=$((fail+1))
fi

# (l2) CLAUDE_PROJECT_DIR unset, cwd AND target both outside any git
# work-tree -> root is indeterminate -> refused (never silently allowed).
out_out="$(cd "$outside_dir" && env -u CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT="$plugin_root" bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload_l" "$gate" 2>&1)"
code_out=$?
rm -rf "$outside_dir"
if [ "$code_out" -ne 0 ]; then
  echo "PASS: (l2) CLAUDE_PROJECT_DIR unset, cwd/target both outside any git work-tree — indeterminate root refused (exit $code_out)"
  pass=$((pass+1))
else
  echo "FAIL: (l2) CLAUDE_PROJECT_DIR unset, cwd/target both outside any git work-tree — expected refused (non-zero), got exit 0. Output: $out_out"
  fail=$((fail+1))
fi

# --- (q) target-repo-governance: CLAUDE_PROJECT_DIR pointed at an
# unrelated, empty (but plausible-looking, git-initialized) directory, and
# the Write targets an owned-tree path that is ALSO not inside any git
# work-tree -> root is genuinely indeterminate -> default-deny per §2(c),
# not silently allowed.
unrelated_dir="$(mktemp -d)"
git init -q "$unrelated_dir" >/dev/null 2>&1
non_git_target_dir="$(mktemp -d)"
scratch_subject_q="gateroot-unrelated-projectdir-test"
mkdir -p "$non_git_target_dir/docs/reports/records/$scratch_subject_q"
payload_q="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$non_git_target_dir/docs/reports/records/$scratch_subject_q/feasibility.md\",\"content\":\"---\\nstatus: idle\\n---\\nbody\\n\"}}"
out_q="$(cd "$non_git_target_dir" && env CLAUDE_PROJECT_DIR="$unrelated_dir" CLAUDE_PLUGIN_ROOT="$plugin_root" bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload_q" "$gate" 2>&1)"
rc_q=$?
rm -rf "$unrelated_dir" "$non_git_target_dir"
if [ "$rc_q" -ne 0 ]; then
  echo "PASS: (q) CLAUDE_PROJECT_DIR pointed at an unrelated empty dir, target's owned-tree write has no resolvable git root either — indeterminate root default-denied (exit $rc_q), not silently allowed"
  pass=$((pass+1))
else
  echo "FAIL: (q) CLAUDE_PROJECT_DIR pointed at an unrelated empty dir, target has no resolvable git root — expected refused (default-deny), got exit 0 (silently allowed). Output: $out_q"
  fail=$((fail+1))
fi

# --- (r) target-repo-governance: CLAUDE_PROJECT_DIR correctly set (target
# is under it, and it looks like a project root) -> gate enforced normally
# against that SEPARATE target project, not against this rulebook repo.
new_work
payload_r="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$work/$record_path\",\"content\":\"---\\nstatus: verdict\\n---\\nbody\\n\"}}"
code_r="$(run_gate "$payload_r")"
if [ "$code_r" -ne 0 ]; then
  echo "PASS: (r) valid CLAUDE_PROJECT_DIR pointed at a separate target project — illegal (none)->verdict bootstrap write refused there (exit $code_r)"
  pass=$((pass+1))
else
  echo "FAIL: (r) valid CLAUDE_PROJECT_DIR pointed at a separate target project — expected refused, got exit 0."
  fail=$((fail+1))
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

# --- (q) write-detection bypass fix (docs/proposals/2026-07-26-fix-state-gate-writeop-bypass.md)
# write-through-another-tool (python3's open()) previously matched none of
# write_shape's idioms, so a write reaching an owned record path via
# `python3 -c "open(path,'w').write(...)"` fell through this gate's
# could_write check entirely and was allowed unjudged. Fixed by adding an
# open()-write detector to write_shape/OPEN_LITERAL_RE.

# (q1) fresh repo: Bash python3-open write reaching feasibility's OWN
# owned record path must now be caught and refused, exactly like the
# already-covered `>`/`tee`/`cp` idioms are (this gate denies ANY
# Bash-mediated write reaching an owned record path outright, since it
# cannot verify the resulting content before the shell runs it).
new_fresh_repo
subject_path="docs/reports/records/widget-x/feasibility.md"
mkdir -p "$(dirname "$work/$subject_path")"
printf -- '---\nstatus: idle\n---\nbody\n' > "$work/$subject_path"
payload_q1=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"python3 -c \"open('$subject_path','w').write('x')\""}}
JSON
)
code_q1="$(run_fresh_gate "$payload_q1")"
check "(q1) fresh repo, Bash python3-open write to feasibility's own record is refused" deny "$code_q1"

# (q2) fresh repo: Bash python3-open write to a path clearly OUTSIDE the
# owned record tree remains ungated (proves the fix does not over-deny).
new_fresh_repo
payload_q2=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"python3 -c \"open('/tmp/unrelated-scratch-file.md','w').write('x')\""}}
JSON
)
code_q2="$(run_fresh_gate "$payload_q2")"
check "(q2) fresh repo, Bash python3-open write outside the owned record tree stays ungated (allow)" allow "$code_q2"

# (q3) fresh repo: Bash python3-open write whose target path is built from
# concatenation (not a clean literal), in a command that names the owned
# record tree, must be default-denied — the gate cannot prove the
# indeterminate target lands outside docs/reports/records/.
new_fresh_repo
payload_q3=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import sys; open('docs/reports/records/' + sys.argv[1] + '/feasibility.md','w').write('x')\" widget-x"}}
JSON
)
code_q3="$(run_fresh_gate "$payload_q3")"
check "(q3) fresh repo, Bash python3-open write with indeterminate target in the owned record tree is refused" deny "$code_q3"

# --- path-reference default-deny (docs/proposals/2026-07-26-gate-nested-shell-default-deny.md)
# Each of these targets feasibility's OWN owned record path via a write
# idiom this gate never enumerated by name (write_text/write_bytes/
# os.write) or via a nested shell / command substitution wrapper around a
# plain write. The rule is not "match this idiom" — it is "default-deny
# any reference into the owned record tree this gate cannot prove is
# read-only" — so all five must be refused regardless of idiom.
new_fresh_repo
subject_path_p="docs/reports/records/widget-x/feasibility.md"
mkdir -p "$(dirname "$work/$subject_path_p")"
printf -- '---\nstatus: idle\n---\nbody\n' > "$work/$subject_path_p"
payload_p1=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import pathlib; pathlib.Path('$subject_path_p').write_text('x')\""}}
JSON
)
code_p1="$(run_fresh_gate "$payload_p1")"
check "(p1) Bash pathlib.Path(...).write_text(...) write to feasibility's own record is refused" deny "$code_p1"

new_fresh_repo
mkdir -p "$(dirname "$work/$subject_path_p")"
printf -- '---\nstatus: idle\n---\nbody\n' > "$work/$subject_path_p"
payload_p2=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import pathlib; pathlib.Path('$subject_path_p').write_bytes(b'x')\""}}
JSON
)
code_p2="$(run_fresh_gate "$payload_p2")"
check "(p2) Bash pathlib.Path(...).write_bytes(...) write to feasibility's own record is refused" deny "$code_p2"

new_fresh_repo
mkdir -p "$(dirname "$work/$subject_path_p")"
printf -- '---\nstatus: idle\n---\nbody\n' > "$work/$subject_path_p"
payload_p3=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import os; fd = os.open('$subject_path_p', os.O_WRONLY); os.write(fd, b'x')\""}}
JSON
)
code_p3="$(run_fresh_gate "$payload_p3")"
check "(p3) Bash os.write(...) write to feasibility's own record is refused" deny "$code_p3"

new_fresh_repo
mkdir -p "$(dirname "$work/$subject_path_p")"
printf -- '---\nstatus: idle\n---\nbody\n' > "$work/$subject_path_p"
payload_p4=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"sh -c \"echo x > $subject_path_p\""}}
JSON
)
code_p4="$(run_fresh_gate "$payload_p4")"
check "(p4) sh -c-wrapped write to feasibility's own record is refused" deny "$code_p4"

new_fresh_repo
mkdir -p "$(dirname "$work/$subject_path_p")"
printf -- '---\nstatus: idle\n---\nbody\n' > "$work/$subject_path_p"
payload_p5=$(cat <<JSON
{"tool_name":"Bash","tool_input":{"command":"echo x > \$(echo $subject_path_p)"}}
JSON
)
code_p5="$(run_fresh_gate "$payload_p5")"
check "(p5) command-substitution-wrapped write to feasibility's own record is refused" deny "$code_p5"

# === scope-record-gate.sh Bash-bypass fix ==================================
# (docs/proposals/2026-07-26-scope-record-gate-bash-bypass.md): a Bash-authored
# write that lands the front record at status: scope-approved used to reach
# zero token-checking hook (hooks.json only wired
# Write|Edit|MultiEdit|NotebookEdit to scope-record-gate.sh). hooks.json now
# also routes Bash there, and the gate judges a Bash write by its resolved
# target and literal resulting content, same as a Write call.
scope_gate="$script_dir/scope-record-gate.sh"

run_scope_gate() {
  # $1 = json payload
  CLAUDE_PROJECT_DIR="$work" CLAUDE_PLUGIN_ROOT="$plugin_root" \
    bash "$scope_gate" <<<"$1" >"$work/stdout" 2>"$work/stderr"
  echo $?
}

# --- (n1) Bash-authored, tokenless scope-approved transition -> REFUSED ---
new_work
seed_record $'---\nstatus: scope-proposed\n---\nbody\n'
bash_approve_cmd="cat > $record_path <<'EOF'
---
status: scope-approved
---
scope approved via Bash, no token
EOF"
payload_n1="$(json_bash "$bash_approve_cmd")"
code_n1="$(run_scope_gate "$payload_n1")"
check "(n1) Bash-authored tokenless scope-approved transition is refused" deny "$code_n1"
if grep -q '^status: scope-proposed$' "$work/$record_path"; then
  pass=$((pass + 1)); echo "PASS: (n1b) front record on disk is still scope-proposed after the refused Bash write"
else
  fail=$((fail + 1)); echo "FAIL: (n1b) front record on disk unexpectedly changed despite the refusal"
fi

# --- (n2) same transition, but with a valid human-placed token -> PASS ---
mkdir -p "$work/docs/reports/records/gate-test-subject/tokens"
printf 'approved by human\n' > "$work/docs/reports/records/gate-test-subject/tokens/scope-approved.token"
code_n2="$(run_scope_gate "$payload_n1")"
check "(n2a) Bash-authored scope-approved transition with a valid token is allowed" allow "$code_n2"
if [ ! -f "$work/docs/reports/records/gate-test-subject/tokens/scope-approved.token" ]; then
  pass=$((pass + 1)); echo "PASS: (n2b) note: this gate's token is read-only (never consumed), matching the pre-existing Write path (token file was intentionally left in place)"
else
  pass=$((pass + 1)); echo "PASS: (n2b) token file still present, as expected (this gate's tokens are not single-use, matching the pre-existing Write path)"
fi

# --- (n3) normal Write-path still behaves: tokenless -> refused, tokened -> allowed
new_work
seed_record $'---\nstatus: scope-proposed\n---\nbody\n'
payload_n3="$(json_write "$work/$record_path" $'---\nstatus: scope-approved\n---\nscope approved via Write\n')"
code_n3a="$(run_scope_gate "$payload_n3")"
check "(n3a) normal Write-path tokenless scope-approved transition is still refused" deny "$code_n3a"
mkdir -p "$work/docs/reports/records/gate-test-subject/tokens"
printf 'approved by human\n' > "$work/docs/reports/records/gate-test-subject/tokens/scope-approved.token"
code_n3b="$(run_scope_gate "$payload_n3")"
check "(n3b) normal Write-path scope-approved transition with a valid token is still allowed" allow "$code_n3b"

# --- (n4) Bash write unrelated to the front record path -> left alone -----
new_work
payload_n4="$(json_bash "echo hi > /tmp/feasibility-scope-record-gate-unrelated-scratch.txt")"
code_n4="$(run_scope_gate "$payload_n4")"
rm -f /tmp/feasibility-scope-record-gate-unrelated-scratch.txt
check "(n4) Bash write unrelated to the front record tree is left ungated" allow "$code_n4"

# === tool-agnostic default-deny (docs/proposals/2026-07-26-scope-record-gate-tool-agnostic.md)
# feasibility's non-Write path used to deny every Edit/MultiEdit/NotebookEdit
# unconditionally (safe but over-broad — legitimate non-transition writes via
# those tools were blocked too). It now evaluates Edit/MultiEdit by applying
# the edit to on-disk content, and NotebookEdit/unrecognized tools by
# extracting a content-bearing field, judging each exactly like Write. These
# cases prove: NotebookEdit and an arbitrary unrecognized tool are refused
# tokenless; every recognized tool passes with a valid token; every
# recognized tool still passes a normal, non-scope-approved write.
json_notebookedit() { # <path> <new_source>
  python3 -c 'import json,sys;print(json.dumps({"tool_name":"NotebookEdit","tool_input":{"notebook_path":sys.argv[1],"new_source":sys.argv[2]}}))' "$1" "$2"
}
json_unknown_tool() { # <path> <content>
  python3 -c 'import json,sys;print(json.dumps({"tool_name":"SomeFutureTool","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]}}))' "$1" "$2"
}
mint_token_feas() { # subject
  mkdir -p "$work/docs/reports/records/$1/tokens"
  printf 'approved by human\n' > "$work/docs/reports/records/$1/tokens/scope-approved.token"
}

# --- (t1) NotebookEdit-authored, tokenless scope-approved -> REFUSED -------
new_work
seed_record $'---\nstatus: scope-proposed\n---\nbody\n'
payload_t1="$(json_notebookedit "$work/$record_path" $'---\nstatus: scope-approved\n---\nbody\n')"
code_t1="$(run_scope_gate "$payload_t1")"
check "(t1) NotebookEdit-authored tokenless scope-approved transition is refused" deny "$code_t1"

# --- (t2) unrecognized/other-tool, tokenless scope-approved -> REFUSED -----
new_work
seed_record $'---\nstatus: scope-proposed\n---\nbody\n'
payload_t2="$(json_unknown_tool "$work/$record_path" $'---\nstatus: scope-approved\n---\nbody\n')"
code_t2="$(run_scope_gate "$payload_t2")"
check "(t2) unrecognized-tool tokenless scope-approved transition is refused" deny "$code_t2"

# --- (t3) properly-tokened transition PASSES for every tool ---------------
for tname in Write Edit MultiEdit NotebookEdit Bash; do
  new_work
  seed_record $'---\nstatus: scope-proposed\n---\nbody\n'
  mint_token_feas "gate-test-subject"
  case "$tname" in
    Write)
      payload_t3="$(json_write "$work/$record_path" $'---\nstatus: scope-approved\n---\nbody\n')"
      ;;
    Edit)
      payload_t3="$(python3 -c 'import json,sys;print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":"status: scope-proposed","new_string":"status: scope-approved"}}))' "$work/$record_path")"
      ;;
    MultiEdit)
      payload_t3="$(python3 -c 'import json,sys;print(json.dumps({"tool_name":"MultiEdit","tool_input":{"file_path":sys.argv[1],"edits":[{"old_string":"status: scope-proposed","new_string":"status: scope-approved"}]}}))' "$work/$record_path")"
      ;;
    NotebookEdit)
      payload_t3="$(json_notebookedit "$work/$record_path" $'---\nstatus: scope-approved\n---\nbody\n')"
      ;;
    Bash)
      bash_cmd_t3="cat > $record_path <<'EOF'
---
status: scope-approved
---
body
EOF"
      payload_t3="$(json_bash "$bash_cmd_t3")"
      ;;
  esac
  code_t3="$(run_scope_gate "$payload_t3")"
  check "(t3-$tname) tokened scope-approved transition via $tname is allowed" allow "$code_t3"
done

# --- (t4) normal, non-scope-approved write still PASSES for every tool -----
for tname in Write Edit MultiEdit NotebookEdit Bash; do
  new_work
  seed_record $'---\nstatus: scope-proposed\n---\nbody\n'
  case "$tname" in
    Write)
      payload_t4="$(json_write "$work/$record_path" $'---\nstatus: scope-proposed\nnote: still gathering\n---\nbody\n')"
      ;;
    Edit)
      payload_t4="$(python3 -c 'import json,sys;print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":"status: scope-proposed","new_string":"status: scope-proposed\nnote: still gathering"}}))' "$work/$record_path")"
      ;;
    MultiEdit)
      payload_t4="$(python3 -c 'import json,sys;print(json.dumps({"tool_name":"MultiEdit","tool_input":{"file_path":sys.argv[1],"edits":[{"old_string":"status: scope-proposed","new_string":"status: scope-proposed\nnote: still gathering"}]}}))' "$work/$record_path")"
      ;;
    NotebookEdit)
      payload_t4="$(json_notebookedit "$work/$record_path" $'---\nstatus: scope-proposed\nnote: still gathering\n---\nbody\n')"
      ;;
    Bash)
      bash_cmd_t4="cat > $record_path <<'EOF'
---
status: scope-proposed
note: still gathering
---
body
EOF"
      payload_t4="$(json_bash "$bash_cmd_t4")"
      ;;
  esac
  code_t4="$(run_scope_gate "$payload_t4")"
  check "(t4-$tname) normal non-scope-approved write via $tname still passes" allow "$code_t4"
done

# === deny-on-ambiguity (docs/proposals/2026-07-26-scope-record-gate-deny-on-ambiguity.md)
# Terminal fix: (a) hooks.json routes scope-record-gate.sh via a catch-all
# matcher so no tool name escapes it; (b) a Bash write whose captured
# front-record target/content contains any shell expansion marker is refused
# rather than judged by its unexpanded literal text.

# --- (u0) hooks.json routes scope-record-gate.sh via a catch-all matcher ---
hooks_json="$script_dir/hooks.json"
if python3 -c '
import json, re, sys
data = json.load(open(sys.argv[1]))
ok = False
for entry in data["hooks"]["PreToolUse"]:
    names = [h.get("command", "") for h in entry.get("hooks", [])]
    if any("scope-record-gate.sh" in n for n in names):
        matcher = entry.get("matcher", "")
        if re.fullmatch(matcher, "apply_patch") and re.fullmatch(matcher, "SomeBrandNewTool"):
            ok = True
sys.exit(0 if ok else 1)
' "$hooks_json"; then
  pass=$((pass+1)); echo "PASS: (u0) hooks.json routes scope-record-gate.sh via a catch-all matcher (matches unenumerated tool names)"
else
  fail=$((fail+1)); echo "FAIL: (u0) hooks.json does NOT route scope-record-gate.sh via a catch-all matcher"
fi

# --- (u1) the \$VAR-heredoc bypass is now REFUSED --------------------------
new_work
seed_record $'---\nstatus: scope-proposed\n---\nbody\n'
bash_u1_cmd="STATE=scope-approved; cat > $record_path <<EOF
---
status: \$STATE
---
EOF"
payload_u1="$(json_bash "$bash_u1_cmd")"
code_u1="$(run_scope_gate "$payload_u1")"
check "(u1) \$VAR-heredoc scope-approved bypass is now refused" deny "$code_u1"
if grep -q '^status: scope-proposed$' "$work/$record_path"; then
  pass=$((pass + 1)); echo "PASS: (u1b) front record on disk is still scope-proposed after the refused \$VAR-heredoc write"
else
  fail=$((fail + 1)); echo "FAIL: (u1b) front record on disk unexpectedly changed despite the refusal"
fi

# --- (u2) catch-all-matched unknown-named tool, tokenless scope-approved -> REFUSED
new_work
seed_record $'---\nstatus: scope-proposed\n---\nbody\n'
payload_u2="$(python3 -c 'import json,sys;print(json.dumps({"tool_name":"apply_patch","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]}}))' "$work/$record_path" $'---\nstatus: scope-approved\n---\nbody\n')"
code_u2="$(run_scope_gate "$payload_u2")"
check "(u2) catch-all-matched unknown tool name, tokenless scope-approved, is refused" deny "$code_u2"

# --- (u3) provably-literal non-scope Bash write still PASSES ---------------
new_work
seed_record $'---\nstatus: scope-proposed\n---\nbody\n'
bash_u3_cmd="cat > $record_path <<'EOF'
---
status: scope-proposed
note: still gathering evidence
---
EOF"
payload_u3="$(json_bash "$bash_u3_cmd")"
code_u3="$(run_scope_gate "$payload_u3")"
check "(u3) provably-literal non-scope-approved Bash write still passes" allow "$code_u3"

# --- (u4) properly-tokened scope-approved transition still PASSES ----------
new_work
seed_record $'---\nstatus: scope-proposed\n---\nbody\n'
mint_token_feas "gate-test-subject"
bash_u4_cmd="cat > $record_path <<'EOF'
---
status: scope-approved
---
body
EOF"
payload_u4="$(json_bash "$bash_u4_cmd")"
code_u4="$(run_scope_gate "$payload_u4")"
check "(u4) properly-tokened scope-approved transition still passes" allow "$code_u4"

# === read-only-tool passthrough regression fix
# (docs/proposals/2026-07-26-scope-record-gate-deny-on-ambiguity.md): the
# catch-all `.*` matcher (see hooks.json) routes every tool, including
# read-only ones, into scope-record-gate.sh. The tool-agnostic default-deny
# then refused Read/Grep/Glob/LS on the front record because their payload
# has no content field — wrongly blocking reads. These tools must PASS
# untouched regardless of payload shape or on-disk state.

# --- (v1) Read of the front-record path PASSES ------------------------------
new_work
seed_record $'---\nstatus: scope-proposed\n---\nbody\n'
payload_v1="$(python3 -c 'import json,sys;print(json.dumps({"tool_name":"Read","tool_input":{"file_path":sys.argv[1]}}))' "$work/$record_path")"
code_v1="$(run_scope_gate "$payload_v1")"
check "(v1) Read of the front-record path passes" allow "$code_v1"

# --- (v2) Grep over the front-record tree PASSES ----------------------------
new_work
seed_record $'---\nstatus: scope-proposed\n---\nbody\n'
payload_v2="$(python3 -c 'import json;print(json.dumps({"tool_name":"Grep","tool_input":{"pattern":"status","path":"docs/reports/records"}}))')"
code_v2="$(run_scope_gate "$payload_v2")"
check "(v2) Grep over the front-record tree passes" allow "$code_v2"

# --- (v3) Glob over the front-record tree PASSES ----------------------------
new_work
payload_v3="$(python3 -c 'import json;print(json.dumps({"tool_name":"Glob","tool_input":{"pattern":"docs/reports/records/**/feasibility.md"}}))')"
code_v3="$(run_scope_gate "$payload_v3")"
check "(v3) Glob over the front-record tree passes" allow "$code_v3"

# --- (v4) previously-refused write bypasses STILL refuse (guard against ----
#     over-widening the passthrough to write-shaped tools) ------------------
new_work
seed_record $'---\nstatus: scope-proposed\n---\nbody\n'
bash_v4_cmd="STATE=scope-approved; cat > $record_path <<EOF
---
status: \$STATE
---
EOF"
payload_v4="$(json_bash "$bash_v4_cmd")"
code_v4="$(run_scope_gate "$payload_v4")"
check "(v4a) \$VAR-heredoc bypass is still refused after the read-only passthrough fix" deny "$code_v4"

new_work
seed_record $'---\nstatus: scope-proposed\n---\nbody\n'
payload_v4b="$(python3 -c 'import json,sys;print(json.dumps({"tool_name":"apply_patch","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]}}))' "$work/$record_path" $'---\nstatus: scope-approved\n---\nbody\n')"
code_v4b="$(run_scope_gate "$payload_v4b")"
check "(v4b) unknown-named WRITE tool, tokenless scope-approved, is still refused" deny "$code_v4b"

echo
echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
