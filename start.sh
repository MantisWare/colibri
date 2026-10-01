#!/usr/bin/env bash
# Start colibrì from the repository root.
#
#   cp start.conf.example start.conf   # set MODEL= to the weights directory
#   ./start.sh                         # chat
#   ./start.sh web                     # API + dashboard, opens a browser
#   ./start.sh serve                   # API + dashboard, no browser
#   ./start.sh --model /nvme/glm52_i4 --metal chat
#
# coli reads config.json and picks the engine, so the same command runs any
# family. Flags this script does not recognize are passed through to coli.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

usage() {
  cat <<'EOF'
Usage: ./start.sh [options] [command] [coli args...]

Command (default: chat, or MODE in start.conf):
  chat     interactive chat
  web      API + dashboard, opens a browser
  serve    API + dashboard, no browser
  doctor   read-only readiness check
  plan     show RAM / disk / GPU placement
  info     model and machine summary
  tune     measure and save a tuning profile
  run      one-shot generation; the remaining words are the prompt

Options:
  --model PATH    weights directory (the folder with config.json)
  --ram N         RAM budget in GB (omit to let coli choose)
  --topp P        adaptive expert top-p
  --topk N        fixed expert top-k
  --cap N         cache slots per layer
  --metal         set COLI_METAL=1 (binary built with ./build.sh --metal)
  --no-metal      leave the run on the CPU
  --mirror PATH   second copy of the weights (COLI_MODEL_MIRROR)
  --gpu SPEC      auto, none, or a device list such as 0,1
  --vram N        VRAM budget in GB
  --policy NAME   quality, balanced, or experimental-fast
  --host ADDR     web/serve bind address
  --port N        web/serve port
  -h, --help      show this help

Model, in order: --model, then MODEL in start.conf, then COLI_MODEL.
Copy start.conf.example to start.conf to keep a default.
Anything else is passed to coli, for example: ./start.sh chat --effort high
EOF
}

MODEL=""
MODE=""
RAM=""
TOPP=""
TOPK=""
CAP=""
METAL=""
MIRROR=""
GPU=""
VRAM=""
POLICY=""
HOST=""
PORT=""
EXTRA=()

assign_setting() {
  key="$1"
  value="$2"
  case "$key" in
    MODEL) MODEL="$value" ;;
    MODE) MODE="$value" ;;
    RAM) RAM="$value" ;;
    TOPP) TOPP="$value" ;;
    TOPK) TOPK="$value" ;;
    CAP) CAP="$value" ;;
    METAL)
      case "$value" in
        1|true|yes|on) METAL=1 ;;
        0|false|no|off|"") METAL=0 ;;
        *)
          echo "start.conf: METAL must be 1 or 0 (got ${value})" >&2
          exit 2
          ;;
      esac
      ;;
    MIRROR) MIRROR="$value" ;;
    GPU) GPU="$value" ;;
    VRAM) VRAM="$value" ;;
    POLICY) POLICY="$value" ;;
    HOST) HOST="$value" ;;
    PORT) PORT="$value" ;;
    *)
      echo "start.conf: unknown setting ${key}" >&2
      exit 2
      ;;
  esac
}

