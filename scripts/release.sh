#!/bin/bash
# Bump version across package.json, plugin.json, and the marketplace submodule,
# then commit/tag/push both repos and create a GitHub release.
# Usage: scripts/release.sh <patch|minor|major|x.y.z>
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

source scripts/spin.sh

command -v gh >/dev/null || { err "gh CLI required"; exit 1; }

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
  *) err "Invalid bump: $BUMP (use patch|minor|major|x.y.z)"; exit 1 ;;
esac

printf "${BOLD}%s${RESET} ${DIM}v%s${RESET} → ${GREEN}v%s${RESET}\n\n" "$PLUGIN_NAME" "$CURRENT" "$NEW"

write() { tmp="$(mktemp)"; jq "$2" "$1" > "$tmp" && mv "$tmp" "$1"; }

bump_versions() {
  write package.json ".version = \"$NEW\""
  write .claude-plugin/plugin.json ".version = \"$NEW\""
  write .codex-plugin/plugin.json ".version = \"$NEW\""
  write .marketplace/.claude-plugin/marketplace.json \
    "(.plugins[] | select(.name == \"$PLUGIN_NAME\") | .version) = \"$NEW\""
}

push_marketplace() {
  git -C .marketplace add .claude-plugin/marketplace.json
  git -C .marketplace commit -m "$PLUGIN_NAME v$NEW"
  git -C .marketplace push
}

push_repo() {
  git add package.json .claude-plugin/plugin.json .codex-plugin/plugin.json .marketplace
  git commit -m "chore: release v$NEW"
  git tag "v$NEW"
  git push && git push --tags
}

create_release() {
  gh release create "v$NEW" --title "v$NEW" --generate-notes
}

spin "Bump versions" bump_versions
spin "Push marketplace" push_marketplace
spin "Push v$NEW" push_repo
spin "Create GitHub release" create_release

printf "\n${GREEN}Released v%s${RESET}\n" "$NEW"
dim "$(gh release view "v$NEW" --json url -q .url)"
printf "\n${BOLD}Next:${RESET} npm publish\n"
