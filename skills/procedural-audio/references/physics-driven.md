# Physics-driven sound in SoundCraft

Map physical inputs (impact velocity, mass, material, contact time, speed) to synthesis parameters, then
render a set of sounds that covers the range a game will ask for. Checked against SoundCraft 0.19.0.

## Mapping model

| Physical input | Audible result | SoundCraft parameter |
|---|---|---|
| Impact velocity | louder, brighter, more noise in the attack | note `velocity`; subtractive `cutoff` and `filter_env_amount`; noise-layer `mix.volume` |
| Mass / size | lower pitch, longer decay | note `pitch`; drum synth `kick_tune` / `tom_tune` / `*_decay`; subtractive `amp_decay` |
| Material: wood | short, mid-pitched, damped | drum `tom` (45) with `tom_decay` 80–200, `eq_1band` peak 600–1200 Hz |
| Material: metal | long ringing, inharmonic partials | sine/triangle synth + `ring_mod` (frequency 300–900 Hz), long `amp_release`, `plate_reverb` |
| Material: glass | high, bright, brittle | high sine notes (pitch 84–100), very short attack, `ring_mod`, short noise transient |
| Material: stone / concrete | dull, noisy, short | pink-noise burst (signal generator) + `eq_1band` low-pass, `room_reverb` small `size` |
| Contact time (soft vs hard) | slower attack, less high end | `amp_attack` 1 → 10 ms, lower `cutoff` |
| Sliding / scraping speed | noise level and band move with speed | pink noise + `eq_1band` band-pass; automate `plugin:a:freq` and `volume` along the speed curve |
| Rolling | periodic soft impacts | repeated low-velocity notes, spacing = circumference / speed |
| Distance | quieter, duller, wetter | `mix.volume`, `eq_7band` `lpf_freq`, reverb send level (`mix.send`, `send_a_level`) |

Use the same mapping functions in the game as when rendering, so a runtime value picks the right file or
blends the right layers.

## Impact recipe (layers)

1. **Transient** (0–10 ms): drum synth note (`snare` 38 for crack, `hat` 42 for click) or 5–15 ms of white
   noise from the signal generator with `edit.fades_create` out-fade.
2. **Body**: tuned drum (`tom` 45 / `kick` 36) or subtractive synth note with `amp_sustain` 0; pitch and
   decay from mass.
3. **Tail / resonance**: material layer (metal ring, glass shimmer, room reverb).

Keep each layer on its own track. Velocity drives all three: higher velocity raises transient level the
most, so hard hits sound brighter, not only louder.

## Rendering a velocity × size grid

For each (velocity tier, size tier), set the mapped parameters in one `batch`, then
`bounce_mix {path: "impact_<material>_<size>_v<tier>.wav"}`. Three to five velocity tiers and three sizes,
times a few seeded variations (variation.md), cover most game needs. Record the mapping inputs in the
manifest.

## Continuous sounds (scrape, roll, wind)

Write the control curve as automation points: `automation.set_point {track, param, at, value}` per sample
of the curve (thin afterwards with `automation.thin {tracks, tolerance}`). `param` can be `volume`, `pan`,
`mute`, send levels, or insert parameters as `plugin:<slot letter>:<id>`. Instrument parameters are not
automatable; move them with notes or several tracks.

## Finish

`bounce_mix`, then check: louder tiers really measure louder (`lufs` rises with velocity tier), no clipping
(`true_peak_db` ≤ −1), no silence (−144).
