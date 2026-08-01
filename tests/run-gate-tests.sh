#!/usr/bin/env bash
# The surviving review gates, exercised as real subprocesses.
#
# record-fields-gate.sh and trailer-gate.sh are core canon gates (issue-31:
# core fires them globally now; feasibility/hooks/ no longer vendors them).
# CORE resolves the same sibling-path way feasibility/hooks/directive.sh
# resolves core's role-directive.sh — never hardcoded to this repo's own
# hooks dir. When core isn't checked out next to this repo (this repo
# references canon, it does not vendor it), those cases SKIP rather than
# FAIL: a missing external dependency is not this repo's own gate
# regressing.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../feasibility/hooks"
CORE="${CLAUDE_PLUGIN_ROOT_CORE:-$HERE/../../core}/hooks"
pass=0; fail=0; skip=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }
skipped() { skip=$((skip+1)); printf 'SKIP   %-34s %s\n' "$1" "$2"; }

REC=docs/issue-7/reports/technical-feasibility.md
run() { # want name gatedir gate file content
  local gate="$3/$4"
  if [ ! -f "$gate" ]; then skipped "$2" "gate not found at $gate (external dependency not checked out)"; return; fi
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$5" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$6")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$gate" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

GOOD='---
loop_state: landed
---
## What was done
All four probes resolved.
## Why
go; the no-go alternative was rejected on probe evidence.
## Upstream basis
commit abc1234
## Open findings
none'
run allow record-complete "$CORE" record-fields-gate.sh "$REC" "$GOOD"
run deny  record-empty    "$CORE" record-fields-gate.sh "$REC" "nothing"
run deny  open-no-backlog "$CORE" record-fields-gate.sh "$REC" '---
status: probing
---
## What was done
x — upstream basis abc1234'
run allow foreign-path    "$CORE" record-fields-gate.sh "docs/issue-7/reports/verify.md" "x"

# trailer-gate cases carried unchanged, gate resolved via CORE now.
trailergate_case() { # want name stagepath commitcmd
  local gate="$CORE/trailer-gate.sh"
  if [ ! -f "$gate" ]; then skipped "$2" "gate not found at $gate (external dependency not checked out)"; return; fi
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  ( cd "$td" && git config user.email t@t && git config user.name t \
    && mkdir -p "$(dirname "$3")" && echo x > "$3" && git add "$3" )
  printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":"%s"}' \
    "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    | ( cd "$td" && env -u CLAUDE_PROJECT_DIR /bin/bash "$gate" ) >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}
trailergate_case deny  commit-no-trailer   "$REC" 'git commit -m "update"'
trailergate_case allow commit-with-trailer "$REC" 'git commit -m "update

Subject: issue-7"'
trailergate_case allow commit-non-issue    "src/app.py" 'git commit -m "x"'

# Sibling methodology-plugin gates (issue-39): each new plugin ships its own
# standalone test script under <plugin>/tests/; this harness folds their
# pass/fail counts into the totals below rather than re-implementing their
# cases, so one run covers every gate in the repo.
for plugin_tests in "$HERE/../madr-options/tests/run-gate-tests.sh" \
                    "$HERE/../nygard-adr-spine/tests/run-gate-tests.sh" \
                    "$HERE/../evidence-citation/tests/run-gate-tests.sh"; do
  if [ -f "$plugin_tests" ]; then
    echo "-- $plugin_tests --"
    if bash "$plugin_tests"; then pass=$((pass+1)); else fail=$((fail+1)); fi
  else
    skipped "$(basename "$(dirname "$(dirname "$plugin_tests")")")" "test script not found at $plugin_tests"
  fi
done

printf '\n== %d passed, %d failed, %d skipped ==\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