load_conf() {
  file="$1"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    case "$line" in
      ""|[[:space:]]'#'*) continue ;;
    esac
    case "$line" in
      export[[:space:]]*) line="${line#export}" ;;
    esac
    line="${line#"${line%%[![:space:]]*}"}"
    case "$line" in
      ""|'#'*) continue ;;
    esac
    case "$line" in
      *=*) ;;
      *)
        echo "start.conf: expected KEY=value, got: ${line}" >&2
        exit 2
        ;;
    esac
    key="${line%%=*}"
    value="${line#*=}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    if [[ "$value" == \"*\" ]]; then
      value="${value#\"}"
      value="${value%\"}"
    elif [[ "$value" == \'*\' ]]; then
      value="${value#\'}"
      value="${value%\'}"
    fi
    assign_setting "$key" "$value"
  done < "$file"
}

if [[ -f "$ROOT/start.conf" ]]; then
  load_conf "$ROOT/start.conf"
fi

need_value() {
  if [[ $# -lt 2 || -z "${2:-}" || "$2" == --* ]]; then
    echo "$1 needs a value" >&2
    exit 2
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --model) need_value "$@"; MODEL="$2"; shift 2 ;;
    --ram) need_value "$@"; RAM="$2"; shift 2 ;;
    --topp) need_value "$@"; TOPP="$2"; shift 2 ;;
    --topk) need_value "$@"; TOPK="$2"; shift 2 ;;
    --cap) need_value "$@"; CAP="$2"; shift 2 ;;
    --metal) METAL=1; shift ;;
    --no-metal) METAL=0; shift ;;
    --mirror) need_value "$@"; MIRROR="$2"; shift 2 ;;
    --gpu) need_value "$@"; GPU="$2"; shift 2 ;;
    --vram) need_value "$@"; VRAM="$2"; shift 2 ;;
    --policy) need_value "$@"; POLICY="$2"; shift 2 ;;
    --host) need_value "$@"; HOST="$2"; shift 2 ;;
    --port) need_value "$@"; PORT="$2"; shift 2 ;;
    --mode) need_value "$@"; MODE="$2"; shift 2 ;;
    chat|web|serve|doctor|plan|info|tune|run) MODE="$1"; shift ;;
    *) EXTRA+=("$1"); shift ;;
  esac
done

if [[ -z "$MODE" ]]; then
  MODE=chat
fi

case "$MODE" in
  chat|web|serve|doctor|plan|info|tune|run) ;;
  *)
    echo "unknown command: ${MODE}" >&2
    echo "commands: chat web serve doctor plan info tune run" >&2
    exit 2
    ;;
esac

if [[ -z "$MODEL" && -n "${COLI_MODEL:-}" ]]; then
  MODEL="$COLI_MODEL"
fi

if [[ -z "$MODEL" || "$MODEL" == "/path/to/model" ]]; then
  echo "No model directory." >&2
  echo "  Set MODEL in start.conf (cp start.conf.example start.conf)," >&2
  echo "  or run:  ./start.sh --model /path/to/model ${MODE}" >&2
  exit 2
fi

if [[ ! -d "$MODEL" ]]; then
  echo "model directory not found: ${MODEL}" >&2
  exit 1
fi

if [[ ! -f "$MODEL/config.json" ]]; then
  echo "config.json is missing in ${MODEL}" >&2
  echo "coli picks the engine from that file. Copy config.json next to the shards." >&2
  exit 1
fi

if [[ ! -f "$ROOT/c/coli" ]]; then
  echo "c/coli is missing. This script starts a source checkout." >&2
  exit 1
fi

command -v python3 >/dev/null 2>&1 || {
  echo "python3 is missing. The coli launcher is a Python script." >&2
  exit 1
}

if [[ "$METAL" == "1" ]]; then
  export COLI_METAL=1
elif [[ "$METAL" == "0" ]]; then
  unset COLI_METAL || true
fi

if [[ -n "$MIRROR" ]]; then
  if [[ ! -d "$MIRROR" ]]; then
    echo "mirror directory not found: ${MIRROR}" >&2
    exit 1
  fi
  export COLI_MODEL_MIRROR="$MIRROR"
fi

args=("$MODE" --model "$MODEL")
[[ -n "$RAM" ]] && args+=(--ram "$RAM")
[[ -n "$TOPP" ]] && args+=(--topp "$TOPP")
[[ -n "$TOPK" ]] && args+=(--topk "$TOPK")
[[ -n "$CAP" ]] && args+=(--cap "$CAP")
[[ -n "$GPU" ]] && args+=(--gpu "$GPU")
[[ -n "$VRAM" ]] && args+=(--vram "$VRAM")
[[ -n "$POLICY" ]] && args+=(--policy "$POLICY")
if [[ "$MODE" == "web" || "$MODE" == "serve" ]]; then
  [[ -n "$HOST" ]] && args+=(--host "$HOST")
  [[ -n "$PORT" ]] && args+=(--port "$PORT")
fi
if [[ ${#EXTRA[@]} -gt 0 ]]; then
  args+=("${EXTRA[@]}")
fi

echo "colibri — ${MODE}" >&2
echo "  model: ${MODEL}" >&2
if [[ "$METAL" == "1" ]]; then
  echo "  metal: on" >&2
fi

exec python3 "$ROOT/c/coli" "${args[@]}"
