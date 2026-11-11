# Procedural variation in SoundCraft

Goal: many non-identical versions of one sound (footsteps, impacts, UI ticks, weapon shots) from one
recipe, reproducibly. Checked against SoundCraft 0.19.0.

## Principles

- **One recipe, explicit ranges.** Write the sound as a parameter dict, and give each varied parameter a
  range: pitch ±1–3 semitones, filter cutoff ±15–30 %, decay ±20 %, level ±1.5 dB, start offset ±5 ms.
  Bigger ranges sound like different sounds, not variations.
- **Seed everything.** Generate values in code with a fixed seed (`random.Random(seed)`) and record the
  seed and values beside each file, so a variation can be rebuilt.
- **Avoid near-repeats.** Reject a draw that is too close to the previous one (round-robin with minimum
  distance), so consecutive plays never sound identical.
- **Vary several things a little**, not one thing a lot: pitch + timbre + envelope + layer balance.

## Workflow

1. Build the base sound once (see synthesis.md / physics-driven.md) and save it:
   `save_session {path: ".../base.scraft"}`.
2. For each variation *i*:
   - `open_session` the base (or `edit.undo` back to it; every edit is undoable), or keep one session and
     only change the varied parameters;
   - send the changes in one `batch`: `mix.instrument_param` / `mix.instrument {params}`,
     `mix.insert_params {track, slot, params}`, `midi.note_edit {clip, index, pitch?, velocity?, start_ticks?}`,
     `mix.volume {tracks, db}`, `mix.pan`, `clip.gain {clips, db}`;
   - `bounce_mix {path: ".../<name>_<nn>.wav"}` and keep its `peak_db` / `lufs`.
3. Write a manifest (JSON or CSV) next to the files: name, seed, parameter values, peak, LUFS.

Alternative for many short variants: lay them out on the timeline (variation *i* at *i* × 1 s), then
`file.bounce_mix {path, start, end}` per slot, or `file.bounce_stems {dir}` with one track per variant.

Layered sounds: keep each layer on its own track and vary the layer balance (`mix.volume`) and which
layers play, as well as their parameters.

## Quality checks

- Loudness spread: all variants of one sound within about ±1.5 LU of each other (`lufs` from the
  bounce). Correct outliers with `mix.volume` and re-bounce rather than normalizing each to peak.
- No silence (−144) and no clipping (`true_peak_db` > −1).
- Listen to at least the extremes of each range.

## Naming

`<category>_<sound>_<variant two digits>.wav`, e.g. `impact_wood_light_03.wav`; lowercase, no spaces,
same sample rate and bit depth for the whole set (`file.bounce_mix {format: "wav", bit_depth: 24}`).
