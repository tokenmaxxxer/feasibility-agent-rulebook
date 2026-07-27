#!/usr/bin/env bash
# Runs scope-approval-token.sh as a real subprocess against real prompts and
# asserts on the only thing that matters: whether a token file was left behind.
# It never reads the hook's source.
#
# The cases exist because the hook used to mint a token from the NAME of the
# transition rather than from an approval. Measured 2026-07-27 against a real
# subject, all of these produced a valid, consumable token:
#
#   - a refusal ("stop at the scope-approved gate; do not approve on my behalf")
#   - the contract's own text quoted back
#   - a statement that the subject is NOT yet scope-approved
#
# The first minted a token whose own `phrase:` field contained the refusal.
# Contract §19 calls this gate "human-owned, never self-certified"; an agent
# explaining that it must not approve was enough to certify it.
set -uo pipefail

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/scope-approval-token.sh"
SUB="2026-07-27-laundry-drying-time"
pass=0
fail=0

# want: mint | reject
check() {
  want="$1"; name="$2"; prompt="$3"
  td="$(mktemp -d)"
  git init -q "$td"
  printf '%s' "$(python3 -c '
import json, sys
print(json.dumps({"prompt": sys.argv[1], "cwd": sys.argv[2]}))' "$prompt" "$td")" \
    | CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOK" >/dev/null 2>&1
  tok="$(find "$td" -name 'scope-approved.token' -type f | head -1)"
  # The filename carries no subject here (feasibility-cycle's gate reads a
  # fixed name), so the subject is the tokens/ dir's parent.
  if [ -n "$tok" ]; then got="mint:$(basename "$(dirname "$(dirname "$tok")")")"; else got=reject; fi
  # A bare `mint` expectation accepts any subject; `mint:<subject>` pins which
  # one. Filenames carry the subject, and binding the token to the WRONG
  # subject is a distinct defect from minting when it should not have.
  [ "$want" = mint ] && case "$got" in mint:*) got=mint ;; esac
  rm -rf "$td"
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1)); printf 'ok     %-22s %s\n' "$name" "$got"
  else
    fail=$((fail + 1)); printf 'FAIL   %-22s want=%s got=%s\n' "$name" "$want" "$got"
  fi
}

check reject "refusal-ko"       "subject $SUB 의 scope-approved 게이트에 닿으면 멈춰라. 대신 승인하지 마라."
check reject "refusal-en"       "For subject $SUB, do not approve the scope on my behalf."
check reject "contract-quote"   "계약 §19 는 subject $SUB 의 loop_state 를 scope-approved 로 올리는 유일한 경로를 사람으로 규정한다."
check reject "state-mention"    "subject $SUB 는 아직 scope-approved 가 아니다."
check reject "agent-explains"   "subject $SUB 에 대해 제가 scope-approved 를 대신 쓸 수 없습니다."
check reject "bare-assent"      "ok"
check reject "no-subject"       "I approve the scope."
check mint   "approval-en"      "I approve the scope for subject $SUB."
check mint   "approval-ko"      "subject $SUB 의 scope 를 승인한다."
check mint   "approval-ko-범위" "subject $SUB 의 범위를 승인한다."

# Added 2026-07-27 after the first fix leaked. The negation guard it shipped was
# a keyword list scanned in a character window around the match, and it carried
# `\brefus\b`, which cannot match "refuse" — the word boundaries make it look
# for the literal word `refus`. `won't`, `will not` and `should not` were absent
# outright. Each of these minted a valid, consumable token.
check reject "refuse-verb"      "subject $SUB: I refuse to approve the scope."
check reject "wont-contraction" "For subject $SUB I won't approve the scope."
check reject "should-not"       "subject $SUB: you should not approve the scope on my behalf."
check reject "question-anyone"  "subject $SUB - did anyone approve the scope yet?"
check reject "third-party-quote" "subject $SUB: the PR comment says QA approved the scope last week."
check reject "will-not"         "For subject $SUB I will not approve the scope."
check reject "wouldnt"          "subject $SUB: I wouldn't approve the scope as written."

# The subject and the approval must come from the SAME sentence. Otherwise a
# turn discussing two subjects mints for whichever one is named first — here,
# the one the human said stays put.
check "mint:$SUB" "same-sentence-subject" "subject beta is blocked and stays where it is. Separately, I approve the scope for subject $SUB."

# --- the two defects this hook exists to close -------------------------
# Until 2026-07-27 this repo had a gate that CONSUMED a scope-approval token
# and no hook anywhere that MINTED one. The only way to satisfy it was for the
# model to write the token itself, and path-ownership-gate.sh explicitly
# allowed exactly that ("a feasibility session placing its own approval token
# is not a §11 violation"). §19 calls the state human-owned and never
# self-certified; it was self-certified by construction.
self_write_denied() {
  td="$(mktemp -d)"; git init -q "$td"
  mkdir -p "$td/docs/specs" "$td/docs/reports/records/alpha/tokens"
  : > "$td/docs/specs/role-handoff-contract.md"
  payload="$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Write",
                  "tool_input": {"file_path": sys.argv[1] + "/docs/reports/records/alpha/tokens/scope-approved.token",
                                 "content": "approved"},
                  "cwd": sys.argv[1]}))' "$td")"
  printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$td" \
    /bin/bash "$(dirname "${BASH_SOURCE[0]}")/path-ownership-gate.sh" >/dev/null 2>&1
  rc=$?
  rm -rf "$td"
  if [ "$rc" = 2 ]; then
    pass=$((pass + 1)); printf 'ok     %-22s %s\n' "agent-self-token" "denied"
  else
    fail=$((fail + 1)); printf 'FAIL   %-22s want=denied got=rc%s\n' "agent-self-token" "$rc"
  fi
}
self_write_denied

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
