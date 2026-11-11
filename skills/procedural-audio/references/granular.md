# Granular processing in SoundCraft

SoundCraft has no dedicated granular engine. Build grains from two parts it does have: the **Sampler**
(play a short window of a source file per MIDI note) and **clip editing** (slice, scatter, fade, pitch).
Checked against SoundCraft 0.19.0.

## 1. Get a source file

Grains need a file on disk. Use an existing recording (`import_audio` / `file.import_audio`), or render
one: build the material (see synthesis.md), then `file.bounce_mix {path: ".../source.wav"}`. With write
roots set, the path must be inside one.

## 2. Sampler grains (pitch, density, position)

```json
[
  {"command": "track.new", "params": {"kind": "instrument", "name": "Grains", "format": "stereo", "instrument": "sampler"}},
  {"command": "mix.sampler_load", "params": {"track": "Grains", "path": "/abs/source.wav",
    "params": {"play_mode": 1, "start": 40, "attack": 2, "decay": 60, "sustain": 0, "release": 40}}},
  {"command": "midi.new_clip", "params": {"track": "Grains", "start": {"seconds": 0}, "end": {"seconds": 4}}}
]
```

Then one `midi.note_add` per grain on the returned clip id. The grain parameters map to:

| Granular parameter | SoundCraft control |
|---|---|
| Grain size | sampler `decay` + `release` with `sustain` 0 and `play_mode` 1 (One Shot), or `length_ticks` with Gate |
| Grain envelope | `attack` (0.1–5000 ms) and `release`; 2–10 ms avoids clicks |
| Position in the source | `start` (0–100 % of the file). It is one value per track, so for several positions use several sampler tracks (duplicate with `track.duplicate`, then `mix.instrument_param {param: "start"}` on each) |
| Pitch / pitch spread | note `pitch` relative to `root_note` (default 60), plus `transpose` / `fine_tune`; `key_track` 0 keeps pitch fixed |
| Density | how many notes per second; 960 ticks = one quarter note (0.5 s at 120 BPM), so a 20 ms grain spacing is about 38 ticks |
| Amplitude jitter | note `velocity` (with sampler `velocity` sensitivity > 0) |
| Stereo spread | several tracks with different `mix.pan` |
| Texture / cloud | `loop_mode` 1 or 2 with a short `loop_start`…`loop_end` window, long notes |

Generate note lists in code (seeded, see variation.md) and send them in one `batch` (≤ 1000 calls; split
larger clouds).

## 3. Clip-based grains (scatter and rearrange)

1. Put the source on an audio track (`file.import_audio {path, track}` or `clip.place_source {source, track, at}`).
2. Slice: `edit.separate_on_grid {tracks, start, end}` (grid from the session, default 1/16 note) or
   `edit.separate {tracks, at}` at computed positions, or `edit.separate_at_transients {sensitivity}`.
3. Shape each slice: `edit.fades_create {clip, side: "in"|"out", length: samples, shape}`.
4. Transform slices one by one with `audiosuite.process {process, clips: [id], params}`:
   `reverse`, `pitch_shift {semitones}`, `time_stretch {ratio}`, `varispeed {speed}`, `gain {db}`.
5. Read clip ids and positions from `inspect_session` (or `track.inspect {track}`) before moving or
   processing them; never guess ids.

## 4. Freeze the result

`track.bounce {tracks}` or `track.commit {tracks}` turns a grain track into audio, which you can then
re-sample (load into another sampler) for a second generation of grains.

## Finish

`bounce_mix` and check `peak_db` / `lufs` (−144 = silence: usually `start` points past the sound in the
source). Dense clouds stack up: watch `true_peak_db` and add `maximizer {ceiling: -1}` if needed.
