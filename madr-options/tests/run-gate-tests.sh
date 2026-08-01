#!/usr/bin/env bash
# Standalone tests for madr-options/hooks/options-gate.sh, exercised as a real
# subprocess. Mirrors the tmpdir + python3 json.dumps harness style of the
# repo-root tests/run-gate-tests.sh.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"

# options-gate.sh now hard-depends on core's gate-lib.sh (issue-42 gate-lib
# migration) — same external-dependency posture the root tests/
# run-gate-tests.sh already tolerates for record-fields-gate.sh/
# trailer-gate.sh. When core isn't checked out next to this repo, skip
# rather than fail: a missing external dependency is not this repo's own
# gate regressing.
GATE_LIB_CHECK="${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$HERE/../../core" 2>/dev/null && pwd -P)}/hooks/lib/gate-lib.sh"
if [ ! -f "$GATE_LIB_CHECK" ]; then
  echo "SKIP-ALL: core/hooks/lib/gate-lib.sh not found at $GATE_LIB_CHECK (external dependency not checked out; set CLAUDE_PLUGIN_ROOT_CORE)"
  exit 0
fi

pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

run() { # want name file content [extra_env]
  local want="$1" name="$2" file="$3" content="$4" extra_env="${5:-}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/$(dirname "$file")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$file" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    | env $extra_env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/options-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

# --- two-file scenario helper (phase-1 proposal already on disk, then a
#     phase-2 Write is fed through the gate) ---
run_with_proposal() { # want name issue proposal_content record_content
  local want="$1" name="$2" issue="$3" proposal_content="$4" record_content="$5"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/docs/issue-$issue/proposals" "$td/docs/issue-$issue/reports"
  printf '%s' "$proposal_content" > "$td/docs/issue-$issue/proposals/2026-01-01-technical-feasibility.md"
  local file="docs/issue-$issue/reports/technical-feasibility.md"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$file" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$record_content")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/options-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

PROP=docs/issue-7/proposals/2026-01-01-technical-feasibility.md

GOOD_P1='## Candidates considered
- Option A — fast but requires new infra
- Option B — reuses existing infra but slower

## Timebox and acceptance criteria
Timebox: 2 days. Acceptance: a working spike.'
run allow phase1-good "$PROP" "$GOOD_P1"

SINGLE_P1='## Candidates considered
- Option A — the only thing we looked at

## Timebox and acceptance criteria
Timebox: 2 days.'
run deny phase1-single-candidate "$PROP" "$SINGLE_P1"

NO_TIMEBOX_P1='## Candidates considered
- Option A — fast but requires new infra
- Option B — reuses existing infra but slower'
run deny phase1-missing-timebox "$PROP" "$NO_TIMEBOX_P1"

# --- phase-2 carry-forward ---
P1_CONTENT='## Candidates considered
- Option A — fast but requires new infra
- Option B — reuses existing infra but slower

## Timebox and acceptance criteria
Timebox: 2 days.'

CARRIED_RECORD='## Options considered
- Option A — chosen, fast enough
- Option B — rejected, too slow'
run_with_proposal allow phase2-carried-forward 7 "$P1_CONTENT" "$CARRIED_RECORD"

DROPPED_RECORD='## Options considered
- Option A — chosen, fast enough
- Option B dropped: no longer relevant after infra change'
run_with_proposal allow phase2-dropped-with-reason 7 "$P1_CONTENT" "$DROPPED_RECORD"

MISSING_RECORD='## Options considered
- Option A — chosen, fast enough'
run_with_proposal deny phase2-missing-no-reason 7 "$P1_CONTENT" "$MISSING_RECORD"

# --- foreign path / kill switch ---
run allow foreign-path "docs/issue-7/reports/other.md" "anything at all"
run allow kill-switch "$PROP" "not even close to valid" "MADR_OPTIONS_GATE_OFF=1"
run deny kill-switch-unrecognized "$PROP" "not even close to valid" "MADR_OPTIONS_GATE_OFF=banana"

# --- Edit/MultiEdit against an owned path: this gate still needs the
#     complete content (in-scope: gate-lib migration only, Edit posture
#     unchanged per the approved proposal) -> deny either way.
edit_case() { # want name tool file ti_json
  local want="$1" name="$2" tool="$3" file="$4" ti_json="$5"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$file")"
  printf '{"tool_name":"%s","tool_input":%s,"cwd":"%s"}' "$tool" "$ti_json" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/options-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
edit_case deny edit-replace-all-owned-path Edit "$PROP" \
  '{"file_path":"'"$PROP"'","old_string":"x","new_string":"y","replace_all":true}'
edit_case deny multiedit-mixed-replace-all-owned-path MultiEdit "$PROP" \
  '{"file_path":"'"$PROP"'","edits":[{"old_string":"x","new_string":"y","replace_all":true},{"old_string":"a","new_string":"b","replace_all":false}]}'

# --- malformed JSON: truncated / empty / non-object payload ---
malformed_case() { # want name raw_payload
  local want="$1" name="$2" raw="$3"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  printf '%s' "$raw" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/options-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
malformed_case deny malformed-json-truncated '{"tool_name":"Write","tool_input":{'
malformed_case deny malformed-json-empty ''
malformed_case deny malformed-json-non-object '"just a string"'

# --- absolute path + ./-prefixed path, matching the same relative fixture ---
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$PROP")"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$td/$PROP" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$SINGLE_P1")" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/options-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" absolute-path-single-candidate

run deny dot-prefixed-path-single-candidate "./$PROP" "$SINGLE_P1"

# --- Bash-tool write reaching the same owned target ---
bash_case() { # want name command
  local want="$1" name="$2" cmd="$3"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":"%s"}' \
    "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$cmd")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/options-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
bash_case deny bash-write-owned-target "echo x > $PROP"
bash_case allow bash-write-foreign-target "echo hi > /tmp/scratch.txt"

# --- missing-core: CLAUDE_PLUGIN_ROOT_CORE points nowhere -> guarded source must deny ---
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"},"cwd":"%s"}' "$PROP" "$td" \
  | env CLAUDE_PLUGIN_ROOT_CORE="$td/no-such-core" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/options-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" missing-core

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
