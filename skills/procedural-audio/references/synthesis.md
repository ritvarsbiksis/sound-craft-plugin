# Synthesis in SoundCraft

Checked against SoundCraft 0.19.0 (`soundcraft-cli`). Run commands with the MCP `execute` tool (one) or
`batch` (several, in order). Ids are returned by each call; never assume them.

## Sound sources

| Source | How | Use for |
|---|---|---|
| Signal generator (offline) | `audiosuite.process {process: "signal_generator", tracks: [audio track], start, end, params}` | Raw tones, noise beds, sweeps cut from tones, layers for impacts/whooshes |
| Subtractive synth | instrument track, `instrument: "subtractive_synth"` + MIDI notes | Tonal FX (zaps, UI blips, risers, pads, bass) |
| Drum synth | instrument track, `instrument: "drum_synth"` + MIDI notes | Percussive transients, hits, clicks, cymbal-like noise tails |
| Sampler | instrument track + `mix.sampler_load` | Playing rendered material back as grains or pitched one-shots (see granular.md) |

### Signal generator params

`waveform` 0 Sine · 1 Square · 2 Saw · 3 Triangle · 4 White Noise · 5 Pink Noise; `freq` 20–20000 Hz;
`level` −96–0 dB. It writes a new clip on each audio track in `tracks` and returns `{"clips":[id]}`.

### Subtractive synth params (`mix.instrument` / `mix.instrument_param`)

| id | range | default |
|---|---|---|
| `osc1_wave`, `osc2_wave` | 0 Saw · 1 Square · 2 Sine · 3 Triangle | 0 |
| `osc2_semitones` | −24…24 | 0 |
| `osc2_detune` | −100…100 cents | 7 |
| `osc_mix` | 0…100 % | 50 |
| `cutoff` | 20…20000 Hz | 2000 |
| `resonance` | 0…100 % | 20 |
| `filter_env_amount` | −100…100 % | 30 |
| `amp_attack` / `amp_decay` / `amp_release` | ms (0.5…5000 / 1…5000 / 1…10000) | 5 / 200 / 300 |
| `amp_sustain` | 0…100 % | 70 |
| `filter_attack` / `filter_decay` / `filter_sustain` / `filter_release` | as amp | 5 / 300 / 30 / 300 |
| `glide` | 0…1000 ms | 0 |
| `velocity` | 0…100 % (velocity sensitivity) | 70 |
| `level` | −48…6 dB | −6 |

### Drum synth (GM note map)

Notes: 36 kick · 38 snare · 42 closed hat · 46 open hat · 45 tom · 49 crash. Other notes are silent.
Params: `level`, `kick_tune`, `kick_decay`, `snare_tune`, `snare_snappy`, `snare_decay`, `hat_decay`,
`open_hat_decay`, `tom_tune`, `tom_decay`, `cymbal_decay`.

## Building a synth voice

```json
[
  {"command": "track.new", "params": {"kind": "instrument", "name": "Zap", "format": "stereo", "instrument": "subtractive_synth"}},
  {"command": "mix.instrument", "params": {"track": "Zap", "plugin": "subtractive_synth", "params": {
    "osc1_wave": 0, "osc2_wave": 1, "osc2_semitones": 12, "cutoff": 1200, "resonance": 60,
    "filter_env_amount": 80, "filter_decay": 180, "amp_attack": 1, "amp_decay": 250,
    "amp_sustain": 0, "amp_release": 120, "level": 0}}},
  {"command": "midi.new_clip", "params": {"track": "Zap", "start": {"seconds": 0}, "end": {"seconds": 1}}}
]
```

`midi.new_clip` returns `{"clip": id}`. Then add notes to that id:
`midi.note_add {clip, pitch, start_ticks, length_ticks, velocity}`. **960 ticks = one quarter note**
(0.5 s at the default 120 BPM). Set tempo with `event.tempo {bpm}` when you want ticks to map to other
durations.

Recipes (starting points, then listen and adjust):

| Sound | Settings |
|---|---|
| Laser / zap | saw + square up an octave, cutoff 1200, resonance 60, filter env +80 with 150–200 ms decay, amp sustain 0, glide 80 between a high and low note |
| UI blip | sine, amp attack 1, decay 60, sustain 0, release 30; one short high note (pitch 84–96) |
| Riser | saw + saw detuned 15 cents, slow amp attack (2000+), `event.tempo_linear` or rising notes with glide; add `mod_delay` |
| Sub drop | sine, pitch 36 → 24 with glide 400, amp decay 800 |
| Wind / air | signal generator pink noise + `eq_1band` band-pass + `auto_pan`; automate the EQ `freq` |

## Effect chain

`mix.insert {track, slot?: 0..9, plugin, params}` adds a processor (returns its slot). Useful ids:
`eq_1band` (`type` 0 Peak · 1 Low Shelf · 2 High Shelf · 3 High Pass · 4 Low Pass · 5 Notch · 6 Band Pass;
`freq`, `gain`, `q` 0.1–10), `eq_7band`, `saturator` (drive, bias, tone, mix), `lofi`
(bits, sample_rate, noise, mix), `ring_mod` (`effect` 0 Ring · 1 FM · 2 Resonator+ · 3 Resonator−; `frequency` 20–5000, `resonance`,
`mod_source` 0 LFO · 1 Envelope · 2 Sample & Hold, `mod_rate`, `mod_depth`, `mix`), `rectifier`, `subharmonic`, `chorus`,
`flanger`, `phaser`, `mod_delay` (time, feedback, mix, mod_rate, mod_depth, lpf), `room_reverb` /
`plate_reverb` (mix, pre_delay, decay, size, damping…), `pitch_shifter` (semitones, cents, mix),
`compressor`, `maximizer` (threshold, ceiling, release). `engine.plugins` lists every parameter with its range.
`mix.insert_params {track, slot, params}` changes several later; unknown ids are errors.

## Change over time

Automation works on the mixer and on **insert** parameters, not on the instrument's own parameters:
`automation.set_point {track, param, at, value}` with `param` = `volume`, `pan`, `mute`, `send_a_level` or
`plugin:<slot letter>:<param id>` (slot a = 0). Example: sweep a filter by inserting `eq_1band` in slot a
and automating `plugin:a:freq`. For instrument-parameter movement, use notes (velocity, glide, pitch) or
split the sound into several notes or tracks with different settings.

## Offline processing

`audiosuite.process {process, clips: [id], params}` renders into the clip. Target **`clips` by id**
(a `tracks` + range form acts on the current selection and may process nothing). Processes: any built-in
plugin id with its params, plus `reverse`, `invert`, `normalize {target_db}`, `gain {db}`,
`time_stretch {ratio 0.25–4}`, `pitch_shift {semitones −24–24}`, `varispeed {speed 0.25–4}`,
`speed_ramp {change 0|1, selection 0|1, fades 0|1}`. Unknown params are ignored silently, so stick to these.

## Finish

`bounce_mix` (or `file.bounce_mix {path, format, bit_depth, start, end}`) and read `peak_db`, `true_peak_db`
and `lufs` from its result. −144 means silence: check the notes landed inside the clip and the track is not
muted. Aim for peaks at or below −1 dBFS; game SFX are usually delivered unnormalized around −18 to −12 LUFS
short-term so the engine mixes them.
