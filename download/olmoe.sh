#!/usr/bin/env bash
# OLMoE: download allenai/OLMoE-1B-7B-0125-Instruct and convert to merged int8.
# About 7 GB out. Source shards are deleted after each one is converted.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

usage() {
  cat <<'EOF'
Usage: ./download/olmoe.sh [DEST]

Downloads allenai/OLMoE-1B-7B-0125-Instruct one shard at a time and writes the
merged int8 container (~7 GB). With no DEST, weights go to models/olmoe.
A second run resumes.

Installs numpy, torch, safetensors, and huggingface_hub into .venv.
A gated repo needs a Hugging Face token: hf auth login, or HF_TOKEN.
EOF
}

take_dest olmoe "$@"
echo "downloading and converting allenai/OLMoE-1B-7B-0125-Instruct"
echo "  -> ${DEST}"
echo "  a second run resumes"
ensure_download_python numpy torch safetensors huggingface_hub
"$DOWNLOAD_PYTHON" "$ROOT/c/tools/convert_olmoe_merged.py" \
  --repo allenai/OLMoE-1B-7B-0125-Instruct \
  --out "$DEST"
echo "ready: ${DEST}"
echo "  ./start.sh --model ${DEST}"
