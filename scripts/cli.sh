#!/bin/bash
# CLI wrapper — delegates to the marketplace-installed plugin
set -e

PLUGIN_DIR="$HOME/.claude/plugins/cache/lodev09/sounds"
INSTALL_COMMAND="claude plugin install sounds@lodev09"

if [ "${1:-}" = "--codex" ]; then
  PLUGIN_DIR="${CODEX_HOME:-$HOME/.codex}/plugins/cache/lodev09/sounds"
  INSTALL_COMMAND="codex plugin add sounds@lodev09"
  shift
fi

if [ ! -d "$PLUGIN_DIR" ]; then
  echo "agent-sounds plugin not installed." >&2
  echo "Run: $INSTALL_COMMAND" >&2
  exit 1
fi

# Use the latest version directory
ROOT=$(ls -d "$PLUGIN_DIR"/*/ 2>/dev/null | sort -V | tail -1)
if [ -z "$ROOT" ] || [ ! -f "$ROOT/scripts/agent-sounds.sh" ]; then
  echo "agent-sounds plugin is corrupted. Reinstall:" >&2
  echo "Run: $INSTALL_COMMAND" >&2
  exit 1
fi

exec bash "$ROOT/scripts/agent-sounds.sh" "$@"
