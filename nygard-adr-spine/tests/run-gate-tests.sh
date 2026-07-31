#!/usr/bin/env bash
# Standalone harness for nygard-adr-spine's spine-gate.sh, exercised as a
# real subprocess. Mirrors the git-init-tmpdir + python3 json.dumps
# pattern used by the repo-root tests/run-gate-tests.sh.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

REC=docs/issue-7/reports/technical-feasibility.md

run() { # want name file content [extra_env...]
  local want="$1" name="$2" file="$3" content="$4"; shift 4
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$file")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$file" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" "$@" /bin/bash "$HOOKS/spine-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

COMPLETE='## Status
proposed

## Context
The team needs to decide how the phase-2 record represents its ADR.

## Decision
go — adopt the Nygard spine as the base shape.

## Consequences
one-way door; once adopted, downstream records depend on this shape.

## Risks
- Gate too strict — mitigated by heuristic fallback matching.
- Adoption friction — accepted as a one-time cost.'

run allow spine-complete "$REC" "$COMPLETE"

MISSING_STATUS='## Context
Needs a decision.

## Decision
go — adopt the spine.

## Consequences
one-way door.

## Risks
- Some risk — mitigated.'
run deny missing-status "$REC" "$MISSING_STATUS"

RISK_NO_DISPOSITION='## Status
accepted

## Context
Needs a decision.

## Decision
go — adopt the spine.

## Consequences
two-way door.

## Risks
- Some risk with no disposition stated.'
run deny risk-no-disposition "$REC" "$RISK_NO_DISPOSITION"

TERMINAL_INCOMPLETE='## loop_state
verdict

## Decision
go.

## Risks
- Some risk — accepted.'
run deny terminal-incomplete-spine "$REC" "$TERMINAL_INCOMPLETE"

run allow foreign-path "docs/issue-7/reports/other.md" "anything at all"

td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
set +o pipefail
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "nothing complete here")" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" NYGARD_ADR_SPINE_GATE_OFF=1 /bin/bash "$HOOKS/spine-gate.sh" >/dev/null 2>&1
rc=$?; set -o pipefail; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report allow "$got" kill-switch

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
