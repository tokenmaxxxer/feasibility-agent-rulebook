#!/usr/bin/env bash
# One-shot installer for the feasibility-agent-rulebook stack.
# Registers ONLY the tokenmaxxxer-feasibility marketplace and installs
# ONLY this repository's plugins (feasibility-cycle) plus its bundle
# (feasibility-agent-env), at user scope. Names no other repository or
# marketplace.
set -euo pipefail

MARKET="tokenmaxxxer-feasibility"
BUNDLE="feasibility-agent-env"
GITHUB_REPO="tokenmaxxxer/feasibility-agent-rulebook"
PLUGINS=(feasibility-cycle)

usage() {
  cat <<'USAGE'
Usage: install.sh

  Installs the feasibility-agent-rulebook stack for your account only.
  Applies to every machine-local session but does not travel with any repo,
  and does not reach Claude Code on the web / Slack cloud sessions.

  -h, --help  Show this help.

Environment:
  TOKENMAXXXER_SETTINGS_ONLY=1      Skip the CLI and write settings directly.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) echo "install.sh: unknown argument '$1'" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

SETTINGS_SOURCE_JSON="{\"source\": \"github\", \"repo\": \"$GITHUB_REPO\"}"

# Merge extraKnownMarketplaces + enabledPlugins into a settings.json at $1,
# preserving any existing content. Used for the CLI-less fallback.
#
# Two safety rules, checked in this order, before any byte is written:
#   1. The settings path is resolved and prefix-checked against the user's
#      home directory. A path outside $HOME is refused rather than written.
#   2. A parse failure of an existing settings file aborts leaving the
#      original file untouched — no partial write, no .bak-then-clobber.
write_settings() {
  python3 - "$MARKET" "$BUNDLE" "$SETTINGS_SOURCE_JSON" "$1" "${PLUGINS[@]}" <<'PY'
import json, os, shutil, sys

market, bundle, source_json, path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
plugins = sys.argv[5:]

home = os.path.realpath(os.path.expanduser("~"))
path = os.path.expanduser(path)
parent = os.path.dirname(path) or "."
os.makedirs(parent, exist_ok=True)

# Rule 1: resolve and prefix-check against $HOME before any write.
resolved_parent = os.path.realpath(parent)
if resolved_parent != home and not resolved_parent.startswith(home + os.sep):
    sys.exit(f"ERROR: refusing to write outside the home directory ({path} resolves under {resolved_parent}).")

# Follow a symlink through to its real target rather than replacing it.
if os.path.islink(path):
    target = os.path.realpath(path)
    if target != home and not target.startswith(home + os.sep):
        sys.exit(f"ERROR: {path} is a symlink pointing outside the home directory; refusing to write through it.")
    path = target
    print(f"    settings.json is a symlink; writing through to {path}")

settings = {}
if os.path.exists(path):
    with open(path) as f:
        try:
            settings = json.load(f)
        except ValueError:
            # Rule 2: abort leaving the original file untouched.
            sys.exit(f"ERROR: {path} is not valid JSON — fix it and re-run. Nothing was written.")
    shutil.copy2(path, path + ".bak")
    print(f"    backup written to {path}.bak")

settings.setdefault("extraKnownMarketplaces", {})[market] = {
    "source": json.loads(source_json)
}

enabled = settings.get("enabledPlugins")
if isinstance(enabled, list):
    enabled = {k: True for k in enabled}
elif not isinstance(enabled, dict):
    enabled = {}

for plugin in plugins:
    enabled[f"{plugin}@{market}"] = True
enabled[f"{bundle}@{market}"] = True
settings["enabledPlugins"] = enabled

tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)
print(f"    updated {path}")
PY
}

find_cli() {
  if command -v claude >/dev/null 2>&1; then
    command -v claude
    return
  fi
  ls -1d "$HOME"/.vscode-server/extensions/anthropic.claude-code-*/resources/native-binary/claude \
         "$HOME"/.vscode/extensions/anthropic.claude-code-*/resources/native-binary/claude \
         2>/dev/null | sort -V | tail -1
}

CLI=""
[ -z "${TOKENMAXXXER_SETTINGS_ONLY:-}" ] && CLI="$(find_cli)"

if [ -n "$CLI" ] && [ -x "$CLI" ]; then
  echo "==> installing via CLI: $CLI"
  cd "$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}")" 2>/dev/null || cd / || true
  if "$CLI" plugin marketplace list 2>/dev/null | grep -q "$MARKET"; then
    echo "    marketplace '$MARKET' already registered"
  else
    "$CLI" plugin marketplace add "$GITHUB_REPO"
  fi
  "$CLI" plugin marketplace update "$MARKET" >/dev/null 2>&1 || true

  install_failed=""
  for plugin in "${PLUGINS[@]}"; do
    "$CLI" plugin install "$plugin@$MARKET" --scope user || install_failed="$install_failed $plugin"
  done
  "$CLI" plugin install "$BUNDLE@$MARKET" --scope user || install_failed="$install_failed $BUNDLE"

  for plugin in "${PLUGINS[@]}"; do
    "$CLI" plugin update "$plugin@$MARKET" || true
  done
  "$CLI" plugin update "$BUNDLE@$MARKET" || true

  if [ -n "$install_failed" ]; then
    echo "==> FAILED to install:$install_failed"
    echo "    Re-run this script — it is idempotent — or install the failures"
    echo "    individually with: $CLI plugin install <name>@$MARKET --scope user"
  else
    echo "==> installed $BUNDLE@$MARKET and feasibility-cycle."
  fi
else
  echo "==> no claude CLI found (standalone or bundled): writing user settings directly"
  if ! write_settings "$HOME/.claude/settings.json"; then
    echo "==> FAILED to write ~/.claude/settings.json (see the error above); nothing was installed." >&2
    exit 1
  fi
  echo "    the bundle and its dependency install on next session start"
fi

cat <<'MSG'
==> done (user scope). Start (or reload) a Claude Code session, then:
    - verify with /plugins
    - RECOMMENDED: open /plugin -> marketplaces -> tokenmaxxxer-feasibility
      and enable auto-update, so future additions arrive automatically.
      There is no CLI/config switch for this toggle; it is a one-time
      interactive step.
    - without auto-update, refresh manually anytime:
      claude plugin update feasibility-agent-env@tokenmaxxxer-feasibility
MSG
