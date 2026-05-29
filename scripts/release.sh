#!/bin/bash
# Bump version across package.json, plugin.json, and the marketplace submodule, then commit/tag/push both repos.
# Usage: scripts/release.sh <patch|minor|major|x.y.z>
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUMP="${1:-patch}"
PLUGIN_NAME="$(jq -r .name .claude-plugin/plugin.json)"
CURRENT="$(jq -r .version package.json)"

if [ ! -f .marketplace/.claude-plugin/marketplace.json ]; then
  git submodule update --init .marketplace
fi

case "$BUMP" in
  patch|minor|major)
    IFS=. read -r MA MI PA <<< "$CURRENT"
    case "$BUMP" in
      patch) PA=$((PA + 1)) ;;
      minor) MI=$((MI + 1)); PA=0 ;;
      major) MA=$((MA + 1)); MI=0; PA=0 ;;
    esac
    NEW="$MA.$MI.$PA"
    ;;
  [0-9]*.[0-9]*.[0-9]*) NEW="$BUMP" ;;
  *) echo "Invalid bump: $BUMP (use patch|minor|major|x.y.z)" >&2; exit 1 ;;
esac

echo "$PLUGIN_NAME: $CURRENT -> $NEW"

write() { tmp="$(mktemp)"; jq "$2" "$1" > "$tmp" && mv "$tmp" "$1"; }

write package.json ".version = \"$NEW\""
write .claude-plugin/plugin.json ".version = \"$NEW\""
write .marketplace/.claude-plugin/marketplace.json \
  "(.plugins[] | select(.name == \"$PLUGIN_NAME\") | .version) = \"$NEW\""

# Marketplace repo (separate remote)
git -C .marketplace add .claude-plugin/marketplace.json
git -C .marketplace commit -m "$PLUGIN_NAME v$NEW"
# git -C .marketplace push

# This repo
git add package.json .claude-plugin/plugin.json
git commit -m "chore: release v$NEW"
git tag "v$NEW"
# git push && git push --tags

echo "Released v$NEW"
