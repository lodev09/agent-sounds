#!/bin/bash
# npm CLI entry — resolves the bin symlink and runs from this package
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
exec bash "$ROOT/scripts/agent-sounds.sh" "$@"
