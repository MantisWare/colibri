#!/usr/bin/env bash
# GLM-5.3-Flash MLX (orcarouter/GLM-5.3-Flash-MLX).
# The repo root mirrors 4-bit/. The other quants live in subfolders.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

usage() {
  cat <<'EOF'
Usage: ./download/glm53-flash-mlx.sh [DEST] [--bits QUANT]

Downloads orcarouter/GLM-5.3-Flash-MLX. Default quant is 4-bit, the build
mirrored at the repo root (~204 GB). A second run resumes.

  --bits 4-bit       recommended default, files land in DEST          ~204 GB
  --bits 6-bit       files land in DEST/6-bit                         ~296 GB
  --bits 3-bit       files land in DEST/3-bit                         ~184 GB
  --bits 2-bit       files land in DEST/2-bit                         ~145 GB
  --bits 2bit-lite   files land in DEST/2bit-lite                     ~102 GB

With no DEST, weights go to models/glm53-flash-mlx-<bits>.

These are MLX weights (Apple Silicon). The colibri engine reads the container
from ./download/glm53-flash.sh.
EOF
}

BITS="4-bit"
DEST_ARG=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --bits)
      if [[ $# -lt 2 || -z "${2:-}" || "$2" == --* ]]; then
        echo "--bits needs a quant: 4-bit, 6-bit, 3-bit, 2-bit, or 2bit-lite" >&2
        exit 2
      fi
      BITS="$2"
      shift 2
      ;;
    --bits=*)
      BITS="${1#*=}"
      shift
      ;;
    *)
      DEST_ARG+=("$1")
      shift
      ;;
  esac
done

case "$BITS" in
  4|4-bit) BITS="4-bit" ;;
  6|6-bit) BITS="6-bit" ;;
  3|3-bit) BITS="3-bit" ;;
  2|2-bit) BITS="2-bit" ;;
  lite|2bit-lite) BITS="2bit-lite" ;;
  *)
    echo "unknown quant: ${BITS}" >&2
    echo "choose 4-bit, 6-bit, 3-bit, 2-bit, or 2bit-lite" >&2
    exit 2
    ;;
esac

if [[ ${#DEST_ARG[@]} -gt 0 ]]; then
  take_dest "glm53-flash-mlx" "${DEST_ARG[@]}"
else
  take_dest "glm53-flash-mlx-${BITS}"
fi

if [[ "$BITS" == "4-bit" ]]; then
  HF_SNAPSHOT_QUIET_READY=1 hf_snapshot \
    "orcarouter/GLM-5.3-Flash-MLX" \
    "$DEST" \
    "" \
    "" \
    "2-bit/*,2bit-lite/*,3-bit/*,4-bit/*,6-bit/*"
  echo "ready: ${DEST}"
  echo "  4-bit MLX weights (repo root)"
else
  HF_SNAPSHOT_QUIET_READY=1 hf_snapshot \
    "orcarouter/GLM-5.3-Flash-MLX" \
    "$DEST" \
    "" \
    "${BITS}/*,README.md" \
    ""
  echo "ready: ${DEST}/${BITS}"
  echo "  ${BITS} MLX weights"
fi
