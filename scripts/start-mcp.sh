#!/bin/bash
# Starts the SoundCraft MCP server (`soundcraft-cli mcp`) for the plugin's `soundcraft` server.
#
# Options come from the plugin's userConfig. .mcp.json maps them into SOUNDCRAFT_PLUGIN_* through
# ${user_config.KEY}; CLAUDE_PLUGIN_OPTION_<KEY> is read as a fallback. A `multiple: true` option
# arrives as one string, its items joined with commas; JSON arrays and newline-separated lists work too.
#
# Modes:
#   connect   soundcraft-cli mcp --connect PORT          drives `soundcraft --control PORT` live
#   headless  soundcraft-cli mcp [--demo] [roots...]     in-process engine, no window, no audio device
#   auto      connect if something listens on 127.0.0.1:PORT, else headless (the CLI has no fallback
#             of its own, so this script probes the port)
#
# Claude Code may launch MCP servers without the user's shell profile, so ~/.local/bin is often not
# on PATH. This searches the usual install folders. Set SOUNDCRAFT_CLI to force a binary.
# stdout belongs to the MCP protocol: diagnostics go to stderr only.
set -euo pipefail

# Keep the real stdout on fd 3 for the CLI; everything this script prints goes to stderr.
exec 3>&1 1>&2

script_dir="${BASH_SOURCE[0]%/*}"
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir=.
ROOT="$(cd "$script_dir/.." && pwd)"
DEFAULT_PORT=7801

log() { echo "soundcraft-plugin: $*" >&2; }

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# opt NAME DEFAULT: SOUNDCRAFT_PLUGIN_NAME, then CLAUDE_PLUGIN_OPTION_NAME, then DEFAULT.
# An unsubstituted "${user_config.x}" placeholder counts as unset.
opt() {
  local name="$1" default="${2:-}" v var
  for var in "SOUNDCRAFT_PLUGIN_$name" "CLAUDE_PLUGIN_OPTION_$name"; do
    v="$(trim "${!var:-}")"
    if [[ -n "$v" && "$v" != *'${user_config.'* ]]; then
      printf '%s' "$v"
      return
    fi
  done
  printf '%s' "$default"
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' 2>/dev/null || printf '%s' "$1"; }

truthy() {
  case "$(lower "$1")" in
    true | 1 | yes | on) return 0 ;;
    *) return 1 ;;
  esac
}

expand_tilde() {
  local p="$1"
  if [[ "$p" == "~" ]]; then
    p="${HOME:-}"
  elif [[ "$p" == "~/"* ]]; then
    p="${HOME:-}/${p#"~/"}"
  fi
  printf '%s' "$p"
}

# parse_roots VALUE: prints one root per line (~ expanded).
parse_roots() {
  local raw item
  raw="$(trim "$1")"
  [[ -z "$raw" || "$raw" == "[]" ]] && return 0
  # A single folder whose name contains a comma: take the whole value when it is an existing folder.
  if [[ "$raw" != "["* && "$raw" != *$'\n'* && -d "$(expand_tilde "$raw")" ]]; then
    expand_tilde "$raw"
    echo
    return 0
  fi
  local -a items=()
  if [[ "$raw" == "["*"]" ]]; then
    # JSON array of strings.
    local rest="${raw#[}" re='^[[:space:]]*"(([^"\\]|\\.)*)"[[:space:]]*,?(.*)$'
    rest="${rest%]}"
    while [[ "$rest" =~ $re ]]; do
      item="${BASH_REMATCH[1]}"
      rest="${BASH_REMATCH[3]}"
      item="${item//\\\"/\"}"
      item="${item//\\\//\/}"
      item="${item//\\\\/\\}"
      items+=("$item")
    done
  elif [[ "$raw" == *$'\n'* ]]; then
    while IFS= read -r item; do items+=("$item"); done <<<"$raw"
  else
    local IFS=','
    read -r -d '' -a items <<<"$raw" || true
  fi
  for item in "${items[@]+"${items[@]}"}"; do
    item="$(trim "$item")"
    [[ -z "$item" ]] && continue
    expand_tilde "$item"
    echo
  done
}

# ---- locate soundcraft-cli ----------------------------------------------------------------------
usable() { [[ -n "$1" && -f "$1" && -x "$1" ]]; }

cli_path="$(expand_tilde "$(opt CLI_PATH "")")"
if [[ -n "$cli_path" && -d "$cli_path" ]]; then
  cli_path="${cli_path%/}/soundcraft-cli"
fi

