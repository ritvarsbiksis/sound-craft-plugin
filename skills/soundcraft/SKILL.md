---
name: soundcraft
description: Make, edit, mix and render audio in SoundCraft (open-source pure-Rust DAW) through the soundcraft MCP server. Use whenever the user mentions SoundCraft or a .scraft session, or asks to create a sound effect, synth sound, beat, drum pattern, MIDI part, mix, stems or a bounced WAV/AIFF/FLAC file, to process or edit audio (reverse, pitch, stretch, fades, EQ, reverb), or to check loudness, even when SoundCraft is not named. Pairs with the procedural-audio skill for synthesis, granular, variation and physics-driven sound design.
---

# SoundCraft

SoundCraft is reached through the `soundcraft` MCP server this plugin starts (`soundcraft-cli mcp`). In
Claude Code its tools are `mcp__plugin_soundcraft-plugin_soundcraft__<tool>`. Checked against 0.19.0.

## Modes

- **Headless** (default when no app listens): in-process engine, no window, no audio device. Everything
  except the app-only tools works, including bouncing.
- **Connect**: the plugin found SoundCraft running with `--control 7801` and drives the live window. Edits
  appear in the app; `screenshot`, `ui_inspect`, `ui_set`, `menu_invoke`, `click`, `drag`, `key` work.
  To use it the user starts `open -a SoundCraft --args --control 7801` (quit SoundCraft first), then
  `/reload-plugins`.

If a tool fails with "not found"/connection errors, say which mode you are in and what the user needs to
do; don't retry in a loop.

## How to work

1. **Discover, don't guess.** Every menu action is a command with an id and JSON params.
   `list_commands {filter}` (or resource `soundcraft://commands`) returns ids and a params doc;
   `execute {command: "engine.plugins"}` lists every built-in plugin with parameter ids, ranges and choices.
   See [references/mcp-tools.md](references/mcp-tools.md) for the tools and the most used commands.
2. **Run** one command with `execute {command, params}`; several in order with
   `batch {calls: [{command, params}], keep_going?}` (≤ 1000 calls; any failure makes the result an error).
3. **Use returned ids.** Tracks, clips and sources share one id counter, so ids are not predictable.
   Read them from each result (`track.new` → `{"tracks":[id]}`, `midi.new_clip` → `{"clip": id}`,
   signal generator → `{"clips":[id]}`) or from `inspect_session`. Tracks can also be named.
4. **Verify** with `inspect_session {detail: "summary"|"full"}` after structural changes.
5. **Render and measure** with `bounce_mix {path, format?, bit_depth?, start?, end?}`. Its result has
   `peak_db`, `true_peak_db`, `lufs`, `seconds`. −144 means silence. Report these numbers to the user.
6. **Save** with `save_session {path}` (`.scraft`; audio goes to `Audio Files/` beside it). It refuses to
   overwrite another file unless `replace: true`; set that only when the user asked to overwrite.

## Conventions

- Positions: samples (integer), `{"seconds": x}`, or `"bars_beats:5|1|000"`. Session default is
  48 kHz, 120 BPM, 4/4. MIDI: **960 ticks per quarter note**.
- Programmatic calls never open dialogs; empty params act on the current selection, so pass explicit
  `tracks` / `clips` instead of relying on selection.
- Every edit is undoable (`edit.undo`, `edit.redo`); prefer undo over rebuilding.
- Instruments: `track.new {kind: "instrument", instrument: "subtractive_synth"|"drum_synth"|"sampler"}`,
  then `mix.instrument {track, plugin, params}` / `mix.instrument_param {track, param, value}`; notes via
  `midi.new_clip` + `midi.note_add {clip, pitch, start_ticks, length_ticks, velocity}`.
- Drum synth notes: 36 kick, 38 snare, 42 closed hat, 46 open hat, 45 tom, 49 crash.
- Offline processing: `audiosuite.process {process, clips: [id], params}`. Target clips by id; unknown
  params are silently ignored, so use the names in the procedural-audio synthesis reference.
- Automation: `automation.set_point {track, param, at, value}`, `param` = `volume`, `pan`, `mute`,
  `send_a_level`, or an insert parameter `plugin:<slot letter>:<param id>`. Instrument parameters are not
  automatable.

## File access

If the user configured read/write roots, every file a command reads (open, import, sampler load, presets)
must be inside a read root and every file it writes (save, bounce, export) inside a write root. A refusal
names the roots: pick a path inside one instead of asking for wider access. Roots force headless mode.

## Sound design

For synthesized or generated sound (SFX, UI sounds, granular textures, variation sets, impacts driven by
physics values), load the `procedural-audio` skill and its references.

## Before you finish

- Bounced at least once and read `peak_db` / `lufs`; no silence, `true_peak_db` ≤ −1 dBFS unless asked.
- Told the user the output paths, the mode used (headless / connected app), and anything you could not do.
