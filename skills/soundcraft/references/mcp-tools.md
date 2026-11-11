# soundcraft MCP tools (SoundCraft 0.19.0)

## Tools

| Tool | Arguments | Notes |
|---|---|---|
| `list_commands` | `filter?` (substring of id or label) | 483 engine commands: id, label, menu, shortcut, params doc, enabled |
| `execute` | `command`, `params?` | One engine command |
| `batch` | `calls: [{command, params}]` (≤ 1000), `keep_going?` | In order; any failure → `isError`; with `keep_going` the rest still run |
| `inspect_session` | `detail?: summary\|full` | Tracks, clips, sources (`loaded`), mixer, inserts, sends, automation, markers, tempo, selection |
| `new_session` | `name?`, `sample_rate?`, `template?: blank\|demo` | |
| `open_session` | `path` | Returns `missing`: media that could not be loaded |
| `save_session` | `path`, `replace?` | `.scraft`; won't overwrite another file without `replace` |
| `import_audio` | `path`, `track?`, `at?` | WAV, AIFF, FLAC, MP3, OGG, AAC/M4A, ALAC, CAF |
| `bounce_mix` | `path`, `format?: wav\|aiff\|flac`, `bit_depth?`, `start?`, `end?`, `normalize?` | Returns `peak_db`, `true_peak_db`, `lufs`, `seconds`, `bytes` |
| `parity` | | Feature-parity report |
| `screenshot`, `ui_inspect`, `ui_set`, `menu_invoke`, `click`, `drag`, `key` | | **Connected app only** |

Resources: `soundcraft://session` (full session JSON), `soundcraft://commands`.

## Most used commands

Run with `execute {command, params}`. `list_commands {filter: "<id>"}` shows the full params doc.

| Area | Commands |
|---|---|
| Session | `session.new`, `session.open`, `session.save {path?, replace?}`, `session.inspect`, `event.tempo {bpm, at?}` |
| Tracks | `track.new {kind: audio\|aux\|midi\|instrument\|…, name?, format?: mono\|stereo, instrument?}`, `track.rename`, `track.duplicate`, `track.delete`, `track.output {output: main\|bus}` |
| Instruments | `mix.instrument {track, plugin, params}`, `mix.instrument_param {track, param, value}`, `mix.sampler_load {track, path, params}` |
| MIDI | `midi.new_clip {track, start?, end?\|length?}` → `{clip}`, `midi.note_add {clip, pitch, start_ticks, length_ticks?: 480, velocity?: 100}`, `midi.note_edit`, `midi.notes {clip}`, `file.import_midi` |
| Mixer | `mix.volume {tracks, db}`, `mix.pan {tracks, pan}`, `mix.mute`, `mix.solo`, `mix.insert {track, slot?, plugin, params}`, `mix.insert_params`, `mix.insert_bypass`, `mix.new_bus {name}`, `mix.send {track, bus, level_db?}` |
| Automation | `automation.set_point {track, param, at, value}`, `automation.write_range`, `automation.clear`, `automation.thin` |
| Editing | `edit.separate {tracks, at}`, `edit.separate_on_grid`, `edit.separate_at_transients`, `edit.fades_create`, `edit.duplicate`, `edit.consolidate`, `edit.undo`, `edit.redo` |
| Clips | `clip.gain {clips, db}`, `clip.loop {clips, count?\|length?\|fill?}`, `clip.place_source {source, track?, at?}`, `clip.rename`, `clip.inspect {clip}` |
| Offline | `audiosuite.process {process, clips: [id], params}` (plugin ids, `signal_generator`, `reverse`, `normalize`, `gain`, `time_stretch`, `pitch_shift`, `varispeed`, `speed_ramp`, …) |
| Render | `file.bounce_mix {path, format?, bit_depth?, start?, end?, source?: main\|bus}`, `file.bounce_stems {dir}`, `track.bounce`, `track.freeze` |
| Discovery | `engine.plugins` (built-in plugins with every parameter), `engine.commands {filter?}`, `engine.clap_plugins`, `engine.vst3_plugins` |
| Transport (app) | `transport.play`, `transport.stop`, `transport.locate {at}`, `transport.status` |

## Built-in plugins

EQ: `eq_1band`, `eq_7band` · Dynamics: `compressor`, `expander_gate`, `de_esser`, `maximizer`,
`channel_strip` · Reverb: `room_reverb`, `plate_reverb` · Delay: `mod_delay` · Modulation: `auto_pan`,
`chorus`, `flanger`, `phaser`, `ring_mod` · Harmonic: `saturator`, `lofi`, `rectifier`, `subharmonic` ·
Pitch: `pitch_shifter` · Other: `time_shift`, `gain`, `trim`, `invert`, `dc_offset_removal`,
`signal_generator`, `dither` · Instruments: `subtractive_synth`, `drum_synth`, `sampler`.

## Command-line equivalents

Useful for quick checks outside MCP (the same engine):

```sh
soundcraft-cli commands bounce                   # search commands
soundcraft-cli describe mix.insert               # one command's params
soundcraft-cli run --cmd 'track.new={"kind":"instrument","name":"Zap","instrument":"subtractive_synth"}' --bounce out.wav
soundcraft-cli info out.wav                      # format of a rendered file
```