candidates=("$cli_path" "${SOUNDCRAFT_CLI:-}" "$(command -v soundcraft-cli 2>/dev/null || true)")
[[ -n "${CLAUDE_PLUGIN_DATA:-}" ]] && candidates+=("$CLAUDE_PLUGIN_DATA/bin/soundcraft-cli")
if [[ -n "${HOME:-}" ]]; then
  candidates+=("$HOME/.local/bin/soundcraft-cli" "${CARGO_HOME:-$HOME/.cargo}/bin/soundcraft-cli")
fi
candidates+=(
  "/usr/bin/soundcraft-cli"
  "/usr/local/bin/soundcraft-cli"
  "/opt/homebrew/bin/soundcraft-cli"
)

if [[ -n "$cli_path" ]] && ! usable "$cli_path"; then
  log "the cli_path option ($cli_path) is not an executable file; searching the usual places instead."
fi
if [[ -n "${SOUNDCRAFT_CLI:-}" ]] && ! usable "$SOUNDCRAFT_CLI"; then
  log "SOUNDCRAFT_CLI ($SOUNDCRAFT_CLI) is not an executable file; searching the usual places instead."
fi

CLI=""
for c in "${candidates[@]}"; do
  if usable "$c"; then
    CLI="$c"
    break
  fi
done

if [[ -z "$CLI" ]]; then
  log "soundcraft-cli not found."
  log "Checked: the cli_path option, \$SOUNDCRAFT_CLI, PATH, \${CLAUDE_PLUGIN_DATA}/bin, ~/.local/bin, ~/.cargo/bin, /usr/bin, /usr/local/bin, /opt/homebrew/bin."
  log "On macOS SoundCraft.app does not include it; it is a separate release download. Install it with:"
  log "  bash \"$ROOT/scripts/install-cli.sh\""
  log "or set the plugin's cli_path option (or SOUNDCRAFT_CLI) to its absolute path, then run /reload-plugins."
  exit 1
fi

# ---- build the arguments ------------------------------------------------------------------------
mode="$(lower "$(opt MODE auto)")"
case "$mode" in
  auto | connect | headless) ;;
  *)
    log "unknown mode '$mode' (expected auto, connect or headless); using auto."
    mode=auto
    ;;
esac

port="$(opt CONTROL_PORT "$DEFAULT_PORT")"
port="${port%.0}"
if ! [[ "$port" =~ ^[0-9]+$ ]] || ((10#$port < 1 || 10#$port > 65535)); then
  log "control_port '$port' is not a port number (1-65535); using $DEFAULT_PORT."
  port=$DEFAULT_PORT
fi
port=$((10#$port))

read_roots=()
write_roots=()
while IFS= read -r r; do [[ -n "$r" ]] && read_roots+=("$r"); done < <(parse_roots "$(opt READ_ROOTS "")")
while IFS= read -r r; do [[ -n "$r" ]] && write_roots+=("$r"); done < <(parse_roots "$(opt WRITE_ROOTS "")")

if ((${#read_roots[@]} + ${#write_roots[@]} > 0)); then
  if [[ "$mode" != headless ]]; then
    # soundcraft-cli refuses --connect together with the root flags, and the desktop app has no
    # confinement flags of its own yet.
    log "read/write roots are set: they confine the headless engine only, so starting headless."
  fi
  missing=0
  for r in "${read_roots[@]+"${read_roots[@]}"}" "${write_roots[@]+"${write_roots[@]}"}"; do
    if [[ ! -d "$r" ]]; then
      log "root folder does not exist: $r"
      missing=1
    fi
  done
  if ((missing)); then
    log "Create the folder(s) or fix the read_roots / write_roots options, then run /reload-plugins."
    exit 1
  fi
  mode=headless
fi

if [[ "$mode" == auto ]]; then
  if (exec 4<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
    mode=connect
  else
    log "nothing is listening on 127.0.0.1:$port (start the app with: open -a SoundCraft --args --control $port); starting headless."
    mode=headless
  fi
fi

args=(mcp)
if [[ "$mode" == connect ]]; then
  args+=(--connect "$port")
else
  truthy "$(opt DEMO false)" && args+=(--demo)
  for r in "${read_roots[@]+"${read_roots[@]}"}"; do args+=(--automation-read-root "$r"); done
  for r in "${write_roots[@]+"${write_roots[@]}"}"; do args+=(--automation-write-root "$r"); done
fi

log "starting $CLI ${args[*]}"
exec "$CLI" "${args[@]}" 1>&3 3>&-
