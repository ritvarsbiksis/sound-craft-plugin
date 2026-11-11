# Changelog

## 0.1.0 — 2026-11-11

- `soundcraft` MCP server: `scripts/start-mcp.sh` runs `soundcraft-cli mcp`, driving a running SoundCraft
  (`--control 7801`) or a headless engine; options `mode`, `control_port`, `cli_path`, `demo`,
  `read_roots`, `write_roots`.
- `scripts/install-cli.sh`: installs `soundcraft-cli` 0.19.0 from the official release, SHA-256 verified.
- `soundcraft` skill (+ `references/mcp-tools.md`).
- `procedural-audio` skill vendored from a5c-ai/babysitter (MIT) with SoundCraft references for synthesis,
  granular processing, procedural variation and physics-driven sound.
