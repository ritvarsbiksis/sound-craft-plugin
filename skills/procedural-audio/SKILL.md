---
name: procedural-audio
description: Procedural sound skill for synthesis and dynamic sound design.
allowed-tools: Read, Grep, Write, Bash, Edit, Glob, WebFetch
graph:
  domains: [domain:gaming]
  specializations: [specialization:game-development]
  skillAreas: [skill-area:game-audio-systems, skill-area:audio-processing]
  roles: [role:game-developer]
---

# Procedural Audio Skill

Generated audio content.

## Capabilities

- Synthesis
- Granular processing
- Procedural variation
- Physics-driven sound

## Using SoundCraft (added by soundcraft-plugin)

<!-- Everything above this heading is the upstream skill, unchanged. See SOURCE.md. -->

When the `soundcraft` MCP server is available (tools `mcp__plugin_soundcraft-plugin_soundcraft__*`), build
and render the sound in SoundCraft instead of writing DSP code from scratch. Read the matching reference
before the first call; every command id and parameter in them was checked against SoundCraft 0.19.0:

| Capability | Reference |
|---|---|
| Synthesis: oscillators, noise, subtractive and drum synth, envelopes, filters, effect chains | [references/synthesis.md](references/synthesis.md) |
| Granular processing: slicing, sampler grains, scatter, density, pitch spread | [references/granular.md](references/granular.md) |
| Procedural variation: seeded randomization, round-robin sets, batch rendering | [references/variation.md](references/variation.md) |
| Physics-driven sound: impacts, scrapes, rolls; mapping velocity, mass and material to parameters | [references/physics-driven.md](references/physics-driven.md) |

Always finish with the render check in the `soundcraft` skill: `bounce_mix`, then read `peak_db` and `lufs`
from the result (silence reads -144). For anything about driving SoundCraft in general, load the
`soundcraft` skill.
