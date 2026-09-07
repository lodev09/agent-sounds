#!/bin/bash
EVENT="$1"

[ -z "$EVENT" ] && exit 0

ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/agent-sounds/config.json"
[ -f "$CONFIG" ] || CONFIG="$ROOT/config.json"

[ ! -f "$CONFIG" ] && exit 0

read -r MUTED VOLUME <<< "$(python3 -c "
import json
with open('$CONFIG') as f:
    c = json.load(f)
print(c.get('muted', False), c.get('volume', 0.25))
")"

[ "$MUTED" = "True" ] && exit 0

files=$(python3 -c "
import json, os
root = '$ROOT'
event = '$EVENT'
with open('$CONFIG') as f:
    config = json.load(f)
for pack in config.get('enabled', []):
    path = os.path.join(root, 'sounds', pack, 'source.json')
    if not os.path.isfile(path):
        continue
    with open(path) as f:
        data = json.load(f)
    for name in data.get(event, []):
        print(os.path.join(root, 'sounds', pack, name))
")

[ -z "$files" ] && exit 0

existing=()
while IFS= read -r f; do [[ -f "$f" ]] && existing+=("$f"); done <<< "$files"
[[ ${#existing[@]} -eq 0 ]] && exit 0

SOUND="${existing[RANDOM % ${#existing[@]}]}"

play_powershell() {
  powershell.exe -NoProfile -Command "
    Add-Type -AssemblyName PresentationCore
    \$p = New-Object System.Windows.Media.MediaPlayer
    \$p.Volume = $VOLUME
    \$p.Open([Uri]::new('$1'))
    \$p.Play()
    Start-Sleep -Seconds 5
  " &
}

play_sound() {
  case "$(uname -s)" in
    Darwin)
      afplay -v "$VOLUME" "$SOUND" &
      ;;
    Linux)
      if grep -qi "microsoft\|wsl" /proc/version 2>/dev/null && command -v powershell.exe >/dev/null 2>&1; then
        play_powershell "file:$(wslpath -m "$SOUND")"
      elif command -v pw-play >/dev/null 2>&1; then
        pw-play --volume "$VOLUME" "$SOUND" &
      elif command -v paplay >/dev/null 2>&1; then
        paplay "$SOUND" &
      elif command -v ffplay >/dev/null 2>&1; then
        ffplay -nodisp -autoexit -loglevel quiet -volume "$(python3 -c "print(int($VOLUME * 100))")" "$SOUND" &
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      if command -v ffplay >/dev/null 2>&1; then
        ffplay -nodisp -autoexit -loglevel quiet -volume "$(python3 -c "print(int($VOLUME * 100))")" "$SOUND" &
      elif command -v powershell.exe >/dev/null 2>&1; then
        play_powershell "$SOUND"
      fi
      ;;
  esac
}

play_sound
