# agent-sounds

Sound feedback plugin for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [Codex](https://learn.chatgpt.com/docs/hooks). Plays Warcraft-style voice lines on session events.

## Install

### Claude Code

```sh
claude plugin marketplace add lodev09/agent-plugins
claude plugin install sounds@lodev09
```

### Codex

```sh
codex plugin marketplace add lodev09/agent-plugins
codex plugin add sounds@lodev09
```

Review and trust the plugin hooks in Codex. Then start a new session.

The shared hooks use `PLUGIN_ROOT`, with `CLAUDE_PLUGIN_ROOT` as a fallback for Claude Code. See the [Codex hooks documentation](https://learn.chatgpt.com/docs/hooks#plugin-bundled-hooks).

### CLI

For CLI access, also install via npm:

```sh
npm install -g @lodev09/agent-sounds
```

## Hook Events

| Event | Sound | Description | Support |
|-------|-------|-------------|---------|
| `SessionStart` | `ready` | Session greeting | Claude Code, Codex |
| `UserPromptSubmit` | `work` | Prompt acknowledgment | Claude Code, Codex |
| `SubagentStart` | `work` | Subagent start | Claude Code, Codex |
| `EnterPlanMode` | `work` | Plan mode entry | Claude Code |
| `ExitPlanMode` | `done` | Plan mode exit | Claude Code |
| `PermissionRequest` | `ask` | Permission request | Claude Code, Codex |
| `Stop` | `done` | Task completion | Claude Code, Codex |

Each event plays a random sound from enabled sources, mapped via `source.json`.

## Available Sources

- [**peon**](sounds/peon/) — Warcraft Orc Peon
- [**peasant**](sounds/peasant/) — Warcraft Human Peasant
- [**bastion**](sounds/bastion/) — Dota 2 Bastion Announcer Pack
- [**ra2**](sounds/ra2/) — Command & Conquer: Red Alert 2

## Usage

Use `/sounds` inside Claude Code or `$sounds` inside Codex.

For terminal access, use `agent-sounds` after the npm install.

Config is shared across Claude Code, Codex, and the CLI at `~/.config/agent-sounds/config.json` (respects `XDG_CONFIG_HOME`). Disabling a source in one applies everywhere.

```sh
agent-sounds                          # Interactive source select
agent-sounds sounds [source]          # List sources or show sounds for a source
agent-sounds enable <source|all>
agent-sounds disable <source|all>
agent-sounds on                       # Turn sounds on
agent-sounds off                      # Turn sounds off
agent-sounds play <event>             # Play a sound (ready, work, done, ask)
agent-sounds volume [0-1]             # Get or set volume
agent-sounds status                   # Show install info
```

## Customization

Create a new folder under `sounds/` with a `source.json` mapping events to audio files:

```
sounds/my-source/
├── source.json
├── hello.mp3
└── done.wav
```

```json
{
  "ready": ["hello.mp3"],
  "work": ["hello.mp3"],
  "done": ["done.wav"],
  "ask": ["hello.mp3"]
}
```

## Requirements

- `python3`
- Audio player (auto-detected):
  - **macOS** — `afplay` (built-in)
  - **Linux** — `pw-play`, `paplay`, or `ffplay`
  - **Windows** — `ffplay` or PowerShell (built-in)

## Credits

All audio assets are property of their respective owners and included here for personal, non-commercial use.

- [Warcraft](https://www.blizzard.com) by Blizzard Entertainment
- [Dota 2 Bastion Announcer Pack](https://liquipedia.net/dota2/Bastion_Announcer_Pack) by Supergiant Games
- [Command & Conquer: Red Alert 2](https://www.ea.com/games/command-and-conquer) by Westwood Studios / EA

## License

MIT
