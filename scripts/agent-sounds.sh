#!/bin/bash
set -e

ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-sounds"
CONFIG="$CONFIG_DIR/config.json"

# Shared across Claude Code and Codex installs; seeded from bundled defaults
if [ ! -f "$CONFIG" ]; then
  mkdir -p "$CONFIG_DIR"
  cp "$ROOT/config.json" "$CONFIG"
fi

DEFAULT_VOLUME="0.25"
EVENTS="ready work done ask"
MARKETPLACE="lodev09"
PLUGIN="sounds@$MARKETPLACE"

source "$(dirname "${BASH_SOURCE[0]}")/spin.sh"

read_config() {
  python3 -c "
import json
with open('$CONFIG') as f:
    print(json.dumps(json.load(f)))
"
}

write_config() {
  local key="$1" value="$2"
  python3 -c "
import json
with open('$CONFIG') as f:
    c = json.load(f)
c['$key'] = $value
with open('$CONFIG', 'w') as f:
    json.dump(c, f, indent=2)
    f.write('\n')
"
}

get_available() {
  for f in "$ROOT"/sounds/*/source.json; do
    [ -f "$f" ] && basename "$(dirname "$f")"
  done | sort
}

get_enabled() {
  python3 -c "
import json
with open('$CONFIG') as f:
    c = json.load(f)
for p in c.get('enabled', []):
    print(p)
"
}

cmd_select() {
  local enabled cursor=0 count=0 i

  while IFS= read -r line; do
    eval "items_$count=\$line"
    count=$((count + 1))
  done < <(get_available)

  if [ "$count" -eq 0 ]; then
    echo "No sound sources found."
    exit 1
  fi

  enabled=$(get_enabled)
  for i in $(seq 0 $((count - 1))); do
    eval "name=\$items_$i"
    if echo "$enabled" | grep -qx "$name"; then
      eval "flags_$i=1"
    else
      eval "flags_$i=0"
    fi
  done

  cleanup() { printf '\033[?25h'; }
  trap cleanup EXIT
  trap 'cleanup; exit 130' INT

  printf '\033[?25l'

  printf '\n'
  for i in $(seq 0 $((count - 1))); do
    printf '\n'
  done

  local total_lines=$((count + 1))

  while true; do
    printf '\033[%dA' "$total_lines"

    printf '\033[2K\033[2mUse arrows to move, space to toggle, enter to confirm\033[0m\r\n'
    for i in $(seq 0 $((count - 1))); do
      eval "name=\$items_$i"
      eval "flag=\$flags_$i"
      printf '\033[2K'
      if [ "$flag" -eq 1 ]; then
        local check="\033[32m●\033[0m"
      else
        local check="\033[2m○\033[0m"
      fi
      if [ "$i" -eq "$cursor" ]; then
        printf '%b %s\r\n' "$check" "$name"
      else
        printf '%b \033[2m%s\033[0m\r\n' "$check" "$name"
      fi
    done

    IFS= read -rsn1 key </dev/tty
    case "$key" in
      $'\x1b')
        # bash 3.2 (macOS) only accepts integer timeouts
        read -rsn2 -t 1 key </dev/tty || true
        case "$key" in
          '[A') [ "$cursor" -gt 0 ] && cursor=$((cursor - 1)) ;;
          '[B') [ "$cursor" -lt $((count - 1)) ] && cursor=$((cursor + 1)) ;;
        esac ;;
      ' ')
        eval "flag=\$flags_$cursor"
        eval "flags_$cursor=$(( 1 - flag ))" ;;
      '') break ;;
    esac
  done

  printf '\033[?25h'

  local selected=()
  for i in $(seq 0 $((count - 1))); do
    eval "flag=\$flags_$i"
    eval "name=\$items_$i"
    [ "$flag" -eq 1 ] && selected+=("\"$name\"")
  done

  local json_array
  json_array=$(IFS=,; echo "[${selected[*]}]")
  write_config "enabled" "$json_array"

  if [ ${#selected[@]} -eq 0 ]; then
    printf '\033[2mNo sound sources enabled\033[0m\n'
  else
    printf '\033[32mEnabled:\033[0m'
    for s in "${selected[@]}"; do printf ' %s' "$(echo "$s" | tr -d '"')"; done
    printf '\n'
  fi
}

cmd_enable() {
  local pack="$1"
  if [ -z "$pack" ]; then
    err "Usage: agent-sounds enable <source|all>"
    exit 1
  fi

  local available
  available=$(get_available)

  if [ "$pack" = "all" ]; then
    local all=()
    while IFS= read -r p; do all+=("\"$p\""); done <<< "$available"
    local json_array
    json_array=$(IFS=,; echo "[${all[*]}]")
    write_config "enabled" "$json_array"
    info "Enabled all sound sources"
    return
  fi

  if ! echo "$available" | grep -qx "$pack"; then
    err "Unknown sound source: $pack"
    dim "Available: $(echo "$available" | tr '\n' ' ')"
    exit 1
  fi

  python3 -c "
import json
with open('$CONFIG') as f:
    c = json.load(f)
enabled = c.get('enabled', [])
if '$pack' not in enabled:
    enabled.append('$pack')
    c['enabled'] = enabled
    with open('$CONFIG', 'w') as f:
        json.dump(c, f, indent=2)
        f.write('\n')
    print('added')
else:
    print('exists')
" | {
    read -r result
    if [ "$result" = "added" ]; then
      info "Enabled: $pack"
    else
      dim "Already enabled: $pack"
    fi
  }
}

cmd_disable() {
  local pack="$1"
  if [ -z "$pack" ]; then
    err "Usage: agent-sounds disable <source|all>"
    exit 1
  fi

  if [ "$pack" = "all" ]; then
    write_config "enabled" "[]"
    info "Disabled all sound sources"
    return
  fi

  python3 -c "
import json
with open('$CONFIG') as f:
    c = json.load(f)
c['enabled'] = [p for p in c.get('enabled', []) if p != '$pack']
with open('$CONFIG', 'w') as f:
    json.dump(c, f, indent=2)
    f.write('\n')
"
  info "Disabled: $pack"
}

cmd_sounds() {
  local name="$1"
  if [ -z "$name" ]; then
    cmd_list
    return
  fi

  local source_json="$ROOT/sounds/$name/source.json"
  if [ ! -f "$source_json" ]; then
    err "Unknown source: $name"
    dim "Available: $(get_available | tr '\n' ' ')"
    exit 1
  fi

  python3 -c "
import json
with open('$source_json') as f:
    data = json.load(f)
events = list(data.items())
for idx, (event, files) in enumerate(events):
    if idx > 0:
        print()
    print(f'\033[32m{event}:\033[0m')
    for name in files:
        print(f'\033[2m{name.rsplit(chr(46), 1)[0]}\033[0m')
"
}

cmd_list() {
  local available enabled
  available=$(get_available)
  enabled=$(get_enabled)

  for pack in $available; do
    if echo "$enabled" | grep -qx "$pack"; then
      printf "%s \033[32m✓\033[0m\n" "$pack"
    else
      printf "\033[2m%s\033[0m\n" "$pack"
    fi
  done
}

cmd_on() {
  local muted
  muted=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('muted', False))")
  if [ "$muted" = "False" ]; then
    dim "Sounds already on"
    return
  fi
  write_config "muted" "False"
  info "Sounds on"
}

cmd_off() {
  local muted
  muted=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('muted', False))")
  if [ "$muted" = "True" ]; then
    dim "Sounds already off"
    return
  fi
  write_config "muted" "True"
  info "Sounds off"
}

cmd_play() {
  local event="$1"
  if [ -z "$event" ]; then
    err "Usage: agent-sounds play <event>"
    dim "Events: $EVENTS"
    exit 1
  fi

  if ! echo "$EVENTS" | grep -qw "$event"; then
    err "Unknown event: $event"
    dim "Events: $EVENTS"
    exit 1
  fi

  bash "$(dirname "${BASH_SOURCE[0]}")/play.sh" "$event"
}

cmd_volume() {
  local vol="$1"
  if [ -z "$vol" ]; then
    python3 -c "import json; print(json.load(open('$CONFIG')).get('volume', $DEFAULT_VOLUME))"
    return
  fi

  if ! printf '%s' "$vol" | grep -qE '^(0(\.[0-9]+)?|1(\.0+)?)$'; then
    err "Volume must be a number between 0.0 and 1.0"
    exit 1
  fi

  write_config "volume" "$vol"
  info "Volume set to $vol"
}

cmd_status() {
  local enabled available volume muted
  enabled=$(get_enabled | tr '\n' ' ' | sed 's/ $//')
  available=$(get_available | wc -l | tr -d ' ')
  volume=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('volume', $DEFAULT_VOLUME))")
  muted=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('muted', False))")

  printf "${DIM}root${RESET}      %s\n" "$ROOT"
  printf "${DIM}config${RESET}    %s\n" "$CONFIG"
  printf "${DIM}sounds${RESET}    %s\n" "$([ "$muted" = "True" ] && echo "off" || echo "on")"
  printf "${DIM}enabled${RESET}   %s\n" "${enabled:-none}"
  printf "${DIM}available${RESET} %s\n" "$available"
  printf "${DIM}volume${RESET}    %s\n" "$volume"
}

cmd_update() {
  local found=0

  if command -v claude >/dev/null; then
    found=1
    spin "Claude Code: update marketplace" claude plugin marketplace update "$MARKETPLACE"
    spin "Claude Code: update plugin" claude plugin update "$PLUGIN"
  fi

  if command -v codex >/dev/null; then
    found=1
    spin "Codex: upgrade marketplace" codex plugin marketplace upgrade "$MARKETPLACE"
    spin "Codex: update plugin" codex plugin add "$PLUGIN"
  fi

  if [ "$found" -eq 0 ]; then
    err "Neither claude nor codex CLI found"
    exit 1
  fi

  dim "Restart sessions to apply"
}

cmd_help() {
  printf "Usage: ${DIM}agent-sounds${RESET} [command]\n"
  echo ""
  printf "${DIM}Commands:${RESET}\n"
  echo "  (no args)                  Interactive source select"
  echo "  sounds [source]            List sources or show sounds for a source"
  echo "  enable <source|all>        Enable a sound source"
  echo "  disable <source|all>       Disable a sound source"
  echo "  on                         Turn sounds on"
  echo "  off                        Turn sounds off"
  echo "  play <event>               Play a sound event"
  echo "  volume [0-1]               Get or set volume"
  echo "  status                     Show install info"
  echo "  update                     Update Claude Code and Codex plugins"
  echo "  --help                     Show this help"
  echo ""
  printf "${DIM}Sources:${RESET} $(get_available | tr '\n' ' ')\n"
}

case "${1:-select}" in
  select)      cmd_select ;;
  list|sounds) cmd_sounds "${2:-}" ;;
  enable)      cmd_enable "${2:-}" ;;
  disable)     cmd_disable "${2:-}" ;;
  on)          cmd_on ;;
  off)         cmd_off ;;
  play)        cmd_play "${2:-}" ;;
  volume)      cmd_volume "${2:-}" ;;
  status)      cmd_status ;;
  update)      cmd_update ;;
  --help)      cmd_help ;;
  *)           cmd_help; exit 1 ;;
esac
