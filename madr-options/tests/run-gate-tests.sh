#!/usr/bin/env bash
# Standalone tests for madr-options/hooks/options-gate.sh, exercised as a real
# subprocess. Mirrors the tmpdir + python3 json.dumps harness style of the
# repo-root tests/run-gate-tests.sh.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
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

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
