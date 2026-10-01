#!/usr/bin/env bash
# GLM-5.3-Flash: download zai-org/GLM-5.3-Flash and convert to int4-gs64.
# Peak disk is the output (~195 GB) plus one source shard, not the 328 GB repo.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

usage() {
  cat <<'EOF'
Usage: ./download/glm53-flash.sh [DEST]

Downloads zai-org/GLM-5.3-Flash one shard at a time and writes the colibri
int4-gs64 container (~195 GB). Dense weights stay BF16. With no DEST, weights
go to models/glm53-flash. A second run resumes.

Installs numpy, torch, safetensors, and huggingface_hub into .venv.
A gated repo needs a Hugging Face token: hf auth login, or HF_TOKEN.
EOF
}

take_dest glm53-flash "$@"
echo "downloading and converting zai-org/GLM-5.3-Flash"
echo "  -> ${DEST}"
echo "  a second run resumes"
ensure_download_python numpy torch safetensors huggingface_hub
"$DOWNLOAD_PYTHON" "$ROOT/c/tools/convert_glm53.py" --outdir "$DEST"
echo "ready: ${DEST}"
echo "  ./start.sh --model ${DEST}"
