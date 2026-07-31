#!/usr/bin/env bash
# Standalone test harness for evidence-citation/hooks/citation-gate.sh.
# Mirrors the pattern in the repo-root tests/run-gate-tests.sh: spin up a
# throwaway git-init'd tmpdir per case, feed the gate a JSON payload on
# stdin, and check its exit code (0=allow, 2=deny).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
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

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
