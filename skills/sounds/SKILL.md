---
name: sounds
description: Manage Claude Code and Codex sound feedback. Select sound packs, enable or disable sounds, adjust volume, play test sounds, and view status.
---

# Instructions

Set `ROOT` to `../..` relative to the directory that contains this `SKILL.md`. Use the absolute skill path from the current session.

Config is shared across Claude Code and Codex at `~/.config/agent-sounds/config.json`.

## With arguments

Pass user arguments directly to the CLI script. Do NOT interpret or reimplement the commands.

- `/sounds status` → `bash "$ROOT/scripts/agent-sounds.sh" status`
- `/sounds volume 0.5` → `bash "$ROOT/scripts/agent-sounds.sh" volume 0.5`
- `/sounds enable peon` → `bash "$ROOT/scripts/agent-sounds.sh" enable peon`

In Codex, use `$sounds` with the same arguments.

## Without arguments (`/sounds` or `$sounds`)

The interactive select requires a TTY. Use the agent's user-input tool or a numbered list:

1. Run `bash "$ROOT/scripts/agent-sounds.sh" sounds` to get available packs and their enabled state
2. Ask the user which packs to enable/disable using a numbered list
3. Run the corresponding `enable` / `disable` commands based on user selection
