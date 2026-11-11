# soundcraft-plugin

A Claude Code plugin that lets Claude make, mix and render audio in
[**SoundCraft**](https://github.com/storytold/soundcraft), the open-source, pure-Rust digital audio
workstation. Built and tested on macOS with SoundCraft 0.19.0. It bundles:

- **`soundcraft` MCP server**: SoundCraft's own `soundcraft-cli mcp` (sessions, tracks, MIDI, mixer,
  built-in synths and effects, automation, offline processing, bounce with peak and LUFS, any of the 483
  engine commands, atomic batches; plus screenshots and UI control when connected to the app), started by
  `scripts/start-mcp.sh`. It drives a running app live, or a headless engine when no app is running.
- **`soundcraft` skill**: how to drive SoundCraft through MCP: command discovery, ids, positions and MIDI
  ticks, batches, verification by bouncing and measuring loudness.
- **`procedural-audio` skill** (MIT, from [a5c-ai/babysitter](https://github.com/a5c-ai/babysitter)):
  synthesis, granular processing, procedural variation and physics-driven sound, with SoundCraft
  references written for this plugin.

```
Claude ─stdio─▶ scripts/start-mcp.sh ─exec─▶ soundcraft-cli mcp --connect 7801 ─tcp 127.0.0.1:7801─▶ SoundCraft (--control 7801)
                                                   └─ or headless: in-process engine, no window, no audio device
```

## Install

Requirements: Claude Code, `soundcraft-cli`; the SoundCraft desktop app only for live editing.

1. Add the marketplace and install the plugin (in Claude Code):
   ```
   /plugin marketplace add ritvarsbiksis/sound-craft-plugin
   /plugin install soundcraft-plugin@soundcraft
   ```
2. Install `soundcraft-cli`. On macOS it is **not** inside `SoundCraft.app`; it ships as a separate
   release asset. The script downloads it from the official GitHub release, verifies it against
   `SHA256SUMS.txt` and links it as `~/.local/bin/soundcraft-cli`:
   ```bash
   bash ~/.claude/plugins/marketplaces/soundcraft/scripts/install-cli.sh
   ```
   (from a clone: `bash scripts/install-cli.sh`; `--version latest` installs the newest release; the server's
   startup error also prints the exact command). On Linux the script extracts the CLI from the release
   tarball; the `.deb`/`.rpm` packages already put it at `/usr/bin/soundcraft-cli`. On Windows, set the
   plugin's `cli_path` option to `soundcraft-cli.exe`.
3. For live editing, start the app with its control port:
   ```bash
   open -a SoundCraft --args --control 7801
   ```
   If SoundCraft is already open, quit it first. The control port has no authentication and listens on
   loopback only; leave it closed when you're not using it.
4. Start a new Claude Code session (or `/reload-plugins`) and ask, for example: *"In SoundCraft, design
   five variations of a wooden impact for a game, bounce them as 24-bit WAVs and tell me their loudness."*

## Options

Set at install or later in `/plugin` › soundcraft-plugin › configure:

| Option | Default | Effect |
| --- | --- | --- |
| `mode` | `auto` | `auto`: the running app if one listens on the port, else headless. `connect`: the app only. `headless`: no app. |
| `control_port` | `7801` | Port the app was started with (`--control PORT`). |
| `cli_path` | empty | Absolute path to `soundcraft-cli` (or its folder). Empty searches PATH, `~/.local/bin`, `~/.cargo/bin`, `/usr/bin`, `/usr/local/bin`, `/opt/homebrew/bin`. |
| `demo` | off | Headless: start from SoundCraft's demo session (`--demo`). |
| `read_roots`, `write_roots` | empty | Existing folders the agent may read from / write to. Any root confines file access and **forces headless** (SoundCraft refuses `--connect` with roots, and the app has no confinement of its own yet). |

`auto` decides when the server starts: if you launch the app afterwards, run `/reload-plugins`.

## Skills

| Skill | Use it for |
| --- | --- |
| `/soundcraft-plugin:soundcraft` | Building, editing, mixing and rendering anything in SoundCraft through MCP |
| `/soundcraft-plugin:procedural-audio` | Synthesized SFX, granular textures, variation sets, physics-driven sounds |

Claude loads them automatically when a request matches; the slash commands force them. In Claude Code the MCP
tools appear as `mcp__plugin_soundcraft-plugin_soundcraft__<tool>`.

## Troubleshooting

- **The `soundcraft` server fails to start**: `soundcraft-cli` wasn't found. Run `install-cli.sh` (step 2) or
  set `cli_path`, then `/reload-plugins`. The launcher's stderr (`claude --debug` or `/mcp`) lists every place
  it looked.
- **Changes don't show in the app**: the server started headless. Start the app with `--control 7801`, then
  `/reload-plugins`; or set `mode` to `connect` to make a missing app an error instead.
- **A bounce reports `-144` dB**: it rendered silence. Usually MIDI notes outside their clip, a sampler
  `start` past the end of the sound, or a muted track.
- **`screenshot` / `click` fail**: those tools need the connected app.
- **Reads or writes refused**: the path is outside `read_roots` / `write_roots`.

## Repository layout

```
.claude-plugin/plugin.json        plugin manifest and userConfig options
.claude-plugin/marketplace.json   marketplace "soundcraft" listing this repo root as the plugin
.mcp.json                         registers the soundcraft MCP server (via scripts/start-mcp.sh)
scripts/start-mcp.sh              finds soundcraft-cli, maps the options to flags, execs `soundcraft-cli mcp`
scripts/install-cli.sh            installs soundcraft-cli from the official release, SHA-256 verified
skills/soundcraft/                SoundCraft over MCP (+ references/mcp-tools.md)
skills/procedural-audio/          vendored from a5c-ai/babysitter (MIT) + SoundCraft references
```

## Development

- Load the working copy as a plugin (the root `.mcp.json` only works as a plugin, where `${CLAUDE_PLUGIN_ROOT}`
  is set; decline it if Claude Code offers it as a project server):
  ```bash
  claude --plugin-dir .
  ```
- Validate:
  ```bash
  claude plugin validate .
  ```
- Smoke-test the server without Claude (headless, prints the tool list):
  ```bash
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"0"}}}' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | SOUNDCRAFT_PLUGIN_MODE=headless bash scripts/start-mcp.sh
  ```
- Bump `version` in `.claude-plugin/plugin.json` for every release; installed users only get updates when it
  changes. Bump `DEFAULT_VERSION` in `scripts/install-cli.sh` after testing a new SoundCraft release, and
  re-check the command ids and plugin parameters in the skill references (`soundcraft-cli commands --json`,
  `soundcraft-cli run --cmd 'engine.plugins={}'`).

## License

MIT, see [LICENSE](LICENSE). `skills/procedural-audio/` keeps its upstream MIT notice (A5C AI); see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). SoundCraft itself is Apache-2.0 and is not bundled.
