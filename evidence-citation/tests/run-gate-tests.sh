#!/usr/bin/env bash
# Standalone test harness for evidence-citation/hooks/citation-gate.sh.
# Mirrors the pattern in the repo-root tests/run-gate-tests.sh: spin up a
# throwaway git-init'd tmpdir per case, feed the gate a JSON payload on
# stdin, and check its exit code (0=allow, 2=deny).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"

# citation-gate.sh now hard-depends on core's gate-lib.sh (issue-42 gate-lib
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

run() { # want name file content [extra_env...]
  want="$1" name="$2" file="$3" content="$4"; shift 4
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/$(dirname "$file")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$file" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    | env "$@" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/citation-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

PHASE1=docs/issue-7/proposals/2026-01-01-technical-feasibility.md
PHASE2=docs/issue-7/reports/technical-feasibility.md

# Phase 1: allow — cited claims in Evidence format section.
run allow phase1-cited "$PHASE1" '## Evidence format
The library is actively maintained — source: https://github.com/example/repo
Test coverage is high — check-name Maintained score 9'

# Phase 1: deny — Evidence format section present with prose but zero citations.
run deny phase1-uncited "$PHASE1" '## Evidence format
The library is actively maintained and well tested.
Everything looks fine.'

# Phase 1: allow — bare/empty Evidence format section (nothing to check).
run allow phase1-empty-section "$PHASE1" '## Evidence format

## Next section
some text'

# Phase 2: allow — all claims cited or carried forward.
run allow phase2-cited "$PHASE2" '## Decision
We chose library X — source: https://github.com/example/repo
It performed well in the spike — path:tests/spike.py:42'

# Phase 2: deny — a new claim with no citation anywhere in the document.
run deny phase2-uncited "$PHASE2" '## Decision
We chose library X because it is fast and well documented.
This is the final decision.'

# Foreign path: allow (passthrough).
run allow foreign-path "docs/issue-7/reports/other.md" "no citations here at all."

# Kill switch: allow regardless of content.
run allow kill-switch "$PHASE1" '## Evidence format
totally uncited prose with no citation shape at all.' EVIDENCE_CITATION_GATE_OFF=1

# Kill switch: unrecognized value stays active (not disabled).
run deny kill-switch-unrecognized "$PHASE1" '## Evidence format
totally uncited prose with no citation shape at all.' EVIDENCE_CITATION_GATE_OFF=banana

# ASCII '--' separator accepted alongside the em-dash.
run allow ascii-dash-citation "$PHASE1" '## Evidence format
The library is actively maintained -- source: https://github.com/example/repo'

# Section/adjacency upgrade: one citation cannot cover five distinct claims.
run deny phase1-one-citation-five-claims "$PHASE1" '## Evidence format
The library is actively maintained.
It has high test coverage.
It is widely adopted.
It has a permissive license.
Only this one line is cited — source: https://github.com/example/repo'

# --- Edit/MultiEdit reconstruction (against real on-disk content) ---
edit_case() { # want name file initial_content tool_input_json [extra_env...]
  local want="$1" name="$2" file="$3" initial="$4" ti_json="$5"; shift 5
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/$(dirname "$file")"
  printf '%s' "$initial" > "$td/$file"
  printf '{"tool_name":"Edit","tool_input":%s,"cwd":"%s"}' "$ti_json" "$td" \
    | env "$@" CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/citation-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

# Edit with replace_all: true against a multiply-occurring old_string —
# reconstructed result still lacks a citation -> deny.
edit_case deny edit-replace-all-still-uncited "$PHASE1" \
'## Evidence format
CLAIM CLAIM' \
'{"file_path":"'"$PHASE1"'","old_string":"CLAIM","new_string":"The lib is fast.","replace_all":true}'

# Edit with replace_all: true where the reconstructed result carries a
# citation -> allow (proves the Edit is checked against the merged result,
# not a bare fragment).
edit_case allow edit-replace-all-cited "$PHASE1" \
'## Evidence format
CLAIM CLAIM' \
'{"file_path":"'"$PHASE1"'","old_string":"CLAIM","new_string":"— source: https://example.com","replace_all":true}'

# Edit whose old_string is not present in the current file -> unreconstructable -> deny.
edit_case deny edit-old-string-not-found "$PHASE1" \
'## Evidence format
something else entirely' \
'{"file_path":"'"$PHASE1"'","old_string":"NOT PRESENT","new_string":"x"}'

# MultiEdit with mixed replace_all true/false, reconstructed result is
# fully cited -> allow.
multiedit_case() {
  local want="$1" name="$2" file="$3" initial="$4" ti_json="$5"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/$(dirname "$file")"
  printf '%s' "$initial" > "$td/$file"
  printf '{"tool_name":"MultiEdit","tool_input":%s,"cwd":"%s"}' "$ti_json" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/citation-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
multiedit_case allow multiedit-mixed-replace-all "$PHASE1" \
'## Evidence format
FOO FOO
BAR' \
'{"file_path":"'"$PHASE1"'","edits":[{"old_string":"FOO","new_string":"claim one — source: https://a.example","replace_all":true},{"old_string":"BAR","new_string":"claim two — source: https://b.example","replace_all":false}]}'

# --- malformed JSON: truncated / empty / non-object payload ---
malformed_case() { # want name raw_payload
  local want="$1" name="$2" raw="$3"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  printf '%s' "$raw" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/citation-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
malformed_case deny malformed-json-truncated '{"tool_name":"Write","tool_input":{'
malformed_case deny malformed-json-empty ''
malformed_case deny malformed-json-non-object '"just a string"'

# --- absolute path + ./-prefixed path, matching the same relative fixture ---
path_case() { # want name file_path_expr(uses $td)
  local want="$1" name="$2" file_path="$3"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$PHASE1")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$file_path" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' '## Evidence format
totally uncited prose.')" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/citation-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
td_abs="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td_abs"; mkdir -p "$td_abs/$(dirname "$PHASE1")"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$td_abs/$PHASE1" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' '## Evidence format
totally uncited prose.')" "$td_abs" \
  | env CLAUDE_PROJECT_DIR="$td_abs" /bin/bash "$HOOKS/citation-gate.sh" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td_abs"; report deny "$got" absolute-path-uncited

path_case deny dot-prefixed-path-uncited "./$PHASE1"

# --- Bash-tool write reaching the same owned target ---
bash_case() { # want name command
  local want="$1" name="$2" cmd="$3"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":"%s"}' \
    "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$cmd")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/citation-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
bash_case deny bash-write-owned-target "echo uncited > $PHASE1"
bash_case allow bash-write-foreign-target "echo hi > /tmp/scratch.txt"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
