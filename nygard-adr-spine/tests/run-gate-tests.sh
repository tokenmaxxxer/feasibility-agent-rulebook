#!/usr/bin/env bash
# Standalone harness for nygard-adr-spine's spine-gate.sh, exercised as a
# real subprocess. Mirrors the git-init-tmpdir + python3 json.dumps
# pattern used by the repo-root tests/run-gate-tests.sh.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"

# spine-gate.sh now hard-depends on core's gate-lib.sh (issue-42 gate-lib
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

# Kill switch: unrecognized value stays active (not disabled).
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
set +o pipefail
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "nothing complete here")" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" NYGARD_ADR_SPINE_GATE_OFF=banana /bin/bash "$HOOKS/spine-gate.sh" >/dev/null 2>&1
rc=$?; set -o pipefail; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" kill-switch-unrecognized

# --- Edit/MultiEdit reconstruction against the real on-disk record ---
edit_case() { # want name initial_content tool_input_json
  local want="$1" name="$2" initial="$3" ti_json="$4"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '%s' "$initial" > "$td/$REC"
  printf '{"tool_name":"Edit","tool_input":%s,"cwd":"%s"}' "$ti_json" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/spine-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

# Edit against an already-complete record, replace_all true against a
# multiply-occurring old_string, result stays complete -> allow (proves
# Edit no longer denies unconditionally).
edit_case allow edit-replace-all-still-complete "$COMPLETE" \
'{"file_path":"'"$REC"'","old_string":"proposed","new_string":"accepted","replace_all":true}'

# Edit whose old_string is not present -> unreconstructable -> deny.
edit_case deny edit-old-string-not-found "$COMPLETE" \
'{"file_path":"'"$REC"'","old_string":"NOT PRESENT","new_string":"x"}'

# MultiEdit with mixed replace_all true/false, reconstructed result is
# still missing Status -> deny.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
printf '%s' "$COMPLETE" > "$td/$REC"
printf '{"tool_name":"MultiEdit","tool_input":{"file_path":"%s","edits":[{"old_string":"## Status\nproposed","new_string":"","replace_all":false},{"old_string":"accepted","new_string":"accepted","replace_all":true}]},"cwd":"%s"}' \
  "$REC" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/spine-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" multiedit-mixed-replace-all-still-incomplete

# --- malformed JSON: truncated / empty / non-object payload ---
malformed_case() { # want name raw_payload
  local want="$1" name="$2" raw="$3"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  printf '%s' "$raw" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/spine-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
malformed_case deny malformed-json-truncated '{"tool_name":"Write","tool_input":{'
malformed_case deny malformed-json-empty ''
malformed_case deny malformed-json-non-object '"just a string"'

# --- absolute path + ./-prefixed path, matching the same relative fixture ---
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$td/$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "nothing complete here")" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/spine-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" absolute-path-incomplete

run deny dot-prefixed-path-incomplete "./$REC" "nothing complete here"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
