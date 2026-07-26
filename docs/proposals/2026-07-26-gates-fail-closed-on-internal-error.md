# Gates fail closed on internal error

status: proposed

## Problem

Claude Code `PreToolUse` hooks BLOCK the guarded tool call only on exit code
**2**. Every other non-zero exit is treated as NON-BLOCKING (fail-open). Each
gate script in this rulebook runs a `python3` judge whose uncaught exceptions
exit with code **1**, and whose shell wrapper could propagate an arbitrary
non-2 code. In particular, a null byte or undecodable byte in
`tool_input.file_path` makes `os.path.realpath` / `os.path.*` raise an
uncaught `ValueError` (exit 1) — silently letting the guarded write through.

## Change

Two defensive layers are applied to every gate script, changing ONLY what
happens on ERROR — never a gate's verdict on well-formed input (the exact
allow=exit 0 and deny=exit 2 paths are preserved):

1. **Shell layer.** The `python3` judge is run under `set +e`; its exit code
   is captured and any code that is not 0 (allow) and not 2 (deny) is mapped
   to a printed `fail-closed: internal error` message on stderr and `exit 2`.
   Missing `python3` already denies (exit 2).

2. **Python layer.** A `sys.excepthook` converts any uncaught exception
   (including the null-byte `ValueError` from `os.path.*`) into `os._exit(2)`.
   `SystemExit` raised by the gates' `allow()`/`deny()` bypasses the hook, so
   the verdict paths are untouched.

## Tests

`run-gate-tests.sh` and `run-procedure-gate-tests.sh` each gain crash cases
per gate — a null byte in `file_path` and/or malformed JSON — asserting the
gate exits **exactly 2**. All pre-existing allow/deny cases still pass.

## Scope

Gate scripts hardened: state-gate.sh, scope-record-gate.sh,
record-fields-gate.sh, path-ownership-gate.sh, doc-bucket-gate.sh,
handbook-trigger-gate.sh, trailer-gate.sh.
